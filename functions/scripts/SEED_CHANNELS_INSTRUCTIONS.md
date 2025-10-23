# Seeding Default Channels

## ✅ Realtime Database - COMPLETED

The Realtime Database channels have been automatically seeded at:
`https://console.firebase.google.com/project/buzzbox-ios/database/buzzbox-ios-default-rtdb/data/conversations`

## 📝 Firestore - Manual Steps Required

You need to manually create 3 documents in the Firestore `conversations` collection.

### Option 1: Use Firebase Console (Recommended)

1. Visit: https://console.firebase.google.com/project/buzzbox-ios/firestore/data
2. Click on "Start collection" or select the existing `conversations` collection
3. Create each document below:

---

### Document 1: `general`

**Document ID:** `general`

**Fields:**
```
participantIDs: [] (array)
adminUserIDs: [] (array)
displayName: "#general" (string)
groupPhotoURL: "" (string)
isGroup: true (boolean)
isCreatorOnly: false (boolean)
createdAt: [Click "Add field" > Select "timestamp" type]
updatedAt: [Click "Add field" > Select "timestamp" type]
lastMessage: "Welcome to #general! General discussion and community chat" (string)
lastMessageTimestamp: [Click "Add field" > Select "timestamp" type]
lastMessageSenderID: "" (string)
```

---

### Document 2: `announcements`

**Document ID:** `announcements`

**Fields:**
```
participantIDs: [] (array)
adminUserIDs: [] (array)
displayName: "#announcements" (string)
groupPhotoURL: "" (string)
isGroup: true (boolean)
isCreatorOnly: true (boolean)
createdAt: [Click "Add field" > Select "timestamp" type]
updatedAt: [Click "Add field" > Select "timestamp" type]
lastMessage: "Welcome to #announcements! Important updates from Andrew" (string)
lastMessageTimestamp: [Click "Add field" > Select "timestamp" type]
lastMessageSenderID: "" (string)
```

---

### Document 3: `off-topic`

**Document ID:** `off-topic`

**Fields:**
```
participantIDs: [] (array)
adminUserIDs: [] (array)
displayName: "#off-topic" (string)
groupPhotoURL: "" (string)
isGroup: true (boolean)
isCreatorOnly: false (boolean)
createdAt: [Click "Add field" > Select "timestamp" type]
updatedAt: [Click "Add field" > Select "timestamp" type]
lastMessage: "Welcome to #off-topic! Casual conversations and off-topic chat" (string)
lastMessageTimestamp: [Click "Add field" > Select "timestamp" type]
lastMessageSenderID: "" (string)
```

---

## ✅ Verification

After creating all documents:

1. Open the Buzzbox app
2. Navigate to the Channels tab
3. You should now see all 3 channels: #general, #announcements, #off-topic
4. New users will automatically join these channels on signup

## 🔄 Auto-Join Behavior

- New users automatically join all three channels during signup (see `AuthService.swift:163-169`)
- Existing users may need to be manually added to channels, or you can re-login to trigger auto-join
