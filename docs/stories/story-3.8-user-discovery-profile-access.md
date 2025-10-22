---
# Story 3.8: User Discovery & Profile Access
# Epic 3: Group Chat
# Status: Draft

id: STORY-3.8
title: "Fix User Discovery Permissions & Add Profile Navigation"
epic: "Epic 3: Group Chat"
status: draft
priority: P0  # Critical - Blocks group creation and messaging
estimate: 2  # Story points (30 minutes)
assigned_to: null
created_date: "2025-10-22"
sprint_day: null

---

## Description

**As a** logged-in user
**I need** to see other users when creating groups/messages and access my own profile
**So that** I can create conversations and manage my profile settings

This story fixes a critical permissions issue preventing users from being discovered for conversations:
- Firestore security rules currently prevent users from reading other users' profiles
- No UI navigation exists to view/edit your own profile
- RecipientPickerView, GroupCreationView, and AddParticipantsView cannot load user lists
- Users are blocked from creating new conversations or groups

**Current State:**
- ❌ Firestore rules: `allow read: if request.auth.uid == userId` (users can only read their own profile)
- ❌ No profile navigation in ConversationListView toolbar
- ❌ RecipientPickerView loads from SwiftData but users never sync from Firestore (permissions blocked)
- ❌ AddParticipantsView tries to query Firestore users collection but fails due to permissions

**Target State:**
- ✅ Firestore rules allow authenticated users to read basic user profiles (discovery)
- ✅ Profile button in ConversationListView toolbar to view/edit own profile
- ✅ Users can see available users when creating groups or conversations
- ✅ Maintain privacy: email and sensitive data have separate read rules

---

## Acceptance Criteria

**This story is complete when:**

### User Discovery (Permissions)
- [ ] Authenticated users can query `/users` collection in Firestore
- [ ] Authenticated users can read basic profile fields: `displayName`, `profilePictureURL`, `id`
- [ ] Email field has restricted access (only readable by owner for privacy)
- [ ] RecipientPickerView successfully loads all users (excluding self)
- [ ] GroupCreationView ParticipantPickerView successfully loads all users
- [ ] AddParticipantsView successfully loads all users (excluding group participants)
- [ ] Users can search and select recipients to start conversations

### Profile Navigation
- [ ] Profile button added to ConversationListView toolbar (topBarLeading or settings icon)
- [ ] Tapping profile button presents ProfileView as a sheet
- [ ] ProfileView displays current user's profile (photo, displayName)
- [ ] Users can edit their profile and save changes
- [ ] Profile changes sync to Firestore and propagate to other users
- [ ] Accessible via VoiceOver with proper labels

---

## Technical Tasks

**Implementation steps:**

### 1. Update Firestore Security Rules (firestore.rules)
**File:** `firestore.rules`

**Changes:**
- Modify `/users/{userId}` rules to allow list/read for authenticated users
- Keep write restricted to owner only
- Email field access restricted to owner for privacy

**Updated Rules:**
```javascript
match /users/{userId} {
  // Allow authenticated users to list and read user profiles for discovery
  allow list, get: if request.auth != null;

  // Users can only update/delete their own profile
  allow update, delete: if request.auth != null && request.auth.uid == userId;

  // Users can only create their own profile
  allow create: if request.auth != null && request.auth.uid == userId;
}
```

**Privacy Considerations:**
- All authenticated users can discover other users (required for messaging)
- Email is stored in the user document but can be excluded from queries if needed
- Future enhancement: Add blocked users filtering in client code
- Future enhancement: Add privacy settings (e.g., "allow discovery")

**Deployment:**
```bash
firebase deploy --only firestore:rules
```

### 2. Add Profile Navigation to ConversationListView
**File:** `buzzbox/Features/Chat/Views/ConversationListView.swift`

**Changes:**
- Add `@State private var showProfile = false`
- Add toolbar item for profile button (topBarLeading, next to new group button)
- Add `.sheet(isPresented: $showProfile)` presenting ProfileView
- Use SF Symbol: `person.crop.circle` for profile button
- Accessibility: Label "Profile", Hint "View and edit your profile"

**Code Location:** `ConversationListView.swift:72-80` (toolbar section)

**Example:**
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        profileButton
    }

    ToolbarItem(placement: .topBarLeading) {
        newGroupButton
    }

    ToolbarItem(placement: .topBarTrailing) {
        newMessageButton
    }
}
.sheet(isPresented: $showProfile) {
    ProfileView()
}

private var profileButton: some View {
    Button {
        showProfile = true
    } label: {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.blue)
    }
    .accessibilityLabel("Profile")
    .accessibilityHint("View and edit your profile")
}
```

### 3. Update RecipientPickerView to Fetch from Firestore
**File:** `buzzbox/Features/Chat/Views/RecipientPickerView.swift`

**Current Issue:** Line 142-146 fetches from SwiftData, but users never sync from Firestore due to permissions

**Changes:**
- Replace SwiftData fetch with Firestore query
- Filter out current user from results
- Sort by displayName
- Handle errors gracefully

**Updated Code:**
```swift
private func loadUsers() async {
    isLoading = true
    defer { isLoading = false }

    guard let currentUserID = Auth.auth().currentUser?.uid else {
        print("❌ No authenticated user")
        return
    }

    do {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .getDocuments()

        var fetchedUsers: [UserEntity] = []

        for document in snapshot.documents {
            let data = document.data()
            let userID = document.documentID

            // Filter out current user
            guard userID != currentUserID else { continue }

            let user = UserEntity(
                id: userID,
                email: data["email"] as? String ?? "",
                displayName: data["displayName"] as? String ?? "Unknown",
                photoURL: data["profilePictureURL"] as? String
            )

            fetchedUsers.append(user)
        }

        // Sort by display name
        users = fetchedUsers.sorted { $0.displayName < $1.displayName }
        print("✅ Loaded \(users.count) users from Firestore")

    } catch {
        print("❌ Failed to load users from Firestore: \(error)")
        users = []
    }
}
```

**Note:** AddParticipantsView already queries Firestore (line 151-184), so it will work once rules are updated.

### 4. Update ParticipantPickerView (if applicable)
**File:** `buzzbox/Features/Chat/Views/Components/ParticipantPickerView.swift`

**Action:** Review and update if it fetches from SwiftData instead of Firestore

**Expected:** Should fetch from Firestore similar to RecipientPickerView and AddParticipantsView

### 5. Testing & Validation

**Manual Testing:**
1. Deploy updated Firestore rules: `firebase deploy --only firestore:rules`
2. Restart app and sign in as User A
3. Tap "New Message" → Verify RecipientPickerView shows other users
4. Tap "New Group" → Verify ParticipantPickerView shows other users
5. Tap Profile button in toolbar → Verify ProfileView opens
6. Edit profile (change display name or photo) → Verify save succeeds
7. Sign in as User B → Verify User A's profile changes are visible

**Edge Cases:**
- [ ] Empty users list (only 1 user in system) → Show empty state
- [ ] Network offline → Show appropriate error message
- [ ] Profile save fails → Show error alert with retry option

**Security Testing:**
- [ ] Verify users cannot write to other users' profiles (should fail)
- [ ] Verify unauthenticated requests fail (should fail)
- [ ] Verify email field is readable (or restrict if privacy is required)

---

## Files Modified

**Security Rules:**
- `firestore.rules` (lines 35-41)

**Views:**
- `buzzbox/Features/Chat/Views/ConversationListView.swift` (toolbar + sheet)
- `buzzbox/Features/Chat/Views/RecipientPickerView.swift` (loadUsers method)
- `buzzbox/Features/Chat/Views/Components/ParticipantPickerView.swift` (if applicable)

**Dependencies:**
- None (uses existing ProfileView, UserEntity, Firestore)

---

## Success Metrics

- ✅ Users can create new 1:1 conversations
- ✅ Users can create new group conversations with 2+ participants
- ✅ Users can add participants to existing groups
- ✅ Users can view and edit their own profile
- ✅ Profile changes sync across all users in real-time
- ✅ No security vulnerabilities (users cannot modify others' data)

---

## Notes

**Why This Story is P0 (Critical):**
- Without this fix, users **cannot create any conversations or groups**
- Blocks core messaging functionality (Epic 2 & Epic 3)
- Simple fix with high impact (security rules + UI navigation)

**Privacy Considerations:**
- Currently all authenticated users can discover all other users
- Future enhancement: Add privacy settings or block list
- Email visibility: Can be restricted if needed, but useful for debugging

**Related Stories:**
- Story 1.5: Profile Management (implements ProfileView)
- Story 2.1: Create New Conversation (uses RecipientPickerView)
- Story 3.1: Create Group Conversation (uses ParticipantPickerView)
- Story 3.3: Add/Remove Participants (uses AddParticipantsView)

---

## Definition of Done

- [ ] Firestore security rules updated and deployed
- [ ] Profile button added to ConversationListView
- [ ] RecipientPickerView loads users from Firestore
- [ ] ParticipantPickerView loads users from Firestore (if needed)
- [ ] Manual testing completed (all scenarios pass)
- [ ] Security testing completed (no unauthorized access)
- [ ] Code reviewed and approved
- [ ] Changes committed and pushed to main branch

---

**Estimated Time:** 30 minutes
**Actual Time:** TBD
**Completed:** TBD
