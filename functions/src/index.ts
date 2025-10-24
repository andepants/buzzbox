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

// Initialize Firebase Admin
admin.initializeApp();

// Export AI Processing functions
export {processMessageAI} from "./ai-processing";
export {checkFAQ} from "./faq";
export {generateSmartReplies} from "./smart-replies";

// Export Seed Data functions (QA testing only)
export {seedFAQs, seedCreatorProfile} from "./seed-data";

/**
 * Message data structure from RTDB
 */
interface MessageData {
  text: string;
  senderID: string;
  serverTimestamp?: number;
  isSystemMessage?: boolean;
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

    if (!fcmToken) {
      logger.warn("⚠️ No FCM token found for recipient", {
        conversationID,
        recipientID,
        reason: "User may not have logged in on a physical device (FCM requires physical device)",
      });
      return null;
    }

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

      // Re-throw error to trigger automatic retry (if retry is enabled)
      throw error;
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
