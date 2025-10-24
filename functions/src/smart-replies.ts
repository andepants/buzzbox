/**
 * Context-Aware Smart Replies Cloud Function for Buzzbox
 *
 * Feature 2: Response drafting in creator's voice
 * Advanced AI Capability: Context-Aware Smart Replies (10 points)
 *
 * Generates 3 reply options (short/medium/detailed) using:
 * - Conversation context (last 20 messages)
 * - Creator's writing style from Firestore
 * - GPT-4o-mini for speed (<3s target)
 *
 * [Source: Epic 6 - AI-Powered Creator Inbox]
 * [Story: 6.4 - Context-Aware Smart Replies Cloud Function]
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI from "openai";

/**
 * Message data structure from RTDB
 */
interface Message {
  senderID: string;
  senderName?: string;
  text: string;
  timestamp: number;
}

/**
 * Creator profile data structure from Firestore
 */
interface CreatorProfile {
  personality: string;
  tone: string;
  examples: string[];
  avoid: string[];
  signature?: string;
}

/**
 * Smart reply response structure
 */
interface SmartReplyResponse {
  drafts: {
    short: string;
    medium: string;
    detailed: string;
  };
}

/**
 * Smart reply request structure
 */
interface SmartReplyRequest {
  conversationId: string;
  messageText: string;
  replyType?: "short" | "funny" | "professional"; // NEW: Single reply type
}

/**
 * Generate 3 context-aware smart replies in creator's voice
 * Features: Response Drafting (2) + Advanced AI Capability
 *
 * @return {Promise<SmartReplyResponse>} Three reply drafts
 */
export const generateSmartReplies = onCall<SmartReplyRequest>({
  region: "us-central1",
  secrets: ["OPENAI_API_KEY"],
  timeoutSeconds: 30, // GPT-4o-mini needs more time for context
}, async (request) => {
  const {conversationId, messageText, replyType} = request.data;

  if (!conversationId || !messageText) {
    throw new HttpsError(
      "invalid-argument",
      "conversationId and messageText are required",
    );
  }

  try {
    // If replyType specified, generate single targeted reply
    if (replyType) {
      logger.info("✨ Generating single smart reply", {
        conversationId,
        replyType,
        messagePreview: messageText.substring(0, 50),
      });

      const draft = await generateSingleReply(
        conversationId,
        messageText,
        replyType,
      );

      // Cache single reply in RTDB on the last message
      try {
        const lastMessageSnapshot = await admin.database()
          .ref(`/messages/${conversationId}`)
          .orderByChild("timestamp")
          .limitToLast(1)
          .once("value");

        if (lastMessageSnapshot.exists()) {
          const updates: { [key: string]: string | object } = {};
          lastMessageSnapshot.forEach((child) => {
            const cacheKey = replyType === "short" ? "short" :
              replyType === "funny" ? "medium" : "detailed";
            updates[`/messages/${conversationId}/${child.key}/smartReplies/${cacheKey}`] = draft;
            updates[`/messages/${conversationId}/${child.key}/smartReplies/generatedAt`] =
              admin.database.ServerValue.TIMESTAMP;
          });

          await admin.database().ref().update(updates);
          logger.info("💾 Single smart reply cached in RTDB", {conversationId, replyType});
        }
      } catch (cacheError) {
        logger.warn("⚠️ Failed to cache single smart reply", {cacheError});
      }

      return {
        drafts: {
          short: replyType === "short" ? draft : "",
          medium: replyType === "funny" ? draft : "",
          detailed: replyType === "professional" ? draft : "",
        },
      } as SmartReplyResponse;
    }

    // Otherwise, generate all 3 (existing behavior for backward compatibility)
    logger.info("✨ Generating smart replies", {
      conversationId,
      messagePreview: messageText.substring(0, 50),
    });

    // 1. Fetch recent messages from RTDB (last 20)
    const messagesSnapshot = await admin.database()
      .ref(`/messages/${conversationId}`)
      .orderByChild("timestamp")
      .limitToLast(20)
      .once("value");

    const messages: Message[] = [];
    messagesSnapshot.forEach((child) => {
      const msg = child.val();
      messages.push({
        senderID: msg.senderID,
        senderName: msg.senderName || "User",
        text: msg.text,
        timestamp: msg.timestamp,
      });
    });

    logger.info(`Retrieved ${messages.length} messages for context`);

    // 2. Fetch creator profile from Firestore
    const profileDoc = await admin.firestore()
      .collection("creator_profiles")
      .doc("andrew")
      .get();

    if (!profileDoc.exists) {
      throw new HttpsError("not-found", "Creator profile not found");
    }

    const profile = profileDoc.data() as CreatorProfile;
    logger.info("Creator profile loaded", {
      personality: profile.personality.substring(0, 50),
    });

    // 3. Build context prompt
    const conversationContext = messages
      .map((m) => `${m.senderName}: ${m.text}`)
      .join("\n");

    const systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join("\n")}

Avoid: ${profile.avoid.join(", ")}

Recent conversation context:
${conversationContext}`;

    const userPrompt = `The fan just sent: "${messageText}"

Generate 3 reply options:
1. Short (1 sentence, quick acknowledgment)
2. Medium (2-3 sentences, friendly and helpful)
3. Detailed (4-5 sentences, comprehensive response)

Make each option sound authentic to Andrew's voice. Use conversation context to make replies relevant.

Respond with ONLY valid JSON in this exact format:
{
  "short": "your short reply here",
  "medium": "your medium reply here",
  "detailed": "your detailed reply here"
}`;

    // 4. Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    // 5. Call OpenAI GPT-4o-mini
    logger.info("🤖 Calling GPT-4o-mini for smart replies...");
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      temperature: 0.7,
      response_format: {type: "json_object"},
    });

    const responseText = completion.choices[0].message.content;

    if (!responseText) {
      throw new Error("No response from OpenAI");
    }

    const drafts = JSON.parse(responseText);

    logger.info("✅ Smart replies generated", {
      shortLength: drafts.short?.length || 0,
      mediumLength: drafts.medium?.length || 0,
      detailedLength: drafts.detailed?.length || 0,
    });

    // Cache smart replies in RTDB on the last message in conversation
    try {
      const lastMessageSnapshot = await admin.database()
        .ref(`/messages/${conversationId}`)
        .orderByChild("timestamp")
        .limitToLast(1)
        .once("value");

      if (lastMessageSnapshot.exists()) {
        const updates: { [key: string]: string | object } = {};
        lastMessageSnapshot.forEach((child) => {
          updates[`/messages/${conversationId}/${child.key}/smartReplies`] = {
            short: drafts.short || "",
            medium: drafts.medium || "",
            detailed: drafts.detailed || "",
            generatedAt: admin.database.ServerValue.TIMESTAMP,
          };
        });

        await admin.database().ref().update(updates);
        logger.info("💾 Smart replies cached in RTDB", {conversationId});
      }
    } catch (cacheError) {
      // Don't fail the request if caching fails
      logger.warn("⚠️ Failed to cache smart replies", {cacheError});
    }

    return {
      drafts: {
        short: drafts.short || "",
        medium: drafts.medium || "",
        detailed: drafts.detailed || "",
      },
    } as SmartReplyResponse;
  } catch (error) {
    logger.error("Smart reply generation failed", {error});
    throw new HttpsError("internal", "Smart reply generation failed");
  }
});

/**
 * Generate a single targeted reply based on type
 * @param {string} conversationId - ID of the conversation for context
 * @param {string} messageText - The message to reply to
 * @param {"short" | "funny" | "professional"} replyType - Type of reply
 * @return {Promise<string>} Generated reply text
 */
async function generateSingleReply(
  conversationId: string,
  messageText: string,
  replyType: "short" | "funny" | "professional"
): Promise<string> {
  // Fetch last 20 messages for context (or all if <20 exist)
  const messagesSnapshot = await admin.database()
    .ref(`/messages/${conversationId}`)
    .orderByChild("timestamp")
    .limitToLast(20)
    .once("value");

  const messages: Message[] = [];
  messagesSnapshot.forEach((child) => {
    const msg = child.val();
    messages.push({
      senderID: msg.senderID,
      senderName: msg.senderName || "User",
      text: msg.text,
      timestamp: msg.timestamp,
    });
  });

  // Use all available messages if conversation has <20
  logger.info(`Using ${messages.length} messages for context`);

  // Fetch creator profile
  const profileDoc = await admin.firestore()
    .collection("creator_profiles")
    .doc("andrew")
    .get();

  if (!profileDoc.exists) {
    throw new HttpsError("not-found", "Creator profile not found");
  }

  const profile = profileDoc.data() as CreatorProfile;

  // Build context
  const conversationContext = messages
    .map((m) => `${m.senderName}: ${m.text}`)
    .join("\n");

  // Type-specific prompts
  const typePrompts = {
    short: "Generate a SHORT reply (1 sentence max). " +
      "Quick, warm acknowledgment. Be concise.",
    funny: "Generate a FUNNY reply (2-3 sentences). " +
      "Use Andrew's playful tone. Make it light-hearted and engaging. " +
      "Use emojis if appropriate.",
    professional: "Generate a PROFESSIONAL reply (3-4 sentences). " +
      "Detailed, helpful, and thorough. Maintain warmth but be comprehensive.",
  };

  const systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join("\n")}

Avoid: ${profile.avoid.join(", ")}

Recent conversation context:
${conversationContext}`;

  const userPrompt = `The fan just sent: "${messageText}"

${typePrompts[replyType]}

Make it sound authentic to Andrew's voice. Use conversation context to make it relevant.

Respond with ONLY the reply text (no JSON, no formatting).`;

  // Initialize OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  // Call OpenAI GPT-4o-mini
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {role: "system", content: systemPrompt},
      {role: "user", content: userPrompt},
    ],
    temperature: 0.7,
    max_tokens: replyType === "short" ? 50 : (replyType === "funny" ? 100 : 150),
  });

  const draft = completion.choices[0].message.content?.trim() || "";

  logger.info("✅ Single smart reply generated", {
    replyType,
    draftLength: draft.length,
  });

  return draft;
}
