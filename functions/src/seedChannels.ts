/**
 * seedChannels.ts
 *
 * HTTP Cloud Function to seed default channels
 * Call once to initialize the three default channels
 *
 * Usage: curl https://us-central1-buzzbox-ios.cloudfunctions.net/seedChannels
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const seedChannels = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const rtdb = admin.database();
  const CREATOR_EMAIL = "andrewsheim@gmail.com";

  try {
    console.log("🚀 Starting channel seeding...");

    // Get creator user
    const usersSnapshot = await db
      .collection("users")
      .where("email", "==", CREATOR_EMAIL)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      res.status(404).send({
        error: "Creator user not found",
        email: CREATOR_EMAIL,
      });
      return;
    }

    const creatorDoc = usersSnapshot.docs[0];
    const creatorUID = creatorDoc.id;
    console.log(`✅ Found creator: ${creatorUID}`);

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
      console.log(`🌱 Seeding ${channel.displayName}...`);

      const now = admin.firestore.Timestamp.now();
      const nowMillis = Date.now();

      // 1. Create in Firestore
      const firestoreData = {
        participantIDs: [creatorUID],
        displayName: channel.displayName,
        groupPhotoURL: "",
        adminUserIDs: [creatorUID],
        isGroup: true,
        isCreatorOnly: channel.isCreatorOnly,
        createdAt: now,
        updatedAt: now,
        lastMessage: `Welcome to ${channel.displayName}! ${channel.description}`,
        lastMessageTimestamp: now,
        lastMessageSenderID: creatorUID,
      };

      await db.collection("conversations").doc(channel.id).set(firestoreData);
      console.log(`  ✅ Firestore: conversations/${channel.id}`);

      // 2. Update RTDB (may already exist)
      const rtdbData = {
        participantIDs: {
          [creatorUID]: true,
        },
        adminUserIDs: {
          [creatorUID]: true,
        },
        isGroup: true,
        isCreatorOnly: channel.isCreatorOnly,
        groupName: channel.displayName,
        groupPhotoURL: "",
        lastMessage: `Welcome to ${channel.displayName}! ${channel.description}`,
        lastMessageTimestamp: nowMillis,
        createdAt: nowMillis,
        updatedAt: nowMillis,
        unreadCount: 0,
      };

      await rtdb.ref(`conversations/${channel.id}`).set(rtdbData);
      console.log(`  ✅ RTDB: conversations/${channel.id}`);

      results.push({
        channel: channel.displayName,
        id: channel.id,
        status: "created",
      });
    }

    console.log("✅ All channels seeded successfully!");

    res.status(200).send({
      success: true,
      message: "Default channels seeded successfully",
      channels: results,
      creatorUID: creatorUID,
    });
  } catch (error: unknown) {
    console.error("❌ Error seeding channels:", error);
    res.status(500).send({
      error: "Failed to seed channels",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
