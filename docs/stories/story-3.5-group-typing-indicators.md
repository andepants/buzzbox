---
# Story 3.5: Group Typing Indicators
# Epic 3: Group Chat
# Status: Draft

id: STORY-3.5
title: "Show Typing Indicators for Multiple Users in Groups"
epic: "Epic 3: Group Chat"
status: draft
priority: P1
estimate: 2  # Story points (30 minutes)
assigned_to: null
created_date: "2025-10-21"
sprint_day: null

---

## Description

**As a** group chat participant
**I need** to see who is typing in the group
**So that** I know who is actively responding and can wait for their message

This story extends typing indicators to support multiple simultaneous typers in group conversations:
- Shows "Alice is typing..." for single typer
- Shows "Alice and Bob are typing..." for 2 typers
- Shows "Alice, Bob, and 2 others are typing..." for 4+ typers
- Disappears after 3 seconds of inactivity
- Only shown in active conversation (MessageThreadView)

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Shows "Alice is typing..." for single typer in group
- [ ] Shows "Alice and Bob are typing..." for 2 typers
- [ ] Shows "Alice, Bob, and Charlie are typing..." for 3 typers
- [ ] Shows "Alice, Bob, and 2 others are typing..." for 4+ typers
- [ ] Typing indicator disappears after 3 seconds of inactivity per user
- [ ] Only shows typing indicator in active conversation (MessageThreadView)
- [ ] Does not show in ConversationListView (group or 1:1)
- [ ] Current user's own typing not shown to themselves
- [ ] Typing indicators synced via RTDB `/typing/{conversationID}/{userID}/`
- [ ] Display names fetched from Firestore for typers

---

## Technical Tasks

**Implementation steps:**

1. **Extend TypingIndicatorService for Groups** [Source: epic-3-group-chat.md lines 1133-1154]
   - Add method: `formatTypingText(userIDs: Set<String>, participants: [UserEntity]) -> String`
   - Handle 0 typers: return ""
   - Handle 1 typer: "{Name} is typing..."
   - Handle 2 typers: "{Name1} and {Name2} are typing..."
   - Handle 3 typers: "{Name1}, {Name2}, and {Name3} are typing..."
   - Handle 4+ typers: "{Name1}, {Name2}, and {N} others are typing..."

2. **Update MessageThreadView Typing Display** [Source: epic-3-group-chat.md lines 1156-1158]
   - Listen to RTDB `/typing/{conversationID}/` for all user typing states
   - Filter out current user (don't show own typing)
   - Collect typing user IDs into Set<String>
   - Resolve user display names from Firestore or SwiftData
   - Call `formatTypingText()` to get formatted string
   - Display typing text below message list

3. **Fetch Typing User Display Names** [Source: epic-3-group-chat.md lines 1157]
   - Query SwiftData for UserEntity matching typing user IDs
   - If not in local cache, fetch from Firestore `/users/{userID}`
   - Extract `displayName` field
   - Pass to `formatTypingText()` with user IDs

4. **Handle Typing Timeout (3 seconds)**
   - RTDB auto-expires typing indicators after 3 seconds (existing logic)
   - TypingIndicatorService updates `lastUpdated: { ".sv": "timestamp" }`
   - RTDB removes stale entries automatically
   - No additional client-side timeout needed

5. **Filter Out Removed Participants**
   - Before formatting typing text, filter user IDs by `conversation.participantIDs`
   - Ignore typing indicators from users no longer in group
   - Prevents showing typing for removed users

---

## Technical Specifications

### Files to Modify

```
sorted/Core/Services/TypingIndicatorService.swift (modify - add formatTypingText method)
sorted/Features/Chat/Views/MessageThreadView.swift (modify - display group typing)
```

### RTDB Schema

**Typing Indicators (per user in group):**
```
/typing/{conversationID}/{userID}/
  ├── isTyping: true
  └── lastUpdated: { ".sv": "timestamp" }
```

**Example (3 users typing):**
```
/typing/group_abc123/
  ├── user1/
  │   ├── isTyping: true
  │   └── lastUpdated: 1704067200000
  ├── user2/
  │   ├── isTyping: true
  │   └── lastUpdated: 1704067201000
  └── user3/
      ├── isTyping: true
      └── lastUpdated: 1704067202000
```

### Code Examples

**TypingIndicatorService Extension:**
```swift
extension TypingIndicatorService {
    /// Format typing text for multiple users in group
    func formatTypingText(userIDs: Set<String>, participants: [UserEntity]) -> String {
        let typingUsers = participants.filter { userIDs.contains($0.id) }

        switch typingUsers.count {
        case 0:
            return ""
        case 1:
            return "\(typingUsers[0].displayName) is typing..."
        case 2:
            return "\(typingUsers[0].displayName) and \(typingUsers[1].displayName) are typing..."
        case 3:
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(typingUsers[2].displayName) are typing..."
        default:
            let others = typingUsers.count - 2
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(others) others are typing..."
        }
    }
}
```

**MessageThreadView Integration:**
```swift
struct MessageThreadView: View {
    let conversation: ConversationEntity

    @State private var typingUserIDs: Set<String> = []
    @State private var participants: [UserEntity] = []

    private var typingText: String {
        // Filter out current user
        let otherTypingUserIDs = typingUserIDs.filter { $0 != AuthService.shared.currentUserID }

        // Filter by current participants only
        let validTypingUserIDs = otherTypingUserIDs.filter { conversation.participantIDs.contains($0) }

        return TypingIndicatorService.shared.formatTypingText(
            userIDs: validTypingUserIDs,
            participants: participants
        )
    }

    var body: some View {
        VStack {
            // Message list...

            // Typing indicator
            if !typingText.isEmpty {
                HStack {
                    Text(typingText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Message input...
        }
        .task {
            await loadParticipants()
            await observeTypingIndicators()
        }
    }

    private func observeTypingIndicators() async {
        let typingRef = Database.database().reference()
            .child("typing")
            .child(conversation.id)

        typingRef.observe(.value) { snapshot in
            var userIDs: Set<String> = []

            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let data = snap.value as? [String: Any],
                   let isTyping = data["isTyping"] as? Bool,
                   isTyping {
                    userIDs.insert(snap.key)
                }
            }

            typingUserIDs = userIDs
        }
    }
}
```

### Dependencies

**Required:**
- ✅ Story 2.6: Typing Indicators (1:1 foundation)
- ✅ Story 3.1: Create Group Conversation (groups exist)
- ✅ TypingIndicatorService exists
- ✅ RTDB `/typing/` path configured

**Blocks:**
- None (independent feature)

**External:**
- RTDB configured with typing indicators
- Firestore `/users` collection for display names

---

## Testing & Validation

### Test Procedure

1. **Single Typer:**
   - User A and User B in group
   - User A types message (don't send)
   - User B sees: "Alice is typing..."
   - User A stops typing (3 seconds)
   - Typing indicator disappears

2. **Two Typers:**
   - User A, User B, User C in group
   - User A and User B type simultaneously
   - User C sees: "Alice and Bob are typing..."
   - User A stops typing
   - User C sees: "Bob is typing..."

3. **Three Typers:**
   - Group with 4 users (A, B, C, D)
   - Users A, B, C type simultaneously
   - User D sees: "Alice, Bob, and Charlie are typing..."

4. **Four+ Typers:**
   - Group with 6 users (A, B, C, D, E, F)
   - Users A, B, C, D type simultaneously
   - User E sees: "Alice, Bob, and 2 others are typing..."
   - User F sees same indicator

5. **Own Typing Not Shown:**
   - User A types in group
   - User A does NOT see own typing indicator
   - Other users see "Alice is typing..."

6. **Removed Participant Filtering:**
   - User A types in group
   - Admin removes User A mid-typing
   - Other users no longer see "Alice is typing..."

7. **Timeout (3 seconds):**
   - User A types, then stops
   - Wait 3 seconds
   - Typing indicator disappears
   - RTDB entry removed automatically

8. **Multiple Rapid Typers:**
   - 5 users type rapidly in succession
   - Typing text updates smoothly
   - No lag or flickering

9. **1:1 Chat Compatibility:**
   - Verify 1:1 chat still shows single typing indicator
   - Format: "Alice is typing..." (not "and")

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS 17+ simulator and device
- [ ] Single typer shows "{Name} is typing..."
- [ ] Two typers show "{Name1} and {Name2} are typing..."
- [ ] Three typers show all three names
- [ ] 4+ typers show first two + "N others"
- [ ] Typing disappears after 3 seconds
- [ ] Own typing not shown to self
- [ ] Removed participants filtered out
- [ ] Display names resolved correctly
- [ ] Real-time updates via RTDB
- [ ] No performance issues with many typers

---

## References

**Architecture Docs:**
- `docs/architecture/unified-project-structure.md` - File organization

**PRD Sections:**
- `docs/prd.md` - Epic 3: Group Chat

**Epic Documentation:**
- `docs/epics/epic-3-group-chat.md` - Story 3.5 specification (lines 1113-1162)

**Related Stories:**
- Story 2.6: Real-time Typing Indicators (1:1 foundation)
- Story 3.1: Create Group Conversation (group infrastructure)
- Story 3.3: Add/Remove Participants (participant filtering)

---

## Notes & Considerations

### Implementation Notes

**Typing Text Formatting:**
- 0 typers: "" (empty string)
- 1 typer: "Alice is typing..."
- 2 typers: "Alice and Bob are typing..."
- 3 typers: "Alice, Bob, and Charlie are typing..."
- 4+ typers: "Alice, Bob, and 2 others are typing..."

**RTDB Structure:**
- Path: `/typing/{conversationID}/{userID}/`
- Each user has own typing state node
- Auto-expires after 3 seconds (`lastUpdated` timestamp)

**Display Name Resolution:**
- First try SwiftData cache (faster)
- Fallback to Firestore if not cached
- Use "Someone" as fallback if fetch fails

### Edge Cases

- All users stop typing simultaneously → smooth transition to empty
- User removed while typing → filtered out immediately
- Deleted user account typing → show "Someone is typing..."
- Network disconnects → typing indicators freeze until reconnect
- Many users (10+) typing → show first 2 + "N others"
- User types single character then stops → indicator appears briefly

### Performance Considerations

- Use SwiftData cache for display names (avoid repeated Firestore calls)
- Debounce RTDB typing updates (max 1 update per second)
- Limit displayed names to first 3 (avoid UI overflow)
- Filter participant IDs locally (don't query RTDB repeatedly)

### Security Considerations

- Typing indicators don't reveal message content
- Only participants can see group typing indicators (RTDB rules)
- Removed users' typing indicators auto-removed
- No sensitive data in typing indicator payload

---

## Dev Notes

**CRITICAL: This section contains ALL implementation context needed. Developer should NOT need to read external docs.**

### TypingIndicatorService Extension for Multiple Users
[Source: epic-3-group-chat.md lines 1133-1154]

**Add formatTypingText Method:**
```swift
extension TypingIndicatorService {
    /// Format typing text for multiple users in group
    func formatTypingText(userIDs: Set<String>, participants: [UserEntity]) -> String {
        let typingUsers = participants.filter { userIDs.contains($0.id) }

        switch typingUsers.count {
        case 0:
            return ""
        case 1:
            return "\(typingUsers[0].displayName) is typing..."
        case 2:
            return "\(typingUsers[0].displayName) and \(typingUsers[1].displayName) are typing..."
        case 3:
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(typingUsers[2].displayName) are typing..."
        default:
            let others = typingUsers.count - 2
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(others) others are typing..."
        }
    }
}
```

**CRITICAL Typing Text Formats:**
- 0 typers: "" (empty string)
- 1 typer: "Alice is typing..."
- 2 typers: "Alice and Bob are typing..."
- 3 typers: "Alice, Bob, and Charlie are typing..."
- 4+ typers: "Alice, Bob, and 2 others are typing..."

### RTDB Typing Indicator Listener for Groups
[Source: epic-3-group-chat.md lines 1156-1158]

**MessageThreadView Typing Observation:**
```swift
// In MessageThreadView
@State private var typingUserIDs: Set<String> = []
@State private var participants: [UserEntity] = []

private var typingText: String {
    // Filter out current user (don't show own typing)
    let otherTypingUserIDs = typingUserIDs.filter {
        $0 != AuthService.shared.currentUserID
    }

    // Filter by current participants only (exclude removed users)
    let validTypingUserIDs = otherTypingUserIDs.filter {
        conversation.participantIDs.contains($0)
    }

    return TypingIndicatorService.shared.formatTypingText(
        userIDs: validTypingUserIDs,
        participants: participants
    )
}

var body: some View {
    VStack {
        // Message list...

        // Typing indicator
        if !typingText.isEmpty {
            HStack {
                Text(typingText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }

        // Message input...
    }
    .task {
        await loadParticipants()
        await observeTypingIndicators()
    }
}

private func observeTypingIndicators() async {
    let typingRef = Database.database().reference()
        .child("typing")
        .child(conversation.id)

    typingRef.observe(.value) { snapshot in
        var userIDs: Set<String> = []

        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let data = snap.value as? [String: Any],
               let isTyping = data["isTyping"] as? Bool,
               isTyping {
                userIDs.insert(snap.key)
            }
        }

        typingUserIDs = userIDs
    }
}
```

### Display Name Resolution for Typing Users
[Source: epic-3-group-chat.md lines 1157]

**Fetch Participants Pattern:**
```swift
// In MessageThreadView.loadParticipants()
private func loadParticipants() async {
    let participantIDs = conversation.participantIDs
    let descriptor = FetchDescriptor<UserEntity>(
        predicate: #Predicate<UserEntity> { user in
            participantIDs.contains(user.id)
        }
    )
    participants = (try? modelContext.fetch(descriptor)) ?? []

    // If not in SwiftData, fetch from Firestore
    let missingUserIDs = participantIDs.filter { userID in
        !participants.contains { $0.id == userID }
    }

    for userID in missingUserIDs {
        if let userData = try? await Firestore.firestore()
            .collection("users")
            .document(userID)
            .getDocument()
            .data() {
            let displayName = userData["displayName"] as? String ?? "Unknown"
            let profilePictureURL = userData["profilePictureURL"] as? String

            // Create UserEntity and add to participants
            // (or just use displayName directly)
        }
    }
}
```

**Fallback for Missing Users:**
```swift
// If user not found in SwiftData or Firestore
let displayName = "Someone"
```

### Auto-Expiration with RTDB Server Timestamp
[Source: epic-3-group-chat.md lines 1133-1162]

**CRITICAL: RTDB auto-expires typing indicators after 3 seconds**

**Client Sets Timestamp:**
```swift
// When user starts typing
let typingRef = Database.database().reference()
    .child("typing")
    .child(conversationID)
    .child(currentUserID)

typingRef.setValue([
    "isTyping": true,
    "lastUpdated": [".sv": "timestamp"]  // Server timestamp
])
```

**RTDB Rule Enforces Expiration (Already Configured):**
```json
{
  "rules": {
    "typing": {
      "$conversationID": {
        "$userID": {
          ".read": true,
          ".write": "$userID == auth.uid",
          ".validate": "newData.child('lastUpdated').val() > (now - 3000)"
        }
      }
    }
  }
}
```

**Client-Side Cleanup (Optional):**
```swift
// Remove typing indicator when user stops typing for 3 seconds
Task {
    try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
    if !isTyping {
        try? await typingRef.removeValue()
    }
}
```

### Filter Out Removed Participants
[Source: epic-3-group-chat.md lines 1156-1158]

**CRITICAL: Only show typing for current group members**

```swift
private var typingText: String {
    // Filter out current user
    let otherTypingUserIDs = typingUserIDs.filter {
        $0 != AuthService.shared.currentUserID
    }

    // Filter by current participants only
    let validTypingUserIDs = otherTypingUserIDs.filter {
        conversation.participantIDs.contains($0)
    }

    // If user removed while typing, they're filtered out
    return TypingIndicatorService.shared.formatTypingText(
        userIDs: validTypingUserIDs,
        participants: participants
    )
}
```

### 1:1 Chat Compatibility
[Source: epic-3-group-chat.md lines 1133]

**Existing 1:1 typing logic unchanged:**
```swift
// In MessageThreadView
if conversation.isGroup {
    // Use formatTypingText for multiple users
    typingText = TypingIndicatorService.shared.formatTypingText(
        userIDs: validTypingUserIDs,
        participants: participants
    )
} else {
    // Simple 1:1 typing indicator (existing logic)
    if isOtherUserTyping {
        typingText = "\(otherUserName) is typing..."
    } else {
        typingText = ""
    }
}
```

### File Modification Order

**CRITICAL: Follow this exact sequence:**

1. Update `TypingIndicatorService.swift` (add formatTypingText method)
2. Update `MessageThreadView.swift` (observe typing, display typing text)

### Testing Standards

**Manual Testing Required (No Unit Tests for MVP):**
- Test single typer (1 user typing)
- Test two typers (2 users typing simultaneously)
- Test three typers (3 users typing)
- Test 4+ typers (multiple users, show "N others")
- Test timeout (typing disappears after 3 seconds)
- Test removed participant filtering
- Test own typing not shown
- Test 1:1 chat compatibility

**CRITICAL Edge Cases:**
1. Single typer → "{Name} is typing..."
2. Two typers → "{Name1} and {Name2} are typing..."
3. Three typers → "{Name1}, {Name2}, and {Name3} are typing..."
4. 4+ typers → "{Name1}, {Name2}, and N others are typing..."
5. User removed while typing → filtered out immediately
6. Deleted user typing → show "Someone is typing..."
7. Network disconnects → typing indicators freeze until reconnect
8. Own typing → NOT shown to self

**Performance Considerations:**
- Use SwiftData cache for display names (avoid repeated Firestore calls)
- Debounce RTDB typing updates (max 1 update per second)
- Limit displayed names to first 3 (avoid UI overflow)
- Filter participant IDs locally (don't query RTDB repeatedly)

---

## Metadata

**Created by:** @sm (Scrum Master Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 2-3 of 7-day sprint
**Epic:** Epic 3: Group Chat
**Story points:** 2
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
