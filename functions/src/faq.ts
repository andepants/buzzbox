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
  const {text} = request.data;

  if (!text || typeof text !== "string") {
    throw new HttpsError("invalid-argument", "Text is required");
  }

  try {
    logger.info("📚 Checking FAQ for message", {
      textPreview: text.substring(0, 50),
    });

    // 1. Fetch all FAQs from Firestore (only 15, very fast)
    const faqsSnapshot = await admin.firestore()
      .collection("faqs")
      .get();

    const faqs: FAQ[] = [];
    faqsSnapshot.forEach((doc) => {
      faqs.push(doc.data() as FAQ);
    });

    if (faqs.length === 0) {
      logger.warn("No FAQs found in Firestore");
      return {isFAQ: false} as FAQResponse;
    }

    logger.info(`Found ${faqs.length} FAQs to check against`);

    // 2. Build FAQ context for GPT-4o-mini
    const faqContext = faqs
      .map((faq) => `Q: ${faq.question}\nA: ${faq.answer}`)
      .join("\n\n");

    // 3. Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    // 4. Ask GPT-4o-mini to match and respond
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: `You are a helpful FAQ assistant. Given a user's question, determine if it matches any FAQ below.

Available FAQs:
${faqContext}

If the question matches an FAQ (even if worded differently), respond with ONLY the matched FAQ answer verbatim.
If no good match, respond with exactly: NO_MATCH`,
        },
        {
          role: "user",
          content: text,
        },
      ],
      temperature: 0.3,
      max_tokens: 200,
    });

    const response = completion.choices[0].message.content?.trim() || "NO_MATCH";

    // 5. Check if we got a match
    if (response === "NO_MATCH") {
      logger.info("No FAQ match found");
      return {isFAQ: false} as FAQResponse;
    }

    // 6. Find which FAQ was matched (for logging)
    const matchedFAQ = faqs.find((faq) =>
      response.includes(faq.answer.substring(0, 50)),
    );

    logger.info("✅ FAQ matched", {
      userQuestion: text.substring(0, 100),
      matchedQuestion: matchedFAQ?.question || "Unknown",
      answerPreview: response.substring(0, 100),
    });

    return {
      isFAQ: true,
      answer: response,
      matchedQuestion: matchedFAQ?.question,
    } as FAQResponse;
  } catch (error) {
    logger.error("FAQ check failed:", error);
    throw new HttpsError("internal", "FAQ check failed");
  }
});
