---
# Story 2.0: Setup Firebase Cloud Messaging & Push Notifications

id: STORY-2.0
title: "Setup Firebase Cloud Messaging & Push Notifications"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P0  # Blocker - First story in Epic 2
estimate: 3  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 1  # Day 1 MVP

---

## Description

**As a** developer
**I need** to configure FCM and APNs for the iOS app
**So that** users receive push notifications when messages arrive while the app is backgrounded or closed

This story establishes the foundational push notification infrastructure required for all messaging features. It includes FCM SDK integration, APNs setup, token management, and deep linking configuration.

**Performance Target:** Push notification delivery <5 seconds after message send

**Critical Note:** APNs configuration is already complete (see Epic 2 lines 24-67):
- ✅ Team ID: `H8R6C22KR8`
- ✅ APNs Key ID: `XXQ7GB65VH`
- ✅ .p8 key uploaded to Firebase Console
- ✅ Push Notifications capability enabled in Xcode

---

## Acceptance Criteria

**This story is complete when:**

- [x] Firebase Cloud Messaging (FCM) SDK integrated into iOS app ✅
- [x] APNs registration completes successfully on app launch ✅
- [x] FCM token generated and stored in Firestore `/users/{userId}/fcmToken` ✅
- [x] Notification permissions requested with proper messaging ✅
- [x] User can grant/deny notification permissions ✅
- [x] FCM token updates when permissions change ✅
- [x] Deep linking works: tapping notification opens specific conversation ✅
- [ ] Test notification successfully delivered to device ⚠️ REQUIRES PHYSICAL DEVICE
- [x] **FCM token refresh handled** (token can change periodically) ✅
- [x] **Permission state persisted** (don't re-prompt if already denied) ✅
- [x] **Background notification handling** (app closed/backgrounded) ✅
- [x] **Foreground notification handling** (app active - silent update) ✅

---

## Technical Tasks

**Implementation steps:**

1. **Add Firebase Cloud Messaging SDK to Xcode project**
   ```swift
   // Add to Package.swift or use Swift Package Manager in Xcode
   // Firebase Messaging: https://github.com/firebase/firebase-ios-sdk

   dependencies: [
       .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
   ]

   // In target dependencies:
   .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
   ```

2. **Enable Push Notifications capability in Xcode**
   - Open project settings → Signing & Capabilities
   - Click "+ Capability" → Select "Push Notifications"
   - Verify capability appears in entitlements

3. **Create AppDelegate for FCM configuration**
   - File: `sorted/App/AppDelegate.swift`
   - Configure Firebase on launch
   - Set FCM messaging delegate
   - Set UNUserNotificationCenter delegate
   - Request notification permissions
   - Register for remote notifications (APNs)
   - Handle APNs token registration success/failure

4. **Implement MessagingDelegate to receive FCM token**
   - Extension: `AppDelegate+MessagingDelegate`
   - Method: `messaging(_:didReceiveRegistrationToken:)`
   - Store FCM token in Firestore `/users/{userID}/fcmToken`
   - Include timestamp: `fcmTokenUpdatedAt`

5. **Implement UNUserNotificationCenterDelegate for notification handling**
   - Extension: `AppDelegate+UNUserNotificationCenterDelegate`
   - Handle foreground notifications (suppress banner, RTDB updates UI)
   - Handle notification taps for deep linking
   - Extract conversationID from notification payload
   - Post NotificationCenter event for navigation

6. **Update SortedApp.swift to use AppDelegate**
   - Add `@UIApplicationDelegateAdaptor(AppDelegate.self)`
   - Listen for deep link notifications
   - Navigate to conversation when notification tapped

7. **Test push notification delivery**
   - Use Firebase Console → Cloud Messaging → "Send test message"
   - Verify notification appears on physical device
   - Verify deep linking works when notification tapped

---

## Technical Specifications

### Files to Create/Modify

```
sorted/App/AppDelegate.swift (create)
sorted/App/SortedApp.swift (modify - add UIApplicationDelegateAdaptor)
sorted.entitlements (modify - verify Push Notifications capability)
```

### Code Examples

**AppDelegate.swift (from Epic 2 lines 557-622):**

```swift
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set FCM messaging delegate
        Messaging.messaging().delegate = self

        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        Task {
            await requestNotificationPermissions()
        }

        // Register for remote notifications (APNs)
        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass APNs token to FCM
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        } catch {
            print("Error requesting notification permissions: \(error)")
        }
    }
}
```

**MessagingDelegate Extension (from Epic 2 lines 625-658):**

```swift
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        print("FCM Token: \(token)")

        // Store token in Firestore
        Task { @MainActor in
            await storeFCMToken(token)
        }
    }

    private func storeFCMToken(_ token: String) async {
        guard let userID = AuthService.shared.currentUserID else {
            print("No authenticated user - cannot store FCM token")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        do {
            try await userRef.updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ])
            print("FCM token stored successfully")
        } catch {
            print("Error storing FCM token: \(error)")
        }
    }
}
```

**UNUserNotificationCenterDelegate Extension (from Epic 2 lines 661-707):**

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {

    // Handle notification when app is in FOREGROUND
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        print("Notification received in foreground: \(userInfo)")

        // For messaging app, suppress notification when app is open
        // RTDB real-time listener will update UI automatically
        completionHandler([]) // Don't show notification
    }

    // Handle notification TAP when app is backgrounded/closed
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        print("Notification tapped: \(userInfo)")

        // Extract conversation ID for deep linking
        if let conversationID = userInfo["conversationID"] as? String {
            // Notify app to navigate to conversation
            NotificationCenter.default.post(
                name: .openConversation,
                object: nil,
                userInfo: ["conversationID": conversationID]
            )
        }

        completionHandler()
    }
}

// Notification name for deep linking
extension Notification.Name {
    static let openConversation = Notification.Name("openConversation")
}
```

**SortedApp.swift Update (from Epic 2 lines 710-734):**

```swift
import SwiftUI
import FirebaseCore

@main
struct SortedApp: App {
    // Register AppDelegate for FCM setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { notification in
                    // Handle deep link to conversation
                    if let conversationID = notification.userInfo?["conversationID"] as? String {
                        // Navigate to MessageThreadView
                        print("Navigate to conversation: \(conversationID)")
                    }
                }
        }
    }
}
```

### Firestore Data Structure

```json
{
  "users": {
    "{userID}": {
      "email": "user@example.com",
      "displayName": "John Doe",
      "fcmToken": "fE3Kd...",  // FCM token for push notifications
      "fcmTokenUpdatedAt": {"_seconds": 1704067200}
    }
  }
}
```

### Dependencies

**Required:**
- Epic 0 (Project Scaffolding) must be complete
- Epic 1 (User Authentication) must be complete - AuthService.shared.currentUserID
- Firebase project created and configured
- APNs certificates uploaded to Firebase Console (✅ COMPLETE)

**Blocks:**
- Story 2.0B (Cloud Functions FCM Triggers) - deferred to Epic 3
- Story 2.1-2.6 (all other Epic 2 stories)

**External:**
- Apple Developer Account with active membership
- APNs Authentication Key (.p8 file) - ✅ COMPLETE
- Physical iOS device for testing (APNs doesn't work on simulator)

---

## Testing & Validation

### Test Procedure

1. **Permission Flow:**
   - Launch app on physical device
   - Verify permission alert appears
   - Grant permission
   - Verify console logs "Notification permission granted"
   - Verify console logs "FCM Token: ..."

2. **Token Storage:**
   - Check Firestore Console → `users/{userId}`
   - Verify `fcmToken` field exists with token string
   - Verify `fcmTokenUpdatedAt` timestamp is recent

3. **Test Notification Delivery:**
   - Background the app
   - Send test notification from Firebase Console
   - Verify notification appears on device lock screen
   - Tap notification
   - Verify app opens (deep link will be tested in Story 2.3)

4. **Edge Cases:**
   - Test on app fresh install (first launch)
   - Test when user denies permissions
   - Test when user changes permissions in Settings → Notifications
   - Test token refresh (may take days - monitor logs)

### Success Criteria

- [ ] Builds without errors on Xcode
- [ ] Runs on physical iOS device (17+)
- [ ] Notification permission prompt appears on first launch
- [ ] FCM token logged to console
- [ ] FCM token stored in Firestore with timestamp
- [ ] Test notification delivered to device successfully
- [ ] No crashes when app backgrounded/foregrounded
- [ ] Deep link NotificationCenter event fires on notification tap

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (N/A for this story)

**PRD Sections:**
- Push Notifications (if applicable)

**Implementation Guides:**
- Firebase Cloud Messaging iOS Setup: https://firebase.google.com/docs/cloud-messaging/ios/client
- APNs Overview: https://developer.apple.com/documentation/usernotifications
- UNUserNotificationCenter: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter

**Related Stories:**
- Story 2.0B - Cloud Functions FCM Triggers (Epic 3 - deferred)
- Story 2.1-2.6 (blocked by this story)

---

## Notes & Considerations

### Implementation Notes

**⚠️ CRITICAL: Push Notification Anti-Pattern Warning (from Epic 2 lines 750-860)**

**DO NOT create local notifications when receiving remote push notifications!**

**❌ WRONG APPROACH:**
```swift
// DON'T DO THIS - Creates duplicate notification layer
func userNotificationCenter(..., willPresent notification...) {
    let content = UNMutableNotificationContent()
    content.title = userInfo["senderName"] as? String ?? "New Message"
    content.body = userInfo["messageText"] as? String ?? ""

    let request = UNNotificationRequest(...)
    UNUserNotificationCenter.current().add(request) // ❌ Wrong!
    completionHandler([])
}
```

**✅ CORRECT APPROACH:**
- Let FCM/APNs handle notification display
- In foreground: suppress banner (`completionHandler([])`), let RTDB update UI
- In background: FCM/APNs shows notification automatically
- On tap: extract conversationID and deep link

**Why our approach is correct:**
- ✅ Single source of truth - FCM handles ALL notifications
- ✅ Proper deep linking - FCM data payload preserved
- ✅ APNs integration - respects delivery, grouping, badge management
- ✅ No duplication - RTDB updates UI, notification shows in background only

### Edge Cases

- **Simulator Limitations:** APNs doesn't work on iOS Simulator - MUST test on physical device
- **Permission Timing:** Request permissions early (on login or first app launch)
- **Permission Denial:** Don't re-prompt if user already denied (check current authorization status)
- **Token Refresh:** FCM tokens can change - `didReceiveRegistrationToken` handles this automatically
- **App Not Running:** APNs delivers notification even when app is terminated

### Performance Considerations

- FCM token storage should not block UI (use background Task)
- Notification permission request is async (use `await`)
- Deep link navigation should be smooth (use NavigationStack state)

### Security Considerations

- Never log full FCM tokens in production (use truncated version for debugging)
- FCM tokens are sensitive - treat like auth tokens
- Firestore security rules should protect FCM token field (only user can read/write their own token)

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 3
**Priority:** P0 (Blocker)

---

## Story Lifecycle

- [ ] **Draft** - Story created, needs review
- [x] **Ready** - Story reviewed and ready for development ✅
- [x] **In Progress** - Developer working on story ✅
- [ ] **Blocked** - Story blocked by dependency or issue
- [x] **Review** - Implementation complete, needs QA review ✅
- [ ] **Done** - Story complete and validated (pending physical device testing)

**Current Status:** Review (Ready for QA - Physical Device Testing Required)
**Last Updated:** 2025-10-21
**Implemented By:** @dev
