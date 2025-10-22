/**
 * seed-channels.js
 *
 * Pre-seeds default channels in Firestore for BuzzBox
 * Run this script ONCE before app launch to create #general, #announcements, #off-topic
 *
 * Usage:
 *   node seed-channels.js
 *
 * Prerequisites:
 *   - Firebase Admin SDK installed: npm install firebase-admin
 *   - Service account key downloaded from Firebase Console
 *   - Set GOOGLE_APPLICATION_CREDENTIALS environment variable
 *
 * Created: 2025-10-22
 * Source: Story 5.3 - Channel System
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Make sure GOOGLE_APPLICATION_CREDENTIALS environment variable is set
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

// Default channels configuration
const channels = [
  {
    id: 'general',
    name: '#general',
    isGroup: true,
    isCreatorOnly: false,
    participantIDs: [],
    adminUserIDs: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageAt: null,
    lastMessageText: '',
    lastMessageSenderID: null,
    isPinned: false,
    isMuted: false,
    isArchived: false,
    unreadCount: 0,
    groupPhotoURL: '',
    avatarURL: null,
    supermemoryConversationID: null
  },
  {
    id: 'announcements',
    name: '#announcements',
    isGroup: true,
    isCreatorOnly: true,  // Creator-only posting
    participantIDs: [],
    adminUserIDs: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageAt: null,
    lastMessageText: '',
    lastMessageSenderID: null,
    isPinned: false,
    isMuted: false,
    isArchived: false,
    unreadCount: 0,
    groupPhotoURL: '',
    avatarURL: null,
    supermemoryConversationID: null
  },
  {
    id: 'off-topic',
    name: '#off-topic',
    isGroup: true,
    isCreatorOnly: false,
    participantIDs: [],
    adminUserIDs: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageAt: null,
    lastMessageText: '',
    lastMessageSenderID: null,
    isPinned: false,
    isMuted: false,
    isArchived: false,
    unreadCount: 0,
    groupPhotoURL: '',
    avatarURL: null,
    supermemoryConversationID: null
  }
];

/**
 * Seed channels in Firestore
 */
async function seedChannels() {
  console.log('🚀 Starting channel seeding...\n');

  try {
    // Check if channels already exist
    for (const channel of channels) {
      const docRef = db.collection('conversations').doc(channel.id);
      const doc = await docRef.get();

      if (doc.exists) {
        console.log(`⚠️  Channel "${channel.name}" already exists. Skipping...`);
        continue;
      }

      // Create channel
      await docRef.set(channel);
      console.log(`✅ Created channel: ${channel.name}`);
      console.log(`   - ID: ${channel.id}`);
      console.log(`   - Creator-only: ${channel.isCreatorOnly}`);
      console.log(`   - Participants: ${channel.participantIDs.length}\n`);
    }

    console.log('✅ Channel seeding completed successfully!\n');
    console.log('📝 Next steps:');
    console.log('   1. Verify channels in Firebase Console: Firestore > conversations');
    console.log('   2. Users will auto-join these channels on signup');
    console.log('   3. Launch the app and verify channels appear\n');

  } catch (error) {
    console.error('🔴 Error seeding channels:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Run seeding
seedChannels();
