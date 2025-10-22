---
# Story 3.7: Group Message Notifications
# Epic 3: Group Chat
# Status: Draft

id: STORY-3.7
title: "Send FCM Notifications for Group Messages"
epic: "Epic 3: Group Chat"
status: draft
priority: P1
estimate: 3  # Story points (45 minutes)
assigned_to: null
created_date: "2025-10-21"
sprint_day: null

---

## Description

**As a** group chat participant
**I need** to receive push notifications when someone sends a message in a group
**So that** I stay updated on group conversations even when the app is in the background

This story extends the Cloud Functions notification system (from Story 2.0B) to support group messages:
- Sends FCM notifications to all participants except sender
- Notification title: "{SenderName} in {GroupName}"
- Deep links to MessageThreadView for that group
- Notification stacking/grouping by conversation
- System messages don't trigger notifications
- Works with offline message queue

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Group message triggers FCM notification to all participants except sender
- [ ] Notification title format: "{SenderName} in {GroupName}"
- [ ] Notification body shows message preview (truncated to 100 characters)
- [ ] Tapping notification deep links to MessageThreadView for that group
- [ ] Notification includes conversationID in data payload for deep linking
- [ ] Multiple messages from same group stack together (iOS notification grouping)
- [ ] System messages (joins, leaves) don't trigger notifications
- [ ] Group photo shown as notification icon (if available)
- [ ] Notification sound plays for unmuted groups
- [ ] Works with offline queue: queued messages send notifications when synced

---

## Technical Tasks

**Implementation steps:**

1. **Update Cloud Functions `onMessageCreated`** [Source: epic-3-group-chat.md lines 1280-1297]
   - Extend existing function from Story 2.0B
   - Detect `isGroup` flag in RTDB conversation
   - If group: loop through all participantIDs (exclude sender)
   - Use `sendEachForMulticast` for multiple recipients
   - Title format: "{SenderName} in {GroupName}"
   - Add `threadId` to APNS payload for notification stacking

2. **Implement Multi-Recipient FCM Sending** [Source: epic-3-group-chat.md lines 1292-1296]
   - Fetch FCM tokens for all participants (except sender)
   - Build token array: `[token1, token2, token3]`
   - Use `admin.messaging().sendEachForMulticast()` instead of `send()`
   - Handle partial failures (some tokens invalid, some succeed)
   - Log failures for debugging

3. **Build Group Notification Payload** [Source: epic-3-group-chat.md lines 1306-1332]
   - Title: "{SenderDisplayName} in {GroupName}"
   - Body: Message text (truncated to 100 chars)
   - Data: `conversationID`, `messageID`, `senderID`, `isGroup: "true"`, `timestamp`
   - APNS: `threadId` = conversationID (for stacking)
   - APNS: `sound` = "default", `badge` = increment

4. **Filter System Messages** [Source: epic-3-group-chat.md lines 1296]
   - Check if `isSystemMessage == true` in RTDB message
   - If true: skip notification sending
   - System messages (joins, leaves, name changes) don't notify

5. **Update iOS AppDelegate for Deep Linking** [Source: epic-3-group-chat.md lines 1333-1338]
   - Handle notification tap with conversationID
   - Post NotificationCenter event: "OpenConversation" with conversationID
   - RootView observes event, presents MessageThreadView for group
   - Works for both 1:1 and group conversations

6. **Add Notification Grouping (Thread-ID)** [Source: epic-3-group-chat.md lines 1296, 1321-1327]
   - Set `threadId` in APNS payload = conversationID
   - iOS stacks multiple notifications from same group
   - User sees: "3 new messages in Family Group"
   - Tapping expands to show individual notifications

7. **Handle Offline Queue Notifications**
   - When queued messages sync to RTDB, Cloud Functions trigger
   - Notifications sent as normal (no special handling needed)
   - User receives notifications for messages sent while offline

---

## Technical Specifications

### Files to Modify

```
functions/src/index.ts (modify - extend onMessageCreated for groups)
sorted/App/AppDelegate.swift (modify - handle group deep links)
sorted/Features/Root/RootView.swift (modify - observe OpenConversation event)
```

### Cloud Functions Extension

**Key Changes from 1:1 Chat (Story 2.0B):**
```typescript
// In functions/src/index.ts

export const onMessageCreated = functions.database
  .ref('/messages/{conversationID}/{messageID}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.val();
    const { conversationID, messageID } = context.params;

    // Skip system messages
    if (message.isSystemMessage === true) {
      console.log('Skipping system message notification');
      return null;
    }

    // Fetch conversation
    const conversationSnap = await admin.database()
      .ref(`/conversations/${conversationID}`)
      .once('value');
    const conversation = conversationSnap.val();

    // Detect if group
    const isGroup = conversation.isGroup === true;
    const senderID = message.senderID;

    // Get sender display name
    const senderDoc = await admin.firestore()
      .collection('users')
      .doc(senderID)
      .get();
    const senderName = senderDoc.data()?.displayName || 'Someone';

    if (isGroup) {
      // GROUP MESSAGE NOTIFICATION
      const groupName = conversation.groupName || 'Group Chat';
      const participantIDs = Object.keys(conversation.participantIDs || {});

      // Fetch FCM tokens for all participants except sender
      const recipientIDs = participantIDs.filter(id => id !== senderID);
      const tokens: string[] = [];

      for (const recipientID of recipientIDs) {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(recipientID)
          .get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) {
          tokens.push(fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for group participants');
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
          type: 'new_message',
          isGroup: 'true',
          timestamp: String(message.serverTimestamp || Date.now()),
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
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

      console.log(`Group notification sent: ${response.successCount} succeeded, ${response.failureCount} failed`);
      return null;

    } else {
      // 1:1 MESSAGE NOTIFICATION (existing logic from Story 2.0B)
      // ... existing code ...
    }
  });
```

### FCM Payload Structure (Group)

```json
{
  "notification": {
    "title": "Alice Smith in Family Group",
    "body": "Hey everyone, how's it going?"
  },
  "data": {
    "conversationID": "group_abc123",
    "messageID": "msg_xyz789",
    "type": "new_message",
    "senderID": "user1",
    "isGroup": "true",
    "timestamp": "1704067200000"
  },
  "apns": {
    "payload": {
      "aps": {
        "sound": "default",
        "badge": 1,
        "threadId": "group_abc123"
      }
    }
  }
}
```

### Deep Linking Flow

```
1. User B receives notification
2. User B taps notification
3. AppDelegate receives userInfo dict
4. AppDelegate posts NotificationCenter event:
   - Name: "OpenConversation"
   - Object: conversationID
5. RootView observes event
6. RootView fetches ConversationEntity by ID
7. RootView presents MessageThreadView
```

### Dependencies

**Required:**
- ✅ Story 2.0B: Cloud Functions FCM (foundation)
- ✅ Story 3.1: Create Group Conversation (groups in RTDB)
- ✅ Epic 1: Authentication (user profiles in Firestore)
- ✅ Firebase Cloud Functions deployed
- ✅ FCM configured in iOS app

**Blocks:**
- None (final story in Epic 3)

**External:**
- Firebase Cloud Functions project configured
- FCM tokens stored in Firestore `/users/{userID}/fcmToken`
- APNS certificates configured in Firebase Console

---

## Testing & Validation

### Test Procedure

1. **Group Message Notification (3 Participants):**
   - Create group: User A, User B, User C
   - User A sends message: "Hello everyone"
   - User B receives notification:
     - Title: "Alice in Test Group"
     - Body: "Hello everyone"
   - User C receives same notification
   - User A does NOT receive notification (sender excluded)

2. **Notification Title Format:**
   - User A sends message in "Family Group"
   - User B receives notification
   - Title: "Alice Smith in Family Group"
   - Not just "Alice Smith" (missing group name)

3. **Message Truncation:**
   - User A sends long message (200 characters)
   - User B receives notification
   - Body truncated to 100 characters + "..."

4. **Deep Link Navigation:**
   - User B receives notification
   - User B taps notification
   - App opens (or comes to foreground)
   - MessageThreadView for that group appears
   - Shows conversation with User A's message

5. **Notification Stacking (Thread-ID):**
   - User A sends 5 rapid messages in group
   - User B receives 5 notifications
   - iOS stacks them under single thread
   - Notification center shows: "5 notifications" under "Family Group"
   - Expanding shows all 5 messages

6. **System Message Filtering:**
   - User A creates group (system message: "Alice created the group")
   - User B does NOT receive notification
   - User A adds User C (system message: "Alice added Charlie")
   - User B and User C do NOT receive notifications

7. **Offline Queue Notifications:**
   - User A goes offline
   - User A sends message (queued locally)
   - User A reconnects
   - Message syncs to RTDB
   - Cloud Function triggers
   - User B receives notification

8. **Partial Failure Handling:**
   - Group with 5 participants
   - 2 participants have invalid FCM tokens
   - User A sends message
   - 3 participants receive notification (success)
   - 2 participants don't receive (logged as failures)
   - No errors thrown

9. **1:1 Chat Compatibility:**
   - User A sends message in 1:1 chat
   - Notification title: "Alice Smith" (not "in Group")
   - Verify group changes don't break 1:1

### Success Criteria

- [ ] Builds without errors (Cloud Functions and iOS app)
- [ ] Deploys to Firebase Cloud Functions successfully
- [ ] Group messages trigger FCM notifications
- [ ] All participants (except sender) receive notifications
- [ ] Notification title format correct: "{SenderName} in {GroupName}"
- [ ] Message body truncated to 100 chars
- [ ] Deep linking works (tap notification → opens group)
- [ ] Notification stacking works (threadId set)
- [ ] System messages don't trigger notifications
- [ ] Offline queue messages trigger notifications when synced
- [ ] Partial failures handled gracefully
- [ ] 1:1 chat notifications still work

---

## References

**Architecture Docs:**
- `docs/architecture/unified-project-structure.md` - File organization

**PRD Sections:**
- `docs/prd.md` - Epic 3: Group Chat (Notifications)

**Epic Documentation:**
- `docs/epics/epic-3-group-chat.md` - Story 3.7 specification (lines 1263-1372)

**Related Stories:**
- Story 2.0B: Cloud Functions FCM (foundation)
- Story 3.1: Create Group Conversation (group infrastructure)

**Implementation Guides:**
- Firebase Cloud Messaging Docs: https://firebase.google.com/docs/cloud-messaging
- Firebase Cloud Functions Docs: https://firebase.google.com/docs/functions

---

## Notes & Considerations

### Implementation Notes

**Multi-Recipient Sending:**
- Use `sendEachForMulticast()` for efficiency (batch sending)
- Don't use `send()` in a loop (inefficient, rate-limited)
- Max 500 tokens per multicast request

**Notification Stacking:**
- Set `threadId` in APNS payload = conversationID
- iOS automatically stacks notifications with same threadId
- User sees grouped notifications in Notification Center

**System Message Filtering:**
- Check `isSystemMessage` field in RTDB message
- Skip notification sending if true
- Prevents spam from group management actions

**Error Handling:**
- Log failures for debugging
- Don't throw errors (prevents other notifications)
- Invalid tokens automatically removed by FCM

### Edge Cases

- User has no FCM token → skip silently
- All participants offline → notifications queued by FCM
- Group with 1 participant (sender only) → no notifications sent
- Message deleted before Cloud Function triggers → handle gracefully
- Sender's token invalid → they don't receive notification (expected)
- Large group (100+ participants) → batch token fetching

### Performance Considerations

- Fetch FCM tokens in parallel (use Promise.all)
- Batch notification sending with multicast
- Limit notification payload size (avoid large data objects)
- Cache sender display name (avoid repeated Firestore fetches)

### Security Considerations

- Cloud Functions run with admin privileges (secure)
- Validate participantIDs before sending notifications
- Don't include sensitive data in notification payload
- FCM tokens rotated automatically (no manual management)
- RTDB rules prevent unauthorized message creation

---

## Dev Notes

**CRITICAL: This section contains ALL implementation context needed. Developer should NOT need to read external docs.**

### Cloud Functions onMessageCreated Extension for Groups
[Source: epic-3-group-chat.md lines 1280-1297, Story 2.0B]

**Extend Existing Cloud Function from Story 2.0B:**
```typescript
// In functions/src/index.ts

export const onMessageCreated = functions.database
  .ref('/messages/{conversationID}/{messageID}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.val();
    const { conversationID, messageID } = context.params;

    // Skip system messages
    if (message.isSystemMessage === true) {
      console.log('Skipping system message notification');
      return null;
    }

    // Fetch conversation
    const conversationSnap = await admin.database()
      .ref(`/conversations/${conversationID}`)
      .once('value');
    const conversation = conversationSnap.val();

    // Detect if group
    const isGroup = conversation.isGroup === true;
    const senderID = message.senderID;

    // Get sender display name
    const senderDoc = await admin.firestore()
      .collection('users')
      .doc(senderID)
      .get();
    const senderName = senderDoc.data()?.displayName || 'Someone';

    if (isGroup) {
      // GROUP MESSAGE NOTIFICATION
      const groupName = conversation.groupName || 'Group Chat';
      const participantIDs = Object.keys(conversation.participantIDs || {});

      // Fetch FCM tokens for all participants except sender
      const recipientIDs = participantIDs.filter(id => id !== senderID);
      const tokens: string[] = [];

      for (const recipientID of recipientIDs) {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(recipientID)
          .get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) {
          tokens.push(fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for group participants');
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
          type: 'new_message',
          isGroup: 'true',
          timestamp: String(message.serverTimestamp || Date.now()),
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
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

      console.log(`Group notification sent: ${response.successCount} succeeded, ${response.failureCount} failed`);
      return null;

    } else {
      // 1:1 MESSAGE NOTIFICATION (existing logic from Story 2.0B)
      // ... existing code ...
    }
  });
```

**CRITICAL Changes from 1:1 Chat:**
- Detect `isGroup` flag in conversation
- Loop through ALL `participantIDs` (exclude sender)
- Use `sendEachForMulticast()` instead of `send()` for multiple recipients
- Title format: `"{SenderName} in {GroupName}"`
- Add `threadId` to APNS payload for notification stacking

### Multi-Recipient FCM Sending with sendEachForMulticast
[Source: epic-3-group-chat.md lines 1292-1296]

**CRITICAL: Use multicast for efficiency**

```typescript
// DON'T: Loop and send individually (inefficient, rate-limited)
for (const token of tokens) {
  await admin.messaging().send({
    token: token,
    ...payload
  });
}

// DO: Use sendEachForMulticast for batch sending
const response = await admin.messaging().sendEachForMulticast({
  tokens: tokens,  // Array of FCM tokens (max 500)
  notification: {
    title: `${senderName} in ${groupName}`,
    body: message.text.substring(0, 100),
  },
  data: {
    conversationID: conversationID,
    messageID: messageID,
    senderID: senderID,
    type: 'new_message',
    isGroup: 'true',
    timestamp: String(message.serverTimestamp || Date.now()),
  },
  apns: {
    payload: {
      aps: {
        sound: 'default',
        badge: 1,
        threadId: conversationID,
      },
    },
  },
});

console.log(`Group notification sent: ${response.successCount} succeeded, ${response.failureCount} failed`);
```

**Partial Failure Handling:**
```typescript
// Handle partial failures (some tokens invalid, some succeed)
if (response.failureCount > 0) {
  const failedTokens: string[] = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      console.log(`Failed to send to token ${tokens[idx]}: ${resp.error}`);
      failedTokens.push(tokens[idx]);
    }
  });
  // Optionally: Remove invalid tokens from Firestore
}
```

**Max 500 Tokens per Multicast:**
- If group has >500 participants, batch into multiple multicast requests
- Split tokens array into chunks of 500

### Notification Payload Structure for Groups
[Source: epic-3-group-chat.md lines 1306-1332]

**FCM Payload:**
```json
{
  "notification": {
    "title": "Alice Smith in Family Group",
    "body": "Hey everyone, how's it going?"
  },
  "data": {
    "conversationID": "group_abc123",
    "messageID": "msg_xyz789",
    "type": "new_message",
    "senderID": "user1",
    "isGroup": "true",
    "timestamp": "1704067200000"
  },
  "apns": {
    "payload": {
      "aps": {
        "sound": "default",
        "badge": 1,
        "threadId": "group_abc123"
      }
    }
  }
}
```

**CRITICAL Fields:**
- `notification.title`: `"{SenderName} in {GroupName}"`
- `notification.body`: Message text (truncated to 100 chars)
- `data.conversationID`: For deep linking
- `data.messageID`: Unique message identifier
- `data.isGroup`: `"true"` (string, not boolean)
- `data.timestamp`: Server timestamp
- `apns.payload.aps.threadId`: conversationID (for notification stacking)
- `apns.payload.aps.sound`: "default"
- `apns.payload.aps.badge`: 1 (increment badge count)

### System Message Filtering
[Source: epic-3-group-chat.md lines 1296]

**CRITICAL: Skip notifications for system messages**

```typescript
// At the top of Cloud Function
if (message.isSystemMessage === true) {
  console.log('Skipping system message notification');
  return null;
}
```

**System messages that DON'T trigger notifications:**
- Group created: "Alice created the group"
- Participant added: "Alice added Bob"
- Participant removed: "Alice removed Bob"
- User left: "Alice left the group"
- Name changed: "Alice changed the group name to..."

**System Message Detection:**
- Field: `isSystemMessage: true` in RTDB message
- Field: `senderID: "system"` in RTDB message

### iOS AppDelegate Deep Linking for Groups
[Source: epic-3-group-chat.md lines 1333-1338]

**Handle Notification Tap (AppDelegate.swift):**
```swift
// In AppDelegate.swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo

    if let conversationID = userInfo["conversationID"] as? String {
        // Post NotificationCenter event
        NotificationCenter.default.post(
            name: Notification.Name("OpenConversation"),
            object: nil,
            userInfo: ["conversationID": conversationID]
        )
    }

    completionHandler()
}
```

**RootView Observes Event:**
```swift
// In RootView.swift
.onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenConversation"))) { notification in
    guard let userInfo = notification.userInfo,
          let conversationID = userInfo["conversationID"] as? String else { return }

    // Fetch ConversationEntity
    let descriptor = FetchDescriptor<ConversationEntity>(
        predicate: #Predicate<ConversationEntity> { conv in
            conv.id == conversationID
        }
    )
    if let conversation = try? modelContext.fetch(descriptor).first {
        // Present MessageThreadView
        selectedConversation = conversation
        showMessageThread = true
    }
}
```

**Deep Linking Flow:**
```
1. User B receives notification
2. User B taps notification
3. AppDelegate receives userInfo dict
4. AppDelegate posts NotificationCenter event: "OpenConversation" with conversationID
5. RootView observes event
6. RootView fetches ConversationEntity by ID
7. RootView presents MessageThreadView (works for both 1:1 and group)
```

### Notification Stacking with threadId
[Source: epic-3-group-chat.md lines 1296, 1321-1327]

**CRITICAL: Set threadId for iOS notification grouping**

```typescript
apns: {
  payload: {
    aps: {
      sound: 'default',
      badge: 1,
      threadId: conversationID  // CRITICAL: Same conversationID groups notifications
    }
  }
}
```

**iOS Behavior:**
- Multiple notifications from same group stack together
- User sees: "3 new messages in Family Group"
- Tapping expands to show individual notifications
- Reduces notification clutter

### Offline Queue Notifications
[Source: Story 3.7 specification lines 95-97]

**CRITICAL: Cloud Functions trigger for queued messages**

```
1. User A goes offline
2. User A sends message (queued locally with syncStatus: .pending)
3. User A reconnects
4. SyncCoordinator syncs message to RTDB
5. Cloud Function onMessageCreated triggers
6. Notifications sent to all participants (except User A)
```

**No special handling needed:**
- Offline messages queue locally (SwiftData)
- When online, SyncCoordinator syncs to RTDB
- Cloud Function triggers on RTDB write
- Notifications sent as normal

### 1:1 Chat Compatibility
[Source: epic-3-group-chat.md lines 1263-1372]

**CRITICAL: Preserve existing 1:1 chat logic**

```typescript
if (isGroup) {
  // GROUP MESSAGE NOTIFICATION (new logic)
  // ... group notification code ...
} else {
  // 1:1 MESSAGE NOTIFICATION (existing logic from Story 2.0B)
  // ... existing 1:1 notification code ...
}
```

**Ensure 1:1 chats still work:**
- Title: `"{SenderName}"` (NOT "in Group")
- Single recipient (not multicast)
- No `threadId` in APNS payload

### File Modification Order

**CRITICAL: Follow this exact sequence:**

1. Update `functions/src/index.ts` (extend onMessageCreated for groups)
2. Update `AppDelegate.swift` (handle group deep links)
3. Update `RootView.swift` (observe OpenConversation event)

### Testing Standards

**Manual Testing Required (No Unit Tests for MVP):**
- Test group message notification (3 participants)
- Test notification title format ("{SenderName} in {GroupName}")
- Test message body truncation (100 chars)
- Test deep link navigation (tap notification → opens group)
- Test notification stacking (multiple messages from same group)
- Test system message filtering (no notifications)
- Test offline queue notifications (queued messages send notifications when synced)
- Test 1:1 chat compatibility (verify 1:1 notifications still work)

**CRITICAL Edge Cases:**
1. Group message → all participants (except sender) receive notification
2. Notification title: "Alice in Test Group" (not just "Alice")
3. Long message → body truncated to 100 characters
4. Tap notification → MessageThreadView for that group appears
5. Multiple messages from same group → stack together
6. System message (join, leave) → NO notification sent
7. Offline queued message → notification sent when synced
8. Partial failure (some tokens invalid) → logged, other recipients succeed
9. 1:1 chat → notification title just "{SenderName}" (compatibility maintained)

**Deployment:**
- Deploy Cloud Functions: `firebase deploy --only functions`
- Test on physical device (FCM requires real device)
- Verify APNS certificates configured in Firebase Console

---

## Metadata

**Created by:** @sm (Scrum Master Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 2-3 of 7-day sprint
**Epic:** Epic 3: Group Chat
**Story points:** 3
**Priority:** P1

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-21 | 1.0 | Initial story creation | @sm (Scrum Master Bob) |
| 2025-10-21 | 1.1 | Added Dev Notes section per template compliance | @po (Product Owner Sarah) |

---

## Dev Agent Record

**This section is populated by the @dev agent during implementation.**

### Agent Model Used

*Agent model name and version will be recorded here by @dev*

### Debug Log References

*Links to debug logs or traces generated during development will be recorded here by @dev*

### Completion Notes

*Notes about task completion and any issues encountered will be recorded here by @dev*

### File List

*All files created, modified, or affected during story implementation will be listed here by @dev*

---

## QA Results

**This section is populated by the @qa agent after reviewing the completed story implementation.**

*QA validation results, test outcomes, and any issues found will be recorded here by @qa*

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review
- [ ] **Ready** - Story reviewed and ready for development
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Draft
