/**
 * FAQ Auto-Responder Cloud Function for Buzzbox
 *
 * Feature 3: FAQ Auto-Responder
 * Checks if incoming message matches FAQ using GPT-4o-mini with all FAQs as context
 * Simple approach: 15 FAQs fit easily in GPT-4o-mini's context window
 *
 * [Source: Epic 6 - AI-Powered Creator Inbox]
 * [Story: 6.3 - FAQ Auto-Responder Cloud Function]
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI from "openai";

/**
 * FAQ data structure from Firestore
 */
interface FAQ {
  question: string;
  answer: string;
  category: string;
}

/**
 * FAQ response structure
 */
interface FAQResponse {
  isFAQ: boolean;
  answer?: string;
  matchedQuestion?: string;
}

/**
 * Check if message matches FAQ using GPT-4o-mini with all FAQs as context
 * Feature 3: FAQ Auto-Responder
 * Simple approach: 15 FAQs fit easily in GPT-4o-mini's context window
 *
 * @return {Promise<FAQResponse>} FAQ match result
 */
export const checkFAQ = onCall({
  region: "us-central1",
  secrets: ["OPENAI_API_KEY"],
}, async (request) => {
  const startTime = Date.now();
  const {text} = request.data;

  // === ENTRY LOGGING ===
  logger.info("🔵 === FAQ CHECK STARTED ===", {
    timestamp: new Date().toISOString(),
    messageLength: text?.length || 0,
    callerAuth: request.auth?.uid || "unauthenticated",
  });

  if (!text || typeof text !== "string") {
    logger.error("❌ Invalid input: Text is required", {
      receivedType: typeof text,
      receivedValue: text,
    });
    throw new HttpsError("invalid-argument", "Text is required");
  }

  logger.info("📥 Message to check", {
    fullText: text,
    textLength: text.length,
    wordCount: text.split(/\s+/).length,
  });

  try {
    // === FAQ DATABASE LOGGING ===
    logger.info("📚 Fetching FAQs from Firestore...");
    const faqFetchStart = Date.now();

    const faqsSnapshot = await admin.firestore()
      .collection("faqs")
      .get();

    const faqFetchTime = Date.now() - faqFetchStart;
    logger.info("📚 Firestore query completed", {
      queryTimeMs: faqFetchTime,
      documentsFound: faqsSnapshot.size,
    });

    const faqs: FAQ[] = [];
    faqsSnapshot.forEach((doc) => {
      const faqData = doc.data() as FAQ;
      faqs.push(faqData);
      logger.info("📖 FAQ loaded", {
        docID: doc.id,
        question: faqData.question,
        answerPreview: faqData.answer.substring(0, 100),
        category: faqData.category,
      });
    });

    if (faqs.length === 0) {
      logger.warn("⚠️ No FAQs found in Firestore database", {
        collection: "faqs",
        suggestion: "Run seedFAQs function to populate FAQ database",
      });
      return {isFAQ: false} as FAQResponse;
    }

    logger.info("✅ FAQ database loaded", {
      totalFAQs: faqs.length,
      categories: [...new Set(faqs.map((f) => f.category))],
    });

    // === OPENAI REQUEST LOGGING ===
    const faqContext = faqs
      .map((faq) => `Q: ${faq.question}\nA: ${faq.answer}`)
      .join("\n\n");

    const systemPrompt = "You are a helpful FAQ assistant. Given a user's " +
      `question, determine if it matches any FAQ below.

Available FAQs:
${faqContext}

If the question matches an FAQ (even if worded differently), respond with ONLY the matched FAQ answer verbatim.
If no good match, respond with exactly: NO_MATCH`;

    logger.info("🤖 Preparing OpenAI request", {
      model: "gpt-4o-mini",
      temperature: 0.3,
      maxTokens: 200,
      systemPromptLength: systemPrompt.length,
      userMessageLength: text.length,
    });

    logger.info("📝 OpenAI System Prompt", {
      prompt: systemPrompt,
    });

    logger.info("📝 OpenAI User Message", {
      message: text,
    });

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    logger.info("🚀 Calling OpenAI API...");
    const aiCallStart = Date.now();

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: systemPrompt,
        },
        {
          role: "user",
          content: text,
        },
      ],
      temperature: 0.3,
      max_tokens: 200,
    });

    const aiCallTime = Date.now() - aiCallStart;

    // === OPENAI RESPONSE LOGGING ===
    logger.info("✅ OpenAI API call completed", {
      callTimeMs: aiCallTime,
      model: completion.model,
      finishReason: completion.choices[0].finish_reason,
    });

    if (completion.usage) {
      logger.info("📊 Token usage", {
        promptTokens: completion.usage.prompt_tokens,
        completionTokens: completion.usage.completion_tokens,
        totalTokens: completion.usage.total_tokens,
        estimatedCost: `$${(completion.usage.total_tokens * 0.00015 / 1000).toFixed(6)}`,
      });
    }

    const response = completion.choices[0].message.content?.trim() || "NO_MATCH";

    logger.info("📤 OpenAI raw response", {
      response: response,
      responseLength: response.length,
    });

    // === MATCHING LOGIC LOGGING ===
    logger.info("🔍 Analyzing response for FAQ match...");

    if (response === "NO_MATCH") {
      logger.info("❌ No FAQ match found", {
        reason: "OpenAI returned NO_MATCH",
        userQuestion: text,
        checkedAgainst: faqs.length,
        totalTimeMs: Date.now() - startTime,
      });
      return {isFAQ: false} as FAQResponse;
    }

    // Find which FAQ was matched
    logger.info("🔎 Searching for matched FAQ...");
    const matchedFAQ = faqs.find((faq) =>
      response.includes(faq.answer.substring(0, 50)),
    );

    if (matchedFAQ) {
      logger.info("✅ FAQ matched successfully", {
        matchedQuestion: matchedFAQ.question,
        matchedCategory: matchedFAQ.category,
        answerLength: response.length,
        userQuestion: text,
      });
    } else {
      logger.warn("⚠️ FAQ matched but couldn't identify which one", {
        responsePreview: response.substring(0, 100),
        reason: "Response doesn't contain any FAQ answer substring",
      });
    }

    // === SUCCESS LOGGING ===
    const totalTime = Date.now() - startTime;
    logger.info("🎉 === FAQ CHECK COMPLETED SUCCESSFULLY ===", {
      totalTimeMs: totalTime,
      faqFetchTimeMs: faqFetchTime,
      aiCallTimeMs: aiCallTime,
      result: "MATCH_FOUND",
      matchedQuestion: matchedFAQ?.question || "Unknown",
    });

    return {
      isFAQ: true,
      answer: response,
      matchedQuestion: matchedFAQ?.question,
    } as FAQResponse;
  } catch (error) {
    // === ERROR LOGGING ===
    const totalTime = Date.now() - startTime;

    logger.error("❌ === FAQ CHECK FAILED ===", {
      totalTimeMs: totalTime,
      errorType: error instanceof Error ? error.constructor.name : typeof error,
      errorMessage: error instanceof Error ? error.message : String(error),
      errorStack: error instanceof Error ? error.stack : undefined,
      userQuestion: text,
    });

    // Log specific OpenAI errors
    if (error instanceof Error) {
      if (error.message.includes("API key")) {
        logger.error("🔑 OpenAI API Key Error", {
          suggestion: "Check if OPENAI_API_KEY secret is configured in Firebase",
          errorMessage: error.message,
        });
      } else if (error.message.includes("rate limit")) {
        logger.error("⏱️ OpenAI Rate Limit Error", {
          suggestion: "Too many requests. Wait and retry.",
          errorMessage: error.message,
        });
      } else if (error.message.includes("timeout")) {
        logger.error("⏰ OpenAI Timeout Error", {
          suggestion: "Request took too long. Check network or increase timeout.",
          errorMessage: error.message,
        });
      }
    }

    throw new HttpsError("internal", "FAQ check failed");
  }
});
