/**
 * Context-Aware Smart Replies Cloud Function for Buzzbox
 *
 * Feature 2: Response drafting in creator's voice
 * Advanced AI Capability: Context-Aware Smart Replies (10 points)
 *
 * Generates 3 reply options (short/medium/detailed) using:
 * - Full conversation context (up to 100 messages)
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
  ragContext?: string; // NEW: RAG context from Supermemory (Story 9.3)
}

/**
 * Result from Supermemory search with detailed logging
 */
interface SupermemorySearchResult {
  hasHighSimilarityMatch: boolean;
  useExactMemory?: boolean; // If true, return memory without adaptation
  bestMatch?: {
    memory: string;
    similarity: number;
  };
  ragContext: string;
  resultCount: number;
}

/**
 * Search Supermemory for relevant past responses with comprehensive logging
 * @param {string} messageText - The message to search for
 * @return {Promise<SupermemorySearchResult>} Search results with logging
 */
async function searchSupermemoryForReply(
  messageText: string
): Promise<SupermemorySearchResult> {
  const defaultResult: SupermemorySearchResult = {
    hasHighSimilarityMatch: false,
    ragContext: "",
    resultCount: 0,
  };

  // Check API key availability
  const supermemoryApiKey = process.env.SUPERMEMORY_API_KEY;
  if (!supermemoryApiKey) {
    logger.info("❌ SUPERMEMORY_API_KEY not configured, skipping RAG context");
    return defaultResult;
  }

  logger.info("✅ SUPERMEMORY_API_KEY configured, searching for relevant memories");

  try {
    const searchQuery = messageText.substring(0, 100); // Limit query length
    logger.info("🔍 Supermemory Search Request", {
      query: searchQuery,
      limit: 3,
      threshold: 0.5,
      rerank: true,
      containerTag: "andrew-heim-response",
    });

    const searchResponse = await fetch("https://api.supermemory.ai/v4/search", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${supermemoryApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        q: messageText,
        limit: 3,
        threshold: 0.5,
        containerTag: "andrew-heim-response",
        rerank: true,
      }),
    });

    if (!searchResponse.ok) {
      const errorBody = await searchResponse.text();
      logger.warn("❌ Supermemory API error", {
        status: searchResponse.status,
        statusText: searchResponse.statusText,
        responseBody: errorBody.substring(0, 500), // Log first 500 chars
      });
      return defaultResult;
    }

    const searchResult = await searchResponse.json();
    const memories = searchResult.results || [];

    logger.info(`📊 Supermemory returned ${memories.length} results`);

    // Log each memory with similarity score
    memories.forEach((m: {similarity?: number; memory: string}, index: number) => {
      logger.info(`Memory ${index + 1}:`, {
        similarity: m.similarity || 0,
        memoryPreview: m.memory.substring(0, 100),
      });
    });

    if (memories.length === 0) {
      logger.info("💭 No memories found in Supermemory");
      return defaultResult;
    }

    // Check for high-similarity match (>= 0.75) - use memory directly
    const bestMatch = memories[0];
    const similarity = bestMatch.similarity || 0;

    if (similarity >= 0.9) {
      logger.info("🎯 VERY HIGH-SIMILARITY MATCH (≥0.9) → Returning EXACT memory unchanged", {
        similarity,
        memoryPreview: bestMatch.memory.substring(0, 100),
      });

      return {
        hasHighSimilarityMatch: true,
        useExactMemory: true,
        bestMatch: {
          memory: bestMatch.memory,
          similarity,
        },
        ragContext: "",
        resultCount: memories.length,
      };
    }

    if (similarity >= 0.75) {
      logger.info("🎯 HIGH-SIMILARITY MATCH (0.75-0.89) → Using minimal adaptation", {
        similarity,
        memoryPreview: bestMatch.memory.substring(0, 100),
      });

      return {
        hasHighSimilarityMatch: true,
        useExactMemory: false,
        bestMatch: {
          memory: bestMatch.memory,
          similarity,
        },
        ragContext: "",
        resultCount: memories.length,
      };
    }

    // No perfect match - use memories as supplemental context
    const relevantMemories = memories.filter((m: {similarity?: number}) =>
      (m.similarity || 0) >= 0.6
    );

    if (relevantMemories.length > 0) {
      const ragContext = "RELEVANT PAST RESPONSES:\n" +
        relevantMemories.map((m: {memory: string}) => m.memory).join("\n\n");

      logger.info(`📚 MEDIUM RELEVANCE (0.6-0.75) → Using ${relevantMemories.length} memories as RAG context`, {
        memoryCount: relevantMemories.length,
        contextLength: ragContext.length,
      });

      return {
        hasHighSimilarityMatch: false,
        ragContext,
        resultCount: memories.length,
      };
    }

    logger.info("⚠️ LOW RELEVANCE (<0.6) → Not using memories", {
      bestSimilarity: similarity,
    });

    return defaultResult;
  } catch (error) {
    const err = error as Error;
    logger.error("❌ Supermemory search failed with exception", {
      error: err.message,
      stack: err.stack,
      name: err.name,
    });
    return defaultResult;
  }
}

/**
 * Generate 3 context-aware smart replies in creator's voice
 * Features: Response Drafting (2) + Advanced AI Capability
 *
 * @return {Promise<SmartReplyResponse>} Three reply drafts
 */
export const generateSmartReplies = onCall<SmartReplyRequest>({
  region: "us-central1",
  secrets: ["OPENAI_API_KEY", "SUPERMEMORY_API_KEY"],
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

    // 1. Fetch recent messages from RTDB (up to 100 for full context)
    const messagesSnapshot = await admin.database()
      .ref(`/messages/${conversationId}`)
      .orderByChild("timestamp")
      .limitToLast(100)
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

    logger.info(`Retrieved ${messages.length} messages for context (up to 100)`);

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

    // 3. Search Supermemory for relevant past responses (RAG context)
    const supermemoryResult = await searchSupermemoryForReply(messageText);

    // If we found a high-similarity match, use it directly
    if (supermemoryResult.hasHighSimilarityMatch && supermemoryResult.bestMatch) {
      let response: string;

      if (supermemoryResult.useExactMemory) {
        // Very high similarity (≥0.9) - return exact memory unchanged
        logger.info("✅ Returning EXACT memory without modification", {
          similarity: supermemoryResult.bestMatch.similarity,
          length: supermemoryResult.bestMatch.memory.length,
        });
        response = supermemoryResult.bestMatch.memory;
      } else {
        // High similarity (0.75-0.89) - minimal adaptation
        logger.info("🔄 Adapting high-similarity memory with minimal changes");

        response = await adaptMemoryToContext(
          supermemoryResult.bestMatch.memory,
          messageText,
          profile
        );

        logger.info("✅ Returning minimally adapted memory", {
          originalLength: supermemoryResult.bestMatch.memory.length,
          adaptedLength: response.length,
        });
      }

      // Return memory as single best response
      return {
        drafts: {
          short: response,
          medium: response,
          detailed: response,
        },
      } as SmartReplyResponse;
    }

    const ragContext = supermemoryResult.ragContext;

    // 4. Build context prompt
    const conversationContext = messages
      .map((m) => `${m.senderName}: ${m.text}`)
      .join("\n");

    // Build system prompt with RAG context (Story 9.3)
    let systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join("\n")}

Avoid: ${profile.avoid.join(", ")}`;

    // Add RAG context if available (from Supermemory)
    if (ragContext) {
      systemPrompt += `\n\n${ragContext}`;
      logger.info("📝 RAG context included in GPT-4o-mini prompt", {
        contextLength: ragContext.length,
      });
    } else {
      logger.info("📝 No RAG context - using OpenAI generation only");
    }

    // Add recent conversation context
    systemPrompt += `\n\nRecent conversation context:
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

    // 5. Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    // 6. Call OpenAI GPT-4o-mini
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
 * NOW WITH SUPERMEMORY INTEGRATION (Epic 9)
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
  logger.info("🎯 generateSingleReply called", {
    conversationId,
    replyType,
    messagePreview: messageText.substring(0, 50),
  });

  // Fetch creator profile first (needed for adaptation)
  const profileDoc = await admin.firestore()
    .collection("creator_profiles")
    .doc("andrew")
    .get();

  if (!profileDoc.exists) {
    throw new HttpsError("not-found", "Creator profile not found");
  }

  const profile = profileDoc.data() as CreatorProfile;

  // Search Supermemory FIRST (before fetching all messages)
  const supermemoryResult = await searchSupermemoryForReply(messageText);

  // If we found a high-similarity match, use it directly
  if (supermemoryResult.hasHighSimilarityMatch && supermemoryResult.bestMatch) {
    if (supermemoryResult.useExactMemory) {
      // Very high similarity (≥0.9) - return exact memory unchanged
      logger.info("✅ Returning EXACT memory without modification (single reply)", {
        replyType,
        similarity: supermemoryResult.bestMatch.similarity,
        length: supermemoryResult.bestMatch.memory.length,
      });
      return supermemoryResult.bestMatch.memory;
    } else {
      // High similarity (0.75-0.89) - minimal adaptation
      logger.info("🎯 High-similarity match in single reply - using minimal adaptation");

      const adaptedResponse = await adaptMemoryToContext(
        supermemoryResult.bestMatch.memory,
        messageText,
        profile
      );

      logger.info("✅ Returning minimally adapted memory as single smart reply", {
        replyType,
        originalLength: supermemoryResult.bestMatch.memory.length,
        adaptedLength: adaptedResponse.length,
      });

      return adaptedResponse;
    }
  }

  // No high-similarity match - proceed with normal generation
  // Fetch up to 100 messages for full conversation context
  const messagesSnapshot = await admin.database()
    .ref(`/messages/${conversationId}`)
    .orderByChild("timestamp")
    .limitToLast(100)
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

  logger.info(`Using ${messages.length} messages for context (up to 100)`);

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

  let systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join("\n")}

Avoid: ${profile.avoid.join(", ")}`;

  // Add RAG context if available (from Supermemory)
  const ragContext = supermemoryResult.ragContext;
  if (ragContext) {
    systemPrompt += `\n\n${ragContext}`;
    logger.info("📝 RAG context included in single reply prompt", {
      contextLength: ragContext.length,
      replyType,
    });
  } else {
    logger.info("📝 No RAG context for single reply - using OpenAI generation only", {
      replyType,
    });
  }

  // Add conversation context
  systemPrompt += `\n\nRecent conversation context:
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
  logger.info("🤖 Calling GPT-4o-mini for single smart reply...", {replyType});

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

  logger.info("✅ Single smart reply generated via OpenAI", {
    replyType,
    draftLength: draft.length,
    hadRAGContext: !!ragContext,
  });

  return draft;
}

/**
 * Adapts a past memory/response to the current context
 * Uses lightweight GPT call to personalize while maintaining voice
 * @param {string} memory - The past response from Supermemory
 * @param {string} currentMessage - The current fan message
 * @param {CreatorProfile} profile - Creator's profile for context
 * @return {Promise<string>} Adapted response text
 */
async function adaptMemoryToContext(
  memory: string,
  currentMessage: string,
  profile: CreatorProfile
): Promise<string> {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  const prompt = `You are Andrew, a ${profile.personality}

You previously wrote this EXACT response:
"${memory}"

The current fan message is: "${currentMessage}"

CRITICAL INSTRUCTIONS - Minimal Adaptation Only:
- PRESERVE the exact style, tone, punctuation, capitalization, and way of talking
- PRESERVE any emojis, slang, or unique phrasing
- PRESERVE the sentence structure and length
- ONLY change specific details if absolutely necessary (e.g., pronouns, names, minor context)
- If the questions are similar (e.g., "what's your favorite cat" vs "what is your favorite cat"),
  return the EXACT original response UNCHANGED
- DO NOT add new information, explanations, or change the message
- DO NOT make the response more formal or polished
- When in doubt, return the original text exactly as-is

Respond with ONLY the adapted text (no JSON, no explanation, no quotes).`;

  logger.info("🔄 Adapting memory to current context (minimal changes only)", {
    memoryLength: memory.length,
    messageLength: currentMessage.length,
  });

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{role: "user", content: prompt}],
    temperature: 0.1, // Very low temperature for maximum consistency
    max_tokens: 250,
  });

  const adaptedText = completion.choices[0].message.content?.trim() || memory;

  logger.info("✅ Memory adapted successfully", {
    originalLength: memory.length,
    adaptedLength: adaptedText.length,
  });

  return adaptedText;
}
