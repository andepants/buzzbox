# Story 5.4: DM Restrictions

## Status
Draft

## Story
**As the** system,
**I want** to restrict DMs so fans can only message Andrew,
**so that** the platform maintains a single-creator fan engagement model.

## Acceptance Criteria

1. Fans can create DMs with creator (Andrew) only
2. Fans cannot create DMs with other fans
3. Attempting fan-to-fan DM shows clear error message
4. Creator can respond to any fan DM
5. Creator can initiate DMs with fans (if needed)
6. UI shows "Message Andrew" button for fans (primary DM action)
7. DM creation validates recipient's userType before allowing
8. Existing DM infrastructure (Epic 2) continues to work unchanged
9. Error handling provides helpful feedback to users
10. Fans can view other fan profiles (but cannot message them)
11. Andrew's profile is visible to all users (isPublic = true)

## Tasks / Subtasks

- [ ] Implement DM recipient validation logic (AC: 1, 2, 3, 7)
  - [ ] Create canCreateDM(from: user, to: recipient) validation function
  - [ ] If both users are fans → return false with error
  - [ ] If user is fan and recipient is creator → return true
  - [ ] If user is creator → return true (can DM anyone)
  - [ ] Return ValidationResult with error message for UI

- [ ] Update ConversationService DM creation (AC: 1, 2, 3, 7)
  - [ ] Add recipient type check in createConversation method
  - [ ] Call canCreateDM validation before creating conversation
  - [ ] Throw appropriate error if validation fails
  - [ ] Return error to ViewModel for display
  - [ ] Only create conversation if validation passes

- [ ] Update DM creation UI for fans (AC: 6)
  - [ ] Replace user search with "Message Andrew" button
  - [ ] Button should only appear for fans (creator doesn't see it)
  - [ ] Button directly creates/opens DM with Andrew
  - [ ] Remove ability for fans to search for other users
  - [ ] Simplify new conversation flow for fans

- [ ] Add error handling and user feedback (AC: 3, 9)
  - [ ] Create error message: "You can only message Andrew"
  - [ ] Display error as toast/alert when fan attempts invalid DM
  - [ ] Ensure error is user-friendly and clear
  - [ ] Log validation failures for debugging

- [ ] Update creator DM UI (AC: 4, 5)
  - [ ] Creator retains full DM capabilities
  - [ ] Creator can reply to any fan DM from inbox
  - [ ] Creator can search for and DM any user (if needed)
  - [ ] No restrictions on creator DM creation

- [ ] Add Firebase security rules (AC: 1, 2, 10, 11)
  - [ ] Add Firestore rule to enforce DM restrictions
  - [ ] Verify both participants' userTypes on conversation creation
  - [ ] Reject conversation creation if both are fans
  - [ ] Allow conversation creation if one is creator
  - [ ] Allow reading creator profile (isPublic = true)
  - [ ] Allow fans to read other fan profiles (for channel context)
  - [ ] Security rules as backup to client-side validation

- [ ] Update profile UI for DM restrictions (AC: 10, 11)
  - [ ] Fans can view any profile (creator or other fans)
  - [ ] Show "Message" button only for creator profile
  - [ ] Disable/hide "Message" button on fan profiles
  - [ ] Display tooltip "Only Andrew accepts DMs" on fan profiles
  - [ ] Creator profile shows creator badge

## Dev Notes

### Architecture Context

**Validation Logic:**
```swift
enum DMValidationError: Error, LocalizedError {
    case bothFans
    case invalidRecipient

    var errorDescription: String? {
        switch self {
        case .bothFans:
            return "You can only send direct messages to Andrew"
        case .invalidRecipient:
            return "Invalid recipient"
        }
    }
}

func canCreateDM(from sender: UserEntity, to recipient: UserEntity) throws {
    // Creator can DM anyone
    if sender.isCreator { return }

    // Fan can only DM creator
    if sender.userType == .fan && recipient.userType == .fan {
        throw DMValidationError.bothFans
    }

    // Fan can DM creator
    if sender.userType == .fan && recipient.isCreator {
        return
    }
}
```

**ConversationService Integration:**
```swift
class ConversationService {
    func createDirectMessage(with recipient: UserEntity, currentUser: UserEntity) async throws -> ConversationEntity {
        // Validate DM permissions
        try canCreateDM(from: currentUser, to: recipient)

        // Existing DM creation logic continues...
        let conversation = ConversationEntity(
            id: UUID().uuidString,
            participantIDs: [currentUser.id, recipient.id],
            isGroup: false
        )

        // Save to SwiftData and sync to Firestore
        return conversation
    }
}
```

**UI Simplification for Fans:**
```swift
// In ConversationListView or Profile
if !currentUser.isCreator {
    Button("Message Andrew") {
        Task {
            await viewModel.createDMWithCreator()
        }
    }
}
```

### Source Tree
```
Core/
├── Models/
│   └── DMValidationError.swift (NEW enum)
├── Services/
│   └── ConversationService.swift (Add validation)
├── Views/
│   └── Conversations/
│       ├── NewConversationView.swift (Simplify for fans)
│       └── ConversationListView.swift (Add "Message Andrew" button)
└── ViewModels/
    └── ConversationListViewModel.swift (Add createDMWithCreator method)
```

### Firebase Security Rules

**Firestore Rules (conversations collection):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /conversations/{conversationID} {
      allow create: if request.auth.uid in request.resource.data.participantIDs &&
        // If conversation has 2 participants (DM)
        request.resource.data.participantIDs.size() == 2 &&
        !request.resource.data.isGroup &&
        // Ensure at least one participant is creator
        (isCreator(request.resource.data.participantIDs[0]) ||
         isCreator(request.resource.data.participantIDs[1]));
    }

    function isCreator(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data.userType == 'creator';
    }
  }
}
```

### Integration Points
- **Reuses:** Epic 2 one-on-one chat infrastructure
- **Adds:** Permission validation layer
- **Changes:** UI simplified for fans (no user search)

### Dependencies
- **Depends on:** Story 5.2 (User Type) - Need userType for validation
- **Depends on:** Epic 2 (One-on-One Chat) - DM infrastructure must exist
- **Blocks:** Story 5.5 (Creator Inbox) - DM restrictions affect inbox content

## Testing

### Testing Standards
- Manual testing with two test accounts (fan and creator)
- Test on simulator for quick iteration
- Test on physical device for Firebase rules
- Verify security rules in Firebase console

### Test Cases

1. **Fan → Creator DM (Should Work):**
   - Login as fan account
   - Click "Message Andrew" button
   - DM conversation created successfully
   - Can send messages to Andrew
   - Conversation appears in fan's DM list

2. **Fan → Fan DM (Should Fail):**
   - Login as fan account
   - Attempt to create DM with another fan
   - Receive error: "You can only send direct messages to Andrew"
   - No conversation created
   - Error displayed as toast/alert

3. **Creator → Fan DM (Should Work):**
   - Login as Andrew (creator)
   - Search for fan user
   - Create DM with fan
   - DM conversation created successfully
   - Can send messages to fan

4. **Creator → Creator (Edge Case):**
   - Login as Andrew
   - Since Andrew is the only creator, this shouldn't be possible
   - But if it were, should be allowed

5. **UI Changes for Fans:**
   - Login as fan
   - Verify "Message Andrew" button exists
   - Verify no user search UI for fans
   - Verify button creates/opens DM with Andrew
   - Check button styling and placement

6. **UI for Creator:**
   - Login as Andrew
   - Verify full DM capabilities
   - Can search for users
   - Can create DM with any fan
   - No restrictions on UI

7. **Security Rules Enforcement:**
   - Attempt to create fan-to-fan DM via Firestore console
   - Verify Firestore rejects the write
   - Check security rules console for errors
   - Confirm only valid DMs can be created

8. **Error Messaging:**
   - Trigger validation error
   - Verify error message is clear and helpful
   - Check error is displayed to user (not silent)
   - Verify error doesn't crash app

9. **Existing DM Functionality:**
   - Verify existing DMs still work
   - Send messages in existing DM
   - Check real-time sync
   - Verify offline queue works
   - Check typing indicators work

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
