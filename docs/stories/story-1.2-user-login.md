---
# Story 1.2: User Login with Email/Password

id: STORY-1.2
title: "User Login with Email/Password"
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
**I need** to log in with my email and password
**So that** I can access my account and manage my fan messages

This story implements the complete login flow with Firebase Auth, including email/password authentication, auth token storage in iOS Keychain, user data synchronization from Firestore to SwiftData, and navigation to the main app.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Login screen with email and password fields
- [ ] "Forgot Password?" link
- [ ] Loading indicator during login
- [ ] Error messages for invalid credentials or network errors
- [ ] Success: Navigate to main app (conversation list)
- [ ] Auth token stored securely in Keychain
- [ ] User data synced from Firestore to SwiftData
- [ ] Email autofill support with `.textContentType(.username)`
- [ ] Password autofill support with `.textContentType(.password)`
- [ ] Form submission on keyboard "Return" key

---

## Technical Tasks

**Implementation steps:**

1. **Create Login View** (`Features/Auth/Views/LoginView.swift`)
   - Email TextField
   - Password SecureField
   - Login button
   - "Forgot Password?" button
   - Link to Sign Up screen ("Don't have an account?")
   - **iOS-specific**: `.keyboardType(.emailAddress)` for email field
   - **iOS-specific**: `.textContentType(.username)` for iOS autofill
   - **iOS-specific**: `.textContentType(.password)` for iOS Keychain password manager
   - **iOS-specific**: `.onSubmit {}` for form submission on keyboard "Return"
   - **iOS-specific**: Accessibility labels and Dynamic Type support

2. **Add to AuthViewModel** (`Features/Auth/ViewModels/AuthViewModel.swift`)
   - `func login() async throws`
   - `@Published var loginAttemptCount: Int` (for shake animation)
   - Error handling for login failures
   - Loading state management

3. **Add to AuthService** (`Features/Auth/Services/AuthService.swift`)
   - `func signIn(email: String, password: String) async throws -> User`
   - Firebase Auth integration: `Auth.auth().signIn(withEmail:password:)`
   - Fetch user data from Firestore `/users/{userId}`
   - Update local SwiftData UserEntity
   - Store auth token in Keychain via KeychainService

4. **Create KeychainService** (`Core/Services/KeychainService.swift`)
   - `func save(token: String) throws`
   - `func retrieve() -> String?`
   - `func delete() throws`
   - Secure Keychain storage for Firebase auth token
   - Service identifier: `"com.sorted.app"`
   - Account identifier: `"firebase_auth_token"`

5. **Error Handling**
   - Invalid credentials (wrong email/password)
   - User not found
   - Network errors
   - Map Firebase Auth error codes to user-friendly messages

6. **Testing**
   - Unit tests for login validation
   - Integration test: Login flow with Firebase Emulator
   - Test with valid credentials (should succeed)
   - Test with invalid credentials (should show error)
   - Test network failure handling

---

## Technical Specifications

### Files to Create/Modify

```
Features/Auth/Views/LoginView.swift (create)
Features/Auth/ViewModels/AuthViewModel.swift (modify - add login())
Features/Auth/Services/AuthService.swift (modify - add signIn())
Core/Services/KeychainService.swift (create)
```

### Code Examples

**AuthService.swift - signIn() Implementation:**

```swift
/// AuthService.swift
/// Handles Firebase Auth operations for sign up, login, and session management
/// [Source: Epic 1, Story 1.2]

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData

extension AuthService {
    /// Signs in user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: User object with synced data from Firestore
    /// - Throws: AuthError if login fails
    func signIn(email: String, password: String) async throws -> User {
        // 1. Sign in with Firebase Auth
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let uid = authResult.user.uid

        // 2. Get ID token for Keychain storage
        let idToken = try await authResult.user.getIDToken()

        // 3. Store token in Keychain
        let keychainService = KeychainService()
        try keychainService.save(token: idToken)

        // 4. Fetch user data from Firestore
        let userDoc = try await firestore.collection("users").document(uid).getDocument()

        guard let data = userDoc.data() else {
            throw AuthError.userNotFound
        }

        // 5. Parse user data
        let email = data["email"] as? String ?? ""
        let displayName = data["displayName"] as? String ?? ""
        let photoURL = data["photoURL"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        // 6. Create User object
        let user = User(
            id: uid,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            createdAt: createdAt
        )

        // 7. Update local SwiftData UserEntity
        // (Implementation depends on SwiftData ModelContext - see swiftdata-implementation-guide.md)

        return user
    }
}
```

**KeychainService.swift:**

```swift
/// KeychainService.swift
/// Handles secure storage of Firebase auth tokens in iOS Keychain
/// [Source: Epic 1, Story 1.2]

import Foundation
import Security

/// Manages secure storage of authentication tokens in iOS Keychain
final class KeychainService {
    private let service = "com.sorted.app"
    private let account = "firebase_auth_token"

    /// Saves auth token to Keychain
    /// - Parameter token: Firebase ID token to store securely
    /// - Throws: KeychainError.saveFailed if save operation fails
    func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete old token first
        SecItemDelete(query as CFDictionary)

        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }

    /// Retrieves auth token from Keychain
    /// - Returns: Firebase ID token if found, nil otherwise
    func retrieve() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Deletes auth token from Keychain
    /// - Throws: KeychainError.deleteFailed if delete operation fails
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save authentication token securely."
        case .deleteFailed:
            return "Failed to delete authentication token."
        }
    }
}
```

**LoginView.swift:**

```swift
/// LoginView.swift
/// Login screen with email/password authentication
/// [Source: Epic 1, Story 1.2]

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo or branding
                    Image(systemName: "envelope.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.top, 40)

                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Log in to your account")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    // Email TextField
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .accessibilityLabel("Email address")
                        .accessibilityIdentifier("emailTextField")
                        .padding(.horizontal)

                    // Password SecureField
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("passwordTextField")
                        .padding(.horizontal)
                        .onSubmit {
                            Task { await viewModel.login() }
                        }

                    // Forgot Password link
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            // Navigate to ForgotPasswordView (Story 1.4)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)

                    // Login Button
                    Button(action: {
                        Task { await viewModel.login() }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 20, height: 20)
                                Text("Logging in...")
                            } else {
                                Text("Log In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading || !isFormValid)
                    .padding(.horizontal)
                    .accessibilityIdentifier("loginButton")

                    // Sign Up link
                    HStack {
                        Text("Don't have an account?")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("Sign Up") {
                            // Navigate to SignUpView
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert("Login Failed", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // Success haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty
    }
}
```

### Dependencies

**Required:**
- Story 1.1 (User Sign Up) must be complete (AuthService, AuthViewModel foundations)
- Firebase SDK installed and configured
- SwiftData ModelContainer configured in App.swift

**Blocks:**
- Story 1.3 (Persistent Login uses Keychain)
- Story 1.6 (Logout uses Keychain deletion)

**External:**
- Firebase project created with Auth enabled
- Firebase Security Rules deployed

---

## Testing & Validation

### Test Procedure

1. **Test Login Form Validation**
   - Leave email empty → Login button should be disabled
   - Leave password empty → Login button should be disabled
   - Fill both fields → Login button should be enabled

2. **Test Login Flow**
   - Enter valid credentials (created in Story 1.1)
   - Tap "Log In" button
   - Should show loading indicator
   - Should navigate to conversation list on success

3. **Test Error Handling**
   - Enter wrong password → Should show error alert
   - Enter unregistered email → Should show error alert
   - Test with airplane mode → Should show network error

4. **Verify Keychain Storage**
   - After successful login, verify auth token stored in Keychain
   - Use Xcode debugger to check KeychainService.retrieve() returns token

5. **Test iOS Features**
   - Test email autofill with saved credentials
   - Test password autofill from iOS Keychain
   - Submit form with keyboard "Return" key

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS Simulator (iPhone 16)
- [ ] Login with valid credentials succeeds
- [ ] Auth token stored in Keychain
- [ ] User data synced from Firestore to SwiftData
- [ ] Invalid credentials show appropriate error
- [ ] Network errors handled gracefully
- [ ] iOS autofill integration works
- [ ] Accessibility labels present and correct

---

## References

**Architecture Docs:**
- [Source: docs/architecture/technology-stack.md] - Firebase Auth, iOS Keychain
- [Source: docs/architecture/data-architecture.md] - UserEntity SwiftData model
- [Source: docs/architecture/security-architecture.md] - Keychain security patterns
- [Source: docs/swiftdata-implementation-guide.md] - UserEntity implementation

**PRD Sections:**
- PRD Section 8.1.1: Authentication specifications
- PRD Section 10.1: Firebase Firestore schema (users collection)

**Epic:**
- docs/epics/epic-1-user-authentication-profiles.md

**Related Stories:**
- Story 1.1: User Sign Up (prerequisite)
- Story 1.3: Persistent Login (uses Keychain from this story)
- Story 1.4: Password Reset (accessed from "Forgot Password?" link)
- Story 1.6: Logout (uses Keychain deletion from this story)

---

## Notes & Considerations

### Implementation Notes

**iOS Mobile-Specific Considerations:**

1. **Biometric Authentication Preparation**
   - Structure login flow to support Face ID/Touch ID in future enhancement
   - Store email in UserDefaults for autofill (security: NEVER store password)
   - Use `.textContentType(.username)` and `.textContentType(.password)` for iOS autofill
   - Foundation laid for biometric auth in future epic

2. **Keyboard Optimization**
   - Email field: `.keyboardType(.emailAddress)`, `.textContentType(.username)`, `.autocapitalization(.none)`
   - Password field: `.textContentType(.password)` for iOS Keychain password manager integration
   - Submit form on keyboard "Return" key:
     ```swift
     .onSubmit { Task { await viewModel.login() } }
     ```
   - Use `@FocusState` to manage field focus and keyboard dismissal

3. **Error Presentation**
   - Use iOS native `.alert()` for login errors (not custom banners)
   - Provide actionable error messages: Include "Forgot Password?" link in alert for wrong password error
   - Shake animation on failed login (iOS standard pattern):
     ```swift
     .modifier(ShakeEffect(shakes: viewModel.loginAttemptCount))
     ```

4. **Loading & Progress**
   - Inline loading indicator in Login button (replace text with `ProgressView()`)
   - Disable all inputs during login to prevent double-submission: `.disabled(viewModel.isLoading)`
   - Haptic feedback on success:
     ```swift
     UINotificationFeedbackGenerator().notificationOccurred(.success)
     ```
   - Haptic feedback on failure:
     ```swift
     UINotificationFeedbackGenerator().notificationOccurred(.error)
     ```

5. **Accessibility**
   - Announce login status changes to VoiceOver:
     ```swift
     .onChange(of: viewModel.isLoading) { _, isLoading in
         if isLoading {
             UIAccessibility.post(notification: .announcement, argument: "Logging in")
         }
     }
     ```
   - Ensure minimum 44x44pt touch targets for all buttons
   - Support reduced motion (disable shake animation if `UIAccessibility.isReduceMotionEnabled`)

6. **Keychain Security**
   - Keychain access group configured correctly in entitlements (for future Keychain Sharing)
   - Token encrypted by iOS automatically (Keychain handles encryption)
   - Token accessible only when device unlocked (use `kSecAttrAccessibleWhenUnlocked`)

### Edge Cases

- Email registered but email verification not complete (Firebase handles this)
- User deletes account while still logged in on device
- Keychain access denied (device lock/jailbreak detection)
- Firebase Auth session expired during login attempt
- Network failure mid-login (show retry option)

### Performance Considerations

- Login should complete in < 2 seconds on good network
- Cache user profile data in SwiftData to avoid repeated Firestore fetches
- Use `.task(priority: .userInitiated)` for login operation (high priority)

### Security Considerations

- NEVER log passwords (use `SecureField` in SwiftUI)
- Store auth tokens in Keychain only (iOS encrypts Keychain by default)
- Validate all inputs client-side AND server-side
- Use HTTPS only (Firebase SDK enforces this by default)
- Token refresh handled by Firebase SDK automatically

**Firebase Security Rules (already deployed):**
- User can only read their own `/users/{userId}` document
- Auth token verified server-side by Firebase

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
