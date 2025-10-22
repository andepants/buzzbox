/**
 * Cloud Functions for Buzzbox
 *
 * onMessageCreated: Sends FCM notifications when messages are created
 * Supports both 1:1 and group conversations
 *
 * [Source: Story 2.0B - Cloud Functions FCM (foundation)]
 * [Source: Story 3.7 - Group Message Notifications]
 * [Updated: Using Firebase Functions v2 API per Context7 best practices]
 */

import {onValueCreated} from "firebase-functions/v2/database";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

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
 */
export const onMessageCreated = onValueCreated({
  ref: "/messages/{conversationID}/{messageID}",
  region: "us-central1",
  instance: "buzzbox-91c9a-default-rtdb",
}, async (event) => {
  const message = event.data.val() as MessageData;
  const {conversationID, messageID} = event.params;

  // Skip system messages
  if (message.isSystemMessage === true) {
    logger.info("Skipping system message notification", {conversationID, messageID});
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
    // 1:1 MESSAGE NOTIFICATION
    // ========================================
    const participantIDs = Object.keys(conversation.participantIDs || {});
    const recipientID = participantIDs.find((id) => id !== senderID);

    if (!recipientID) {
      logger.error("Recipient not found in conversation", {conversationID});
      return null;
    }

    // Fetch recipient FCM token
    const recipientDoc = await admin.firestore()
      .collection("users")
      .doc(recipientID)
      .get();
    const fcmToken = recipientDoc.data()?.fcmToken;

    if (!fcmToken) {
      logger.info("No FCM token found for recipient", {conversationID, recipientID});
      return null;
    }

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

    // Send notification
    try {
      await admin.messaging().send(payload);
      logger.info("1:1 notification sent", {conversationID, recipientID});
    } catch (error) {
      logger.error("Failed to send 1:1 notification", {
        conversationID,
        recipientID,
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return null;
  }
});
