# Epic 1: User Authentication & Profiles

**Phase:** MVP (Day 1 - 24 Hours)
**Priority:** P0 (Blocker)
**Estimated Time:** 2-3 hours
**Epic Owner:** iOS Development Team
**Dependencies:** Epic 0 (Project Scaffolding) must be complete

---

## Overview

Implement complete user authentication system using Firebase Auth with email/password, including sign up, login, password reset, persistent sessions via Keychain, and basic user profile management. This epic establishes the foundation for all user-specific features in the Sorted app.

---

## What This Epic Delivers

- ✅ Email/password authentication via Firebase Auth
- ✅ Sign up flow with email validation
- ✅ **Instagram-style displayName validation (3-30 chars, alphanumeric + _ + .)**
- ✅ **DisplayName uniqueness enforcement (Firestore + Security Rules)**
- ✅ Login flow with error handling
- ✅ Password reset via email
- ✅ Persistent sessions (auto-login after app restart)
- ✅ Secure token storage in iOS Keychain
- ✅ User profile creation in Firestore (static data)
- ✅ **User presence tracking in Realtime Database**
- ✅ Profile picture upload to Firebase Storage
- ✅ Display name management with uniqueness validation
- ✅ Logout functionality with local data cleanup
- ✅ **Firebase Security Rules deployed (Firestore, Realtime DB, Storage)**

**🔧 MCP Tools Available:** Firebase MCP and XcodeBuild MCP can automate testing and deployment throughout this epic.

---

### iOS-Specific Implementation Notes

**This is a native iOS mobile app** - all implementation must follow iOS Human Interface Guidelines and mobile-first patterns:

- ✅ **Keyboard Management:** All text input screens handle keyboard show/hide with proper dismiss gestures
- ✅ **Safe Area Awareness:** All layouts respect safe areas (notch, Dynamic Island, home indicator)
- ✅ **Accessibility First:** VoiceOver labels, Dynamic Type support, reduced motion, accessibility identifiers
- ✅ **Haptic Feedback:** Use iOS haptics for success/error states (UINotificationFeedbackGenerator)
- ✅ **Native Components:** Use SwiftUI native components (`.alert()`, `.sheet()`, `.confirmationDialog()`)
- ✅ **Network Awareness:** Handle offline states, loading indicators, timeouts, network reachability
- ✅ **Photo Permissions:** Request permissions gracefully with Info.plist descriptions, handle denials
- ✅ **Memory Management:** Optimize image caching for mobile constraints (Kingfisher configuration)
- ✅ **Touch Targets:** Minimum 44x44pt for all interactive elements
- ✅ **Loading States:** Use native iOS patterns (skeleton screens, inline progress, pull-to-refresh)

---

## User Stories

### Story 1.1: User Sign Up with Email/Password
**As a content creator, I can sign up with email/password so I can create an account and access Sorted.**

**Acceptance Criteria:**
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

**Technical Tasks:**
1. Create `SignUpView.swift` in `Features/Auth/Views/`
   - Email TextField with keyboard type `.emailAddress`
   - Password SecureField
   - Confirm Password SecureField
   - Display Name TextField
   - Sign Up button
   - Link to Login screen ("Already have an account?")
2. Create `AuthViewModel.swift` in `Features/Auth/ViewModels/`
   - `@Published var email: String`
   - `@Published var password: String`
   - `@Published var confirmPassword: String`
   - `@Published var displayName: String`
   - `@Published var isLoading: Bool`
   - `@Published var errorMessage: String?`
   - `func signUp() async throws`
   - Email validation logic
   - Password strength validation
3. Create `AuthService.swift` in `Features/Auth/Services/`
   - `func createUser(email: String, password: String, displayName: String) async throws -> User`
   - Firebase Auth integration: `Auth.auth().createUser(withEmail:password:)`
   - Create Firestore user document: `/users/{userId}`
   - Create local SwiftData UserEntity
4. Create `User` model in `Features/Auth/Models/`
   - Conforms to `Sendable` for Swift 6 concurrency
   - Properties: `id`, `email`, `displayName`, `photoURL`, `createdAt`
5. Add input validation:
   - Email regex validation
   - Password length check (min 8 characters)
   - **Instagram-style displayName validation:**
     - Length: 3-30 characters
     - Regex: `^[a-zA-Z0-9._]+$`
     - Cannot start/end with period: `^[^.].*[^.]$`
     - No consecutive periods: no `..` substring
   - Real-time uniqueness check (debounced, 500ms)
6. Create `DisplayNameService.swift` in `Features/Auth/Services/`
   - `func checkAvailability(_ name: String) async throws -> Bool`
   - Query Firestore `/displayNames/{name}` document
   - `func reserveDisplayName(_ name: String, userId: String) async throws`
   - Create document in `/displayNames/{name}` with `{userId: uid}`
7. Add presence tracking in `AuthService.swift`:
   - Initialize Realtime Database `/userPresence/{userId}` on signup
   - Set `{status: "online", lastSeen: ServerValue.timestamp()}`
8. Error handling:
   - Firebase errors (email already in use, weak password, etc.)
   - DisplayName validation errors (format, availability)
   - Network errors
   - Validation errors
9. Testing:
   - Unit tests for AuthViewModel validation logic
   - Unit tests for displayName regex patterns
   - Integration test: Sign up flow end-to-end with Firebase Emulator
   - **MCP Tool:** Use Firebase MCP to test with emulator: `firebase emulators:start`

**iOS Mobile Considerations:**
1. **Keyboard Management**
   - Use `.focused(_:)` modifier with `@FocusState` to programmatically dismiss keyboard
   - Add `.submitLabel(.next)` to advance through form fields (Email → Password → Confirm → Display Name)
   - Implement `.onSubmit {}` for "Done" keyboard action to submit form
   - Add tap gesture on background to dismiss keyboard:
     ```swift
     .onTapGesture {
         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
     }
     ```

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
   - Add haptic feedback on signup success:
     ```swift
     UINotificationFeedbackGenerator().notificationOccurred(.success)
     ```
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

**Firebase Integration:**
```swift
// In AuthService.swift
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
    let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
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
    try await Firestore.firestore().collection("users").document(uid).setData(userData)

    // 6. Initialize user presence in Realtime Database
    let presenceRef = Database.database().reference().child("userPresence").child(uid)
    try await presenceRef.setValue([
        "status": "online",
        "lastSeen": ServerValue.timestamp()
    ])

    // 7. Create local SwiftData UserEntity
    let user = User(id: uid, email: email, displayName: displayName, photoURL: nil, createdAt: Date())
    return user
}

func isValidDisplayName(_ name: String) -> Bool {
    guard name.count >= 3 && name.count <= 30 else { return false }
    guard name.range(of: "^[a-zA-Z0-9._]+$", options: .regularExpression) != nil else { return false }
    guard !name.hasPrefix(".") && !name.hasSuffix(".") else { return false }
    guard !name.contains("..") else { return false }
    return true
}
```

**DisplayNameService.swift:**
```swift
import FirebaseFirestore

class DisplayNameService {
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

**Security Enforcement:**
Firebase Security Rules (already deployed) enforce:
- DisplayName format validation on server
- Uniqueness enforcement (can't create if exists)
- User can only claim displayName for themselves

**UI Flow:**
```
[Sign Up Screen]
  ↓
[Enter Email, Password, Display Name]
  ↓
[Tap "Sign Up" Button]
  ↓
[Validate Input] → [Show Errors if Invalid]
  ↓
[Call AuthViewModel.signUp()]
  ↓
[AuthService.createUser()] → [Create Firebase Auth User]
  ↓
[Create Firestore User Document]
  ↓
[Create SwiftData UserEntity]
  ↓
[Store Auth Token in Keychain]
  ↓
[Navigate to Conversation List]
```

**Time Estimate:** 1-1.5 hours

---

### Story 1.2: User Login with Email/Password
**As a content creator, I can log in with my email/password so I can access my account and messages.**

**Acceptance Criteria:**
- [ ] Login screen with email and password fields
- [ ] "Forgot Password?" link
- [ ] Loading indicator during login
- [ ] Error messages for invalid credentials or network errors
- [ ] Success: Navigate to main app (conversation list)
- [ ] Auth token stored securely in Keychain
- [ ] User data synced from Firestore to SwiftData

**Technical Tasks:**
1. Create `LoginView.swift` in `Features/Auth/Views/`
   - Email TextField
   - Password SecureField
   - Login button
   - "Forgot Password?" button
   - Link to Sign Up screen ("Don't have an account?")
2. Add to `AuthViewModel.swift`:
   - `func login() async throws`
   - Error handling for login failures
3. Add to `AuthService.swift`:
   - `func signIn(email: String, password: String) async throws -> User`
   - Firebase Auth integration: `Auth.auth().signIn(withEmail:password:)`
   - Fetch user data from Firestore
   - Update local SwiftData UserEntity
4. Create `KeychainService.swift` in `Core/Services/`
   - `func save(token: String) throws`
   - `func retrieve() -> String?`
   - `func delete() throws`
   - Secure Keychain storage for Firebase auth token
5. Error handling:
   - Invalid credentials (wrong email/password)
   - User not found
   - Network errors
6. Testing:
   - Unit tests for login validation
   - Integration test: Login flow with Firebase Emulator

**iOS Mobile Considerations:**
1. **Biometric Authentication Preparation**
   - Structure login flow to support Face ID/Touch ID in future enhancement
   - Store email in UserDefaults for autofill (security: NEVER store password)
   - Use `.textContentType(.username)` and `.textContentType(.password)` for iOS autofill

2. **Keyboard Optimization**
   - Email field: `.keyboardType(.emailAddress)`, `.textContentType(.username)`, `.autocapitalization(.none)`
   - Password field: `.textContentType(.password)` for iOS Keychain password manager integration
   - Submit form on keyboard "Return" key:
     ```swift
     .onSubmit { Task { await viewModel.login() } }
     ```

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
   - Haptic feedback on success (`UINotificationFeedbackGenerator().notificationOccurred(.success)`)
   - Haptic feedback on failure (`UINotificationFeedbackGenerator().notificationOccurred(.error)`)

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

**Keychain Integration:**
```swift
// In KeychainService.swift
import Security

class KeychainService {
    private let service = "com.sorted.app"
    private let account = "firebase_auth_token"

    func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary) // Delete old token
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }

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

enum KeychainError: Error {
    case saveFailed
    case deleteFailed
}
```

**Time Estimate:** 45 mins - 1 hour

---

### Story 1.3: Persistent Login (Auto-Login on App Launch)
**As a content creator, I stay logged in after closing the app so I don't have to log in every time.**

**Acceptance Criteria:**
- [ ] On app launch, check for valid auth token in Keychain
- [ ] If valid token exists, auto-login and navigate to conversation list
- [ ] If no token or invalid token, show login screen
- [ ] Silent refresh of Firebase auth token if needed
- [ ] User data synced from Firestore on auto-login

**Technical Tasks:**
1. Create `RootView.swift` in `App/`
   - Initial loading state
   - Check for auth token on appear
   - Conditionally show LoginView or ConversationListView
2. Add to `AuthViewModel.swift`:
   - `@Published var isAuthenticated: Bool`
   - `func checkAuthStatus() async`
   - Auto-login logic
3. Add to `AuthService.swift`:
   - `func autoLogin() async throws -> User?`
   - Check Keychain for token
   - Verify token with Firebase: `Auth.auth().currentUser`
   - Fetch user data from Firestore
4. Update `SortedApp.swift`:
   - Use `RootView` as initial view instead of hardcoded ContentView
5. Testing:
   - Test app launch with valid token (should auto-login)
   - Test app launch with no token (should show login)
   - Test app launch with expired token (should show login)

**iOS Mobile Considerations:**
1. **App Lifecycle Management**
   - Use `@Environment(\.scenePhase)` to detect app foreground/background transitions
   - Refresh auth token when app returns to foreground if > 1 hour in background:
     ```swift
     .onChange(of: scenePhase) { _, newPhase in
         if newPhase == .active {
             Task { await viewModel.refreshAuthIfNeeded() }
         }
     }
     ```
   - Handle cold start vs warm start differently (different loading animations)

2. **Splash Screen / Loading State**
   - Show branded launch screen during auth check, not blank `ProgressView()`
   - Use `.task { await viewModel.checkAuthStatus() }` on RootView for async auth check
   - Add timeout for auth check (max 10 seconds), fallback to login screen if timeout
   - Show subtle loading indicator (not full-screen spinner)

3. **Security Considerations**
   - Add privacy overlay when app backgrounds (prevent screenshots showing sensitive data)
   - Optional: Lock app if backgrounded > 5 minutes (require re-authentication)
   - Verify Keychain access group configured correctly in entitlements
   - Clear auth token from memory when app terminates

4. **Performance**
   - Auth check must complete in < 2 seconds for good UX
   - Cache user profile data in SwiftData to avoid Firestore fetch on every launch
   - Use `.task(priority: .userInitiated)` for auth check (high priority)
   - Preload conversation list during auth check to reduce perceived latency

**RootView Implementation:**
```swift
import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isLoading {
                ProgressView("Loading...")
            } else if authViewModel.isAuthenticated {
                ConversationListView()
            } else {
                LoginView()
            }
        }
        .task {
            await authViewModel.checkAuthStatus()
        }
    }
}
```

**Time Estimate:** 30 mins

---

### Story 1.4: Password Reset Flow
**As a content creator, I can reset my password via email if I forget it.**

**Acceptance Criteria:**
- [ ] "Forgot Password?" button on login screen
- [ ] Password reset screen with email input
- [ ] Send reset email button
- [ ] Loading indicator during email send
- [ ] Success message: "Reset email sent, check your inbox"
- [ ] Error handling for invalid email or network errors
- [ ] Navigate back to login after success

**Technical Tasks:**
1. Create `ForgotPasswordView.swift` in `Features/Auth/Views/`
   - Email TextField
   - Send Reset Email button
   - Back to Login button
2. Add to `AuthViewModel.swift`:
   - `func sendPasswordReset(email: String) async throws`
3. Add to `AuthService.swift`:
   - `func resetPassword(email: String) async throws`
   - Firebase Auth: `Auth.auth().sendPasswordReset(withEmail:)`
4. Error handling:
   - Invalid email format
   - User not found
   - Network errors
5. Testing:
   - Unit test for email validation
   - Manual test: Receive reset email in inbox

**iOS Mobile Considerations:**
1. **Email Input UX**
   - Autofill email from login screen if user navigated from "Forgot Password?" button
   - `.keyboardType(.emailAddress)`, `.textContentType(.emailAddress)`, `.autocapitalization(.none)`
   - Real-time email validation with visual feedback (green checkmark for valid, red X for invalid)

2. **Success State**
   - Use native `.alert()` with "Check your email" title and descriptive message
   - Add haptic success feedback:
     ```swift
     UINotificationFeedbackGenerator().notificationOccurred(.success)
     ```
   - Auto-dismiss to login screen after 3 seconds OR when user taps "OK" button

3. **Accessibility**
   - VoiceOver announcement after email sent:
     ```swift
     UIAccessibility.post(notification: .announcement, argument: "Password reset email sent to \(email)")
     ```
   - Ensure "Back to Login" button is accessible with proper label

4. **Error Handling**
   - For security, don't reveal if email exists: Show generic "If this email is registered, you'll receive a reset link"
   - Network timeout handling (30s max) with retry option
   - Show actionable error for invalid email format

**Time Estimate:** 30 mins

---

### Story 1.5: User Profile Management (Display Name & Photo)
**As a content creator, I can set my display name and profile picture so others can identify me.**

**Acceptance Criteria:**
- [ ] Profile settings screen accessible from main app
- [ ] Display name field (editable with validation)
- [ ] **DisplayName change validates uniqueness before saving**
- [ ] **Release old displayName claim in `/displayNames/` collection**
- [ ] Profile picture (tap to change)
- [ ] Image picker for selecting profile photo
- [ ] Upload progress indicator
- [ ] Save button
- [ ] Success message after save
- [ ] Profile updates sync to Firestore
- [ ] Profile updates sync to local SwiftData UserEntity
- [ ] **User presence updated in Realtime Database on profile changes**

**Technical Tasks:**
1. Create `ProfileView.swift` in `Features/Settings/Views/`
   - AsyncImage showing current profile picture
   - Display name TextField
   - "Change Photo" button
   - Save button
2. Create `ProfileViewModel.swift` in `Features/Settings/ViewModels/`
   - `@Published var displayName: String`
   - `@Published var photoURL: URL?`
   - `@Published var isUploading: Bool`
   - `func updateProfile() async throws`
   - `func uploadProfileImage(_ image: UIImage) async throws -> URL`
3. Add to `AuthService.swift`:
   - `func updateUserProfile(displayName: String?, photoURL: URL?) async throws`
   - **If displayName changed:**
     - Check availability via DisplayNameService
     - Release old claim from `/displayNames/{oldName}`
     - Reserve new claim in `/displayNames/{newName}`
   - Update Firestore user document
   - Update local SwiftData UserEntity
   - **Update Realtime Database presence** (optional: add displayName for quick lookup)
4. Create `StorageService.swift` in `Core/Services/`
   - `func uploadImage(_ image: UIImage, path: String) async throws -> URL`
   - Firebase Storage upload to `/profile_pictures/{userId}/{filename}`
   - Image compression before upload (0.7 quality, max 5MB)
   - Security: Storage Rules enforce max size & ownership
5. Image picker integration:
   - Use `PHPickerViewController` wrapped in SwiftUI
   - Or use `PhotosPicker` (iOS 16+)
6. Testing:
   - Unit tests for profile update logic
   - Unit tests for displayName change flow (release + reserve)
   - Integration test: Upload image to Firebase Storage
   - **MCP Tool:** Use XcodeBuild MCP to run tests: `swift test`

**iOS Mobile Considerations:**
1. **Photo Picker Integration (Critical)**
   - **Required:** Add Photo Library permission to Info.plist:
     ```xml
     <key>NSPhotoLibraryUsageDescription</key>
     <string>We need access to your photos to set your profile picture.</string>
     ```
   - Use `PhotosPicker` (iOS 16+) instead of UIKit's `PHPickerViewController`:
     ```swift
     PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
         Label("Change Photo", systemImage: "photo")
     }
     ```
   - Handle permission denial gracefully: Show `.alert()` directing user to Settings app
   - Optional: Add camera permission for taking new photo

2. **Image Handling**
   - Compress images on-device before upload (reduce cellular data usage):
     - Max dimension: 2048x2048 pixels
     - Quality: 85% JPEG compression
     - Target size: < 500KB per image
   - Show upload progress indicator using `StorageService` progress callback
   - Allow cancellation of upload (stop Firebase upload task)
   - Image cropping: Use `.aspectRatio(contentMode: .fill)` + `.frame()` + `.clipShape(Circle())`

3. **Loading States**
   - Show skeleton loader for profile picture while downloading from Firebase
   - Kingfisher loading: Use `ActivityIndicatorView` in `.placeholder { }` closure
   - Disable "Save" button during upload: `.disabled(viewModel.isUploading)`
   - Show upload progress percentage: "Uploading... 47%"

4. **Form UX**
   - DisplayName field: Same validation as signup (real-time availability check with debounce)
   - Show "saving..." feedback in button text during save operation
   - Haptic feedback on save success (`UINotificationFeedbackGenerator().notificationOccurred(.success)`)
   - Optimistic UI: Update profile picture immediately in UI, rollback on failure

5. **Accessibility**
   - Profile picture: `.accessibilityLabel("Profile picture")`, `.accessibilityHint("Double tap to change")`
   - VoiceOver: Announce upload progress percentage changes
   - Support Dynamic Type for all text (displayName, labels)
   - High contrast mode support for validation indicators

6. **Memory Management**
   - Kingfisher automatically caches images (disk + memory)
   - Configure cache limits in app initialization:
     ```swift
     KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024 // 50MB
     KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024 // 200MB
     ```
   - Clear cached profile pictures on logout:
     ```swift
     KingfisherManager.shared.cache.clearCache()
     ```

**Firebase Storage Upload & URL Handling:**
```swift
// In StorageService.swift
import FirebaseStorage
import UIKit

/// Handles Firebase Storage operations for profile pictures and media
class StorageService {
    private let storage = Storage.storage()

    /// Upload image to Firebase Storage and return publicly accessible download URL
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - path: Storage path (e.g., "profile_pictures/{userId}/profile.jpg")
    /// - Returns: HTTPS download URL (not gs:// reference URL)
    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        // 1. Compress image (0.7 quality, max ~5MB after compression)
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.imageCompressionFailed
        }

        // 2. Validate file size (5MB max enforced by Storage Rules)
        let maxSize = 5 * 1024 * 1024 // 5MB
        guard imageData.count <= maxSize else {
            throw StorageError.fileTooLarge
        }

        // 3. Create storage reference
        let storageRef = storage.reference().child(path)

        // 4. Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year

        let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // 5. CRITICAL: Get download URL (HTTPS, not gs://)
        // This URL is what we store in Firestore and use with Kingfisher
        let downloadURL = try await storageRef.downloadURL()

        // 6. Verify URL is HTTPS (required for Kingfisher & AsyncImage)
        guard downloadURL.scheme == "https" else {
            throw StorageError.invalidDownloadURL
        }

        return downloadURL
    }

    /// Delete image from Firebase Storage
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
}

enum StorageError: Error, LocalizedError {
    case imageCompressionFailed
    case fileTooLarge
    case invalidDownloadURL

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different image."
        case .fileTooLarge:
            return "Image is too large. Maximum size is 5MB."
        case .invalidDownloadURL:
            return "Failed to get valid download URL from Firebase Storage."
        }
    }
}
```

**CRITICAL: URL Format for Display**
Firebase Storage returns an HTTPS download URL like:
```
https://firebasestorage.googleapis.com/v0/b/sorted-d3844.appspot.com/o/profile_pictures%2F{userId}%2Fprofile.jpg?alt=media&token=...
```

✅ **This URL works with:**
- Kingfisher's `KFImage`
- SwiftUI's `AsyncImage`
- Any standard image loading library

❌ **Do NOT use gs:// reference URLs for display** (e.g., `gs://bucket/path`)
- These require Firebase SDK to resolve
- Cannot be used directly with image loading libraries

**Profile Picture Display with Kingfisher (Recommended):**
```swift
// In ProfileView.swift
import SwiftUI
import Kingfisher
import ActivityIndicatorView // For loading states

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture with Kingfisher + Loading Indicator
            ZStack {
                if let photoURL = viewModel.photoURL {
                    KFImage(photoURL)
                        .placeholder {
                            // Show loading indicator while image downloads
                            ActivityIndicatorView(isVisible: .constant(true), type: .gradient([.blue, .purple]))
                                .frame(width: 120, height: 120)
                        }
                        .retry(maxCount: 3, interval: .seconds(2)) // Retry failed loads
                        .cacheOriginalImage() // Cache for offline access
                        .fade(duration: 0.25) // Smooth fade-in
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                } else {
                    // Default placeholder
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }

                // Upload progress overlay
                if viewModel.isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)

                    ActivityIndicatorView(
                        isVisible: $viewModel.isUploading,
                        type: .arcs(count: 3, lineWidth: 2)
                    )
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                }
            }
            .onTapGesture {
                viewModel.showImagePicker = true
            }

            // Display Name TextField
            TextField("Username", text: $viewModel.displayName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disabled(viewModel.isLoading)

            // Availability indicator
            if viewModel.isCheckingAvailability {
                HStack {
                    ActivityIndicatorView(
                        isVisible: $viewModel.isCheckingAvailability,
                        type: .default
                    )
                    .frame(width: 20, height: 20)
                    Text("Checking availability...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if !viewModel.displayNameError.isEmpty {
                Text(viewModel.displayNameError)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if viewModel.displayNameAvailable {
                Label("Available", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Save Button
            Button(action: {
                Task {
                    await viewModel.updateProfile()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ActivityIndicatorView(
                            isVisible: $viewModel.isLoading,
                            type: .default
                        )
                        .frame(width: 20, height: 20)
                        Text("Saving...")
                    } else {
                        Text("Save Changes")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.isLoading || !viewModel.hasChanges)
        }
        .padding()
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
    }
}
```

**Why Kingfisher over AsyncImage:**
- ✅ **Automatic caching** (memory + disk)
- ✅ **Retry logic** for failed downloads
- ✅ **Placeholder support** with loading indicators
- ✅ **Better performance** for multiple images
- ✅ **Progress tracking** during download
- ✅ **Image processing** (resize, blur, etc.)

**Alternative: AsyncImage (Native, but no caching):**
```swift
// Simpler but no automatic caching
AsyncImage(url: viewModel.photoURL) { phase in
    switch phase {
    case .empty:
        ActivityIndicatorView(isVisible: .constant(true), type: .default)
            .frame(width: 120, height: 120)
    case .success(let image):
        image
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
    case .failure:
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 120, height: 120)
            .foregroundColor(.red)
    @unknown default:
        EmptyView()
    }
}
```

**UX Best Practices:**
1. **Always show loading indicators** during upload/download
2. **Use placeholders** for better perceived performance
3. **Cache images** to reduce Firebase Storage reads (saves money!)
4. **Handle errors gracefully** with retry logic
5. **Show progress** for long uploads (use PopupView for toasts)

**Time Estimate:** 1 hour (includes Kingfisher integration)

---

### Story 1.6: Logout Functionality
**As a content creator, I can log out of my account so I can switch accounts or secure my device.**

**Acceptance Criteria:**
- [ ] Logout button in settings/profile screen
- [ ] Confirmation dialog: "Are you sure you want to log out?"
- [ ] On confirm: Sign out from Firebase Auth
- [ ] Clear auth token from Keychain
- [ ] Clear local SwiftData cache (optional, can keep for offline access)
- [ ] Navigate back to login screen

**Technical Tasks:**
1. Add logout button to `ProfileView.swift`
2. Add to `AuthViewModel.swift`:
   - `func logout() async throws`
   - Confirmation logic
3. Add to `AuthService.swift`:
   - `func signOut() async throws`
   - Firebase Auth: `try Auth.auth().signOut()`
   - Keychain: `keychainService.delete()`
   - Optionally clear SwiftData
4. Navigation logic:
   - Update `isAuthenticated` state to trigger RootView re-render
5. Testing:
   - Test logout flow end-to-end
   - Verify token removed from Keychain
   - Verify user redirected to login screen

**iOS Mobile Considerations:**
1. **Confirmation UX**
   - Use native `.confirmationDialog()` instead of `.alert()` for better iOS UX:
     ```swift
     .confirmationDialog("Log out of your account?", isPresented: $showLogoutDialog) {
         Button("Log Out", role: .destructive) {
             Task { await viewModel.logout() }
         }
         Button("Cancel", role: .cancel) { }
     } message: {
         Text("You can log back in anytime.")
     }
     ```
   - Destructive button style: `.foregroundColor(.red)` for "Log Out" action

2. **Data Cleanup**
   - Clear Kingfisher image cache:
     ```swift
     KingfisherManager.shared.cache.clearMemoryCache()
     KingfisherManager.shared.cache.clearDiskCache()
     ```
   - Clear SwiftData context (optional based on offline strategy - consider keeping for offline access)
   - Reset all @Published properties in ViewModels to prevent data leaks

3. **Haptic Feedback**
   - Subtle haptic on logout confirmation tap (`.impact(.medium)`)
   - No haptic on "Cancel" (preserves current state, no feedback needed)

4. **Accessibility**
   - VoiceOver announcement after logout:
     ```swift
     UIAccessibility.post(notification: .screenChanged, argument: "You have been logged out")
     ```
   - Ensure logout button is easily discoverable and properly labeled

**Time Estimate:** 15-20 mins

---

## Technical Dependencies

### Required Services:
- ✅ Firebase Auth (configured in Epic 0)
- ✅ Firebase Firestore (for user profiles)
- ✅ Firebase Storage (for profile pictures)
- ✅ iOS Keychain (for secure token storage)
- ✅ SwiftData UserEntity (from Epic 0)

### Required Libraries:
- ✅ Firebase iOS SDK (FirebaseAuth, FirebaseFirestore, FirebaseStorage)
- ✅ SwiftUI (for all UI)
- ✅ SwiftData (for local user persistence)

---

## Data Models

### User Model (Swift)
```swift
// Features/Auth/Models/User.swift
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

### Firestore Schema
```
/users/{userId}
  - email: string
  - displayName: string
  - photoURL: string (Firebase Storage URL)
  - createdAt: timestamp

/displayNames/{displayName}
  - userId: string (reference to user who owns this displayName)
  - createdAt: timestamp
```

### Realtime Database Schema
```
/userPresence/{userId}
  - status: "online" | "offline" | "away"
  - lastSeen: timestamp (server timestamp)
  - displayName: string (optional, for quick lookup)
```

### SwiftData UserEntity
See `docs/swiftdata-implementation-guide.md` Section 3 for complete UserEntity definition.

---

## Architecture Pattern: MVVM

### Flow:
```
[View (SwiftUI)]
    ↓ User Action (e.g., tap Login)
[@MainActor ViewModel]
    ↓ async function call
[AuthService]
    ↓ Firebase SDK calls
[Firebase Backend]
    ↓ Response
[AuthService] → ViewModel (@Published update) → View (auto re-render)
```

### Example:
```swift
// LoginView.swift
Button("Login") {
    Task {
        await viewModel.login()
    }
}

// AuthViewModel.swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService()

    func login() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await authService.signIn(email: email, password: password)
            // Success - RootView will auto-navigate
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## Testing Strategy

### Unit Tests:
- [ ] Email validation logic
- [ ] Password strength validation
- [ ] AuthViewModel state transitions
- [ ] KeychainService save/retrieve/delete

### Integration Tests:
- [ ] Sign up flow with Firebase Emulator
- [ ] Login flow with Firebase Emulator
- [ ] Auto-login on app launch
- [ ] Profile update with Firestore

### Manual Testing:
- [ ] Sign up with real email (receive verification email if enabled)
- [ ] Login with valid credentials
- [ ] Login with invalid credentials (should show error)
- [ ] Forgot password (receive reset email)
- [ ] Auto-login after app restart
- [ ] Logout and verify redirect to login
- [ ] Upload profile picture

---

## MCP Tools Integration

Epic 1 can leverage two powerful MCP (Model Context Protocol) servers for automation and testing:

### Firebase MCP
The Firebase MCP provides CLI-level control over Firebase services:

**Available Commands:**
```bash
# Start Firebase Emulators for local testing
firebase emulators:start

# Deploy Security Rules (already deployed)
firebase deploy --only firestore:rules,database:rules,storage:rules

# Test Firestore queries
# Use Firebase MCP tools to query /users and /displayNames collections

# Validate Security Rules
# Firebase MCP can validate rules syntax before deployment
```

**Use Cases in Epic 1:**
- Story 1.1: Test displayName uniqueness with emulator
- Story 1.2: Test login flow with emulated auth
- Story 1.5: Test profile picture upload to emulated storage
- All stories: Validate Security Rules enforcement

### XcodeBuild MCP
The XcodeBuild MCP provides Xcode automation:

**Available Commands:**
```bash
# Build the project
xcodebuild build -project sorted.xcodeproj -scheme sorted

# Run unit tests
xcodebuild test -project sorted.xcodeproj -scheme sorted

# Run on iOS Simulator
xcodebuild test -project sorted.xcodeproj -scheme sorted \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Use Cases in Epic 1:**
- After Story 1.1: Run unit tests for AuthViewModel validation
- After Story 1.2: Test login flow on simulator
- After Story 1.3: Test auto-login persistence
- After all stories: Full integration test suite

### Testing Workflow with MCPs

**Recommended workflow for each story:**
1. Start Firebase Emulators: `firebase emulators:start`
2. Implement story features
3. Run XcodeBuild tests: `xcodebuild test ...`
4. Validate with Firebase MCP (check Firestore data, rules)
5. Deploy to TestFlight once all stories pass

**Important:** Always test against emulators first before touching production Firebase!

---

## Error Handling

### Common Firebase Auth Errors:
```swift
enum AuthError: Error, LocalizedError {
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case wrongPassword
    case userNotFound
    case networkError
    case invalidDisplayName
    case displayNameTaken
    case displayNameTooShort
    case displayNameTooLong
    case displayNameInvalidCharacters
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emailAlreadyInUse:
            return "This email is already registered. Please log in."
        case .weakPassword:
            return "Password must be at least 8 characters long."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email."
        case .networkError:
            return "Network error. Please check your connection."
        case .invalidDisplayName:
            return "Invalid username format."
        case .displayNameTaken:
            return "This username is already taken. Please choose another."
        case .displayNameTooShort:
            return "Username must be at least 3 characters long."
        case .displayNameTooLong:
            return "Username must be 30 characters or less."
        case .displayNameInvalidCharacters:
            return "Username can only contain letters, numbers, periods, and underscores."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

### Error Mapping:
```swift
// In AuthService.swift
func mapFirebaseError(_ error: Error) -> AuthError {
    let nsError = error as NSError

    switch nsError.code {
    case AuthErrorCode.invalidEmail.rawValue:
        return .invalidEmail
    case AuthErrorCode.emailAlreadyInUse.rawValue:
        return .emailAlreadyInUse
    case AuthErrorCode.weakPassword.rawValue:
        return .weakPassword
    case AuthErrorCode.wrongPassword.rawValue:
        return .wrongPassword
    case AuthErrorCode.userNotFound.rawValue:
        return .userNotFound
    case AuthErrorCode.networkError.rawValue:
        return .networkError
    default:
        return .unknown(error)
    }
}
```

---

## UI/UX Specifications

See `docs/ux-design.md` Section 4.1 for complete onboarding and authentication UI specifications.

### Key UI Elements:
- **Sign Up Screen**: Email, Password, Confirm Password, Display Name, Sign Up button
- **Login Screen**: Email, Password, Login button, Forgot Password link
- **Forgot Password Screen**: Email, Send Reset Email button
- **Profile Screen**: Profile picture (tap to change), Display Name field, Save button

### Design System:
- Use iOS native `.textFieldStyle(.roundedBorder)` for inputs
- Use `.buttonStyle(.borderedProminent)` for primary actions
- Show `.progressView()` during async operations
- Use `.alert()` for error messages

---

## Success Criteria

**Epic 1 is complete when:**
- ✅ User can sign up with email/password
- ✅ User can log in with email/password
- ✅ User stays logged in after app restart (Keychain persistence)
- ✅ User can reset password via email
- ✅ User can set display name and profile picture
- ✅ User can log out successfully
- ✅ Auth token stored securely in Keychain
- ✅ User profile synced to Firestore
- ✅ User data cached in SwiftData
- ✅ All error states handled gracefully
- ✅ Unit and integration tests pass

---

## Time Estimates

| Story | Estimated Time |
|-------|---------------|
| 1.1 User Sign Up | 1-1.5 hours |
| 1.2 User Login | 45 mins - 1 hour |
| 1.3 Persistent Login | 30 mins |
| 1.4 Password Reset | 30 mins |
| 1.5 Profile Management | 1 hour |
| 1.6 Logout | 15-20 mins |
| **Total** | **2-3 hours** |

---

## Implementation Order

**Recommended sequence:**
1. Story 1.1 (Sign Up) - Foundation for auth
2. Story 1.2 (Login) - Core login flow
3. Story 1.3 (Persistent Login) - Keychain integration
4. Story 1.6 (Logout) - Complete auth cycle
5. Story 1.4 (Password Reset) - Forgot password flow
6. Story 1.5 (Profile Management) - Profile pictures (can be last)

---

## References

- **PRD Section 8.1.1**: Authentication specifications
- **PRD Section 10.1**: Firebase Firestore schema (users collection)
- **SwiftData Implementation Guide**: Section 3 (UserEntity)
- **UX Design Doc**: Section 4.1 (Onboarding & Authentication UI)
- **Architecture Doc**: Section 8 (Security - Keychain, Firebase Auth)

---

## Notes for Development Team

### Critical Security Considerations:
- **Never log passwords** - Use `SecureField` in SwiftUI
- **Store auth tokens in Keychain only** - Never UserDefaults or plain files
- **Use HTTPS only** - Firebase SDK enforces this by default
- **Validate all inputs** - Email format, password strength

### Tips for Success:
- Test with Firebase Emulators during development (faster, no costs)
- Use real Firebase for final testing (to test email delivery)
- Handle all Firebase Auth error codes explicitly
- Use Swift 6 async/await (no completion handlers)

### Potential Blockers:
- **Firebase email verification**: Can enable later, not required for MVP
- **Profile picture upload time**: Compress images before upload (0.7 quality)
- **Keychain access**: Test on real device if simulator has issues

---

**Epic Status:** Ready for implementation
**Blockers:** Epic 0 must be complete
**Risk Level:** Low (well-documented Firebase Auth patterns)
