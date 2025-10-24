/**
 * AI Processing Cloud Function for Buzzbox
 *
 * Auto-triggered on new messages to process with AI:
 * - Feature 1: Auto-categorization (fan/business/spam/urgent)
 * - Feature 4: Sentiment analysis (positive/negative/urgent/neutral)
 * - Feature 5: Opportunity scoring (0-100 for business messages)
 *
 * Processes messages sent to the creator (Andrew) only.
 * Updates message in RTDB with AI metadata.
 *
 * [Source: Epic 6 - AI-Powered Creator Inbox]
 * [Story: 6.2 - Auto-Processing Cloud Function]
 */

import {onValueWritten} from "firebase-functions/v2/database";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI from "openai";

// Creator UID constant (Andrew's Firebase Auth UID)
const CREATOR_UID = "UoLk9GtxDaaYGlI8Ah6RnCbXXbf2";

/**
 * Message data structure from RTDB
 */
interface Message {
  id: string;
  text: string;
  senderID: string;
  receiverID?: string;
  timestamp: number;
  aiCategory?: string;
  aiSentiment?: string;
  aiOpportunityScore?: number;
  aiProcessedAt?: number;
}

/**
 * Auto-triggered on new messages to process with AI
 * Features: Categorization (1), Sentiment (4), Opportunity Scoring (5)
 *
 * Trigger: RTDB onValueWritten at /messages/{conversationID}/{messageID}
 * Only processes messages sent TO the creator
 * Skip if already processed (aiCategory exists)
 * Parallel AI processing for speed (<1s target)
 */
export const processMessageAI = onValueWritten({
  ref: "/messages/{conversationID}/{messageID}",
  region: "us-central1",
  secrets: ["OPENAI_API_KEY"],
  retry: true, // Auto-retry on failure
  timeoutSeconds: 10, // 10s timeout (OpenAI can be slow)
}, async (event) => {
  const change = event.data;

  // Only process new messages or updates (not deletions)
  if (!change.after.exists()) {
    logger.info("Message deleted, skipping AI processing");
    return null;
  }

  const message = change.after.val() as Message;
  const {conversationID, messageID} = event.params;

  logger.info("🤖 AI Processing triggered", {
    conversationID,
    messageID,
    senderID: message.senderID,
    textPreview: message.text?.substring(0, 50),
  });

  // Only process messages sent TO the creator (Andrew)
  // receiverID may not exist in old messages, so also check senderID != creator
  const isToCreator = message.receiverID === CREATOR_UID ||
                      (message.senderID !== CREATOR_UID && !message.receiverID);

  if (!isToCreator) {
    logger.info("Message not sent to creator, skipping AI processing", {
      senderID: message.senderID,
      receiverID: message.receiverID,
    });
    return null;
  }

  // Skip if already processed
  if (change.after.child("aiCategory").exists()) {
    logger.info("Message already processed, skipping", {messageID});
    return null;
  }

  // Validate message text exists
  if (!message.text || typeof message.text !== "string" || message.text.trim() === "") {
    logger.warn("Message has no text, skipping AI processing", {messageID});
    return null;
  }

  try {
    // Initialize OpenAI client with secret
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    logger.info("🔄 Starting parallel AI processing...", {messageID});

    // Step 1: Run categorization and sentiment in parallel
    const [category, sentiment] = await Promise.all([
      categorizeMessage(openai, message.text),
      analyzeSentiment(openai, message.text),
    ]);

    // Step 2: Only run opportunity scoring if category is 'business'
    const score = category === "business" ?
      await scoreOpportunity(openai, message.text) :
      null;

    logger.info("✅ AI processing complete", {
      messageID,
      category,
      sentiment,
      score,
    });

    // Update message with AI metadata
    await change.after.ref.update({
      aiCategory: category,
      aiSentiment: sentiment,
      aiOpportunityScore: score,
      aiProcessedAt: admin.database.ServerValue.TIMESTAMP,
    });

    logger.info("💾 Message updated with AI metadata", {
      messageID,
      conversationID,
    });

    return {success: true};
  } catch (error) {
    // Log error but don't throw - message should still work without AI metadata
    logger.error("❌ AI processing failed", {
      messageID,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });

    // Mark as failed so we don't retry infinitely
    await change.after.ref.update({
      aiProcessingFailed: true,
      aiProcessedAt: admin.database.ServerValue.TIMESTAMP,
    });

    return {success: false, error};
  }
});

/**
 * Categorize message using GPT-4o-mini
 * Categories: fan | business | spam | urgent
 *
 * @param {OpenAI} openai - OpenAI client instance
 * @param {string} text - Message text to categorize
 * @return {Promise<string>} Category string (fan/business/spam/urgent)
 */
async function categorizeMessage(openai: OpenAI, text: string): Promise<string> {
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `You are a message categorization assistant for a tech content creator.
Categorize messages into ONE of these categories:
- fan: General fan message (appreciation, questions about content, casual chat)
- business: Business inquiry, collaboration, sponsorship, partnership
- spam: Spam, advertisements, phishing, irrelevant content
- urgent: Time-sensitive requests requiring immediate attention

Respond with ONLY the category word (lowercase).`,
      },
      {
        role: "user",
        content: text,
      },
    ],
    temperature: 0.3, // Low temperature for consistent categorization
    max_tokens: 10,
  });

  const category = completion.choices[0].message.content?.trim().toLowerCase() || "fan";

  // Validate category (fallback to 'fan' if invalid)
  if (!["fan", "business", "spam", "urgent"].includes(category)) {
    logger.warn("Invalid category returned, defaulting to fan", {
      returned: category,
      text: text.substring(0, 50),
    });
    return "fan";
  }

  return category;
}

/**
 * Analyze sentiment using GPT-4o-mini
 * Sentiments: positive | negative | urgent | neutral
 *
 * @param {OpenAI} openai - OpenAI client instance
 * @param {string} text - Message text to analyze
 * @return {Promise<string>} Sentiment string (positive/negative/urgent/neutral)
 */
async function analyzeSentiment(openai: OpenAI, text: string): Promise<string> {
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `Analyze the sentiment of this message. Choose ONE:
- positive: Friendly, appreciative, enthusiastic
- negative: Angry, disappointed, frustrated, critical
- urgent: Time-sensitive, requires immediate attention
- neutral: Informational, matter-of-fact, no strong emotion

Respond with ONLY the sentiment word (lowercase).`,
      },
      {
        role: "user",
        content: text,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const sentiment = completion.choices[0].message.content?.trim().toLowerCase() || "neutral";

  // Validate sentiment (fallback to 'neutral' if invalid)
  if (!["positive", "negative", "urgent", "neutral"].includes(sentiment)) {
    logger.warn("Invalid sentiment returned, defaulting to neutral", {
      returned: sentiment,
      text: text.substring(0, 50),
    });
    return "neutral";
  }

  return sentiment;
}

/**
 * Score business opportunities using GPT-4o-mini
 * Returns 0-100 score for business messages
 * NOTE: Only call this function for messages categorized as 'business'
 *
 * Scoring criteria:
 * - Monetary value potential
 * - Brand fit for tech content creator
 * - Legitimacy (not spam)
 * - Urgency
 *
 * @param {OpenAI} openai - OpenAI client instance
 * @param {string} text - Message text to score
 * @return {Promise<number>} Score (0-100)
 */
async function scoreOpportunity(openai: OpenAI, text: string): Promise<number> {
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: `Score this message as a business collaboration opportunity from 0-100.

Scoring criteria for a tech content creator:
- 80-100: High-value partnership (known brand, clear budget, strong fit)
- 50-79: Moderate opportunity (legitimate but needs vetting)
- 20-49: Low-value (generic pitch, unclear value)
- 0-19: Not a real business opportunity (spam, generic outreach)

If the message is clearly NOT a business inquiry (just a fan message, general question, etc.), respond with "0".

Consider:
- Monetary value potential
- Brand alignment with tech content
- Legitimacy (specific vs generic pitch)
- Urgency and clarity

Respond with ONLY a number from 0-100.`,
      },
      {
        role: "user",
        content: text,
      },
    ],
    temperature: 0.5,
    max_tokens: 10,
  });

  const scoreText = completion.choices[0].message.content?.trim() || "0";
  const score = parseInt(scoreText, 10);

  // Validate score
  if (isNaN(score) || score < 0 || score > 100) {
    logger.warn("Invalid score returned, defaulting to 50", {
      returned: scoreText,
      text: text.substring(0, 50),
    });
    return 50;
  }

  return score;
}
