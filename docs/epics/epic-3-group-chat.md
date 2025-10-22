# Epic 3: Group Chat

**Phase:** Day 2-3 (Extended Messaging)
**Priority:** P1 (High - Core Feature)
**Estimated Time:** 3-4 hours
**Epic Owner:** Development Team Lead
**Dependencies:** Epic 2 (One-on-One Chat Infrastructure)

---

## ✅ CODEBASE READINESS (Updated: 2025-10-21)

**All prerequisite fixes have been applied to the codebase:**
- ✅ `ConversationEntity` extended with `adminUserIDs: [String]` and `groupPhotoURL`
- ✅ `MessageEntity` extended with `isSystemMessage: Bool` and `readBy: [String: Date]`
- ✅ RTDB rules updated with group validation (admin permissions, participant limits, system messages)
- ✅ `ConversationService.syncConversation()` syncs all group fields to RTDB
- ✅ Storage rules added for `/group_photos/{groupId}/` path
- ✅ `StorageService.uploadGroupPhoto()` method added for group photo uploads

**Security Enhancements:**
- ✅ Only admins can modify `groupName`, `groupPhotoURL`, and `participantList` (enforced by RTDB rules)
- ✅ Participant limits enforced: min 2, max 256 (RTDB validation)
- ✅ System messages validated: `senderID` must be "system" if `isSystemMessage == true`
- ✅ Read receipts support timestamps: `readBy: { "userID": timestamp }`

**Implementation Ready:** This epic is now ready for Story 3.1 implementation.

---

## Overview

Extend the one-on-one messaging infrastructure to support group conversations with multiple participants. Includes group creation, participant management, group info editing, and optimized message delivery for multi-user scenarios.

---

## What This Epic Delivers

- ✅ Create group conversations with multiple participants
- ✅ Group info screen (name, photo, participant list)
- ✅ Add/remove participants from groups
- ✅ Group admin permissions (creator is admin)
- ✅ Leave group functionality
- ✅ Group name and photo editing
- ✅ Participant typing indicators ("Alice and Bob are typing...")
- ✅ Read receipts showing who read each message
- ✅ Group message delivery optimized for multiple recipients

---

### iOS-Specific Group Messaging Patterns

**Group chat extends Epic 2 with iOS mobile-first enhancements:**

- ✅ **Multi-Select UI:** Native iOS participant selection with checkmarks
- ✅ **Group Photo Picker:** Same permissions as profile photos (NSPhotoLibraryUsageDescription)
- ✅ **Confirmation Dialogs:** Use `.confirmationDialog()` for destructive actions (leave group, remove participant)
- ✅ **Sheet Presentations:** Use `.sheet()` for group creation, editing, participant management
- ✅ **List Performance:** Efficient rendering of large participant lists with LazyVStack
- ✅ **Haptic Feedback:** Haptics for participant add/remove, group name changes
- ✅ **Accessibility:** VoiceOver announces participant count changes, admin badges
- ✅ **Safe Areas:** All modals respect safe areas (especially on iPad)

---

### Data Flow Architecture (CRITICAL)

**✅ VERIFIED: Epic 3 uses Firebase Realtime Database (RTDB) for all real-time group chat features, consistent with Epic 2 implementation.**

**Note:** The actual codebase implements Epic 2 with RTDB (not Firestore), so Epic 3 properly extends this architecture. All models, services, and security rules have been updated to support group chat features.

#### Local Persistence (SwiftData)

```swift
// Local-only models for offline access
@Model final class ConversationEntity {
    var id: String
    var participantIDs: [String]
    var isGroup: Bool
    var groupName: String?
    var syncStatus: SyncStatus // .pending, .synced, .failed
    // ... other fields
}

@Model final class MessageEntity {
    var id: String
    var conversationID: String
    var senderID: String
    var text: String
    var syncStatus: SyncStatus
    // ... other fields
}
```

#### Remote Real-time Database (Firebase RTDB)

**Conversations:**
```
/conversations/{conversationID}/
  ├── participantIDs: { "user1": true, "user2": true, "user3": true }
  ├── isGroup: true
  ├── groupName: "Family Group"
  ├── groupPhotoURL: "https://storage.googleapis.com/..."
  ├── adminUserIDs: { "user1": true }
  ├── lastMessage: "Hey everyone!"
  ├── lastMessageTimestamp: 1704067200000
  ├── createdAt: 1704067100000
  └── updatedAt: 1704067200000
```

**Messages:**
```
/messages/{conversationID}/{messageID}/
  ├── senderID: "user1"
  ├── text: "Hey everyone!"
  ├── serverTimestamp: 1704067200000
  ├── status: "sent"
  ├── isSystemMessage: false
  └── readBy/
      ├── user2: 1704067300000
      └── user3: 1704067400000
```

**Typing Indicators:**
```
/typing/{conversationID}/{userID}/
  ├── isTyping: true
  └── lastUpdated: { ".sv": "timestamp" }
```

#### Remote Static Database (Cloud Firestore)

**User Profiles (READ-ONLY for messaging features):**
```
/users/{userID}/
  ├── displayName: "Alice Smith"
  ├── email: "alice@example.com"
  ├── profilePictureURL: "https://..."
  ├── fcmToken: "fE3Kd..."
  └── updatedAt: Timestamp
```

#### Bidirectional Sync Strategy

**Write Flow (User → RTDB):**
1. User creates/edits group → Save to SwiftData with `syncStatus: .pending`
2. SyncCoordinator detects pending changes → Writes to RTDB
3. RTDB write succeeds → Update SwiftData `syncStatus: .synced`
4. RTDB write fails → Retry with exponential backoff, keep `syncStatus: .pending`

**Read Flow (RTDB → User):**
1. RTDB listener observes change (new message, participant added, etc.)
2. Fetch change from RTDB
3. Update/insert into SwiftData with `syncStatus: .synced`
4. SwiftUI views auto-update via `@Query`

**Offline Behavior:**
1. All writes queued in SwiftData with `syncStatus: .pending`
2. NetworkMonitor detects connection restored
3. SyncCoordinator processes queue: sync all pending items to RTDB
4. UI shows sync progress via SyncProgressView

**Service Responsibilities:**

- **ConversationService:** CRUD operations on RTDB `/conversations/`
- **MessageService:** CRUD operations on RTDB `/messages/`
- **TypingIndicatorService:** Real-time updates to RTDB `/typing/`
- **StorageService:** Upload group photos to Firebase Storage
- **SyncCoordinator:** Orchestrates SwiftData ↔ RTDB synchronization
- **Firestore:** Only accessed for user profile lookups (displayName, profilePictureURL)

---

## User Stories

### Story 3.1: Create Group Conversation
**As a user, I want to create a group chat with multiple people so we can all communicate together.**

**Acceptance Criteria:**
- [ ] User can tap "New Group" button from conversation list
- [ ] User can select 2+ recipients from contacts list
- [ ] User can set group name and optional group photo
- [ ] Group appears in conversation list immediately
- [ ] All participants receive notification of group creation
- [ ] Creator automatically becomes group admin
- [ ] Group persists locally and syncs to RTDB
- [ ] Group creation limited to 256 participants maximum
- [ ] Group name validated (non-empty after trim, 1-50 characters)
- [ ] Duplicate participant prevention in selection UI
- [ ] Offline group creation queued, syncs when connection restored
- [ ] Group photo upload shows progress bar with cancel option
- [ ] Group photo upload failure shows error toast with retry button
- [ ] Deep link support: tapping notification opens group MessageThreadView

---

## Prerequisite Components

**These components must be created BEFORE implementing the main story tasks:**

### Component 1: ImagePicker

**File:** `sorted/Core/Components/ImagePicker.swift`

**Purpose:** Reusable UIImagePickerController wrapper for SwiftUI

**Requirements:**
- Presents UIImagePickerController for photo library access
- Returns selected UIImage via SwiftUI binding
- Handles permission requests (NSPhotoLibraryUsageDescription)
- Supports dismiss action
- iOS 17+ compatible

**Interface:**
```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    // UIViewControllerRepresentable implementation
}
```

**Usage:**
```swift
.sheet(isPresented: $showImagePicker) {
    ImagePicker(image: $selectedImage)
}
```

**Estimated Time:** 15 minutes

**Acceptance Criteria:**
- [ ] Presents photo library picker
- [ ] Returns selected image via binding
- [ ] Handles "Cancel" action (dismisses without selection)
- [ ] Handles permission denied gracefully
- [ ] Compiles without warnings

---

### Component 2: ParticipantPickerView

**File:** `sorted/Features/Chat/Views/Components/ParticipantPickerView.swift`

**Purpose:** Multi-select user picker for group participant selection

**Requirements:**
- Fetches all users from Firestore `/users` collection
- Displays users in List with profile pictures and display names
- Multi-select with checkmark indicators
- Filters out current user (can't add yourself)
- Returns Set<String> of selected user IDs via binding
- Search/filter capability (optional for MVP)

**Interface:**
```swift
struct ParticipantPickerView: View {
    @Binding var selectedUserIDs: Set<String>

    @State private var users: [UserEntity] = []
    @State private var isLoading = false

    var body: some View {
        // Implementation
    }
}
```

**Data Source:**
- Fetch from Firestore: `Firestore.firestore().collection("users").getDocuments()`
- Convert to `UserEntity` objects
- Filter out `AuthService.shared.currentUserID`

**UI Design:**
```
┌─────────────────────────────────┐
│ [Profile Pic] Alice Smith     ✓ │ ← Selected
│ [Profile Pic] Bob Jones       ○ │ ← Not selected
│ [Profile Pic] Charlie Lee     ✓ │ ← Selected
└─────────────────────────────────┘
```

**Estimated Time:** 30 minutes

**Acceptance Criteria:**
- [ ] Loads all users from Firestore
- [ ] Displays profile pictures (AsyncImage with fallback)
- [ ] Multi-select with checkmark toggle
- [ ] Current user filtered out
- [ ] Loading state shown while fetching
- [ ] Empty state if no users found
- [ ] Selected user IDs returned via binding

---

**Total Prerequisite Time:** 45 minutes

**Implementation Order:**
1. Create ImagePicker (15 min)
2. Create ParticipantPickerView (30 min)
3. Proceed with Story 3.1 main tasks

---

**Technical Tasks:**
1. Update ConversationEntity to support group metadata:
   ```swift
   @Model
   final class ConversationEntity {
       @Attribute(.unique) var id: String
       var participantIDs: [String] // Multiple participants for groups
       var isGroup: Bool // true for groups, false for 1:1
       var displayName: String? // Group name (nil for 1:1 chats)
       var groupPhotoURL: String? // Group photo URL
       var adminUserIDs: [String] // Admins who can edit group
       var lastMessage: String?
       var lastMessageTimestamp: Date
       var unreadCount: Int
       var createdAt: Date
       var updatedAt: Date
       var syncStatus: SyncStatus
       var isArchived: Bool

       init(
           id: String,
           participantIDs: [String],
           isGroup: Bool = false,
           displayName: String? = nil,
           groupPhotoURL: String? = nil,
           adminUserIDs: [String] = [],
           lastMessage: String? = nil,
           lastMessageTimestamp: Date = Date(),
           unreadCount: Int = 0,
           createdAt: Date = Date(),
           updatedAt: Date = Date(),
           syncStatus: SyncStatus = .pending,
           isArchived: Bool = false
       ) {
           self.id = id
           self.participantIDs = participantIDs
           self.isGroup = isGroup
           self.displayName = displayName
           self.groupPhotoURL = groupPhotoURL
           self.adminUserIDs = adminUserIDs
           self.lastMessage = lastMessage
           self.lastMessageTimestamp = lastMessageTimestamp
           self.unreadCount = unreadCount
           self.createdAt = createdAt
           self.updatedAt = updatedAt
           self.syncStatus = syncStatus
           self.isArchived = isArchived
       }
   }
   ```

---

⚠️ **IMPORTANT: Proposed Implementation**

The code examples below are **PROPOSED implementations** for reference only.
These views DO NOT currently exist in the codebase. Developers should use
these as architectural guides, not as existing code to modify.

**Views to be created in this story:**
- `GroupCreationView` (lines 253-381)
- `ParticipantPickerView` (Task #3, see prerequisite components section)
- `ImagePicker` (prerequisite component, see below)

---

2. Create GroupCreationView:
   ```swift
   struct GroupCreationView: View {
       @Environment(\.dismiss) private var dismiss
       @Environment(\.modelContext) private var modelContext

       @StateObject private var viewModel: GroupCreationViewModel
       @State private var groupName = ""
       @State private var selectedUserIDs: Set<String> = []
       @State private var groupPhoto: UIImage?
       @State private var showImagePicker = false

       var body: some View {
           NavigationStack {
               Form {
                   Section {
                       HStack {
                           // Group photo
                           Button(action: { showImagePicker = true }) {
                               if let photo = groupPhoto {
                                   Image(uiImage: photo)
                                       .resizable()
                                       .scaledToFill()
                                       .frame(width: 80, height: 80)
                                       .clipShape(Circle())
                               } else {
                                   ZStack {
                                       Circle()
                                           .fill(Color.gray.opacity(0.3))
                                           .frame(width: 80, height: 80)

                                       Image(systemName: "camera.fill")
                                           .foregroundColor(.gray)
                                   }
                               }
                           }

                           VStack(alignment: .leading) {
                               TextField("Group Name", text: $groupName)
                                   .font(.system(size: 18, weight: .semibold))

                               Text("\(selectedUserIDs.count) participants")
                                   .font(.system(size: 14))
                                   .foregroundColor(.secondary)
                           }
                       }
                   }

                   Section("Participants") {
                       ParticipantPickerView(selectedUserIDs: $selectedUserIDs)
                   }
               }
               .navigationTitle("New Group")
               .navigationBarTitleDisplayMode(.inline)
               .toolbar {
                   ToolbarItem(placement: .cancellationAction) {
                       Button("Cancel") { dismiss() }
                   }

                   ToolbarItem(placement: .confirmationAction) {
                       Button("Create") {
                           Task {
                               await createGroup()
                           }
                       }
                       .disabled(groupName.isEmpty || selectedUserIDs.count < 2)
                   }
               }
               .sheet(isPresented: $showImagePicker) {
                   ImagePicker(image: $groupPhoto)
               }
           }
       }

       private func createGroup() async {
           var participantIDs = Array(selectedUserIDs)
           participantIDs.append(AuthService.shared.currentUserID)

           let conversation = ConversationEntity(
               id: UUID().uuidString,
               participantIDs: participantIDs,
               isGroup: true,
               displayName: groupName,
               adminUserIDs: [AuthService.shared.currentUserID]
           )

           // Save locally
           modelContext.insert(conversation)
           try? modelContext.save()

           // Upload group photo if provided
           if let photo = groupPhoto {
               Task.detached {
                   if let url = try? await StorageService.shared.uploadGroupPhoto(
                       photo,
                       groupID: conversation.id
                   ) {
                       await MainActor.run {
                           conversation.groupPhotoURL = url
                           try? modelContext.save()
                       }
                   }
               }
           }

           // Sync to RTDB
           Task.detached {
               try? await ConversationService.shared.syncConversationToRTDB(conversation)

               // Send system message to RTDB
               let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
                   for: AuthService.shared.currentUserID ?? ""
               ) ?? "Someone"

               let systemMessage = MessageEntity(
                   id: UUID().uuidString,
                   conversationID: conversation.id,
                   senderID: "system",
                   text: "\(currentUserDisplayName) created the group",
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

3. Create ParticipantPickerView component
4. Update ConversationListView to show "New Group" button
5. Update ConversationService to handle group creation in RTDB:
   - Write to `/conversations/{conversationID}` with group metadata
   - Use RTDB transaction to ensure atomic creation
   - Set participantIDs as object: `{ "user1": true, "user2": true }` (faster lookups)
   - Set adminUserIDs as object: `{ "user1": true }`
   - Add RTDB listener for real-time updates to this conversation

**References:**
- SwiftData Implementation Guide Section 3.2 (ConversationEntity updates)
- PRD Epic 3: Group Chat

---

### Story 3.2: Group Info Screen
**As a user, I want to view group details so I can see participants and group settings.**

**Acceptance Criteria:**
- [ ] Tap group name in navigation bar opens group info screen
- [ ] Shows group photo, name, participant count
- [ ] Lists all participants with profile pictures
- [ ] Admin badge shown for group admins
- [ ] "Edit Group" button visible only to admins
- [ ] "Leave Group" button at bottom (destructive action)
- [ ] "Add Participants" button for admins
- [ ] Deleted user accounts shown as "Deleted User" with placeholder avatar
- [ ] Lazy loading for participant lists with 50+ members
- [ ] Concurrent participant removal handled gracefully (no duplicate removal errors)
- [ ] User automatically navigates back if removed while viewing group
- [ ] Last admin cannot leave without transferring admin rights first
- [ ] "Leave Group" shows admin transfer dialog if user is last admin
- [ ] If last admin force-leaves, oldest member automatically becomes admin

---

⚠️ **IMPORTANT: Proposed Implementation**

The `GroupInfoView` implementation shown below is a **PROPOSED
implementation** for reference. This view does NOT currently exist in the codebase.

**Views to be created in this story:**
- `GroupInfoView` (lines 434-641)
- `EditGroupInfoView` (Task #2, referenced in Story 3.4)
- `AddParticipantsView` (Task #3, detailed in Story 3.3)

---

**Technical Tasks:**
1. Create GroupInfoView:
   ```swift
   struct GroupInfoView: View {
       let conversation: ConversationEntity

       @Environment(\.modelContext) private var modelContext
       @State private var participants: [UserEntity] = []
       @State private var showEditSheet = false
       @State private var showAddParticipants = false
       @State private var showLeaveConfirmation = false

       private var isAdmin: Bool {
           conversation.adminUserIDs.contains(AuthService.shared.currentUserID)
       }

       var body: some View {
           List {
               Section {
                   VStack(spacing: 16) {
                       // Group photo
                       AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
                           image.resizable().scaledToFill()
                       } placeholder: {
                           ZStack {
                               Circle().fill(Color.gray.opacity(0.3))
                               Image(systemName: "person.3.fill")
                                   .foregroundColor(.gray)
                           }
                       }
                       .frame(width: 120, height: 120)
                       .clipShape(Circle())

                       // Group name
                       Text(conversation.displayName ?? "Unnamed Group")
                           .font(.system(size: 22, weight: .bold))

                       Text("\(conversation.participantIDs.count) participants")
                           .font(.system(size: 16))
                           .foregroundColor(.secondary)

                       if isAdmin {
                           Button("Edit Group Info") {
                               showEditSheet = true
                           }
                           .buttonStyle(.bordered)
                       }
                   }
                   .frame(maxWidth: .infinity)
                   .padding(.vertical)
               }

               Section("Participants") {
                   ForEach(participants) { participant in
                       HStack(spacing: 12) {
                           // Profile picture
                           AsyncImage(url: URL(string: participant.profilePictureURL ?? "")) { image in
                               image.resizable().scaledToFill()
                           } placeholder: {
                               Circle().fill(Color.gray.opacity(0.3))
                           }
                           .frame(width: 44, height: 44)
                           .clipShape(Circle())

                           VStack(alignment: .leading) {
                               Text(participant.displayName)
                                   .font(.system(size: 16, weight: .medium))

                               if conversation.adminUserIDs.contains(participant.id) {
                                   Text("Group Admin")
                                       .font(.system(size: 14))
                                       .foregroundColor(.blue)
                               }
                           }

                           Spacer()

                           if isAdmin && participant.id != AuthService.shared.currentUserID {
                               Button(role: .destructive) {
                                   removeParticipant(participant)
                               } label: {
                                   Image(systemName: "minus.circle.fill")
                                       .foregroundColor(.red)
                               }
                           }
                       }
                   }

                   if isAdmin {
                       Button {
                           showAddParticipants = true
                       } label: {
                           Label("Add Participants", systemImage: "plus.circle.fill")
                       }
                   }
               }

               Section {
                   Button(role: .destructive) {
                       showLeaveConfirmation = true
                   } label: {
                       Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                           .foregroundColor(.red)
                   }
               }
           }
           .navigationTitle("Group Info")
           .navigationBarTitleDisplayMode(.inline)
           .sheet(isPresented: $showEditSheet) {
               EditGroupInfoView(conversation: conversation)
           }
           .sheet(isPresented: $showAddParticipants) {
               AddParticipantsView(conversation: conversation)
           }
           .confirmationDialog("Leave Group?", isPresented: $showLeaveConfirmation) {
               Button("Leave Group", role: .destructive) {
                   Task { await leaveGroup() }
               }
           } message: {
               Text("Are you sure you want to leave this group? You can't undo this action.")
           }
           .task {
               await loadParticipants()
           }
       }

       private func loadParticipants() async {
           // Fetch participant users
           let descriptor = FetchDescriptor<UserEntity>(
               predicate: #Predicate { user in
                   conversation.participantIDs.contains(user.id)
               }
           )

           participants = (try? modelContext.fetch(descriptor)) ?? []
       }

       private func removeParticipant(_ participant: UserEntity) {
           conversation.participantIDs.removeAll { $0 == participant.id }
           conversation.updatedAt = Date()
           conversation.syncStatus = .pending
           try? modelContext.save()

           // Sync to RTDB
           Task.detached {
               try? await ConversationService.shared.syncConversationToRTDB(conversation)

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

       private func leaveGroup() async {
           let currentUserID = AuthService.shared.currentUserID
           let isLastAdmin = conversation.adminUserIDs.count == 1 &&
                             conversation.adminUserIDs.contains(currentUserID)

           // If last admin, must transfer admin rights first
           if isLastAdmin && conversation.participantIDs.count > 1 {
               // Show admin transfer dialog (UI task)
               showAdminTransferDialog = true
               return
           }

           // Remove self from participants
           conversation.participantIDs.removeAll { $0 == currentUserID }
           conversation.adminUserIDs.removeAll { $0 == currentUserID }
           conversation.isArchived = true
           conversation.syncStatus = .pending
           try? modelContext.save()

           // Sync to RTDB
           try? await ConversationService.shared.syncConversationToRTDB(conversation)

           // Send system message
           let systemMessage = MessageEntity(
               id: UUID().uuidString,
               conversationID: conversation.id,
               senderID: "system",
               text: "\(AuthService.shared.currentUser?.displayName ?? "Someone") left the group",
               createdAt: Date(),
               status: .sent,
               syncStatus: .synced,
               isSystemMessage: true
           )
           try? await MessageService.shared.sendMessageToRTDB(systemMessage)
       }
   }
   ```

2. Create EditGroupInfoView sheet for admins
3. Create AddParticipantsView sheet for admins
4. Update MessageThreadView to link to GroupInfoView on navigation bar tap

**References:**
- UX Design Doc Section 3.3 (Group Info Screen)

---

### Story 3.3: Add and Remove Participants
**As a group admin, I want to add and remove participants so I can manage group membership.**

**Acceptance Criteria:**
- [ ] Only group admins can add/remove participants
- [ ] "Add Participants" button opens contact picker
- [ ] Selected users added to group immediately
- [ ] New participants receive group join notification
- [ ] Removed participants see "You were removed from [group name]"
- [ ] Participant changes sync to all group members in real-time
- [ ] Minimum 2 participants enforced (cannot remove if only 2 left)
- [ ] New participants see messages from join time forward only (not historical messages)
- [ ] New participants see system message: "You were added to this group"
- [ ] System messages batched: "Alice added 10 participants" (not 10 separate messages)
- [ ] Minimum 2 participants enforced (group auto-archives if only 1 remains)
- [ ] Typing indicators cleaned up when participant removed
- [ ] App badge count includes unread group messages
- [ ] Offline participant add/remove queued for sync when online

---

⚠️ **IMPORTANT: Proposed Implementation**

The `AddParticipantsView` implementation shown below is a
**PROPOSED implementation** for reference. This view does NOT currently exist.

---

**Technical Tasks:**
1. Create AddParticipantsView:
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
                           if selectedUserIDs.contains(user.id) {
                               selectedUserIDs.remove(user.id)
                           } else {
                               selectedUserIDs.insert(user.id)
                           }
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
               .navigationBarTitleDisplayMode(.inline)
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

       private func loadAvailableUsers() async {
           // Fetch users not already in group
           let descriptor = FetchDescriptor<UserEntity>(
               predicate: #Predicate { user in
                   !conversation.participantIDs.contains(user.id)
               }
           )

           availableUsers = (try? modelContext.fetch(descriptor)) ?? []
       }

       private func addParticipants() {
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
                   // Fetch added user's display name
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

2. Add participant removal logic with minimum enforcement
3. Create system messages for join/leave events
4. Update MessageEntity to support system messages:
   ```swift
   @Model
   final class MessageEntity {
       // ... existing properties ...
       var isSystemMessage: Bool = false // true for "Alice joined", etc.
   }
   ```

5. Render system messages differently in MessageBubbleView (centered, gray text)

**References:**
- PRD Epic 3: Group Chat (Participant Management)

---

### Story 3.4: Edit Group Name and Photo
**As a group admin, I want to edit the group name and photo so I can keep group info up to date.**

**Acceptance Criteria:**
- [ ] Only group admins can edit group info
- [ ] "Edit Group Info" button opens edit sheet
- [ ] User can change group name (1-50 characters)
- [ ] User can upload new group photo via image picker
- [ ] Changes save locally and sync to RTDB
- [ ] All group members see updated info in real-time
- [ ] System message posted: "Alice changed the group name to..."
- [ ] Concurrent edit conflict detection: show toast if another admin changed name
- [ ] Group photo upload shows progress bar (0-100%) with cancel option
- [ ] Large photos (>5MB) compressed before upload
- [ ] Upload failure shows specific error (network, quota, etc.) with retry button

---

⚠️ **IMPORTANT: Proposed Implementation**

The `EditGroupInfoView` implementation shown below is a **PROPOSED
implementation** for reference. This view does NOT currently exist.

---

**Technical Tasks:**
1. Create EditGroupInfoView:
   ```swift
   struct EditGroupInfoView: View {
       let conversation: ConversationEntity

       @Environment(\.dismiss) private var dismiss
       @Environment(\.modelContext) private var modelContext

       @State private var groupName: String
       @State private var groupPhoto: UIImage?
       @State private var showImagePicker = false
       @State private var isUploading = false

       init(conversation: ConversationEntity) {
           self.conversation = conversation
           _groupName = State(initialValue: conversation.displayName ?? "")
       }

       var body: some View {
           NavigationStack {
               Form {
                   Section {
                       HStack {
                           Spacer()

                           Button(action: { showImagePicker = true }) {
                               if let photo = groupPhoto {
                                   Image(uiImage: photo)
                                       .resizable()
                                       .scaledToFill()
                                       .frame(width: 100, height: 100)
                                       .clipShape(Circle())
                               } else {
                                   AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
                                       image.resizable().scaledToFill()
                                   } placeholder: {
                                       ZStack {
                                           Circle().fill(Color.gray.opacity(0.3))
                                           Image(systemName: "camera.fill")
                                               .foregroundColor(.gray)
                                       }
                                   }
                                   .frame(width: 100, height: 100)
                                   .clipShape(Circle())
                               }
                           }

                           Spacer()
                       }

                       TextField("Group Name", text: $groupName)
                           .font(.system(size: 18))

                       Text("\(groupName.count)/50 characters")
                           .font(.system(size: 12))
                           .foregroundColor(.secondary)
                   }
               }
               .navigationTitle("Edit Group Info")
               .navigationBarTitleDisplayMode(.inline)
               .toolbar {
                   ToolbarItem(placement: .cancellationAction) {
                       Button("Cancel") { dismiss() }
                   }

                   ToolbarItem(placement: .confirmationAction) {
                       Button("Save") {
                           Task { await saveChanges() }
                       }
                       .disabled(groupName.isEmpty || groupName.count > 50)
                   }
               }
               .sheet(isPresented: $showImagePicker) {
                   ImagePicker(image: $groupPhoto)
               }
               .overlay {
                   if isUploading {
                       ProgressView("Uploading...")
                           .padding()
                           .background(Color(.systemBackground))
                           .cornerRadius(10)
                           .shadow(radius: 10)
                   }
               }
           }
       }

       private func saveChanges() async {
           let oldName = conversation.displayName

           // Update group name
           conversation.displayName = groupName
           conversation.updatedAt = Date()
           try? modelContext.save()

           // Upload new photo if changed
           if let photo = groupPhoto {
               isUploading = true

               if let url = try? await StorageService.shared.uploadGroupPhoto(
                   photo,
                   groupID: conversation.id
               ) {
                   conversation.groupPhotoURL = url
                   try? modelContext.save()
               }

               isUploading = false
           }

           // Sync to RTDB
           conversation.syncStatus = .pending
           try? modelContext.save()

           Task.detached {
               try? await ConversationService.shared.syncConversationToRTDB(conversation)

               // Post system message if name changed
               if oldName != groupName {
                   let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
                       for: AuthService.shared.currentUserID ?? ""
                   ) ?? "Someone"

                   let systemMessage = MessageEntity(
                       id: UUID().uuidString,
                       conversationID: conversation.id,
                       senderID: "system",
                       text: "\(currentUserDisplayName) changed the group name to \"\(groupName)\"",
                       createdAt: Date(),
                       status: .sent,
                       syncStatus: .synced,
                       isSystemMessage: true
                   )

                   try? await MessageService.shared.sendMessageToRTDB(systemMessage)
               }
           }

           dismiss()
       }
   }
   ```

2. Update StorageService to support group photo uploads
3. Add system message for name changes
4. Update Firestore listener to handle group info updates

**References:**
- Architecture Doc Section 5.3 (Conversation Management)

---

### Story 3.5: Group Typing Indicators
**As a user, I want to see who is typing in a group so I know who is responding.**

**Acceptance Criteria:**
- [ ] Shows "Alice is typing..." for single typer
- [ ] Shows "Alice and Bob are typing..." for 2 typers
- [ ] Shows "Alice, Bob, and 2 others are typing..." for 4+ typers
- [ ] Typing indicator disappears after 3 seconds of inactivity
- [ ] Only shows for active conversation (not in conversation list)

---

⚠️ **IMPORTANT: Proposed Implementation**

The `formatTypingText()` method shown below does NOT currently exist in
`TypingIndicatorService.swift`. This is a new extension method to be implemented.

---

**Technical Tasks:**
1. Update TypingIndicatorService to handle multiple users:
   ```swift
   extension TypingIndicatorService {
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

2. Update MessageThreadView to show formatted typing text
3. Add participant name resolution for typing users

**References:**
- UX Design Doc Section 3.2 (Message Thread - Typing Indicators)

---

### Story 3.6: Group Read Receipts
**As a user, I want to see who read my messages in a group so I know who is up to date.**

**Acceptance Criteria:**
- [ ] Tap message in group shows read receipt sheet
- [ ] Sheet lists all participants with read status
- [ ] Shows "Read" with timestamp for readers
- [ ] Shows "Delivered" for non-readers
- [ ] Only available for user's own sent messages
- [ ] Updates in real-time as participants read

**Technical Tasks:**
1. Add read receipts to MessageEntity:
   ```swift
   @Model
   final class MessageEntity {
       // ... existing properties ...
       var isSystemMessage: Bool = false // true for "Alice joined", etc.
       var readBy: [String: Date] = [:] // userID -> readAt timestamp
   }
   ```

2. Create ReadReceiptsView sheet:
   ```swift
   struct ReadReceiptsView: View {
       let message: MessageEntity
       let participants: [UserEntity]

       var body: some View {
           NavigationStack {
               List {
                   Section("Read") {
                       ForEach(readParticipants) { participant in
                           HStack {
                               AsyncImage(url: URL(string: participant.profilePictureURL ?? "")) { image in
                                   image.resizable().scaledToFill()
                               } placeholder: {
                                   Circle().fill(Color.gray.opacity(0.3))
                               }
                               .frame(width: 36, height: 36)
                               .clipShape(Circle())

                               VStack(alignment: .leading) {
                                   Text(participant.displayName)
                                       .font(.system(size: 16))

                                   if let readAt = message.readBy[participant.id] {
                                       Text(readAt, style: .relative)
                                           .font(.system(size: 14))
                                           .foregroundColor(.secondary)
                                   }
                               }
                           }
                       }
                   }

                   if !unreadParticipants.isEmpty {
                       Section("Delivered") {
                           ForEach(unreadParticipants) { participant in
                               HStack {
                                   AsyncImage(url: URL(string: participant.profilePictureURL ?? "")) { image in
                                       image.resizable().scaledToFill()
                                   } placeholder: {
                                       Circle().fill(Color.gray.opacity(0.3))
                                   }
                                   .frame(width: 36, height: 36)
                                   .clipShape(Circle())

                                   Text(participant.displayName)
                                       .font(.system(size: 16))
                               }
                           }
                       }
                   }
               }
               .navigationTitle("Read By")
               .navigationBarTitleDisplayMode(.inline)
           }
       }

       private var readParticipants: [UserEntity] {
           participants.filter { message.readBy[$0.id] != nil }
       }

       private var unreadParticipants: [UserEntity] {
           participants.filter { message.readBy[$0.id] == nil && $0.id != message.senderID }
       }
   }
   ```

3. Update MessageBubbleView to show read receipt sheet on long press
4. Update MessageService to track read receipts in Firestore
5. Add Firestore listener for read receipt updates

**References:**
- PRD Epic 3: Group Chat (Read Receipts)

---

### Story 3.7: Group Message Notifications
**As a user, I want to receive push notifications when someone sends a message in a group so I stay updated on group conversations.**

**Acceptance Criteria:**
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

**Technical Tasks:**

1. Update Cloud Functions `onMessageCreated` to detect group conversations (extend Story 2.0B)
2. Implement multi-recipient FCM sending for all group participants except sender
3. Add notification grouping by thread-id (conversationID) for message stacking
4. Update iOS AppDelegate to handle group conversation deep links
5. Test notification delivery with 3+ participant groups
6. Deploy updated Cloud Functions to production

**Dev Notes:**

### Cloud Functions Extension (functions/src/index.ts)

**Key Changes from 1:1 Chat (Story 2.0B):**
- Detect `isGroup` flag in RTDB conversation
- Loop through all participantIDs to send FCM (exclude sender)
- Use `sendEachForMulticast` instead of `send` for multiple recipients
- Title format: "{SenderName} in {GroupName}" instead of just sender name
- Add `threadId` to APNS payload for notification stacking

**RTDB Schema for Group Conversations:**
```
/conversations/{conversationID}/
  ├── participantIDs: { "user1": true, "user2": true, "user3": true }
  ├── isGroup: true
  ├── groupName: "Family Group"
```

**FCM Notification Payload Structure (Group):**
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

**Deep Linking Flow:**
1. User taps notification
2. AppDelegate receives userInfo with conversationID
3. Post NotificationCenter event: "OpenConversation"
4. RootView observes event, presents MessageThreadView

**Testing Standards:**

**Unit Tests:**
- [ ] Test notification payload generation for group vs 1:1
- [ ] Test recipient filtering (excludes sender)
- [ ] Test message text truncation at 100 chars
- [ ] Test system message filtering (no notifications)

**Integration Tests:**
- [ ] Test Cloud Function triggers on RTDB message creation
- [ ] Test FCM send to multiple recipients
- [ ] Test deep link navigation to group conversation
- [ ] Test notification stacking (same thread-id)

**Manual Testing:**
- [ ] Create group with 3 users (User A, User B, User C)
- [ ] User A sends message
- [ ] Verify User B and User C receive notification
- [ ] Verify notification title: "User A in {GroupName}"
- [ ] Tap notification on User B's device → opens MessageThreadView
- [ ] User A sends 5 rapid messages
- [ ] Verify notifications stack under single thread on User B's device

**References:**
- Story 2.0B: Cloud Functions FCM Implementation
- Epic 2: One-on-One Chat Infrastructure
- Firebase Cloud Messaging Docs

**Estimated Time:** 45 minutes

**Dependencies:**
- ✅ Story 2.0B (Cloud Functions FCM) - Extends existing function
- ✅ Story 3.1 (Create Group) - Requires group conversations in RTDB
- ✅ Epic 1 (Authentication) - Requires user profiles in Firestore

---

## Dependencies & Prerequisites

### Required Epics:
- [x] Epic 0: Project Scaffolding
- [x] Epic 1: User Authentication
- [x] Epic 2: One-on-One Chat Infrastructure

### Required Services:
- [x] ConversationService with group support
- [x] MessageService with group message delivery
- [x] StorageService for group photo uploads

---

## Testing & Verification

### Verification Checklist:
- [ ] Create group with 3+ participants works
- [ ] Group appears in all participants' conversation lists
- [ ] Group messages deliver to all participants
- [ ] Group info screen shows all participants
- [ ] Add/remove participants works (admin only)
- [ ] Edit group name/photo works (admin only)
- [ ] Leave group removes user from participant list
- [ ] Typing indicators show multiple users correctly
- [ ] Read receipts track who read messages

### Test Procedure:
1. **Group Creation:**
   - User A creates group with User B and User C
   - All users see group in conversation list
   - Send message from User A
   - Verify User B and User C receive message

2. **Participant Management:**
   - User A (admin) adds User D
   - Verify all users see User D in participant list
   - User A removes User D
   - Verify User D sees "You were removed"

3. **Group Editing:**
   - User A changes group name
   - Verify all users see new name
   - User A changes group photo
   - Verify all users see new photo

---

## Success Criteria

**Epic 3 is complete when:**
- ✅ Users can create group conversations with 2+ participants
- ✅ Group info screen shows participants and settings
- ✅ Admins can add/remove participants
- ✅ Admins can edit group name and photo
- ✅ Users can leave groups
- ✅ Typing indicators show multiple users
- ✅ Read receipts show who read messages
- ✅ All group operations sync in real-time

---

## Time Estimates

| Story | Estimated Time |
|-------|---------------|
| 3.1 Create Group Conversation | 60 mins |
| 3.2 Group Info Screen | 50 mins |
| 3.3 Add and Remove Participants | 50 mins |
| 3.4 Edit Group Name and Photo | 35 mins |
| 3.5 Group Typing Indicators | 30 mins |
| 3.6 Group Read Receipts | 45 mins |
| 3.7 Group Message Notifications | 45 mins |
| **Total** | **5-6 hours** |

---

## Implementation Order

**Recommended sequence:**
1. Story 3.1 (Create Group) - Foundation (requires RTDB setup)
2. Story 3.7 (Group Notifications) - Critical path (extends Story 2.0B Cloud Functions)
3. Story 3.2 (Group Info) - Management UI
4. Story 3.3 (Add/Remove Participants) - Core management
5. Story 3.4 (Edit Group Info) - Customization
6. Story 3.5 (Typing Indicators) - Real-time polish (RTDB)
7. Story 3.6 (Read Receipts) - Advanced feature (RTDB)

**Critical Path:** Stories 3.1 → 3.7 must be completed first to enable basic group messaging with notifications.

---

## References

- **SwiftData Implementation Guide**: `docs/swiftdata-implementation-guide.md`
- **Architecture Doc**: `docs/architecture.md` (Section 5: Data Flow)
- **UX Design Doc**: `docs/ux-design.md` (Section 3.3: Group Info)
- **PRD**: `docs/prd.md` (Epic 3: Group Chat)

---

## Post-MVP Enhancements (Deferred)

The following features were identified during Epic 3 planning but deferred to post-MVP to maintain sprint velocity:

### Story 3.8: Mute Group Notifications
**Priority:** P2 (Medium)
**Estimated Time:** 30 minutes

**Features:**
- [ ] User can mute specific groups from Group Info screen
- [ ] Muted groups don't send FCM notifications (Cloud Functions check)
- [ ] Unmute option in Group Info screen
- [ ] Mute duration options (1 hour, 8 hours, 1 day, 1 week, forever)
- [ ] Muted groups show mute icon in ConversationListView
- [ ] Mute status stored in Firestore `/users/{userID}/mutedConversations/{conversationID}`

**Technical Notes:**
- Cloud Functions must check mute status before sending FCM:
  ```typescript
  const mutedDoc = await firestore
    .collection('users')
    .doc(recipientID)
    .collection('mutedConversations')
    .doc(conversationID)
    .get();

  if (mutedDoc.exists && mutedDoc.data()?.mutedUntil > Date.now()) {
    // Skip notification for this recipient
    continue;
  }
  ```

---

### Story 3.9: Notification Grouping & Rich Actions
**Priority:** P3 (Low)
**Estimated Time:** 60 minutes

**Features:**
- [ ] Multiple messages from same group stack into single expandable notification
- [ ] Notification shows: "3 new messages in Family Group"
- [ ] Inline reply from notification (iOS notification actions)
- [ ] Mark as Read action in notification
- [ ] Multi-device notification deduplication (clear on one device = clear on all)

**Technical Notes:**
- Requires iOS Notification Service Extension
- Requires custom notification payload with `collapse_id`
- Requires RTDB tracking of read status per device

---

### Story 3.10: Advanced Group Features
**Priority:** P3 (Low)
**Estimated Time:** 2-3 hours

**Features:**
- [ ] Group invite approval (user consent before joining)
- [ ] Restrict who can send messages (admins only mode)
- [ ] Group description field (shown in Group Info)
- [ ] Pinned messages in groups
- [ ] Group search (find groups by name)
- [ ] Group categories/tags
- [ ] Archive/unarchive groups
- [ ] Group member roles (admin, moderator, member)

---

### Story 3.11: Group Media Gallery
**Priority:** P3 (Low)
**Estimated Time:** 90 minutes

**Features:**
- [ ] Shared media tab in Group Info
- [ ] Grid view of all images/videos sent in group
- [ ] Filter by media type (photos, videos, files, links)
- [ ] Download all media option
- [ ] Delete media from conversation (admins only)

---

### Story 3.12: Group Analytics (Admin Only)
**Priority:** P4 (Nice-to-Have)
**Estimated Time:** 45 minutes

**Features:**
- [ ] Message activity graph (messages per day)
- [ ] Most active members chart
- [ ] Peak messaging hours
- [ ] Group growth over time

---

**Total Post-MVP Scope:** 5-7 hours additional work
**Recommended Phase:** After MVP launch, based on user feedback

---

**Epic Status:** Ready for implementation
**Blockers:** None (depends on Epic 2)
**Risk Level:** Low (extends Epic 2 infrastructure)
