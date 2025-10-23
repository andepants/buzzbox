/**
 * seedDefaultChannels.ts
 *
 * Seeds the three default channels (general, announcements, off-topic)
 * into Firebase for the Buzzbox single-creator platform.
 *
 * Usage: npm run seed-channels
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "buzzbox-ios",
    databaseURL: "https://buzzbox-ios-default-rtdb.firebaseio.com",
  });
}

const db = admin.firestore();
const rtdb = admin.database();

interface Channel {
  id: string;
  displayName: string;
  description: string;
  isCreatorOnly: boolean;
}

const DEFAULT_CHANNELS: Channel[] = [
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
    isCreatorOnly: true, // Only creator can post
  },
  {
    id: "off-topic",
    displayName: "#off-topic",
    description: "Casual conversations and off-topic chat",
    isCreatorOnly: false,
  },
];

/**
 * Seed a channel to both Firestore and Realtime Database
 * @param {Channel} channel - Channel configuration object
 * @param {string} creatorUID - Creator user ID
 * @return {Promise<void>}
 */
async function seedChannel(channel: Channel, creatorUID: string): Promise<void> {
  console.log(`🌱 Seeding channel: ${channel.displayName}`);

  const now = admin.firestore.Timestamp.now();
  const nowMillis = Date.now();

  // 1. Create in Firestore (conversations collection)
  const firestoreData = {
    participantIDs: [creatorUID], // Start with creator only
    displayName: channel.displayName,
    groupPhotoURL: "",
    adminUserIDs: [creatorUID],
    isGroup: true,
    isCreatorOnly: channel.isCreatorOnly,
    createdAt: now,
    updatedAt: now,
    lastMessage: `Welcome to ${channel.displayName}!`,
    lastMessageTimestamp: now,
    lastMessageSenderID: creatorUID,
  };

  await db.collection("conversations").doc(channel.id).set(firestoreData);
  console.log(`  ✅ Firestore: conversations/${channel.id}`);

  // 2. Create in Realtime Database (conversations path)
  const rtdbData = {
    participantIDs: {
      [creatorUID]: true, // Object format for security rules
    },
    adminUserIDs: {
      [creatorUID]: true,
    },
    isGroup: true,
    isCreatorOnly: channel.isCreatorOnly,
    groupName: channel.displayName,
    groupPhotoURL: "",
    lastMessage: `Welcome to ${channel.displayName}!`,
    lastMessageTimestamp: nowMillis,
    createdAt: nowMillis,
    updatedAt: nowMillis,
    unreadCount: 0,
  };

  await rtdb.ref(`conversations/${channel.id}`).set(rtdbData);
  console.log(`  ✅ RTDB: conversations/${channel.id}`);

  // 3. Create welcome message in RTDB
  const welcomeMessageRef = rtdb.ref(`messages/${channel.id}`).push();
  const welcomeMessage = {
    id: welcomeMessageRef.key,
    conversationID: channel.id,
    senderID: creatorUID,
    text: `Welcome to ${channel.displayName}! ${channel.description}`,
    timestamp: nowMillis,
    createdAt: nowMillis,
    isSystemMessage: true,
    reactions: {},
    readBy: {
      [creatorUID]: true,
    },
  };

  await welcomeMessageRef.set(welcomeMessage);
  console.log(`  ✅ RTDB: messages/${channel.id}/${welcomeMessageRef.key}`);
}

/**
 * Main seeding function
 */
async function seedDefaultChannels() {
  console.log("🚀 Starting default channel seeding...\n");

  try {
    // Get the creator's UID (andrewsheim@gmail.com)
    const CREATOR_EMAIL = "andrewsheim@gmail.com";

    // Find creator user
    const usersSnapshot = await db
      .collection("users")
      .where("email", "==", CREATOR_EMAIL)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ Creator user not found with email: ${CREATOR_EMAIL}`);
      console.log("\n💡 Please ensure the creator account exists before seeding channels.");
      process.exit(1);
    }

    const creatorDoc = usersSnapshot.docs[0];
    const creatorUID = creatorDoc.id;
    console.log(`✅ Found creator: ${CREATOR_EMAIL} (UID: ${creatorUID})\n`);

    // Seed each channel
    for (const channel of DEFAULT_CHANNELS) {
      try {
        await seedChannel(channel, creatorUID);
        console.log("");
      } catch (error) {
        console.error(`❌ Failed to seed ${channel.displayName}:`, error);
      }
    }

    console.log("✅ Default channels seeded successfully!");
    console.log("\n📝 Summary:");
    console.log("   - 3 channels created in Firestore");
    console.log("   - 3 channels created in Realtime Database");
    console.log("   - 3 welcome messages created");
    console.log("\n💡 Users will auto-join these channels on signup.");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error seeding channels:", error);
    process.exit(1);
  }
}

// Run the seeding function
seedDefaultChannels();
