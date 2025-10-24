/**
 * Conversation-Level AI Analysis Cloud Function for Buzzbox
 *
 * Analyzes entire conversations (last 100 messages) to provide:
 * - Overall sentiment (positive, negative, neutral, urgent)
 * - Fan categorization (fan, super_fan, business, spam, urgent)
 * - Business opportunity scoring (0-10, only for business category)
 *
 * Triggered when creator opens inbox, only analyzes conversations with new messages.
 *
 * [Source: Story 6.11 - Conversation-Level AI Analysis]
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI from "openai";

/**
 * Hardcoded creator UID for security check
 * TODO: Make this configurable via environment variable
 */
const CREATOR_UID = "pzkN1Va8GiWGrdKhMT6HekMTOyE2"; // andrewsheim@gmail.com

/**
 * Message data structure from RTDB
 */
interface Message {
  senderID: string;
  text: string;
  timestamp: number;
}

/**
 * Conversation analysis request structure
 */
interface AnalyzeConversationRequest {
  conversationID: string;
  forceRefresh?: boolean;
}

/**
 * Conversation analysis response structure
 */
interface AnalyzeConversationResponse {
  sentiment: string;
  category: string;
  businessScore?: number;
  cached: boolean;
}

/**
 * Analyze entire conversation for creator inbox
 * Generates conversation-level sentiment, category, and business score
 *
 * Triggered: HTTP Callable (called when creator opens inbox)
 * Input: { conversationID: string, forceRefresh?: boolean }
 * Output: { sentiment: string, category: string, businessScore?: number }
 */
export const analyzeConversation = onCall<AnalyzeConversationRequest>({
  region: "us-central1",
  secrets: ["OPENAI_API_KEY"],
  timeoutSeconds: 30, // Analyzing 100 messages may take longer
}, async (request) => {
  const {conversationID, forceRefresh} = request.data;
  const auth = request.auth;

  // Only allow creator to call this function
  if (!auth || auth.uid !== CREATOR_UID) {
    throw new HttpsError(
      "permission-denied",
      "Only the creator can analyze conversations"
    );
  }

  logger.info("📊 analyzeConversation called", {
    conversationID,
    forceRefresh,
    uid: auth.uid,
  });

  // Check if analysis already exists and is fresh
  const conversationRef = admin.database().ref(`/conversations/${conversationID}`);
  const conversationSnapshot = await conversationRef.once("value");
  const conversation = conversationSnapshot.val();

  // Skip if already analyzed and no new messages (unless force refresh)
  if (!forceRefresh && conversation?.aiAnalyzedAt) {
    const lastMessageTimestamp = conversation.lastMessageTimestamp || 0;
    const lastAnalyzedTimestamp = conversation.aiAnalyzedAt || 0;

    if (lastAnalyzedTimestamp >= lastMessageTimestamp) {
      logger.info("✅ Conversation already analyzed, no new messages", {
        conversationID,
        lastAnalyzedTimestamp,
        lastMessageTimestamp,
      });

      return {
        sentiment: conversation.aiSentiment,
        category: conversation.aiCategory,
        businessScore: conversation.aiBusinessScore,
        cached: true,
      } as AnalyzeConversationResponse;
    }
  }

  // Fetch last 100 messages for analysis
  const messagesSnapshot = await admin.database()
    .ref(`/messages/${conversationID}`)
    .orderByChild("timestamp")
    .limitToLast(100)
    .once("value");

  const messages: Message[] = [];
  messagesSnapshot.forEach((child) => {
    messages.push(child.val());
  });

  // Skip if no messages
  if (messages.length === 0) {
    logger.info("ℹ️ No messages in conversation, skipping analysis", {
      conversationID,
    });
    return {
      sentiment: "neutral",
      category: "fan",
      cached: false,
    } as AnalyzeConversationResponse;
  }

  // Initialize OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  logger.info("🔄 Starting conversation-level AI analysis...", {
    conversationID,
    messageCount: messages.length,
  });

  // Run parallel analysis
  const [sentiment, category] = await Promise.all([
    analyzeConversationSentiment(openai, messages),
    categorizeConversation(openai, messages),
  ]);

  // Only score business opportunities if category is 'business'
  const businessScore = category === "business" ?
    await scoreConversationOpportunity(openai, messages) :
    null;

  logger.info("✅ Conversation analysis complete", {
    conversationID,
    sentiment,
    category,
    businessScore,
  });

  // Update conversation with AI metadata
  await conversationRef.update({
    aiSentiment: sentiment,
    aiCategory: category,
    aiBusinessScore: businessScore,
    aiAnalyzedAt: admin.database.ServerValue.TIMESTAMP,
  });

  return {
    sentiment,
    category,
    businessScore: businessScore ?? undefined,
    cached: false,
  } as AnalyzeConversationResponse;
});

/**
 * Analyze overall conversation sentiment
 * Returns: positive | negative | neutral | urgent
 * @param {OpenAI} openai - OpenAI client instance
 * @param {Message[]} messages - Array of messages to analyze
 * @return {Promise<string>} Sentiment string
 */
async function analyzeConversationSentiment(
  openai: OpenAI,
  messages: Message[]
): Promise<string> {
  // Build conversation context (last 100 messages)
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? "Creator" : "Fan"}: ${m.text}`)
    .join("\n");

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `Analyze the overall sentiment of this conversation between a tech creator and a fan.
Choose ONE sentiment that best represents the OVERALL tone of the conversation:
- positive: Generally friendly, appreciative, enthusiastic
- negative: Frustrated, angry, disappointed, critical
- urgent: Time-sensitive, requires immediate attention
- neutral: Informational, matter-of-fact, no strong emotion

Consider the entire conversation history, not just individual messages.
Respond with ONLY the sentiment word (lowercase).`,
      },
      {
        role: "user",
        content: conversationContext,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const sentiment = completion.choices[0].message.content?.trim().toLowerCase() || "neutral";

  // Validate
  if (!["positive", "negative", "urgent", "neutral"].includes(sentiment)) {
    logger.warn("Invalid sentiment returned, defaulting to neutral", {
      returned: sentiment,
    });
    return "neutral";
  }

  return sentiment;
}

/**
 * Categorize conversation participant
 * Returns: fan | super_fan | business | spam | urgent
 * @param {OpenAI} openai - OpenAI client instance
 * @param {Message[]} messages - Array of messages to analyze
 * @return {Promise<string>} Category string
 */
async function categorizeConversation(
  openai: OpenAI,
  messages: Message[]
): Promise<string> {
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? "Creator" : "Fan"}: ${m.text}`)
    .join("\n");

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `Categorize this fan based on their conversation with a tech content creator.
Choose the SINGLE MOST RELEVANT category:
- fan: Regular fan (appreciative, asks questions, casual engagement)
- super_fan: Highly engaged fan (frequent messages, deep knowledge of content, very supportive)
- business: Business inquiry, collaboration, sponsorship, partnership opportunity
- spam: Spam, advertisements, phishing, irrelevant/inappropriate content
- urgent: Time-sensitive request requiring immediate attention (live issue, emergency, deadline)

Respond with ONLY the category word (lowercase, use underscore for super_fan).`,
      },
      {
        role: "user",
        content: conversationContext,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const category = completion.choices[0].message.content?.trim().toLowerCase() || "fan";

  // Validate
  if (!["fan", "super_fan", "business", "spam", "urgent"].includes(category)) {
    logger.warn("Invalid category returned, defaulting to fan", {
      returned: category,
    });
    return "fan";
  }

  return category;
}

/**
 * Score business opportunity for entire conversation
 * Returns: 0-10 (only called if category is 'business')
 * @param {OpenAI} openai - OpenAI client instance
 * @param {Message[]} messages - Array of messages to analyze
 * @return {Promise<number>} Score from 0-10
 */
async function scoreConversationOpportunity(
  openai: OpenAI,
  messages: Message[]
): Promise<number> {
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? "Creator" : "Fan"}: ${m.text}`)
    .join("\n");

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `Score this business collaboration opportunity from 0-10 based on the ENTIRE conversation.

Scoring criteria for a tech content creator:
- 8-10: High-value partnership (known brand, clear budget, strong fit, serious engagement)
- 5-7: Moderate opportunity (legitimate, needs vetting, shows promise)
- 2-4: Low-value (generic pitch, unclear value, minimal engagement)
- 0-1: Not a real opportunity (spam, completely generic outreach)

Consider:
- Conversation depth and engagement level
- Specificity of the opportunity (vague vs detailed)
- Brand alignment with tech content
- Professionalism and legitimacy
- Follow-through in conversation

Respond with ONLY a number from 0-10.`,
      },
      {
        role: "user",
        content: conversationContext,
      },
    ],
    temperature: 0.5,
    max_tokens: 10,
  });

  const scoreText = completion.choices[0].message.content?.trim() || "5";
  const score = parseInt(scoreText, 10);

  // Validate score
  if (isNaN(score) || score < 0 || score > 10) {
    logger.warn("Invalid score returned, defaulting to 5", {
      returned: scoreText,
    });
    return 5;
  }

  return score;
}
