/**
 * Cloud Functions for Buzzbox
 *
 * onMessageCreated: Sends FCM notifications when messages are created
 * Supports both 1:1 and group conversations
 *
 * processMessageAI: Auto-processes messages with AI (categorization, sentiment, scoring)
 *
 * [Source: Story 2.0B - Cloud Functions FCM (foundation)]
 * [Source: Story 3.7 - Group Message Notifications]
 * [Source: Story 6.2 - Auto-Processing Cloud Function]
 * [Updated: Using Firebase Functions v2 API per Context7 best practices]
 */

import {onValueCreated} from "firebase-functions/v2/database";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import OpenAI from "openai";

// Initialize Firebase Admin
admin.initializeApp();

// Export AI Processing functions
export {processMessageAI} from "./ai-processing";
export {checkFAQ} from "./faq";
export {generateSmartReplies} from "./smart-replies";
export {analyzeConversation} from "./conversation-analysis";

// Export Seed Data functions (QA testing only)
export {seedFAQs, seedCreatorProfile} from "./seed-data";

// Constants
const CREATOR_EMAIL = "andrewsheim@gmail.com";

/**
 * Message data structure from RTDB
 */
interface MessageData {
  text: string;
  senderID: string;
  serverTimestamp?: number;
  isSystemMessage?: boolean;
  isAIGenerated?: boolean;
  isFAQResponse?: boolean;
}

/**
 * Conversation data structure from RTDB
 */
interface ConversationData {
  isGroup?: boolean;
  groupName?: string;
  participantIDs?: {[key: string]: boolean};
}

/**
 * FAQ data structure from Firestore
 */
interface FAQ {
  question: string;
  answer: string;
  category: string;
}

/**
 * Helper function to check if a message matches an FAQ and return the answer
 * Uses the same logic as the checkFAQ callable function
 * @param {string} messageText - The message text to check against FAQs
 * @return {Promise} FAQ match result with answer if found
 */
async function checkFAQMatch(
  messageText: string
): Promise<{isFAQ: boolean; answer?: string; matchedQuestion?: string}> {
  const startTime = Date.now();

  // === ENTRY LOGGING ===
  logger.info("🔵 === FAQ MATCH CHECK STARTED (Helper) ===", {
    timestamp: new Date().toISOString(),
    messageLength: messageText?.length || 0,
    context: "onMessageCreated helper function",
  });

  logger.info("📥 Message to check", {
    fullText: messageText,
    textLength: messageText.length,
    wordCount: messageText.split(/\s+/).length,
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

    if (faqsSnapshot.empty) {
      logger.warn("⚠️ No FAQs found in Firestore database", {
        collection: "faqs",
        suggestion: "Run seedFAQs function to populate FAQ database",
      });
      return {isFAQ: false};
    }

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
      userMessageLength: messageText.length,
    });

    logger.info("📝 OpenAI System Prompt", {
      prompt: systemPrompt,
    });

    logger.info("📝 OpenAI User Message", {
      message: messageText,
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
        {role: "system", content: systemPrompt},
        {role: "user", content: messageText},
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
        userQuestion: messageText,
        checkedAgainst: faqs.length,
        totalTimeMs: Date.now() - startTime,
      });
      return {isFAQ: false};
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
        userQuestion: messageText,
      });
    } else {
      logger.warn("⚠️ FAQ matched but couldn't identify which one", {
        responsePreview: response.substring(0, 100),
        reason: "Response doesn't contain any FAQ answer substring",
      });
    }

    // === SUCCESS LOGGING ===
    const totalTime = Date.now() - startTime;
    logger.info("🎉 === FAQ MATCH CHECK COMPLETED SUCCESSFULLY ===", {
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
    };
  } catch (error) {
    // === ERROR LOGGING ===
    const totalTime = Date.now() - startTime;

    logger.error("❌ === FAQ MATCH CHECK FAILED ===", {
      totalTimeMs: totalTime,
      errorType: error instanceof Error ? error.constructor.name : typeof error,
      errorMessage: error instanceof Error ? error.message : String(error),
      errorStack: error instanceof Error ? error.stack : undefined,
      userQuestion: messageText,
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

    return {isFAQ: false};
  }
}

/**
 * Helper function to get the creator's user ID
 */
async function getCreatorUID(): Promise<string | null> {
  try {
    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("email", "==", CREATOR_EMAIL)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      logger.error("Creator user not found");
      return null;
    }

    return usersSnapshot.docs[0].id;
  } catch (error) {
    logger.error("Error fetching creator UID:", error);
    return null;
  }
}

/**
 * Triggered when a new message is created in RTDB at /messages/{conversationID}/{messageID}
 * Sends FCM push notifications to recipients
 *
 * For 1:1 chats: Sends to single recipient (other participant)
 * For group chats: Sends to all participants except sender
 * System messages do not trigger notifications
 *
 * Retry Configuration:
 * - Enabled: Function will auto-retry on failure
 * - Firebase Functions will retry failed executions for up to 7 days
 * - Retry happens with exponential backoff
 */
export const onMessageCreated = onValueCreated({
  ref: "/messages/{conversationID}/{messageID}",
  region: "us-central1",
  retry: true, // Enable automatic retry on failure
  secrets: ["OPENAI_API_KEY"], // Required for FAQ checking
}, async (event) => {
  const message = event.data.val() as MessageData;
  const {conversationID, messageID} = event.params;

  logger.info("🔔 onMessageCreated TRIGGERED", {
    conversationID,
    messageID,
    senderID: message.senderID,
    textPreview: message.text.substring(0, 50),
    timestamp: new Date().toISOString(),
  });

  // Skip system messages
  if (message.isSystemMessage === true) {
    logger.info("ℹ️ Skipping system message notification", {conversationID, messageID});
    return null;
  }

  // Skip AI-generated messages (prevent infinite loops)
  if (message.isAIGenerated === true) {
    logger.info("ℹ️ Skipping AI-generated message", {conversationID, messageID});
    return null;
  }

  // Fetch conversation
  const conversationSnap = await admin.database()
    .ref(`/conversations/${conversationID}`)
    .once("value");
  const conversation = conversationSnap.val() as ConversationData;

  if (!conversation) {
    logger.error("Conversation not found", {conversationID});
    return null;
  }

  // Detect if group
  const isGroup = conversation.isGroup === true;
  const senderID = message.senderID;

  // Get sender display name
  const senderDoc = await admin.firestore()
    .collection("users")
    .doc(senderID)
    .get();
  const senderName = senderDoc.data()?.displayName || "Someone";

  if (isGroup) {
    // ========================================
    // GROUP MESSAGE NOTIFICATION
    // ========================================
    const groupName = conversation.groupName || "Group Chat";
    const participantIDs = Object.keys(conversation.participantIDs || {});

    // Fetch FCM tokens for all participants except sender
    const recipientIDs = participantIDs.filter((id) => id !== senderID);
    const tokens: string[] = [];

    for (const recipientID of recipientIDs) {
      const userDoc = await admin.firestore()
        .collection("users")
        .doc(recipientID)
        .get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (fcmToken) {
        tokens.push(fcmToken);
      }
    }

    if (tokens.length === 0) {
      logger.info("No FCM tokens found for group participants", {
        conversationID,
        participantCount: recipientIDs.length,
      });
      return null;
    }

    // Build notification payload
    const payload = {
      notification: {
        title: `${senderName} in ${groupName}`,
        body: message.text.substring(0, 100),
      },
      data: {
        conversationID: conversationID,
        messageID: messageID,
        senderID: senderID,
        type: "new_message",
        isGroup: "true",
        timestamp: String(message.serverTimestamp || Date.now()),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            threadId: conversationID, // For notification stacking
          },
        },
      },
    };

    // Send to multiple recipients
    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      ...payload,
    });

    logger.info("Group notification sent", {
      conversationID,
      groupName,
      successCount: response.successCount,
      failureCount: response.failureCount,
      recipientCount: tokens.length,
    });

    // Log failures for debugging
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.error("Failed to send to recipient", {
            conversationID,
            token: tokens[idx].substring(0, 10) + "...",
            error: resp.error?.message,
          });
        }
      });
    }

    return null;
  } else {
    // ========================================
    // 1:1 MESSAGE NOTIFICATION (DM)
    // ========================================
    logger.info("📱 Processing 1:1 DM notification", {
      conversationID,
      messageID,
      senderID,
      senderName,
    });

    const participantIDs = Object.keys(conversation.participantIDs || {});
    logger.info("👥 DM participants", {participantIDs});

    const recipientID = participantIDs.find((id) => id !== senderID);

    if (!recipientID) {
      logger.error("❌ Recipient not found in conversation", {
        conversationID,
        participantIDs,
        senderID,
      });
      return null;
    }

    logger.info("🎯 Target recipient identified", {recipientID});

    // Fetch recipient FCM token
    logger.info("🔑 Fetching FCM token for recipient...", {recipientID});
    const recipientDoc = await admin.firestore()
      .collection("users")
      .doc(recipientID)
      .get();

    if (!recipientDoc.exists) {
      logger.error("❌ Recipient user document not found in Firestore", {
        recipientID,
        conversationID,
      });
      return null;
    }

    const fcmToken = recipientDoc.data()?.fcmToken;

    // ========================================
    // SEND NOTIFICATION (if FCM token exists)
    // ========================================
    // Note: Notification is optional - FAQ check runs regardless of notification success
    if (!fcmToken) {
      logger.warn("⚠️ No FCM token found for recipient - skipping notification", {
        conversationID,
        recipientID,
        reason: "User may not have logged in on a physical device (FCM requires physical device)",
        note: "FAQ auto-response will still be checked and sent if applicable",
      });
    } else {
      logger.info("✅ FCM token retrieved", {
        recipientID,
        tokenPreview: fcmToken.substring(0, 20) + "...",
      });

      // Build notification payload
      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: message.text.substring(0, 100),
        },
        data: {
          conversationID: conversationID,
          messageID: messageID,
          senderID: senderID,
          type: "new_message",
          isGroup: "false",
          timestamp: String(message.serverTimestamp || Date.now()),
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      logger.info("📤 Sending FCM notification to recipient...", {
        recipientID,
        title: senderName,
        bodyPreview: message.text.substring(0, 50),
      });

      // Send notification with detailed error logging
      try {
        const response = await admin.messaging().send(payload);
        logger.info("✅ 1:1 DM notification sent successfully", {
          conversationID,
          recipientID,
          messageID: response,
          senderName,
        });
      } catch (error) {
        // Detailed FCM error logging
        const errorCode = error && typeof error === "object" && "code" in error ? error.code : undefined;
        const errorMessage = error instanceof Error ? error.message : String(error);

        logger.error("❌ Failed to send 1:1 DM notification", {
          conversationID,
          recipientID,
          messageID,
          errorCode,
          errorMessage,
          senderName,
        });

        // Log specific FCM error types for debugging
        if (errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered") {
          logger.error("🚨 FCM Token Issue - Token is invalid or unregistered", {
            recipientID,
            suggestion: "User should re-login to refresh FCM token, or token expired",
            tokenPreview: fcmToken.substring(0, 20) + "...",
          });
        } else if (errorCode === "messaging/invalid-argument") {
          logger.error("🚨 FCM Payload Issue - Invalid message format", {
            payload: JSON.stringify(payload, null, 2),
          });
        } else if (errorCode === "messaging/server-unavailable") {
          logger.error("🚨 FCM Server Issue - Retry will be attempted", {
            suggestion: "Firebase Functions will auto-retry this function",
          });
        }

        // ⚠️ DON'T RE-THROW - Log error but continue to FAQ check
        logger.warn("⚠️ Notification failed but continuing to FAQ check", {
          conversationID,
          messageID,
          note: "FAQ auto-response will still be sent if message matches FAQ",
        });
      }
    }

    // ========================================
    // FAQ AUTO-RESPONSE (for DMs to creator)
    // ========================================
    // After notification is sent, check if this is a DM to the creator
    // and if the message matches an FAQ, auto-send a response

    logger.info("🤖 === FAQ AUTO-RESPONSE CHECK STARTING ===", {
      conversationID,
      messageID,
      senderID,
      senderName,
      messagePreview: message.text.substring(0, 100),
      messageLength: message.text.length,
      timestamp: new Date().toISOString(),
    });

    // === STEP 1: Get creator UID ===
    logger.info("👤 Step 1: Fetching creator UID...", {
      creatorEmail: CREATOR_EMAIL,
    });

    const creatorUID = await getCreatorUID();

    if (!creatorUID) {
      logger.error("❌ FAQ CHECK ABORTED: Creator UID not found", {
        conversationID,
        messageID,
        reason: "Creator user not found in Firestore",
        creatorEmail: CREATOR_EMAIL,
        suggestion: "Ensure creator has signed up and exists in users collection",
      });
      return null;
    }

    logger.info("✅ Creator UID retrieved", {
      creatorUID,
      creatorEmail: CREATOR_EMAIL,
    });

    // === STEP 2: Check if creator is in conversation ===
    logger.info("👥 Step 2: Checking if creator is a participant...", {
      conversationID,
      participantIDs,
      participantCount: participantIDs.length,
      creatorUID,
    });

    const isCreatorInConversation = participantIDs.includes(creatorUID);

    logger.info("📊 Participant check result", {
      isCreatorInConversation,
      participantIDs,
      creatorUID,
      conversationType: "1:1 DM",
    });

    if (!isCreatorInConversation) {
      logger.warn("⚠️ FAQ CHECK SKIPPED: Creator not in conversation", {
        conversationID,
        messageID,
        participantIDs,
        creatorUID,
        reason: "This DM does not involve the creator",
        suggestion: "FAQ auto-response only works for DMs with the creator",
      });
      return null;
    }

    logger.info("✅ Creator is a participant in this conversation");

    // === STEP 3: Check if message is FROM creator ===
    logger.info("🎯 Step 3: Checking message sender...", {
      senderID,
      senderName,
      creatorUID,
    });

    const isFromCreator = senderID === creatorUID;

    logger.info("📊 Sender check result", {
      isFromCreator,
      senderID,
      creatorUID,
      senderName,
    });

    if (isFromCreator) {
      logger.info("ℹ️ FAQ CHECK SKIPPED: Message is FROM creator", {
        conversationID,
        messageID,
        senderID,
        reason: "FAQ auto-response only triggers for messages TO the creator from fans",
        suggestion: "This is expected behavior - creators don't trigger FAQ responses",
      });
      return null;
    }

    logger.info("✅ Message is TO creator from fan - FAQ check will proceed");

    // === STEP 4: Check FAQ match ===
    logger.info("🔍 Step 4: Initiating FAQ match check...", {
      conversationID,
      messageID,
      messageText: message.text,
      messageLength: message.text.length,
      senderID,
      senderName,
    });

    const faqCheckStart = Date.now();
    const faqResult = await checkFAQMatch(message.text);
    const faqCheckDuration = Date.now() - faqCheckStart;

    logger.info("📊 FAQ match check completed", {
      durationMs: faqCheckDuration,
      isFAQ: faqResult.isFAQ,
      matchedQuestion: faqResult.matchedQuestion || "N/A",
      hasAnswer: !!faqResult.answer,
      answerLength: faqResult.answer?.length || 0,
    });

    // === STEP 5: Send FAQ response if matched ===
    if (faqResult.isFAQ && faqResult.answer) {
      logger.info("✅ === FAQ MATCH FOUND! Sending auto-response... ===", {
        conversationID,
        matchedQuestion: faqResult.matchedQuestion,
        answerLength: faqResult.answer.length,
        answerPreview: faqResult.answer.substring(0, 100),
        originalMessage: message.text,
        fanSenderID: senderID,
        fanSenderName: senderName,
      });

      // Generate response message ID
      const responseMessageID = `faq_${messageID}_${Date.now()}`;

      logger.info("📤 Preparing FAQ auto-response message...", {
        responseMessageID,
        conversationID,
        senderID: creatorUID,
        answerLength: faqResult.answer.length,
      });

      // Send FAQ response from creator
      const responseData: {
        text: string;
        senderID: string;
        serverTimestamp: object;
        status: string;
        isAIGenerated: boolean;
        isFAQResponse: boolean;
      } = {
        text: faqResult.answer,
        senderID: creatorUID,
        serverTimestamp: admin.database.ServerValue.TIMESTAMP,
        status: "sent",
        isAIGenerated: true,
        isFAQResponse: true, // Flag for FAQ badge display
      };

      logger.info("💾 Writing FAQ response to RTDB...", {
        path: `/messages/${conversationID}/${responseMessageID}`,
        dataKeys: Object.keys(responseData),
      });

      try {
        const writeStart = Date.now();

        await admin.database()
          .ref(`/messages/${conversationID}/${responseMessageID}`)
          .set(responseData);

        const writeDuration = Date.now() - writeStart;

        logger.info("✅ FAQ response written to RTDB", {
          durationMs: writeDuration,
          path: `/messages/${conversationID}/${responseMessageID}`,
        });

        // Update conversation last message
        logger.info("🔄 Updating conversation last message...", {
          conversationID,
          lastMessagePreview: faqResult.answer.substring(0, 100),
        });

        const updateStart = Date.now();

        await admin.database()
          .ref(`/conversations/${conversationID}`)
          .update({
            lastMessage: faqResult.answer.substring(0, 100),
            lastMessageTimestamp: admin.database.ServerValue.TIMESTAMP,
          });

        const updateDuration = Date.now() - updateStart;

        logger.info("✅ Conversation last message updated", {
          durationMs: updateDuration,
          conversationID,
        });

        logger.info("🎉 === FAQ AUTO-RESPONSE SENT SUCCESSFULLY ===", {
          conversationID,
          responseMessageID,
          matchedQuestion: faqResult.matchedQuestion,
          originalMessageID: messageID,
          fanSenderID: senderID,
          fanSenderName: senderName,
          totalFAQProcessTimeMs: Date.now() - faqCheckStart,
        });
      } catch (error) {
        logger.error("❌ === FAILED TO SEND FAQ AUTO-RESPONSE ===", {
          conversationID,
          responseMessageID,
          matchedQuestion: faqResult.matchedQuestion,
          errorType: error instanceof Error ? error.constructor.name : typeof error,
          errorMessage: error instanceof Error ? error.message : String(error),
          errorStack: error instanceof Error ? error.stack : undefined,
          suggestion: "Check RTDB permissions and connection",
        });
      }
    } else {
      logger.info("ℹ️ === NO FAQ MATCH FOUND ===", {
        conversationID,
        messageID,
        messageText: message.text,
        messageLength: message.text.length,
        senderID,
        senderName,
        reason: "Message does not match any FAQ in database",
        faqCheckDurationMs: faqCheckDuration,
      });
    }

    return null;
  }
});

/**
 * HTTP function to seed default channels (call once)
 * GET https://us-central1-buzzbox-ios.cloudfunctions.net/seedChannels
 */
export const seedChannels = onRequest({region: "us-central1"}, async (req, res) => {
  const db = admin.firestore();
  const CREATOR_EMAIL = "andrewsheim@gmail.com";

  try {
    logger.info("🚀 Starting channel seeding...");

    // Get creator user (optional - can work without it)
    let creatorUID = "";
    try {
      const usersSnapshot = await db
        .collection("users")
        .where("email", "==", CREATOR_EMAIL)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        creatorUID = usersSnapshot.docs[0].id;
        logger.info(`✅ Found creator: ${creatorUID}`);
      }
    } catch (error) {
      logger.warn("Creator user not found, creating channels without creator", {error});
    }

    const channels = [
      {
        id: "general",
        displayName: "#general",
        description: "General discussion and community chat",
        isCreatorOnly: false,
      },
      {
        id: "announcements",
        displayName: "#announcements",
        description: "Important updates from Andrew",
        isCreatorOnly: true,
      },
      {
        id: "off-topic",
        displayName: "#off-topic",
        description: "Casual conversations and off-topic chat",
        isCreatorOnly: false,
      },
    ];

    const results = [];

    for (const channel of channels) {
      logger.info(`🌱 Seeding ${channel.displayName}...`);

      const now = admin.firestore.Timestamp.now();

      // Create in Firestore
      const firestoreData = {
        participantIDs: creatorUID ? [creatorUID] : [],
        displayName: channel.displayName,
        groupPhotoURL: "",
        adminUserIDs: creatorUID ? [creatorUID] : [],
        isGroup: true,
        isCreatorOnly: channel.isCreatorOnly,
        createdAt: now,
        updatedAt: now,
        lastMessage: `Welcome to ${channel.displayName}! ${channel.description}`,
        lastMessageTimestamp: now,
        lastMessageSenderID: creatorUID || "",
      };

      await db.collection("conversations").doc(channel.id).set(firestoreData);
      logger.info(`  ✅ Firestore: conversations/${channel.id}`);

      results.push({
        channel: channel.displayName,
        id: channel.id,
        status: "created",
      });
    }

    logger.info("✅ All channels seeded successfully!");

    res.status(200).json({
      success: true,
      message: "Default channels seeded successfully",
      channels: results,
      creatorUID: creatorUID || "not found",
    });
  } catch (error) {
    logger.error("❌ Error seeding channels:", error);
    res.status(500).json({
      error: "Failed to seed channels",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});

/**
 * HTTP function to add all existing users to default channels (backfill)
 * GET https://us-central1-buzzbox-ios.cloudfunctions.net/backfillChannelParticipants
 *
 * This function:
 * 1. Queries all users from Firestore
 * 2. Adds each user to all 3 default channels (general, announcements, off-topic)
 * 3. Updates both Firestore (participantIDs array) and RTDB (participantIDs object)
 *
 * Use this when channels were created but existing users need to be added
 */
export const backfillChannelParticipants = onRequest({region: "us-central1"}, async (req, res) => {
  const db = admin.firestore();
  const rtdb = admin.database();
  const DEFAULT_CHANNEL_IDS = ["general", "announcements", "off-topic"];

  try {
    logger.info("🚀 Starting channel participant backfill...");

    // 1. Get all users
    const usersSnapshot = await db.collection("users").get();
    const userIDs = usersSnapshot.docs.map((doc) => doc.id);

    if (userIDs.length === 0) {
      res.status(404).json({
        success: false,
        message: "No users found in Firestore",
      });
      return;
    }

    logger.info(`📊 Found ${userIDs.length} users to add to channels`);

    const results: {[key: string]: {success: number; failed: number}} = {};

    // 2. For each channel, add all users
    for (const channelID of DEFAULT_CHANNEL_IDS) {
      logger.info(`\n🔵 Processing channel: ${channelID}`);
      let successCount = 0;
      let failedCount = 0;

      // Check if channel exists
      const channelDoc = await db.collection("conversations").doc(channelID).get();
      if (!channelDoc.exists) {
        logger.warn(`Channel ${channelID} does not exist, skipping...`);
        continue;
      }

      for (const userID of userIDs) {
        try {
          // 2a. Update Firestore (add to participantIDs array)
          await db.collection("conversations").doc(channelID).update({
            participantIDs: admin.firestore.FieldValue.arrayUnion(userID),
          });

          // 2b. Update RTDB (add to participantIDs object)
          await rtdb.ref(`conversations/${channelID}/participantIDs/${userID}`).set(true);

          successCount++;
          logger.info(`  ✅ Added user ${userID} to ${channelID}`);
        } catch (error) {
          failedCount++;
          logger.error(`  ❌ Failed to add user ${userID} to ${channelID}:`, error);
        }
      }

      results[channelID] = {success: successCount, failed: failedCount};
      logger.info(`📊 Channel ${channelID}: ${successCount} added, ${failedCount} failed`);
    }

    logger.info("\n✅ Backfill complete!");

    res.status(200).json({
      success: true,
      message: "Channel participants backfilled successfully",
      totalUsers: userIDs.length,
      channelsProcessed: DEFAULT_CHANNEL_IDS.length,
      results: results,
    });
  } catch (error) {
    logger.error("❌ Error backfilling channel participants:", error);
    res.status(500).json({
      error: "Failed to backfill channel participants",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
