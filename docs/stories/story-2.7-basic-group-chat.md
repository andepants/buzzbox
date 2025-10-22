# Story 2.7: Basic Group Chat (3+ Participants)

**Epic:** Epic 2 - One-on-One Chat Infrastructure
**Priority:** P0 (MVP BLOCKER - Required for MVP completion)
**Estimated Time:** 2.5 hours
**Story Order:** After Story 2.6 (Typing Indicators)

---

## Story

**As a user,**
**I want to create and participate in group conversations with 3 or more people,**
**so that I can communicate with multiple people simultaneously in one conversation.**

---

## Acceptance Criteria

- [ ] User can create a group conversation with 3+ participants
- [ ] User can set a group name (required for 3+ participants)
- [ ] Group conversation appears in conversation list with group name and participant count
- [ ] Messages in group show sender name (not just "You" or recipient name)
- [ ] All participants receive messages in real-time via RTDB
- [ ] Group conversation persists locally (SwiftData) and syncs to RTDB
- [ ] User can view group participants list
- [ ] **Group conversation ID generation** uses hash instead of sorted participant IDs
- [ ] **Deterministic group ID** prevents duplicate groups with same participants
- [ ] **Message attribution** shows who sent each message in the thread
- [ ] **Read receipts** track who has read each message (basic: show count, not names)
- [ ] **Typing indicators** show "[User] is typing..." in group

---

## Tasks / Subtasks

- [ ] **Task 1: Update ConversationEntity for groups (AC: 1, 2, 8, 9)**
  - [ ] Add `groupName: String?` property to ConversationEntity
  - [ ] Add `isGroup: Bool` computed property (true if participantIDs.count > 2)
  - [ ] Update `conversationID` generation logic:
    - If 2 participants: use sorted IDs (existing logic)
    - If 3+ participants: generate deterministic hash from sorted participant IDs + group name
  - [ ] Add `participantCount: Int` computed property

- [ ] **Task 2: Create GroupChatCreationView (AC: 1, 2)**
  - [ ] Multi-select user picker (select 2+ recipients)
  - [ ] Group name text field (required for 3+ participants)
  - [ ] Participant list preview
  - [ ] Create button (enabled when name + 2+ participants selected)
  - [ ] Cancel button

- [ ] **Task 3: Update ConversationViewModel.createConversation for groups (AC: 1, 9)**
  - [ ] Accept optional `groupName` parameter
  - [ ] Accept array of `participantIDs` (not just single userID)
  - [ ] Generate deterministic group conversation ID:
    ```swift
    // For groups: hash of sorted participant IDs
    let sortedIDs = ([currentUserID] + participantIDs).sorted()
    let conversationID = sortedIDs.joined(separator: "_").sha256Hash()
    ```
  - [ ] Validate: minimum 3 participants for groups
  - [ ] Create ConversationEntity with groupName
  - [ ] Sync to RTDB with group metadata

- [ ] **Task 4: Update ConversationRowView for groups (AC: 3)**
  - [ ] Show group name instead of recipient name
  - [ ] Show participant count: "3 participants" below group name
  - [ ] Use group icon (multiple person icons) instead of single profile picture
  - [ ] Show last message sender: "John: Hello everyone!"

- [ ] **Task 5: Update MessageBubbleView for group attribution (AC: 4)**
  - [ ] Show sender name above message bubble (for messages from others)
  - [ ] Don't show sender name for own messages
  - [ ] Fetch sender displayName from Firestore for each message
  - [ ] Cache sender names to avoid repeated fetches

- [ ] **Task 6: Create GroupParticipantsView (AC: 7)**
  - [ ] List all participants with profile pictures and names
  - [ ] Show "You" indicator for current user
  - [ ] Accessible via navigation link in MessageThreadView header

- [ ] **Task 7: Update MessageThreadView header for groups (AC: 3, 6)**
  - [ ] Show group name in navigation title
  - [ ] Add participants button (shows GroupParticipantsView)
  - [ ] Show participant count subtitle

- [ ] **Task 8: Update RTDB structure for groups (AC: 5, 9)**
  - [ ] Add `isGroup: true` to group conversations
  - [ ] Add `groupName: String` to group conversations
  - [ ] Ensure `participants` object supports 3+ participants
  - [ ] Update security rules to allow 3+ participant conversations

- [ ] **Task 9: Update typing indicators for groups (AC: 12)**
  - [ ] Show "[DisplayName] is typing..." instead of just "Typing..."
  - [ ] Handle multiple users typing: "John and Sarah are typing..."
  - [ ] Fetch typing user display names from Firestore

- [ ] **Task 10: Update read receipts for groups (AC: 11)**
  - [ ] Track read status per participant in RTDB
  - [ ] Show read count: "Read by 2" instead of blue checkmarks
  - [ ] Optional: Long-press to see who read the message

---

## Dev Notes

### Conversation ID Generation Logic

**ONE-ON-ONE (2 participants):**
```swift
// Use sorted UIDs joined with underscore
let participants = [currentUserID, recipientID].sorted()
let conversationID = participants.joined(separator: "_")
// Example: "user1_uid_user2_uid"
```

**GROUP (3+ participants):**
```swift
// Generate deterministic hash to prevent duplicates
import CryptoKit

extension String {
    func sha256Hash() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// Generate group conversation ID
let allParticipants = ([currentUserID] + selectedUserIDs).sorted()
let concatenated = allParticipants.joined(separator: "_")
let conversationID = concatenated.sha256Hash()
// Example: "a3f5b8c9d2e1f4a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0"
```

**Why hash for groups?**
- Prevents ID collision if participant order changes
- Deterministic: same participants = same hash
- Short ID (64 chars) vs long concatenated string

### Updated ConversationEntity

```swift
@Model
final class ConversationEntity {
    var id: String
    var participantIDs: [String]
    var groupName: String?  // ✅ NEW - Only for groups
    var lastMessage: String?
    var lastMessageTimestamp: Date
    var unreadCount: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var isArchived: Bool
    var isPinned: Bool

    // ✅ NEW - Computed property
    var isGroup: Bool {
        return participantIDs.count > 2
    }

    // ✅ NEW - Computed property
    var participantCount: Int {
        return participantIDs.count
    }

    // ✅ NEW - Display name logic
    var displayName: String {
        if isGroup {
            return groupName ?? "Unnamed Group"
        } else {
            // One-on-one: show recipient name
            return recipientDisplayName
        }
    }

    init(
        id: String,
        participantIDs: [String],
        groupName: String? = nil,
        lastMessage: String? = nil,
        lastMessageTimestamp: Date,
        unreadCount: Int = 0,
        createdAt: Date,
        updatedAt: Date,
        syncStatus: SyncStatus,
        isArchived: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.participantIDs = participantIDs
        self.groupName = groupName
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isArchived = isArchived
        self.isPinned = false
    }
}
```

### GroupChatCreationView

```swift
import SwiftUI

struct GroupChatCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ConversationViewModel

    @State private var groupName = ""
    @State private var selectedUserIDs: [String] = []
    @State private var searchText = ""

    var isValid: Bool {
        return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedUserIDs.count >= 2
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Group name input
                TextField("Group Name", text: $groupName)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                // Selected participants
                if !selectedUserIDs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedUserIDs, id: \.self) { userID in
                                SelectedUserChip(userID: userID) {
                                    selectedUserIDs.removeAll { $0 == userID }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // User picker
                List {
                    ForEach(availableUsers) { user in
                        UserRowView(user: user) {
                            if selectedUserIDs.contains(user.id) {
                                selectedUserIDs.removeAll { $0 == user.id }
                            } else {
                                selectedUserIDs.append(user.id)
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if selectedUserIDs.contains(user.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search users")
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createGroup() async {
        do {
            let conversation = try await viewModel.createGroupConversation(
                groupName: groupName,
                participantIDs: selectedUserIDs
            )

            dismiss()

            // Navigate to conversation
            // (handled by NavigationStack in parent view)
        } catch {
            // Handle error
            print("Error creating group: \(error)")
        }
    }
}
```

### Updated ConversationViewModel

```swift
extension ConversationViewModel {

    /// Create a group conversation with 3+ participants
    func createGroupConversation(
        groupName: String,
        participantIDs: [String]
    ) async throws -> ConversationEntity {
        // Validate
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversationError.invalidGroupName
        }

        guard participantIDs.count >= 2 else {
            throw ConversationError.insufficientParticipants
        }

        let currentUserID = AuthService.shared.currentUserID

        // Generate deterministic group ID
        let allParticipants = ([currentUserID] + participantIDs).sorted()
        let concatenated = allParticipants.joined(separator: "_")
        let conversationID = concatenated.sha256Hash()

        // Check if group already exists
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // Create new group conversation
        let conversation = ConversationEntity(
            id: conversationID,
            participantIDs: allParticipants,
            groupName: groupName,
            lastMessage: nil,
            lastMessageTimestamp: Date(),
            unreadCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending,
            isArchived: false
        )

        // Save locally
        modelContext.insert(conversation)
        try modelContext.save()

        // Sync to RTDB
        Task { @MainActor in
            do {
                try await conversationService.syncGroupConversation(conversation)
                conversation.syncStatus = .synced
                try? modelContext.save()
            } catch {
                conversation.syncStatus = .failed
                self.error = error
                try? modelContext.save()
            }
        }

        return conversation
    }
}
```

### RTDB Group Conversation Structure

```json
{
  "conversations": {
    "{groupConversationID}": {
      "participants": {
        "user1_uid": true,
        "user2_uid": true,
        "user3_uid": true
      },
      "participantList": ["user1_uid", "user2_uid", "user3_uid"],
      "isGroup": true,
      "groupName": "Team Alpha",
      "lastMessage": "Hello everyone!",
      "lastMessageTimestamp": 1704067200000,
      "createdAt": 1704067200000,
      "updatedAt": 1704067200000,
      "typing": {
        "user2_uid": true
      }
    }
  },
  "messages": {
    "{groupConversationID}": {
      "{messageID}": {
        "senderID": "user1_uid",
        "senderDisplayName": "John Doe",  // ✅ Cached for display
        "text": "Hello everyone!",
        "serverTimestamp": 1704067200000,
        "sequenceNumber": 1,
        "status": "sent",
        "readBy": {
          "user1_uid": true,
          "user2_uid": true
          // user3_uid has not read yet
        }
      }
    }
  }
}
```

### Updated MessageBubbleView for Groups

```swift
struct MessageBubbleView: View {
    let message: MessageEntity
    let conversation: ConversationEntity

    @State private var senderName: String?

    var isFromCurrentUser: Bool {
        message.senderID == AuthService.shared.currentUserID
    }

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // ✅ Show sender name for group messages from others
                if conversation.isGroup && !isFromCurrentUser {
                    Text(senderName ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }

                // Message bubble
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(18)

                // Timestamp + status
                HStack(spacing: 4) {
                    Text(message.serverTimestamp ?? message.localCreatedAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
        .task {
            await loadSenderName()
        }
    }

    private func loadSenderName() async {
        // Fetch sender display name from Firestore
        if let user = try? await ConversationService.shared.getUser(userID: message.senderID) {
            senderName = user.displayName
        }
    }

    // ... (rest of statusIcon logic)
}
```

### Security Rules Update

Update `database.rules.json` to support groups:

```json
{
  "rules": {
    "conversations": {
      "$conversationID": {
        ".read": "auth != null && data.child('participants').child(auth.uid).val() == true",
        ".write": "auth != null && (
          data.child('participants').child(auth.uid).val() == true ||
          newData.child('participants').child(auth.uid).val() == true
        )",
        ".validate": "newData.hasChildren(['participants', 'participantList', 'createdAt'])",

        "isGroup": {
          ".validate": "newData.isBoolean()"
        },

        "groupName": {
          ".validate": "newData.isString() && newData.val().length >= 1 && newData.val().length <= 100"
        }
      }
    }
  }
}
```

---

## Testing

### Test Plan

1. **Group Creation Test:**
   - Select 3 users
   - Enter group name "Test Group"
   - Tap Create
   - Verify group appears in conversation list
   - Verify group name displays correctly

2. **Group Messaging Test:**
   - Send message to group from User A
   - Verify message appears for User B and User C
   - Verify sender name shows above message
   - Send reply from User B
   - Verify all users see messages in real-time

3. **Group Metadata Test:**
   - Open group conversation
   - Tap participants button
   - Verify all 3 participants listed
   - Verify participant count shows "3 participants"

4. **Typing Indicators in Groups:**
   - User A starts typing
   - Verify User B sees "Alice is typing..."
   - User C also starts typing
   - Verify User A sees "Bob and Charlie are typing..."

5. **Read Receipts in Groups:**
   - User A sends message
   - User B opens conversation
   - Verify message shows "Read by 1"
   - User C opens conversation
   - Verify message shows "Read by 2"

6. **Duplicate Prevention Test:**
   - User A creates group with Users B, C, D
   - User B tries to create group with Users A, C, D (same participants)
   - Verify only ONE group created (deterministic ID)
   - Verify both users see same conversation

7. **Offline Group Test:**
   - User A goes offline
   - Send 3 messages to group
   - User A comes back online
   - Verify all 3 messages sync and appear in correct order

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-20 | 1.0 | Initial story creation - Basic group chat for MVP | PO (Sarah) |

---

## Notes

**MVP Scope:**

This story implements **basic group chat** to satisfy MVP requirements:
- Create group with 3+ participants
- Send/receive messages in group
- See who sent each message
- Basic read receipts (count, not names)

**Deferred to Post-MVP:**
- Add/remove participants from group
- Leave group
- Admin roles
- Group profile picture
- @mentions
- Rich read receipt details (tap to see who read)
- Message replies/threads

**Why Deterministic Group IDs Matter:**

Using a hash of sorted participant IDs prevents:
1. **Duplicate groups** - Multiple users creating "same" group simultaneously
2. **ID collisions** - Different participant orders creating different IDs
3. **Data consistency** - All clients generate same ID for same participants

**Group Name Requirement:**

For MVP, group name is **required** for 3+ participants to avoid confusion. Without a name, UI would show "You, Alice, Bob, Charlie" which becomes unwieldy for large groups.
