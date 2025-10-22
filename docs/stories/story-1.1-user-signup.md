---
# Story 1.1: User Sign Up with Email/Password

id: STORY-1.1
title: "User Sign Up with Email/Password"
epic: "Epic 1: User Authentication & Profiles"
status: draft
priority: P0  # Critical blocker
estimate: 5  # Story points
assigned_to: null
created_date: "2025-10-20"
sprint_day: 1  # Day 1 of 7-day sprint

---

## Description

**As a** content creator
**I need** to sign up with email, password, and display name
**So that** I can create an account and access Sorted to manage my fan messages

This story implements the complete sign-up flow with Firebase Auth, including email/password authentication, Instagram-style displayName validation with uniqueness enforcement, user profile creation in Firestore, and local SwiftData persistence.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Sign up screen with email, password, confirm password, display name fields
- [ ] Email validation (valid format, not already registered)
- [ ] Password strength requirements (8+ characters)
- [ ] Passwords must match (password == confirm password)
- [ ] **DisplayName Instagram-style validation:**
  - [ ] 3-30 characters (not 1-50)
  - [ ] Alphanumeric + underscore (_) + period (.) only
  - [ ] Cannot start or end with period
  - [ ] No consecutive periods
  - [ ] Real-time uniqueness check (query Firestore `/displayNames/{name}`)
  - [ ] Show availability indicator as user types
- [ ] Loading indicator during sign up
- [ ] Error messages for invalid input or Firebase errors
- [ ] Success: Navigate to main app (conversation list)
- [ ] User profile created in Firestore `/users/{userId}`
- [ ] DisplayName claim created in Firestore `/displayNames/{name}` → `{userId: uid}`
- [ ] UserEntity created in SwiftData
- [ ] **User presence initialized in Realtime Database `/userPresence/{userId}`**

---

## Technical Tasks

**Implementation steps:**

1. **Create Sign Up View** (`Features/Auth/Views/SignUpView.swift`)
   - Email TextField with `.keyboardType(.emailAddress)`
   - Password SecureField
   - Confirm Password SecureField
   - Display Name TextField
   - Sign Up button
   - Link to Login screen ("Already have an account?")
   - **iOS-specific**: Keyboard management with `.focused(_:)` and `@FocusState`
   - **iOS-specific**: `.submitLabel(.next)` for field navigation
   - **iOS-specific**: Safe area awareness with `ScrollView`
   - **iOS-specific**: Accessibility labels and Dynamic Type support

2. **Create Auth ViewModel** (`Features/Auth/ViewModels/AuthViewModel.swift`)
   - `@Published var email: String`
   - `@Published var password: String`
   - `@Published var confirmPassword: String`
   - `@Published var displayName: String`
   - `@Published var isLoading: Bool`
   - `@Published var errorMessage: String?`
   - `func signUp() async throws`
   - Email validation logic (regex)
   - Password strength validation (min 8 characters)
   - Password match validation

3. **Create AuthService** (`Features/Auth/Services/AuthService.swift`)
   - `func createUser(email: String, password: String, displayName: String) async throws -> User`
   - Firebase Auth integration: `Auth.auth().createUser(withEmail:password:)`
   - Create Firestore user document: `/users/{userId}`
   - Create local SwiftData UserEntity
   - Initialize Realtime Database presence tracking

4. **Create User Model** (`Features/Auth/Models/User.swift`)
   - Conforms to `Sendable` for Swift 6 concurrency
   - Properties: `id`, `email`, `displayName`, `photoURL`, `createdAt`

5. **Add Input Validation**
   - Email regex validation: `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}`
   - Password length check (min 8 characters)
   - **Instagram-style displayName validation:**
     - Length: 3-30 characters
     - Regex: `^[a-zA-Z0-9._]+$`
     - Cannot start/end with period: `^[^.].*[^.]$`
     - No consecutive periods: no `..` substring
   - Real-time uniqueness check (debounced, 500ms)

6. **Create DisplayNameService** (`Features/Auth/Services/DisplayNameService.swift`)
   - `func checkAvailability(_ name: String) async throws -> Bool`
   - Query Firestore `/displayNames/{name}` document
   - `func reserveDisplayName(_ name: String, userId: String) async throws`
   - Create document in `/displayNames/{name}` with `{userId: uid}`

7. **Add Presence Tracking** (in `AuthService.swift`)
   - Initialize Realtime Database `/userPresence/{userId}` on signup
   - Set `{status: "online", lastSeen: ServerValue.timestamp()}`

8. **Error Handling**
   - Firebase errors (email already in use, weak password, etc.)
   - DisplayName validation errors (format, availability)
   - Network errors
   - Validation errors

9. **Testing**
   - Unit tests for AuthViewModel validation logic
   - Unit tests for displayName regex patterns
   - Integration test: Sign up flow end-to-end with Firebase Emulator

---

## Technical Specifications

### Files to Create/Modify

```
Features/Auth/Views/SignUpView.swift (create)
Features/Auth/ViewModels/AuthViewModel.swift (create)
Features/Auth/Services/AuthService.swift (create)
Features/Auth/Services/DisplayNameService.swift (create)
Features/Auth/Models/User.swift (create)
```

### Code Examples

**AuthService.swift - createUser() Implementation:**

```swift
/// AuthService.swift
/// Handles Firebase Auth operations for sign up, login, and session management
/// [Source: Epic 1, Story 1.1]

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import SwiftData

final class AuthService {
    private let auth: Auth
    private let firestore: Firestore
    private let database: Database

    init(
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore(),
        database: Database = Database.database()
    ) {
        self.auth = auth
        self.firestore = firestore
        self.database = database
    }

    func createUser(email: String, password: String, displayName: String) async throws -> User {
        // 1. Validate displayName format (client-side)
        guard isValidDisplayName(displayName) else {
            throw AuthError.invalidDisplayName
        }

        // 2. Check displayName availability
        let displayNameService = DisplayNameService()
        let isAvailable = try await displayNameService.checkAvailability(displayName)
        guard isAvailable else {
            throw AuthError.displayNameTaken
        }

        // 3. Create Firebase Auth user
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let uid = authResult.user.uid

        // 4. Reserve displayName in Firestore (for uniqueness)
        try await displayNameService.reserveDisplayName(displayName, userId: uid)

        // 5. Create Firestore user document
        let userData: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "photoURL": "",
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await firestore.collection("users").document(uid).setData(userData)

        // 6. Initialize user presence in Realtime Database
        let presenceRef = database.reference().child("userPresence").child(uid)
        try await presenceRef.setValue([
            "status": "online",
            "lastSeen": ServerValue.timestamp()
        ])

        // 7. Create local SwiftData UserEntity
        let user = User(id: uid, email: email, displayName: displayName, photoURL: nil, createdAt: Date())
        return user
    }

    private func isValidDisplayName(_ name: String) -> Bool {
        guard name.count >= 3 && name.count <= 30 else { return false }
        guard name.range(of: "^[a-zA-Z0-9._]+$", options: .regularExpression) != nil else { return false }
        guard !name.hasPrefix(".") && !name.hasSuffix(".") else { return false }
        guard !name.contains("..") else { return false }
        return true
    }
}
```

**DisplayNameService.swift:**

```swift
/// DisplayNameService.swift
/// Manages displayName uniqueness enforcement via Firestore `/displayNames` collection
/// [Source: Epic 1, Story 1.1]

import Foundation
import FirebaseFirestore

final class DisplayNameService {
    private let db = Firestore.firestore()

    func checkAvailability(_ name: String) async throws -> Bool {
        let doc = try await db.collection("displayNames").document(name).getDocument()
        return !doc.exists
    }

    func reserveDisplayName(_ name: String, userId: String) async throws {
        try await db.collection("displayNames").document(name).setData([
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}
```

**User Model:**

```swift
/// User.swift
/// Swift model representing authenticated user data
/// [Source: Epic 1, Story 1.1]

import Foundation

struct User: Sendable, Codable, Identifiable {
    let id: String  // Firebase Auth UID
    var email: String
    var displayName: String
    var photoURL: String?
    let createdAt: Date

    init(id: String, email: String, displayName: String, photoURL: String? = nil, createdAt: Date) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = createdAt
    }
}
```

### Dependencies

**Required:**
- Epic 0 (Project Scaffolding) must be complete
- Firebase SDK installed and configured
- SwiftData ModelContainer configured in App.swift

**Blocks:**
- Story 1.2 (Login requires Auth infrastructure)
- Story 1.3 (Persistent login requires Keychain)

**External:**
- Firebase project created with Auth, Firestore, Realtime Database enabled
- Firebase Security Rules deployed

---

## Testing & Validation

### Test Procedure

1. **Test Sign Up Form Validation**
   - Enter invalid email → Should show error
   - Enter password < 8 characters → Should show error
   - Enter mismatched passwords → Should show error
   - Enter displayName with invalid characters → Should show error
   - Enter displayName that's taken → Should show "already taken"

2. **Test Sign Up Flow**
   - Fill out valid form
   - Tap "Sign Up" button
   - Should show loading indicator
   - Should navigate to conversation list on success

3. **Verify Firebase Data**
   - Check Firestore `/users/{userId}` document exists
   - Check Firestore `/displayNames/{name}` document exists
   - Check Realtime Database `/userPresence/{userId}` exists
   - Check SwiftData UserEntity created locally

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS Simulator (iPhone 16)
- [ ] Sign up creates user in Firebase Auth
- [ ] User profile created in Firestore
- [ ] DisplayName uniqueness enforced
- [ ] Presence initialized in Realtime Database
- [ ] SwiftData UserEntity persisted locally
- [ ] All form validations work correctly
- [ ] Error states handled gracefully

---

## References

**Architecture Docs:**
- [Source: docs/architecture/technology-stack.md] - Firebase Auth, SwiftData
- [Source: docs/architecture/data-architecture.md] - UserEntity SwiftData model
- [Source: docs/architecture/security-architecture.md] - Keychain, Firebase Security Rules
- [Source: docs/swiftdata-implementation-guide.md] - UserEntity implementation

**PRD Sections:**
- PRD Section 8.1.1: Authentication specifications
- PRD Section 10.1: Firebase Firestore schema (users collection)

**Epic:**
- docs/epics/epic-1-user-authentication-profiles.md

**Related Stories:**
- Story 1.2: User Login (depends on this story)
- Story 1.3: Persistent Login (depends on this story)

---

## Notes & Considerations

### Implementation Notes

**iOS Mobile-Specific Considerations:**

1. **Keyboard Management** (Critical for UX)
   - Use `.focused(_:)` modifier with `@FocusState` to programmatically dismiss keyboard
   - Add `.submitLabel(.next)` to advance through form fields (Email → Password → Confirm → Display Name)
   - Implement `.onSubmit {}` for "Done" keyboard action to submit form
   - Add tap gesture on background to dismiss keyboard

2. **Accessibility (VoiceOver & Dynamic Type)**
   - Add `.accessibilityLabel()` and `.accessibilityHint()` to all input fields
   - Email field: `.accessibilityLabel("Email address")`
   - Password: `.accessibilityLabel("Password")`, `.accessibilityHint("Minimum 8 characters")`
   - Support Dynamic Type with `.font(.body)` instead of hardcoded font sizes
   - Add `.accessibilityIdentifier()` for UI testing (e.g., "emailTextField", "signUpButton")

3. **Safe Area & Layout**
   - Wrap form in `ScrollView` for compatibility with small screens (iPhone SE)
   - Use `.safeAreaInset(edge: .bottom)` for bottom-anchored "Sign Up" button
   - Test on iPhone 14 Pro (Dynamic Island), iPhone SE (small screen), iPad
   - Ensure keyboard doesn't obscure focused input field

4. **Loading States & Feedback**
   - Use native `.alert()` for error messages (iOS standard), not custom toast
   - Add haptic feedback on signup success: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
   - Show inline `.progressView()` in button (replace text with ProgressView), not full-screen modal
   - Disable all inputs during loading to prevent double-submission

5. **Form Validation UX**
   - Real-time inline validation with colored borders (red for invalid, green for valid)
   - Display validation errors below each field in `.font(.caption)`, `.foregroundColor(.red)`
   - Disable "Sign Up" button until all fields valid (`.disabled(!isFormValid)`)
   - Show displayName availability as user types with debounced check (500ms)

6. **Network Handling**
   - Show "Retry" button on network errors with `.alert()` actions
   - Add 30-second timeout for signup request
   - Consider offline state detection using Network framework `NWPathMonitor`
   - Cache form data locally if signup fails (but NEVER cache password)

### Edge Cases

- Email already in use (Firebase Auth error)
- DisplayName already taken (checked before auth creation)
- Network failure during signup (retry logic needed)
- User closes app during signup (should be idempotent)
- DisplayName contains only periods or underscores

### Performance Considerations

- Debounce displayName availability check to avoid excessive Firestore queries
- Use SwiftData for local caching to reduce Firebase reads
- Optimize image compression if adding profile pictures later

### Security Considerations

- NEVER log passwords (use `SecureField` in SwiftUI)
- Store auth tokens in Keychain only (Story 1.3)
- Validate all inputs server-side via Firebase Security Rules
- Use HTTPS only (Firebase SDK enforces this by default)

**Firebase Security Rules (already deployed):**
- DisplayName format validation on server
- Uniqueness enforcement (can't create if exists)
- User can only claim displayName for themselves

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-20
**Last updated:** 2025-10-20
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 1: User Authentication & Profiles
**Story points:** 5
**Priority:** P0 (Critical blocker)

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review
- [ ] **Ready** - Story reviewed and ready for development
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Draft
