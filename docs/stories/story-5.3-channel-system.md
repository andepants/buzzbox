# Story 5.3: Channel System

## Status
Draft

## Story
**As a** fan,
**I want** to see topic-based channels,
**so that** I can participate in organized discussions with other community members.

## Acceptance Criteria

1. Default channels are pre-seeded in Firebase before app launch (manual setup)
2. Three channels exist: #general, #announcements, #off-topic
3. Channels use existing group chat infrastructure (ConversationEntity with isGroup = true)
4. #announcements blocks fan posting (shows read-only UI with lock icon)
5. #general and #off-topic allow everyone to post
6. Channel list shows all 3 channels for all users
7. Channels are named with # prefix in UI
8. "Groups" terminology is replaced with "Channels" throughout UI
9. ConversationEntity has `isCreatorOnly` field for permission control
10. Channels persist across app restarts and devices
11. New users automatically join all default channels on account creation
12. Channels are synced from Firebase (not created locally)

## Tasks / Subtasks

- [ ] Update ConversationEntity data model (AC: 8)
  - [ ] Add isCreatorOnly: Bool property to ConversationEntity
  - [ ] Update SwiftData @Model to include new field
  - [ ] Add to Firestore conversation schema
  - [ ] Set default value to false for existing conversations
  - [ ] Ensure Codable conformance

- [ ] Pre-seed channels in Firebase (AC: 1, 2, 4, 12)
  - [ ] Manually create 3 channels in Firestore before app launch
  - [ ] Channel 1: id="general", name="#general", isGroup=true, isCreatorOnly=false
  - [ ] Channel 2: id="announcements", name="#announcements", isGroup=true, isCreatorOnly=true
  - [ ] Channel 3: id="off-topic", name="#off-topic", isGroup=true, isCreatorOnly=false
  - [ ] Set participantIDs to empty array initially (users join on signup)
  - [ ] Document pre-seeding steps in deployment guide

- [ ] Implement auto-join on user signup (AC: 11)
  - [ ] On user account creation, fetch all channels
  - [ ] Add user.id to participantIDs array for each channel
  - [ ] Sync updated participantIDs to Firestore
  - [ ] Ensure channels immediately visible to new user
  - [ ] Handle errors gracefully if auto-join fails

- [ ] Implement creator-only posting logic (AC: 3, 4)
  - [ ] Check isCreatorOnly flag before allowing message send
  - [ ] If isCreatorOnly = true AND user.userType = .fan, block send
  - [ ] Show appropriate error message to fans
  - [ ] Creator can always post to any channel

- [ ] Update UI terminology from "Groups" to "Channels" (AC: 7)
  - [ ] Rename ConversationListView tab label to "Channels"
  - [ ] Update "New Group" button to "New Channel" (or hide it)
  - [ ] Change header text from "Groups" to "Channels"
  - [ ] Update empty state messages
  - [ ] Search through codebase for "Group" strings and replace where appropriate

- [ ] Add channel UI indicators (AC: 3, 6)
  - [ ] Display # prefix before channel names in list view
  - [ ] Show lock icon for creator-only channels
  - [ ] Add read-only indicator in message composer for restricted channels
  - [ ] Disable message input field for fans in creator-only channels
  - [ ] Show tooltip: "Only Andrew can post here" when fan tries to post

- [ ] Ensure channels use group chat infrastructure (AC: 2, 9)
  - [ ] Verify channels are ConversationEntity with isGroup = true
  - [ ] Reuse existing group chat UI components
  - [ ] Reuse existing group message sending logic
  - [ ] Reuse existing group chat real-time sync
  - [ ] Ensure offline support works for channels

## Dev Notes

### Architecture Context

**Channel = Group Chat with Permissions:**
- Channels are just ConversationEntity objects with `isGroup = true`
- 100% reuse of existing group chat infrastructure
- Only new addition: `isCreatorOnly` permission flag
- No new UI components needed - reuse MessageThreadView, ConversationListView, etc.

**Data Model:**
```swift
@Model
final class ConversationEntity {
    var id: String
    var participantIDs: [String]
    var isGroup: Bool
    var name: String?
    var photoURL: String?

    // NEW: Permission control
    var isCreatorOnly: Bool = false

    var createdAt: Date
    var lastMessageAt: Date?
}
```

**Channel Pre-Seeding Strategy:**
Channels are manually created in Firestore before app launch, not programmatically seeded.

**Manual Firestore Setup (one-time):**
```javascript
// Create in Firestore console or via script
// Collection: conversations

// Document 1: general
{
  id: "general",
  name: "#general",
  isGroup: true,
  isCreatorOnly: false,
  participantIDs: [],  // Users join on signup
  createdAt: Timestamp.now(),
  lastMessageAt: null
}

// Document 2: announcements
{
  id: "announcements",
  name: "#announcements",
  isGroup: true,
  isCreatorOnly: true,
  participantIDs: [],
  createdAt: Timestamp.now(),
  lastMessageAt: null
}

// Document 3: off-topic
{
  id: "off-topic",
  name: "#off-topic",
  isGroup: true,
  isCreatorOnly: false,
  participantIDs: [],
  createdAt: Timestamp.now(),
  lastMessageAt: null
}
```

**Auto-Join on Signup:**
```swift
// In AuthService.signUp() after user creation
func autoJoinDefaultChannels(userId: String) async throws {
    let channelIds = ["general", "announcements", "off-topic"]

    for channelId in channelIds {
        try await firestoreService.addUserToChannel(
            userId: userId,
            channelId: channelId
        )
    }
}
```

**Permission Check:**
```swift
func canPostToConversation(_ conversation: ConversationEntity, user: UserEntity) -> Bool {
    if !conversation.isCreatorOnly { return true }
    return user.isCreator
}
```

### Source Tree
```
Core/
├── Models/
│   └── ConversationEntity.swift (Add isCreatorOnly)
├── Services/
│   └── ChannelSeeder.swift (NEW)
├── Views/
│   ├── Conversations/
│   │   ├── ConversationListView.swift (Update labels to "Channels")
│   │   └── ConversationRowView.swift (Add # prefix, lock icon)
│   └── Messages/
│       └── MessageComposerView.swift (Add permission check)
└── ViewModels/
    └── ConversationListViewModel.swift (Update terminology)
```

### Default Channels

| ID | Name | Description | isCreatorOnly |
|----|------|-------------|---------------|
| general | #general | Main discussion | false |
| announcements | #announcements | Creator posts only | true |
| off-topic | #off-topic | Casual chat | false |

### Integration Points
- **Reuses:** Epic 3 group chat infrastructure (100%)
- **Adds:** Permission system for creator-only channels
- **Changes:** UI terminology only (Groups → Channels)

### Dependencies
- **Depends on:** Epic 3 (Group Chat) - Group chat infrastructure must exist
- **Depends on:** Story 5.2 (User Type) - Need userType for permission checks
- **Blocks:** Story 5.5 (Creator Inbox) - Channels are part of community structure

## Testing

### Testing Standards
- Manual testing on simulator and physical device
- Test channel creation on first launch
- Test persistence across app restarts
- Verify real-time messaging works in channels
- Test creator-only permissions

### Test Cases

1. **First Launch - Channel Seeding:**
   - Fresh install of app
   - Create account and login
   - Verify 3 channels appear immediately
   - Check each channel has correct name and # prefix
   - Verify all 3 channels show in Channels tab

2. **Channel Persistence:**
   - Force quit app after channels are created
   - Relaunch app
   - Verify same 3 channels still exist
   - Verify no duplicate channels created
   - Check messages sent before quit are still visible

3. **Creator-Only Permissions (#announcements):**
   - Login as fan account
   - Navigate to #announcements channel
   - See lock icon on channel
   - Message composer is disabled/read-only
   - See "Only Andrew can post here" message
   - Cannot send messages

4. **Creator Posting:**
   - Login as Andrew (creator)
   - Navigate to #announcements
   - No restrictions on message composer
   - Can send messages successfully
   - Messages appear in real-time

5. **Everyone Can Post (#general, #off-topic):**
   - Login as fan account
   - Navigate to #general
   - Message composer is enabled
   - Can type and send messages
   - Messages sync to other users in real-time

6. **UI Terminology:**
   - Check Channels tab label (not "Groups")
   - Check channel names have # prefix
   - Check empty states mention "channels"
   - Search for any remaining "Group" terminology

7. **Multi-User Real-Time:**
   - Login on two devices (one as creator, one as fan)
   - Send message from creator in #announcements
   - Verify fan sees message in real-time
   - Send message from fan in #general
   - Verify creator sees message in real-time

8. **Offline Support:**
   - Disconnect from internet
   - Open #general channel
   - Send message (should queue)
   - Reconnect to internet
   - Verify message syncs to Firestore

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial story creation from Epic 5 | Sarah (PO) |

## Dev Agent Record

### Agent Model Used
_To be filled by dev agent_

### Debug Log References
_To be filled by dev agent_

### Completion Notes List
_To be filled by dev agent_

### File List
_To be filled by dev agent_

## QA Results
_To be filled by QA agent_
