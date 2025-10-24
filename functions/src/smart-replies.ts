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
  const {conversationId, messageText} = request.data;

  if (!conversationId || !messageText) {
    throw new HttpsError(
      "invalid-argument",
      "conversationId and messageText are required",
    );
  }

  try {
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
