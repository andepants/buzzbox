---
# Story 2.1: Create New Conversation

id: STORY-2.1
title: "Create New Conversation"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: review
priority: P0  # Critical - Core messaging feature
estimate: 5  # Story points
assigned_to: James (dev)
created_date: "2025-10-21"
sprint_day: 1  # Day 1 MVP
completed_date: "2025-10-21"

---

## Description

**As a** user
**I need** to start a new one-on-one conversation with another user
**So that** I can begin messaging them

This story implements the conversation creation flow with deterministic conversation IDs, duplicate prevention, optimistic UI, and RTDB synchronization. It establishes the foundation for all messaging features.

**Key Features:**
- Deterministic conversation ID (sorted participant IDs prevents duplicates)
- Optimistic UI (instant conversation creation)
- Simultaneous creation handling (both users create at same time)
- Blocked user validation
- Recipient validation

---

## Acceptance Criteria

**This story is complete when:**

- [ ] User can tap "New Message" button from conversation list
- [ ] User can select a recipient from contacts list
- [ ] New conversation appears in conversation list immediately (optimistic UI)
- [ ] Empty conversation shows placeholder text "No messages yet"
- [ ] Conversation persists locally (SwiftData) and syncs to RTDB
- [ ] **Duplicate conversations prevented** using deterministic conversation ID (sorted participant IDs)
- [ ] **Simultaneous creation handled** (both users create conversation at same time)
- [ ] **Blocked users prevented** (cannot create conversation with blocked user)
- [ ] **Recipient validation** (recipient user exists before creating conversation)

---

## Technical Tasks

**Implementation steps:**

1. **Create ConversationEntity (SwiftData Model)**
   - File: `sorted/Models/ConversationEntity.swift`
   - Properties: id, participantIDs, lastMessage, lastMessageTimestamp, unreadCount, createdAt, updatedAt, syncStatus, isArchived, isPinned
   - Computed property: `recipientDisplayName` (fetches other participant's name)
   - See RTDB Code Examples lines 358-416

2. **Create ConversationService for RTDB operations**
   - File: `sorted/Services/ConversationService.swift`
   - Methods: `syncConversation()`, `findConversation()`, `getUser()`, `isBlocked()`
   - Singleton pattern: `ConversationService.shared`
   - See RTDB Code Examples lines 266-356

3. **Create ConversationViewModel**
   - File: `sorted/ViewModels/ConversationViewModel.swift`
   - Method: `createConversation(withUserID:)` with optimistic UI
   - Deterministic conversation ID: `[userID1, userID2].sorted().joined(separator: "_")`
   - Check local SwiftData first, then RTDB (prevents simultaneous creation duplicates)
   - Background RTDB sync with error handling
   - See RTDB Code Examples lines 24-263

4. **Create RecipientPickerView**
   - File: `sorted/Views/Chat/RecipientPickerView.swift`
   - Search users by display name
   - Show user profile pictures
   - Filter out blocked users
   - Filter out already-existing conversations
   - Native iOS search bar with `.searchable()`

5. **Add "New Message" button to ConversationListView toolbar**
   - Button with pencil icon: `Image(systemName: "square.and.pencil")`
   - Present RecipientPickerView as sheet
   - Accessibility labels: "New Message", "Start a new conversation"
   - Haptic feedback on conversation creation

6. **Implement conversation creation flow**
   - User taps "New Message" → RecipientPickerView appears
   - User selects recipient → ViewModel validates and creates conversation
   - Conversation appears in list immediately (optimistic UI)
   - Background sync to RTDB with error handling
   - Navigate to MessageThreadView automatically

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Models/ConversationEntity.swift (create)
sorted/Services/ConversationService.swift (create)
sorted/ViewModels/ConversationViewModel.swift (create)
sorted/Views/Chat/RecipientPickerView.swift (create)
sorted/Views/Chat/ConversationListView.swift (modify - add "New Message" button)
```

### Code Examples

**ConversationViewModel.swift - createConversation() (from RTDB Code Examples lines 57-139):**

```swift
import SwiftUI
import SwiftData
import FirebaseDatabase

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var conversations: [ConversationEntity] = []
    @Published var isLoading = false
    @Published var error: ConversationError?

    private let modelContext: ModelContext
    private let conversationService: ConversationService

    init(modelContext: ModelContext, conversationService: ConversationService = .shared) {
        self.modelContext = modelContext
        self.conversationService = conversationService
    }

    /// Creates a new one-on-one conversation with deterministic ID
    func createConversation(withUserID userID: String) async throws -> ConversationEntity {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Validate recipient exists
        guard let recipient = try? await conversationService.getUser(userID: userID) else {
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }

        // Step 2: Check if user is blocked
        if try await conversationService.isBlocked(userID: userID) {
            let error = ConversationError.userBlocked
            self.error = error
            throw error
        }

        // Step 3: Generate deterministic conversation ID
        // Pattern: sorted participant IDs joined with underscore
        // Example: "user123_user456" (always same regardless of who initiates)
        let currentUserID = AuthService.shared.currentUserID
        let participants = [currentUserID, userID].sorted()
        let conversationID = participants.joined(separator: "_")

        // Step 4: Check local SwiftData first (optimistic)
        let localDescriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )

        if let existing = try? modelContext.fetch(localDescriptor).first {
            return existing
        }

        // Step 5: Check RTDB for existing conversation (handles simultaneous creation)
        if let remoteConversation = try await conversationService.findConversation(id: conversationID) {
            // Sync remote conversation to local SwiftData
            modelContext.insert(remoteConversation)
            try modelContext.save()

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            return remoteConversation
        }

        // Step 6: Create new conversation
        let conversation = ConversationEntity(
            id: conversationID, // Deterministic!
            participantIDs: participants,
            lastMessage: nil,
            lastMessageTimestamp: Date(),
            unreadCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending,
            isArchived: false,
            isPinned: false
        )

        // Step 7: Save locally first (optimistic UI)
        modelContext.insert(conversation)
        try modelContext.save()

        // Step 8: Sync to RTDB in background
        Task { @MainActor in
            do {
                try await conversationService.syncConversation(conversation)
                conversation.syncStatus = .synced
                try? modelContext.save()

                // Haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

            } catch {
                conversation.syncStatus = .failed
                self.error = .creationFailed
                try? modelContext.save()
            }
        }

        return conversation
    }
}

enum ConversationError: LocalizedError {
    case recipientNotFound
    case userBlocked
    case creationFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .recipientNotFound:
            return "User not found. Please check the username and try again."
        case .userBlocked:
            return "You cannot message this user."
        case .creationFailed:
            return "Failed to create conversation. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}
```

**ConversationService.swift (from RTDB Code Examples lines 266-356):**

```swift
import Foundation
import FirebaseDatabase
import SwiftData

/// Service for managing conversations in Firebase Realtime Database
final class ConversationService {
    static let shared = ConversationService()

    private let database = Database.database().reference()

    private init() {}

    /// Syncs a conversation to RTDB
    func syncConversation(_ conversation: ConversationEntity) async throws {
        let conversationRef = database.child("conversations/\(conversation.id)")

        let conversationData: [String: Any] = [
            "participantIDs": conversation.participantIDs,
            "lastMessage": conversation.lastMessage ?? "",
            "lastMessageTimestamp": ServerValue.timestamp(),
            "createdAt": conversation.createdAt.timeIntervalSince1970,
            "updatedAt": ServerValue.timestamp(),
            "unreadCount": conversation.unreadCount
        ]

        try await conversationRef.setValue(conversationData)
    }

    /// Finds a conversation by ID in RTDB
    func findConversation(id: String) async throws -> ConversationEntity? {
        let conversationRef = database.child("conversations/\(id)")
        let snapshot = try await conversationRef.getData()

        guard snapshot.exists(),
              let conversationData = snapshot.value as? [String: Any] else {
            return nil
        }

        return ConversationEntity(
            id: id,
            participantIDs: conversationData["participantIDs"] as? [String] ?? [],
            lastMessage: conversationData["lastMessage"] as? String,
            lastMessageTimestamp: Date(
                timeIntervalSince1970: conversationData["lastMessageTimestamp"] as? TimeInterval ?? 0
            ),
            unreadCount: conversationData["unreadCount"] as? Int ?? 0,
            createdAt: Date(
                timeIntervalSince1970: conversationData["createdAt"] as? TimeInterval ?? 0
            ),
            updatedAt: Date(
                timeIntervalSince1970: conversationData["updatedAt"] as? TimeInterval ?? 0
            ),
            syncStatus: .synced,
            isArchived: false,
            isPinned: false
        )
    }

    /// Gets a user by ID from RTDB
    func getUser(userID: String) async throws -> UserEntity? {
        let userRef = database.child("users/\(userID)")
        let snapshot = try await userRef.getData()

        guard snapshot.exists(),
              let userData = snapshot.value as? [String: Any] else {
            return nil
        }

        return UserEntity(
            id: userID,
            displayName: userData["displayName"] as? String ?? "",
            profilePictureURL: userData["profilePictureURL"] as? String,
            fcmToken: userData["fcmToken"] as? String
        )
    }

    /// Checks if a user is blocked
    func isBlocked(userID: String) async throws -> Bool {
        let currentUserID = AuthService.shared.currentUserID
        let blockedRef = database.child("users/\(currentUserID)/blockedUsers/\(userID)")
        let snapshot = try await blockedRef.getData()
        return snapshot.exists()
    }
}
```

**ConversationEntity.swift (from RTDB Code Examples lines 358-416):**

```swift
import Foundation
import SwiftData

@Model
final class ConversationEntity {
    var id: String
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTimestamp: Date
    var unreadCount: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var isArchived: Bool
    var isPinned: Bool

    init(
        id: String,
        participantIDs: [String],
        lastMessage: String?,
        lastMessageTimestamp: Date,
        unreadCount: Int,
        createdAt: Date,
        updatedAt: Date,
        syncStatus: SyncStatus,
        isArchived: Bool,
        isPinned: Bool
    ) {
        self.id = id
        self.participantIDs = participantIDs
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isArchived = isArchived
        self.isPinned = isPinned
    }

    /// Computed property: Display name of the other participant
    var recipientDisplayName: String {
        let currentUserID = AuthService.shared.currentUserID
        guard let recipientID = participantIDs.first(where: { $0 != currentUserID }) else {
            return "Unknown"
        }

        // TODO: Fetch user display name from cache or RTDB
        return recipientID
    }
}

enum SyncStatus: String, Codable {
    case pending
    case synced
    case failed
}
```

**RecipientPickerView.swift (Basic structure):**

```swift
import SwiftUI

struct RecipientPickerView: View {
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var users: [UserEntity] = []
    @Environment(\.dismiss) private var dismiss

    var filteredUsers: [UserEntity] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredUsers) { user in
                Button {
                    onSelect(user.id)
                    dismiss()
                } label: {
                    HStack {
                        AsyncImage(url: URL(string: user.profilePictureURL ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        Text(user.displayName)
                            .font(.system(size: 17))
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }

    private func loadUsers() async {
        // TODO: Fetch users from Firestore
        // Filter out blocked users
        // Filter out existing conversations
    }
}
```

### RTDB Data Structure

```json
{
  "conversations": {
    "user123_user456": {
      "participantIDs": ["user123", "user456"],
      "lastMessage": "",
      "lastMessageTimestamp": 1704067200000,
      "createdAt": 1704067200,
      "updatedAt": 1704067200000,
      "unreadCount": 0
    }
  },
  "users": {
    "user123": {
      "blockedUsers": {
        "user789": true
      }
    }
  }
}
```

### Dependencies

**Required:**
- Story 2.0 (FCM/APNs Setup) must be complete
- AuthService.shared.currentUserID available
- AppContainer.shared.modelContainer configured (Pattern 1 from Epic 2)
- Firebase Realtime Database rules deployed

**Blocks:**
- Story 2.2 (Display Conversation List) - needs ConversationEntity
- Story 2.3 (Send and Receive Messages) - needs conversation creation

**External:**
- User profiles must exist in Firestore (Epic 1)
- RTDB security rules allow conversation creation

---

## Testing & Validation

### Test Procedure

1. **Happy Path - New Conversation:**
   - Launch app
   - Tap "New Message" button in ConversationListView
   - Select a recipient from RecipientPickerView
   - Verify conversation appears in list immediately
   - Check Firestore: verify conversation synced to RTDB
   - Verify conversation ID format: "userID1_userID2" (sorted)

2. **Duplicate Prevention:**
   - Create conversation with User A
   - Try to create another conversation with User A
   - Verify existing conversation is returned (no duplicate)

3. **Simultaneous Creation:**
   - User A creates conversation with User B
   - User B simultaneously creates conversation with User A
   - Verify both users see the same conversation (same ID)
   - Verify no duplicate conversations in RTDB

4. **Blocked User Validation:**
   - Block a user (User C)
   - Try to create conversation with User C
   - Verify error: "You cannot message this user"

5. **Recipient Validation:**
   - Try to create conversation with non-existent user ID
   - Verify error: "User not found"

6. **Offline Creation:**
   - Disable network
   - Create conversation
   - Verify conversation appears in list (syncStatus: .pending)
   - Re-enable network
   - Verify conversation syncs to RTDB (syncStatus: .synced)

### Success Criteria

- [ ] Builds without errors
- [ ] "New Message" button appears in toolbar
- [ ] RecipientPickerView presents as sheet
- [ ] Conversation creation is instant (optimistic UI <100ms)
- [ ] Conversation appears in ConversationListView
- [ ] Conversation syncs to RTDB successfully
- [ ] Duplicate conversations prevented
- [ ] Blocked users cannot be messaged
- [ ] Invalid recipients show error
- [ ] Offline conversations sync when network restored

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 974-1196)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 22-416)
- Pattern 1: AppContainer Singleton - Epic 2 lines 123-198

**PRD Sections:**
- Conversation Management
- User Interactions

**Implementation Guides:**
- SwiftData Implementation Guide (docs/swiftdata-implementation-guide.md)
- Firebase RTDB Documentation

**Context7 References:**
- `/mobizt/firebaseclient` (topic: "RTDB set push operations")
- `/pointfreeco/swift-concurrency-extras` (topic: "@MainActor thread safety")

**Related Stories:**
- Story 2.0 (FCM/APNs Setup) - required
- Story 2.2 (Display Conversation List) - builds on this
- Story 2.3 (Send and Receive Messages) - requires conversations

---

## Notes & Considerations

### Implementation Notes

**Deterministic Conversation IDs (from Epic 2 lines 1045-1046):**
```swift
let participants = [AuthService.shared.currentUserID, userID].sorted()
let conversationID = participants.joined(separator: "_")
```
This ensures the SAME conversation ID regardless of who initiates the conversation, preventing duplicates.

**Three-Layer Duplicate Check:**
1. Local SwiftData (fastest - cached)
2. RTDB remote check (handles simultaneous creation)
3. Create new if neither exists

**Optimistic UI Pattern:**
1. Insert into SwiftData immediately
2. Update UI instantly (appears in list)
3. Sync to RTDB in background
4. Update syncStatus on success/failure

### Edge Cases

- **Simultaneous Creation:** Both users create conversation at same time → Same deterministic ID prevents duplicates
- **Blocked Users:** Check RTDB `/users/{userID}/blockedUsers/{blockedUID}` before creation
- **Deleted Conversations:** If user deleted conversation locally but it exists in RTDB, re-sync from remote
- **Network Failures:** Conversation stays in `.pending` state, retried by SyncCoordinator (Story 2.5)

### Performance Considerations

- Local SwiftData check is instant (no network call)
- RTDB check adds <10ms latency (acceptable for duplicate prevention)
- Background RTDB sync doesn't block UI
- Haptic feedback provides instant tactile response

### Security Considerations

- RTDB security rules must validate:
  - User is authenticated
  - User is a participant in the conversation
  - Conversation ID matches sorted participant IDs
- Blocked users check prevents harassment

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 5
**Priority:** P0 (Critical)

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review ✅
- [x] **Ready** - Story reviewed and ready for development ✅
- [x] **In Progress** - Developer working on story ✅
- [ ] **Blocked** - Story blocked by dependency or issue
- [x] **Review** - Implementation complete, needs QA review ✅
- [ ] **Done** - Story complete and validated

**Current Status:** Review

---

## Dev Agent Record

### Agent Model Used
- Model: Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)
- Agent: James (Full Stack Developer)
- Date: 2025-10-21

### Debug Log References
- Build succeeded on first attempt after fixing import and concurrency issues
- Minor concurrency warnings in ConversationService (acceptable for MVP)
- All technical tasks completed successfully

### Completion Notes List
1. ✅ Updated ConversationEntity with syncStatus field
2. ✅ Created ConversationService for RTDB operations  
3. ✅ Created ConversationViewModel with optimistic UI and error handling
4. ✅ Created RecipientPickerView with search functionality
5. ✅ Created ConversationListView with "New Message" button
6. ✅ Created AppContainer singleton for ModelContext access
7. ✅ Updated SortedApp.swift to use AppContainer.shared.modelContainer
8. ✅ Fixed Combine import issue in ConversationViewModel
9. ✅ Fixed concurrency issue by changing recipientDisplayName to getRecipientID()
10. ✅ Build succeeded with minor warnings

### File List

**Created:**
- sorted/Core/Services/ConversationService.swift
- sorted/Features/Chat/ViewModels/ConversationViewModel.swift
- sorted/Features/Chat/Views/RecipientPickerView.swift
- sorted/Features/Chat/Views/ConversationListView.swift
- sorted/App/AppContainer.swift

**Modified:**
- sorted/Core/Models/ConversationEntity.swift (added syncStatus, getRecipientID())
- sorted/App/SortedApp.swift (use AppContainer.shared.modelContainer)

### Change Log
- 2025-10-21: Story implementation completed by @dev (James)
- All 6 technical tasks completed
- Build succeeded
- Status changed from "Ready" to "Review"

---

**Current Status:** Review (Ready for QA)
