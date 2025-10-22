---
# Story 1.6: Logout Functionality

id: STORY-1.6
title: "Logout Functionality"
epic: "Epic 1: User Authentication & Profiles"
status: draft
priority: P0  # Critical blocker
estimate: 1  # Story points
assigned_to: null
created_date: "2025-10-20"
sprint_day: 1  # Day 1 of 7-day sprint

---

## Description

**As a** content creator
**I need** to log out of my account
**So that** I can switch accounts or secure my device when not in use

This story implements complete logout functionality including Firebase Auth sign out, Keychain token deletion, optional local data cleanup, and proper navigation back to the login screen. The implementation uses native iOS patterns for confirmation dialogs and data cleanup.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Logout button in settings/profile screen
- [ ] Confirmation dialog: "Are you sure you want to log out?"
- [ ] On confirm: Sign out from Firebase Auth
- [ ] Clear auth token from Keychain
- [ ] Clear Kingfisher image cache
- [ ] Clear local SwiftData cache (optional, can keep for offline access)
- [ ] Reset all @Published properties in ViewModels
- [ ] Navigate back to login screen
- [ ] Haptic feedback on logout
- [ ] VoiceOver announcement for accessibility
- [ ] Destructive button style for "Log Out" action

---

## Technical Tasks

**Implementation steps:**

1. **Add Logout Button to ProfileView** (`Features/Settings/Views/ProfileView.swift`)
   - Logout button at bottom of profile screen
   - Destructive red button style
   - **iOS-specific**: Use `.confirmationDialog()` for confirmation
   - **iOS-specific**: Destructive role for logout action

2. **Add to AuthViewModel** (`Features/Auth/ViewModels/AuthViewModel.swift`)
   - `func logout() async throws`
   - `@Published var showLogoutDialog: Bool`
   - Confirmation logic
   - Reset all published properties

3. **Add to AuthService** (`Features/Auth/Services/AuthService.swift`)
   - `func signOut() async throws`
   - Firebase Auth: `try Auth.auth().signOut()`
   - Keychain: `keychainService.delete()`
   - Clear Kingfisher cache
   - Optionally clear SwiftData

4. **Navigation Logic**
   - Update `isAuthenticated` state to trigger RootView re-render
   - RootView automatically shows LoginView when `isAuthenticated = false`

5. **Data Cleanup**
   - Clear Keychain auth token
   - Clear Kingfisher memory and disk cache
   - Optional: Clear SwiftData (consider keeping for offline access)
   - Reset ViewModel state

6. **Testing**
   - Test logout flow end-to-end
   - Verify token removed from Keychain
   - Verify user redirected to login screen
   - Verify all caches cleared
   - Test "Cancel" button (should not log out)

---

## Technical Specifications

### Files to Create/Modify

```
Features/Settings/Views/ProfileView.swift (modify - add logout button)
Features/Auth/ViewModels/AuthViewModel.swift (modify - add logout())
Features/Auth/Services/AuthService.swift (modify - add signOut())
```

### Code Examples

**AuthService.swift - signOut() Implementation:**

```swift
/// AuthService.swift
/// Handles Firebase Auth sign out and cleanup
/// [Source: Epic 1, Story 1.6]

import Foundation
import FirebaseAuth
import Kingfisher

extension AuthService {
    /// Signs out user and cleans up local data
    /// - Throws: AuthError if sign out fails
    func signOut() async throws {
        // 1. Sign out from Firebase Auth
        do {
            try auth.signOut()
        } catch {
            throw mapFirebaseError(error)
        }

        // 2. Delete auth token from Keychain
        let keychainService = KeychainService()
        try keychainService.delete()

        // 3. Clear Kingfisher image cache
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()

        // 4. Optional: Clear SwiftData
        // Consider keeping SwiftData for offline access
        // If clearing is needed:
        // await clearSwiftDataContext()
    }

    /// Clears SwiftData context (optional)
    private func clearSwiftDataContext() async {
        // Implementation depends on SwiftData setup
        // See swiftdata-implementation-guide.md
    }
}
```

**AuthViewModel.swift - Add logout():**

```swift
/// AuthViewModel.swift
/// ViewModel for authentication state management
/// [Source: Epic 1, Story 1.6]

import Foundation
import SwiftUI

@MainActor
extension AuthViewModel {
    /// Logs out current user
    func logout() async {
        do {
            try await authService.signOut()

            // Reset all published properties
            isAuthenticated = false
            currentUser = nil
            email = ""
            password = ""
            displayName = ""
            errorMessage = nil

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // VoiceOver announcement
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "You have been logged out"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

**ProfileView.swift - Add Logout Button:**

```swift
/// ProfileView.swift
/// User profile screen with logout functionality
/// [Source: Epic 1, Story 1.6]

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutDialog = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ... existing profile content ...

                    Spacer()

                    // Logout Button
                    Button(role: .destructive, action: {
                        showLogoutDialog = true
                    }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .accessibilityIdentifier("logoutButton")
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Log out of your account?",
                isPresented: $showLogoutDialog,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can log back in anytime.")
            }
        }
    }
}
```

### Dependencies

**Required:**
- Story 1.2 (User Login and Keychain) must be complete
- Story 1.3 (Persistent Login) must be complete
- Story 1.5 (Profile Management) must be complete (for ProfileView)
- Firebase SDK installed and configured
- Kingfisher installed via SPM

**Blocks:**
- None (completes auth cycle)

**External:**
- Firebase Auth configured

---

## Testing & Validation

### Test Procedure

1. **Test Logout Confirmation Dialog**
   - Tap "Log Out" button
   - Confirmation dialog should appear
   - Message: "Log out of your account?"
   - "You can log back in anytime."
   - Two buttons: "Log Out" (red, destructive), "Cancel"

2. **Test Cancel Action**
   - Tap "Log Out" button
   - Tap "Cancel" in dialog
   - Should dismiss dialog without logging out
   - User should remain on profile screen

3. **Test Logout Action**
   - Tap "Log Out" button
   - Tap "Log Out" in dialog
   - Should show brief loading indicator (optional)
   - Should navigate to login screen
   - Should feel haptic feedback (medium impact)

4. **Verify Data Cleanup**
   - After logout, verify auth token removed from Keychain
   - Verify Kingfisher cache cleared (no cached profile pictures)
   - Verify ViewModel state reset (email, password cleared)
   - Launch app again → Should show login screen (not auto-login)

5. **Test Accessibility**
   - Enable VoiceOver
   - Tap "Log Out" button
   - Confirm logout
   - Should hear "You have been logged out" announcement

6. **Test Error Handling**
   - Simulate Firebase sign out failure (difficult to test)
   - Should show error alert if sign out fails

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS Simulator (iPhone 16)
- [ ] Logout button appears on profile screen
- [ ] Confirmation dialog uses native `.confirmationDialog()`
- [ ] "Log Out" button has destructive style (red)
- [ ] Cancel button does not log out
- [ ] Logout successfully signs out from Firebase
- [ ] Auth token removed from Keychain
- [ ] Kingfisher cache cleared
- [ ] User navigated to login screen
- [ ] Haptic feedback on logout
- [ ] VoiceOver announcement works
- [ ] No crashes or data leaks

---

## References

**Architecture Docs:**
- [Source: docs/architecture/technology-stack.md] - Firebase Auth, iOS Keychain
- [Source: docs/architecture/security-architecture.md] - Data cleanup on logout
- [Source: docs/swiftdata-implementation-guide.md] - Optional SwiftData cleanup

**PRD Sections:**
- PRD Section 8.1.4: Logout specifications
- PRD Section 8.3: Session management

**Epic:**
- docs/epics/epic-1-user-authentication-profiles.md

**Related Stories:**
- Story 1.2: User Login (prerequisite - Keychain)
- Story 1.3: Persistent Login (prerequisite - auth state)
- Story 1.5: Profile Management (provides UI for logout button)

---

## Notes & Considerations

### Implementation Notes

**iOS Mobile-Specific Considerations:**

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
   - iOS automatically styles destructive role buttons in red

2. **Data Cleanup**
   - Clear Kingfisher image cache:
     ```swift
     KingfisherManager.shared.cache.clearMemoryCache()
     KingfisherManager.shared.cache.clearDiskCache()
     ```
   - Clear SwiftData context (optional based on offline strategy - consider keeping for offline access)
   - Reset all @Published properties in ViewModels to prevent data leaks:
     ```swift
     isAuthenticated = false
     currentUser = nil
     email = ""
     password = ""
     displayName = ""
     errorMessage = nil
     ```

3. **Haptic Feedback**
   - Subtle haptic on logout confirmation tap (`.impact(.medium)`)
   - No haptic on "Cancel" (preserves current state, no feedback needed)
   - Example:
     ```swift
     UIImpactFeedbackGenerator(style: .medium).impactOccurred()
     ```

4. **Accessibility**
   - VoiceOver announcement after logout:
     ```swift
     UIAccessibility.post(notification: .screenChanged, argument: "You have been logged out")
     ```
   - Ensure logout button is easily discoverable and properly labeled
   - Use `Label` with SF Symbol for better accessibility:
     ```swift
     Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
     ```

5. **Navigation**
   - Logout triggers `isAuthenticated = false` in AuthViewModel
   - RootView observes `isAuthenticated` and automatically shows LoginView
   - No manual navigation code needed (reactive UI pattern)

### Edge Cases

- User taps logout while network request in progress (cancel or wait)
- Firebase sign out fails (show error, don't clear Keychain)
- Keychain delete fails (log error, continue with sign out)
- User rapidly taps logout button (disable button during loading)
- App crashes during logout (data cleanup may be incomplete)

### Performance Considerations

- Logout should complete instantly (< 500ms)
- Kingfisher cache clear is synchronous (fast)
- Firebase sign out is synchronous (instant)
- Keychain delete is synchronous (instant)

### Security Considerations

- Always clear auth token from Keychain on logout
- Clear sensitive cached data (images, profile info)
- Optional: Clear SwiftData (depends on offline strategy)
- Don't cache passwords or sensitive user input
- Reset ViewModel state to prevent data leaks between sessions

**Data Cleanup Strategy:**
- **Always clear:** Keychain auth token, Kingfisher cache, ViewModel state
- **Optional clear:** SwiftData (consider keeping for offline access)
- **Never clear:** User preferences (app settings, theme, etc.)

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-20
**Last updated:** 2025-10-20
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 1: User Authentication & Profiles
**Story points:** 1
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
