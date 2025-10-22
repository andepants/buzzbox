---
# Story 3.3: Add and Remove Participants
# Epic 3: Group Chat
# Status: Draft

id: STORY-3.3
title: "Manage Group Membership (Add/Remove Participants)"
epic: "Epic 3: Group Chat"
status: draft
priority: P1
estimate: 3  # Story points (50 minutes)
assigned_to: null
created_date: "2025-10-21"
sprint_day: null

---

## Description

**As a** group admin
**I need** to add and remove participants from groups
**So that** I can manage group membership dynamically

This story implements participant management functionality:
- Add new participants to existing groups
- Remove participants from groups
- Admin-only permission enforcement
- System messages for participant changes
- Batched system messages for bulk additions
- Minimum participant count enforcement

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Only group admins can add/remove participants
- [ ] "Add Participants" button opens contact picker in GroupInfoView
- [ ] Selected users added to group immediately
- [ ] New participants receive group join notification
- [ ] Removed participants see "You were removed from [group name]"
- [ ] Participant changes sync to all group members in real-time
- [ ] Minimum 2 participants enforced (group auto-archives if only 1 remains)
- [ ] New participants see messages from join time forward only (not historical)
- [ ] New participants see system message: "You were added to this group"
- [ ] System messages batched: "Alice added 10 participants" (not 10 separate messages)
- [ ] Typing indicators cleaned up when participant removed
- [ ] App badge count includes unread group messages
- [ ] Offline participant add/remove queued for sync when online

---

## Technical Tasks

**Implementation steps:**

1. **Create AddParticipantsView** [Source: epic-3-group-chat.md lines 797-915]
   - Create file: `sorted/Features/Chat/Views/AddParticipantsView.swift`
   - Reuse ParticipantPickerView component
   - Filter out users already in group
   - Multi-select with checkmark indicators
   - "Add" button (disabled if no selection)
   - "Cancel" button
   - Present as sheet from GroupInfoView

2. **Implement Add Participants Logic** [Source: epic-3-group-chat.md lines 871-913]
   - Append selected user IDs to `conversation.participantIDs`
   - Update `conversation.updatedAt`
   - Set `conversation.syncStatus = .pending`
   - Save to SwiftData
   - Sync to RTDB via ConversationService
   - Send batched system message:
     - 1 user: "{Admin} added {User}"
     - Multiple: "{Admin} added {N} participants"

3. **Implement Remove Participant Logic** [Source: epic-3-group-chat.md lines 689-719]
   - Admin-only action
   - Remove participant from `participantIDs` array
   - Remove from `adminUserIDs` if admin
   - Enforce minimum 2 participants (auto-archive if 1 remains)
   - Update `updatedAt` timestamp
   - Set `syncStatus = .pending`
   - Sync to RTDB
   - Send system message: "{Admin} removed {Participant}"

4. **Update GroupInfoView Integration** [Source: epic-3-group-chat.md lines 640-646, 689-719]
   - Add "Add Participants" button in participant section
   - Present AddParticipantsView sheet
   - Add remove button (minus circle) next to participants
   - Confirm removal with destructive button action
   - Reload participant list after add/remove

5. **Update MessageEntity for New Participant Visibility**
   - New participants only see messages sent AFTER they joined
   - Use `createdAt` timestamp to filter messages
   - Don't show historical messages to new participants

6. **Cleanup Typing Indicators on Removal**
   - Remove typing indicator from RTDB `/typing/{conversationID}/{removedUserID}/`
   - Prevent removed users from appearing as "typing"

7. **Handle Minimum Participant Enforcement**
   - Check participant count before removal
   - If removing leaves 1 participant → auto-archive group
   - Show warning: "This will archive the group (only 1 member remaining)"

8. **Offline Queue Handling**
   - Add/remove operations queued if offline
   - `syncStatus: .pending` until synced
   - SyncCoordinator processes queue when online

---

## Technical Specifications

### Files to Create

```
sorted/Features/Chat/Views/AddParticipantsView.swift (create)
```

### Files to Modify

```
sorted/Features/Chat/Views/GroupInfoView.swift (modify - add/remove buttons)
sorted/Core/Services/ConversationService.swift (modify - sync participant changes)
sorted/Core/Services/MessageService.swift (modify - filter historical messages)
sorted/Core/Services/TypingIndicatorService.swift (modify - cleanup on removal)
```

### Data Flow

**Add Participants:**
```
1. Admin taps "Add Participants" in GroupInfoView
2. AddParticipantsView sheet appears
3. Admin selects users (filtered: not already in group)
4. Admin taps "Add"
5. Append user IDs to participantIDs
6. Save to SwiftData (syncStatus: pending)
7. Sync to RTDB
8. Send batched system message
9. New participants receive FCM notification
10. Dismiss sheet, reload participant list
```

**Remove Participant:**
```
1. Admin taps remove button next to participant
2. Confirmation action (destructive button)
3. Remove user from participantIDs and adminUserIDs
4. Check if participant count < 2 → auto-archive if true
5. Save to SwiftData (syncStatus: pending)
6. Sync to RTDB
7. Send system message
8. Clean up typing indicator for removed user
9. Reload participant list
```

### Code Examples

**AddParticipantsView:**
```swift
struct AddParticipantsView: View {
    let conversation: ConversationEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedUserIDs: Set<String> = []
    @State private var availableUsers: [UserEntity] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableUsers) { user in
                    Button {
                        toggleSelection(for: user.id)
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: user.profilePictureURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            Text(user.displayName)

                            Spacer()

                            if selectedUserIDs.contains(user.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Participants")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addParticipants()
                    }
                    .disabled(selectedUserIDs.isEmpty)
                }
            }
            .task {
                await loadAvailableUsers()
            }
        }
    }

    private func addParticipants() {
        // Append new participant IDs
        conversation.participantIDs.append(contentsOf: selectedUserIDs)
        conversation.updatedAt = Date()
        conversation.syncStatus = .pending
        try? modelContext.save()

        // Sync to RTDB
        Task.detached {
            try? await ConversationService.shared.syncConversationToRTDB(conversation)

            // Send batched system message
            let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
                for: AuthService.shared.currentUserID ?? ""
            ) ?? "Someone"

            let addedCount = selectedUserIDs.count
            let systemMessageText: String

            if addedCount == 1 {
                let addedUserID = selectedUserIDs.first!
                let addedUserName = await fetchDisplayName(for: addedUserID) ?? "Someone"
                systemMessageText = "\(currentUserDisplayName) added \(addedUserName)"
            } else {
                systemMessageText = "\(currentUserDisplayName) added \(addedCount) participants"
            }

            let systemMessage = MessageEntity(
                id: UUID().uuidString,
                conversationID: conversation.id,
                senderID: "system",
                text: systemMessageText,
                createdAt: Date(),
                status: .sent,
                syncStatus: .synced,
                isSystemMessage: true
            )

            try? await MessageService.shared.sendMessageToRTDB(systemMessage)
        }

        dismiss()
    }
}
```

**Remove Participant:**
```swift
private func removeParticipant(_ participant: UserEntity) {
    // Check minimum participant count
    if conversation.participantIDs.count <= 2 {
        // Show warning: removing will archive group
        showMinimumParticipantWarning = true
        return
    }

    // Remove from participant list
    conversation.participantIDs.removeAll { $0 == participant.id }
    conversation.adminUserIDs.removeAll { $0 == participant.id }
    conversation.updatedAt = Date()
    conversation.syncStatus = .pending
    try? modelContext.save()

    // Sync to RTDB
    Task.detached {
        try? await ConversationService.shared.syncConversationToRTDB(conversation)

        // Clean up typing indicator
        try? await TypingIndicatorService.shared.removeTypingIndicator(
            conversationID: conversation.id,
            userID: participant.id
        )

        // Send system message
        let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
            for: AuthService.shared.currentUserID ?? ""
        ) ?? "Someone"

        let systemMessage = MessageEntity(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: "system",
            text: "\(currentUserDisplayName) removed \(participant.displayName)",
            createdAt: Date(),
            status: .sent,
            syncStatus: .synced,
            isSystemMessage: true
        )
        try? await MessageService.shared.sendMessageToRTDB(systemMessage)
    }

    // Reload participants
    Task { await loadParticipants() }
}
```

### Dependencies

**Required:**
- ✅ Story 3.1: Create Group Conversation (groups exist)
- ✅ Story 3.2: Group Info Screen (UI foundation)
- ✅ ParticipantPickerView component
- ✅ ConversationService with RTDB sync
- ✅ MessageService for system messages
- ✅ TypingIndicatorService

**Blocks:**
- None (independent feature)

**External:**
- RTDB rules enforce admin permissions
- Firestore `/users` collection accessible

---

## Testing & Validation

### Test Procedure

1. **Add Participants:**
   - Open GroupInfoView as admin
   - Tap "Add Participants"
   - AddParticipantsView sheet appears
   - Select 3 new users
   - Tap "Add"
   - Sheet dismisses
   - Participant list updates with new users
   - System message appears: "Alice added 3 participants"
   - New participants receive FCM notification

2. **Add Single Participant:**
   - Open GroupInfoView as admin
   - Tap "Add Participants"
   - Select 1 user: "Bob"
   - Tap "Add"
   - System message: "Alice added Bob"

3. **Remove Participant:**
   - Open GroupInfoView as admin
   - Tap remove button (minus circle) next to participant
   - Participant removed from list
   - System message: "Alice removed Bob"
   - Bob's typing indicator cleaned up
   - Bob receives notification: "You were removed from Family Group"

4. **Minimum Participant Enforcement:**
   - Create group with 2 participants (Alice, Bob)
   - Alice tries to remove Bob
   - Warning appears: "Removing will archive group (only 1 member)"
   - If confirmed → group archived for Alice

5. **Historical Message Filtering:**
   - Create group with Alice and Bob
   - Alice sends 5 messages
   - Alice adds Charlie
   - Charlie opens group
   - Charlie sees only messages sent AFTER he joined
   - Charlie sees system message: "Alice added Charlie"

6. **Offline Add/Remove:**
   - Disconnect network
   - Add participant
   - Verify `syncStatus: .pending`
   - Reconnect network
   - Verify sync completes
   - Verify system message sent

7. **Batched System Messages:**
   - Add 10 participants in one action
   - Verify single system message: "Alice added 10 participants"
   - Not 10 separate messages

8. **Typing Indicator Cleanup:**
   - Bob is typing in group
   - Alice removes Bob
   - Verify Bob's typing indicator disappears
   - RTDB path `/typing/{conversationID}/{bobID}/` deleted

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS 17+ simulator and device
- [ ] AddParticipantsView displays available users
- [ ] Add participants works (admin only)
- [ ] Remove participant works (admin only)
- [ ] System messages created for add/remove
- [ ] Batched system messages for bulk add
- [ ] Minimum 2 participants enforced
- [ ] Historical messages filtered for new participants
- [ ] Typing indicators cleaned up on removal
- [ ] FCM notifications sent to new/removed participants
- [ ] Offline add/remove queued for sync
- [ ] Real-time sync to all group members

---

## References

**Architecture Docs:**
- `docs/architecture/unified-project-structure.md` - File organization
- `docs/swiftdata-implementation-guide.md` - SwiftData patterns

**PRD Sections:**
- `docs/prd.md` - Epic 3: Group Chat (Participant Management)

**Epic Documentation:**
- `docs/epics/epic-3-group-chat.md` - Story 3.3 specification (lines 768-933)

**Related Stories:**
- Story 3.1: Create Group Conversation (participant selection pattern)
- Story 3.2: Group Info Screen (UI integration point)
- Story 2.3: Send/Receive Messages (message filtering)

---

## Notes & Considerations

### Implementation Notes

**Admin-Only Actions:**
- Check `conversation.adminUserIDs.contains(AuthService.shared.currentUserID)` before add/remove
- Show buttons only if admin
- Enforce server-side via RTDB rules

**Batched System Messages:**
- Single participant added: "{Admin} added {User}"
- Multiple participants added: "{Admin} added {N} participants"
- Don't create separate messages for each participant

**Historical Message Filtering:**
- New participants only see messages with `createdAt >= joinTimestamp`
- System message for join always visible
- Implement in MessageService fetch logic

### Edge Cases

- Admin removes themselves → allowed, auto-demoted
- Last admin removed → oldest participant promoted to admin (server-side)
- Participant removed while typing → typing indicator cleaned up
- Offline add/remove → queued, synced when online
- Duplicate add attempt → prevented (already in group)
- Add user who deleted account → Firestore check fails, show error
- Remove participant with unread messages → messages preserved locally

### Performance Considerations

- Load available users asynchronously in AddParticipantsView
- Filter already-in-group users efficiently
- Batch RTDB writes for participant changes
- Clean up typing indicators asynchronously
- Use LazyVStack for large participant lists

### Security Considerations

- Only admins can add/remove participants (RTDB rules enforce)
- Validate participant IDs exist in Firestore before adding
- Sanitize system message text
- Removed users cannot read new messages (RTDB rules)
- Minimum participant count enforced server-side

---

## Dev Notes

**CRITICAL: This section contains ALL implementation context needed. Developer should NOT need to read external docs.**

### Participant Addition Flow with Filtering
[Source: epic-3-group-chat.md lines 797-915]

**Filter Out Already-in-Group Users:**
```swift
// In AddParticipantsView.loadAvailableUsers()
let allUsers = try? modelContext.fetch(FetchDescriptor<UserEntity>())
let currentParticipantIDs = Set(conversation.participantIDs)

availableUsers = allUsers?.filter { user in
    !currentParticipantIDs.contains(user.id)
} ?? []
```

**Add Participants Pattern:**
```swift
func addParticipants(_ selectedUsers: [UserEntity]) async {
    // Append to participantIDs
    conversation.participantIDs.append(contentsOf: selectedUsers.map { $0.id })
    conversation.updatedAt = Date()
    conversation.syncStatus = .pending
    try? modelContext.save()

    // Sync to RTDB
    try? await ConversationService.shared.syncConversationToRTDB(conversation)

    // Send batched system message
    let adminName = AuthService.shared.currentUser?.displayName ?? "Someone"
    let messageText: String
    if selectedUsers.count == 1 {
        messageText = "\(adminName) added \(selectedUsers[0].displayName)"
    } else {
        messageText = "\(adminName) added \(selectedUsers.count) participants"
    }

    let systemMessage = MessageEntity(
        id: UUID().uuidString,
        conversationID: conversation.id,
        senderID: "system",
        text: messageText,
        createdAt: Date(),
        status: .sent,
        syncStatus: .synced,
        isSystemMessage: true
    )
    try? await MessageService.shared.sendMessageToRTDB(systemMessage)
}
```

### Batched System Messages
[Source: epic-3-group-chat.md lines 901-913]

**CRITICAL: Batch multiple additions into single message**

```swift
// DON'T: Send N system messages for N users
for user in selectedUsers {
    sendSystemMessage("\(adminName) added \(user.displayName)")
}

// DO: Send 1 batched system message
if selectedUsers.count == 1 {
    sendSystemMessage("\(adminName) added \(selectedUsers[0].displayName)")
} else {
    sendSystemMessage("\(adminName) added \(selectedUsers.count) participants")
}
```

**System Message Text Formats:**
- Single add: "{AdminName} added {UserName}"
- Bulk add: "{AdminName} added {N} participants"
- Remove: "{AdminName} removed {UserName}"

### Minimum Participant Count Enforcement
[Source: epic-3-group-chat.md lines 855-868]

**CRITICAL: Groups MUST have at least 2 participants**

```swift
func removeParticipant(_ participant: UserEntity) async {
    // Check minimum count BEFORE removal
    if conversation.participantIDs.count <= 2 {
        showArchiveWarning = true  // "This will archive the group"
        return
    }

    // Safe to remove
    conversation.participantIDs.removeAll { $0 == participant.id }
    conversation.adminUserIDs.removeAll { $0 == participant.id }
    conversation.updatedAt = Date()
    conversation.syncStatus = .pending
    try? modelContext.save()

    // Sync and send system message
    try? await ConversationService.shared.syncConversationToRTDB(conversation)
    // ... send system message
}
```

**Auto-Archive Pattern:**
```swift
// If removal leaves only 1 participant
if conversation.participantIDs.count == 1 {
    conversation.isArchived = true  // Archive for remaining user
    conversation.syncStatus = .pending
    try? modelContext.save()
}
```

### Historical Message Filtering for New Participants
[Source: epic-3-group-chat.md lines 901, 915]

**New participants ONLY see messages sent AFTER they joined**

**MessageService Fetch Pattern:**
```swift
// In MessageService.fetchMessages(for conversationID:)
func fetchMessages(for conversationID: String, userJoinedAt: Date?) async -> [MessageEntity] {
    let messagesRef = Database.database().reference()
        .child("messages")
        .child(conversationID)

    let snapshot = try? await messagesRef.getData()
    var messages: [MessageEntity] = []

    for child in snapshot?.children.allObjects as? [DataSnapshot] ?? [] {
        guard let data = child.value as? [String: Any],
              let timestamp = data["serverTimestamp"] as? Double else { continue }

        let messageDate = Date(timeIntervalSince1970: timestamp / 1000)

        // Filter: only show messages after user joined
        if let joinDate = userJoinedAt, messageDate < joinDate {
            continue  // Skip historical messages
        }

        // Parse message...
        messages.append(message)
    }

    return messages
}
```

**Join Timestamp Tracking:**
```swift
// Store in ConversationEntity (extend model if needed)
var participantJoinTimestamps: [String: Date] = [:]  // userID -> joinDate

// When adding participants
for userID in newParticipantIDs {
    conversation.participantJoinTimestamps[userID] = Date()
}
```

### Typing Indicator Cleanup on Removal
[Source: epic-3-group-chat.md lines 1113-1162]

**CRITICAL: Remove typing indicator when participant removed**

```swift
// After removing participant from conversation
func cleanupTypingIndicator(for userID: String, in conversationID: String) async {
    let typingRef = Database.database().reference()
        .child("typing")
        .child(conversationID)
        .child(userID)

    try? await typingRef.removeValue()
}

// Call after participant removal
try? await cleanupTypingIndicator(
    for: removedParticipant.id,
    in: conversation.id
)
```

### Admin Auto-Promotion on Last Admin Removal
[Source: epic-3-group-chat.md lines 455-456]

**Server-Side RTDB Rule (Already Configured):**
```
// If admin removes themselves and they're the last admin
// Server auto-promotes oldest participant to admin
```

**Client-Side Pattern (Story 3.2 Implementation):**
```swift
// When removing participant who is admin
if conversation.adminUserIDs.contains(participant.id) {
    conversation.adminUserIDs.removeAll { $0 == participant.id }

    // If no admins remain, promote oldest participant
    if conversation.adminUserIDs.isEmpty && !conversation.participantIDs.isEmpty {
        let oldestParticipantID = conversation.participantIDs.sorted().first ?? ""
        conversation.adminUserIDs.append(oldestParticipantID)
    }
}
```

### Offline Queue Handling
[Source: epic-3-FIX-PATCHES.md]

**Pattern: All participant changes queue when offline**

```swift
// In ConversationService.syncConversationToRTDB()
func syncConversationToRTDB(_ conversation: ConversationEntity) async throws {
    guard NetworkMonitor.shared.isConnected else {
        // Offline: mark as pending, will sync when online
        conversation.syncStatus = .pending
        try? modelContext.save()
        return
    }

    // Online: sync to RTDB
    let conversationData = [
        "participantIDs": conversation.participantIDs.reduce(into: [:]) { $0[$1] = true },
        // ... other fields
    ]

    try await Database.database().reference()
        .child("conversations")
        .child(conversation.id)
        .setValue(conversationData)

    conversation.syncStatus = .synced
    try? modelContext.save()
}
```

### Duplicate Add Prevention
[Source: epic-3-group-chat.md lines 797-915]

**CRITICAL: Check before adding**

```swift
func addParticipants(_ selectedUsers: [UserEntity]) async {
    // Filter out users already in group (double-check)
    let currentParticipantIDs = Set(conversation.participantIDs)
    let newUserIDs = selectedUsers.map { $0.id }.filter {
        !currentParticipantIDs.contains($0)
    }

    guard !newUserIDs.isEmpty else {
        print("All selected users already in group")
        return
    }

    conversation.participantIDs.append(contentsOf: newUserIDs)
    // ... rest of add logic
}
```

### File Modification Order

**CRITICAL: Follow this exact sequence:**

1. ✅ Update `ConversationEntity.swift` - **Already done in Story 3.1**
2. ✅ Update `MessageEntity.swift` - **Already done in Story 3.1**
3. Create `AddParticipantsView.swift` (participant picker)
4. Update `GroupInfoView.swift` (add "Add Participants" button, remove buttons)
5. Update `ConversationService.swift` (sync participant changes)
6. Update `MessageService.swift` (historical message filtering)
7. Update `TypingIndicatorService.swift` (cleanup on removal)

### Testing Standards

**Manual Testing Required (No Unit Tests for MVP):**
- Test add participants (single, multiple, bulk)
- Test remove participants (admin, non-admin, concurrent)
- Test minimum participant enforcement (2-person group)
- Test historical message filtering (new participants don't see old messages)
- Test offline add/remove (queue for sync)
- Test typing indicator cleanup (removed users)
- Test batched system messages (multiple additions)

**CRITICAL Edge Cases:**
1. Add user already in group → prevented by filter
2. Remove participant with participant count = 2 → show archive warning
3. Remove last admin → oldest participant auto-promoted
4. Removed user typing → typing indicator cleaned up
5. Offline add → queued, synced when online
6. New participant sees only new messages → historical filtering works

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
