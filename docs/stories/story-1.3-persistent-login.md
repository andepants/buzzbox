---
# Story 1.3: Persistent Login / Auto-Login

id: STORY-1.3
title: "Persistent Login / Auto-Login"
epic: "Epic 1: User Authentication & Profiles"
status: draft
priority: P0  # Critical blocker
estimate: 3  # Story points
assigned_to: null
created_date: "2025-10-20"
sprint_day: 1  # Day 1 of 7-day sprint

---

## Description

**As a** content creator
**I need** to stay logged in after closing the app
**So that** I don't have to log in every time I open the app

This story implements persistent authentication using iOS Keychain to store Firebase auth tokens securely. The app checks for a valid token on launch and automatically logs the user in if the token is valid, providing a seamless user experience.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] On app launch, check for valid auth token in Keychain
- [ ] If valid token exists, auto-login and navigate to conversation list
- [ ] If no token or invalid token, show login screen
- [ ] Silent refresh of Firebase auth token if needed
- [ ] User data synced from Firestore on auto-login
- [ ] Loading state shown during auth check (not blank screen)
- [ ] Auth check completes in < 2 seconds
- [ ] App lifecycle: Refresh auth token when app returns to foreground if > 1 hour in background
- [ ] Privacy overlay shown when app backgrounds (prevent sensitive data screenshots)

---

## Technical Tasks

**Implementation steps:**

1. **Create RootView** (`App/Views/RootView.swift`)
   - Initial loading state
   - Check for auth token on appear
   - Conditionally show LoginView or ConversationListView
   - Show branded loading screen during auth check

2. **Add to AuthViewModel** (`Features/Auth/ViewModels/AuthViewModel.swift`)
   - `@Published var isAuthenticated: Bool`
   - `func checkAuthStatus() async`
   - `func refreshAuthIfNeeded() async`
   - Auto-login logic

3. **Add to AuthService** (`Features/Auth/Services/AuthService.swift`)
   - `func autoLogin() async throws -> User?`
   - Check Keychain for token via KeychainService
   - Verify token with Firebase: `Auth.auth().currentUser`
   - Fetch user data from Firestore
   - Refresh token if needed
   - Handle expired/invalid tokens

4. **Update SortedApp.swift**
   - Use `RootView` as initial view instead of hardcoded ContentView
   - Add `@Environment(\.scenePhase)` for lifecycle management
   - Implement foreground/background transitions

5. **Add Privacy Overlay**
   - Create `PrivacyOverlayView.swift` to cover sensitive data when app backgrounds
   - Show overlay when `scenePhase == .background` or `.inactive`

6. **Testing**
   - Test app launch with valid token (should auto-login)
   - Test app launch with no token (should show login)
   - Test app launch with expired token (should show login)
   - Test app backgrounding and foregrounding
   - Test cold start vs warm start

---

## Technical Specifications

### Files to Create/Modify

```
App/Views/RootView.swift (create)
Features/Auth/ViewModels/AuthViewModel.swift (modify - add checkAuthStatus(), refreshAuthIfNeeded())
Features/Auth/Services/AuthService.swift (modify - add autoLogin())
App/SortedApp.swift (modify - use RootView, add scenePhase)
App/Views/PrivacyOverlayView.swift (create)
```

### Code Examples

**AuthService.swift - autoLogin() Implementation:**

```swift
/// AuthService.swift
/// Handles Firebase Auth operations including auto-login
/// [Source: Epic 1, Story 1.3]

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension AuthService {
    /// Attempts auto-login using stored Keychain token
    /// - Returns: User object if auto-login successful, nil if no valid token
    /// - Throws: AuthError if token exists but is invalid
    func autoLogin() async throws -> User? {
        // 1. Check Keychain for stored token
        let keychainService = KeychainService()
        guard let token = keychainService.retrieve() else {
            return nil // No token stored, user needs to login
        }

        // 2. Verify Firebase Auth current user
        guard let firebaseUser = auth.currentUser else {
            // Token exists but no Firebase user - clear invalid token
            try? keychainService.delete()
            return nil
        }

        // 3. Refresh token if needed (Firebase SDK handles this automatically)
        let idToken = try await firebaseUser.getIDToken(forcingRefresh: true)

        // 4. Update Keychain with refreshed token
        try keychainService.save(token: idToken)

        // 5. Fetch user data from Firestore
        let uid = firebaseUser.uid
        let userDoc = try await firestore.collection("users").document(uid).getDocument()

        guard let data = userDoc.data() else {
            throw AuthError.userNotFound
        }

        // 6. Parse user data
        let email = data["email"] as? String ?? ""
        let displayName = data["displayName"] as? String ?? ""
        let photoURL = data["photoURL"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        // 7. Create User object
        let user = User(
            id: uid,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            createdAt: createdAt
        )

        // 8. Update local SwiftData UserEntity
        // (Implementation depends on SwiftData ModelContext)

        return user
    }

    /// Refreshes auth token if app was in background for > 1 hour
    /// - Parameter lastActiveDate: Date when app was last active
    func refreshAuthIfNeeded(lastActiveDate: Date) async throws {
        let oneHour: TimeInterval = 3600
        let timeSinceLastActive = Date().timeIntervalSince(lastActiveDate)

        guard timeSinceLastActive > oneHour else {
            return // No refresh needed
        }

        guard let firebaseUser = auth.currentUser else {
            return
        }

        // Force token refresh
        let idToken = try await firebaseUser.getIDToken(forcingRefresh: true)

        // Update Keychain with refreshed token
        let keychainService = KeychainService()
        try keychainService.save(token: idToken)
    }
}
```

**RootView.swift:**

```swift
/// RootView.swift
/// Root view that handles authentication state and conditional navigation
/// [Source: Epic 1, Story 1.3]

import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showPrivacyOverlay = false

    var body: some View {
        ZStack {
            Group {
                if authViewModel.isLoading {
                    // Loading state during auth check
                    LoadingView()
                } else if authViewModel.isAuthenticated {
                    // User authenticated - show main app
                    ConversationListView()
                } else {
                    // User not authenticated - show login
                    LoginView()
                }
            }

            // Privacy overlay when app backgrounds
            if showPrivacyOverlay {
                PrivacyOverlayView()
            }
        }
        .task {
            // Check auth status on app launch
            await authViewModel.checkAuthStatus()
        }
    }
}

/// Loading view shown during auth check
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App logo or branding
            Image(systemName: "envelope.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)

            Text("Loading...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
```

**SortedApp.swift - Updated with RootView and scenePhase:**

```swift
/// SortedApp.swift
/// App entry point with lifecycle management
/// [Source: Epic 1, Story 1.3]

import SwiftUI
import FirebaseCore

@main
struct SortedApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastActiveDate = Date()
    @State private var showPrivacyOverlay = false

    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(authViewModel)

                // Privacy overlay when app backgrounds
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    /// Handles app lifecycle transitions
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            showPrivacyOverlay = false

            // Refresh auth token if needed (if > 1 hour in background)
            Task {
                await authViewModel.refreshAuthIfNeeded(lastActiveDate: lastActiveDate)
            }

            lastActiveDate = Date()

        case .inactive:
            // App becoming inactive (e.g., system dialog shown)
            showPrivacyOverlay = true

        case .background:
            // App moved to background
            showPrivacyOverlay = true

        @unknown default:
            break
        }
    }
}
```

**PrivacyOverlayView.swift:**

```swift
/// PrivacyOverlayView.swift
/// Privacy overlay shown when app backgrounds to prevent sensitive data screenshots
/// [Source: Epic 1, Story 1.3]

import SwiftUI

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "envelope.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                Text("Sorted")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
    }
}
```

**AuthViewModel.swift - Add checkAuthStatus() and refreshAuthIfNeeded():**

```swift
/// AuthViewModel.swift
/// ViewModel for authentication state management
/// [Source: Epic 1, Story 1.3]

import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: User?
    @Published var errorMessage: String?

    private let authService = AuthService()

    /// Checks authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let user = try await authService.autoLogin() {
                currentUser = user
                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        } catch {
            print("Auto-login failed: \(error.localizedDescription)")
            isAuthenticated = false
        }
    }

    /// Refreshes auth token if app was in background for > 1 hour
    func refreshAuthIfNeeded(lastActiveDate: Date) async {
        guard isAuthenticated else { return }

        do {
            try await authService.refreshAuthIfNeeded(lastActiveDate: lastActiveDate)
        } catch {
            print("Token refresh failed: \(error.localizedDescription)")
            // Token refresh failed - force re-login
            isAuthenticated = false
        }
    }
}
```

### Dependencies

**Required:**
- Story 1.1 (User Sign Up) must be complete
- Story 1.2 (User Login and Keychain) must be complete
- Firebase SDK installed and configured
- SwiftData ModelContainer configured in App.swift

**Blocks:**
- Story 1.6 (Logout needs to clear auth state)

**External:**
- Firebase project created with Auth enabled

---

## Testing & Validation

### Test Procedure

1. **Test Auto-Login with Valid Token**
   - Log in via Story 1.2
   - Close app completely (swipe away from app switcher)
   - Relaunch app
   - Should auto-login and show conversation list (no login screen)

2. **Test No Token Scenario**
   - Fresh app install (or clear Keychain)
   - Launch app
   - Should show login screen (no auto-login attempt)

3. **Test Expired Token**
   - Manually expire Firebase token (use Firebase Console to revoke)
   - Launch app
   - Should show login screen (invalid token detected)

4. **Test App Lifecycle**
   - Log in
   - Background app (swipe to home screen)
   - Wait 1 second, return to app → Should NOT refresh token
   - Background app, wait 2 hours, return → Should refresh token

5. **Test Privacy Overlay**
   - Log in
   - Background app
   - Privacy overlay should appear immediately
   - Return to foreground
   - Privacy overlay should disappear

6. **Test Loading State**
   - Launch app with valid token
   - Should show branded loading screen (not blank)
   - Loading should complete in < 2 seconds

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS Simulator (iPhone 16)
- [ ] Auto-login works with valid token
- [ ] Login screen shown when no token
- [ ] Login screen shown when invalid token
- [ ] Auth check completes in < 2 seconds
- [ ] Token refresh works after > 1 hour in background
- [ ] Privacy overlay shown when app backgrounds
- [ ] No blank screens during transitions
- [ ] App lifecycle handled correctly

---

## References

**Architecture Docs:**
- [Source: docs/architecture/technology-stack.md] - Firebase Auth, iOS Keychain
- [Source: docs/architecture/security-architecture.md] - Keychain security, privacy overlay
- [Source: docs/swiftdata-implementation-guide.md] - UserEntity caching

**PRD Sections:**
- PRD Section 8.1.1: Authentication specifications
- PRD Section 8.3: Session management

**Epic:**
- docs/epics/epic-1-user-authentication-profiles.md

**Related Stories:**
- Story 1.1: User Sign Up (prerequisite)
- Story 1.2: User Login (prerequisite - Keychain)
- Story 1.6: Logout (clears auth state)

---

## Notes & Considerations

### Implementation Notes

**iOS Mobile-Specific Considerations:**

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

5. **Token Refresh Strategy**
   - Firebase SDK handles token refresh automatically (expires after 1 hour)
   - Force refresh only if app was in background > 1 hour
   - If refresh fails, force user to re-login (security best practice)
   - Update Keychain with refreshed token

### Edge Cases

- App killed by iOS while in background (should auto-login on next launch)
- Keychain access denied (device lock/jailbreak detection)
- Firebase Auth session revoked while app in background
- Network failure during token refresh (show login screen with error)
- User deletes account while app in background (should detect on foreground)

### Performance Considerations

- Auto-login should complete in < 2 seconds on good network
- Use SwiftData cache to avoid Firestore fetch on every launch
- Preload critical data during auth check (conversation list)
- Optimize launch time by deferring non-critical Firebase initializations

### Security Considerations

- Privacy overlay prevents sensitive data screenshots when backgrounded
- Token stored in Keychain (encrypted by iOS automatically)
- Token refresh uses HTTPS only (Firebase SDK enforces)
- Expired/invalid tokens cleared from Keychain immediately
- Optional: Require re-authentication if backgrounded > 5 minutes (future enhancement)

**Firebase Security Rules:**
- User can only read their own `/users/{userId}` document
- Auth token verified server-side by Firebase

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-20
**Last updated:** 2025-10-20
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 1: User Authentication & Profiles
**Story points:** 3
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
