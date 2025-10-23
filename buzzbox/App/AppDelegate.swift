/// AppDelegate.swift
/// Handles push notification setup, FCM token management, and deep linking
/// [Source: Story 2.0B - Cloud Functions FCM (foundation)]
/// [Source: Story 3.7 - Group Message Notifications]
///
/// **Responsibilities:**
/// - FCM token registration and updates (device only, not simulator)
/// - Notification permission requests and status tracking
/// - Foreground notification display with [.banner, .sound, .badge]
/// - Deep linking when user taps notifications
/// - FCM analytics tracking via Messaging.messaging().appDidReceiveMessage()
///
/// **Simulator vs Device Behavior:**
/// - **Simulator:** FCM tokens may be generated but APNs won't work for remote push
///   - Local notifications (UNUserNotificationCenter) ARE the primary method
///   - All logging prefixed with [SIMULATOR]
/// - **Device:** Full FCM/APNs support for remote push notifications
///   - Cloud Functions send FCM → APNs → Device
///   - All logging prefixed with [DEVICE]
///
/// **Foreground Notification Handling:**
/// The `willPresent` delegate method ensures notifications show even when app is in foreground.
/// Returns [.banner, .sound, .badge] to display native iOS notification banner.
///
/// **Works for both 1:1 and group conversations**

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure push notifications
        configureNotifications(application: application)
        return true
    }

    // MARK: - Push Notification Configuration

    /// Configures Firebase Cloud Messaging and notification permissions
    private func configureNotifications(application: UIApplication) {
        // ✅ CRITICAL FIX: Set delegates HERE (after Firebase.configure())
        // This prevents crashes from delegates firing before Firebase is ready
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        print("🔔 [APP DELEGATE] Notification delegates set (after Firebase configuration)")

        // Log current notification permission status
        Task {
            await logNotificationPermissionStatus()
        }

        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            print("🔐 [NOTIF PERMISSIONS] Authorization requested")
            if granted {
                print("    └─ ✅ Granted: User allowed notifications")
            } else if let error = error {
                print("    └─ ❌ Denied: \(error.localizedDescription)")
            } else {
                print("    └─ ❌ Denied: User declined notifications")
            }
        }

        // Register for remote notifications
        application.registerForRemoteNotifications()
    }

    /// Logs current notification permission status for debugging
    private func logNotificationPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        #if targetEnvironment(simulator)
        let environment = "[SIMULATOR]"
        #else
        let environment = "[DEVICE]"
        #endif

        print("🔐 [NOTIF PERMISSIONS] \(environment) Current Status:")
        print("    └─ Authorization: \(settings.authorizationStatus.description)")
        print("    └─ Alert: \(settings.alertSetting.description)")
        print("    └─ Sound: \(settings.soundSetting.description)")
        print("    └─ Badge: \(settings.badgeSetting.description)")
        print("    └─ Banner: \(settings.notificationCenterSetting.description)")
    }

    // MARK: - FCM Token Handling

    /// Called when APNs token is registered
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    /// Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }

    // MARK: - MessagingDelegate

    /// Called when FCM token is refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("⚠️ [FCM TOKEN] No token received (expected on simulator)")
            return
        }

        #if targetEnvironment(simulator)
        print("🔑 [FCM TOKEN] [SIMULATOR] Token received (will NOT work for push - use local notifications)")
        #else
        print("🔑 [FCM TOKEN] [DEVICE] Token received and ready for push notifications")
        #endif
        print("    └─ Token: \(fcmToken.prefix(20))...")

        // Store token in Firestore for Cloud Functions to use
        Task {
            await saveFCMToken(fcmToken)
        }
    }

    /// Manually request FCM token (for existing users without tokens)
    ///
    /// ⚠️ IMPORTANT: FCM push notifications DO NOT work in iOS Simulator
    /// - iOS Simulator doesn't support APNs (Apple Push Notification Service)
    /// - FCM on iOS requires APNs to deliver remote push notifications
    /// - For testing push notifications, you MUST use a physical iPhone device
    /// - In-app notifications (NotificationService) still work in simulator while app is open
    func refreshFCMToken() {
        // Skip FCM token on simulator (APNS not available)
        #if targetEnvironment(simulator)
        return
        #else
        Messaging.messaging().token { token, error in
            if let error = error {
            } else if let token = token {
                Task {
                    await self.saveFCMToken(token)
                }
            }
        }
        #endif
    }

    /// Saves FCM token to Firestore for current user
    private func saveFCMToken(_ token: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ [FCM TOKEN] Cannot save: No authenticated user")
            return
        }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .setData(["fcmToken": token], merge: true)
            print("✅ [FCM TOKEN] Saved to Firestore for user: \(userID)")
        } catch {
            print("❌ [FCM TOKEN] Failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when notification is received while app is in foreground
    /// CRITICAL: This method ensures notifications show even when app is active
    /// This is THE KEY method for foreground notification delivery across all screens
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let conversationID = userInfo["conversationID"] as? String ?? "unknown"
        let title = notification.request.content.title
        let body = notification.request.content.body
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if targetEnvironment(simulator)
        let environment = "[SIMULATOR]"
        #else
        let environment = "[DEVICE]"
        #endif

        print("📬 [FOREGROUND NOTIF] \(environment) Notification received while app is in FOREGROUND")
        print("    └─ ConversationID: \(conversationID)")
        print("    └─ Title: \(title)")
        print("    └─ Body: \(body)")
        print("    └─ Timestamp: \(timestamp)")
        print("    └─ UserInfo keys: \(userInfo.keys.map { String(describing: $0) }.joined(separator: ", "))")

        // Check if this is an FCM notification
        if let messageID = userInfo["gcm.message_id"] as? String {
            print("    └─ FCM MessageID: \(messageID)")
            print("    └─ Source: Firebase Cloud Messaging (FCM)")

            // Log FCM analytics (per Firebase best practices)
            Messaging.messaging().appDidReceiveMessage(userInfo)
        } else {
            print("    └─ Source: Local Notification (UNUserNotificationCenter)")
        }

        // ALWAYS show notification in foreground with banner, sound, and badge
        // This ensures consistent notification delivery regardless of app state or screen
        print("    └─ ✅ Showing notification with [.banner, .sound, .badge]")
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when user taps a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract conversationID from notification payload
        if let conversationID = userInfo["conversationID"] as? String {

            // Post NotificationCenter event to open conversation
            // RootView will observe this and present MessageThreadView
            NotificationCenter.default.post(
                name: Notification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationID": conversationID]
            )
        } else {
        }

        completionHandler()
    }
}

// MARK: - UNNotificationSettings Extensions for Logging

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined (user hasn't been asked yet)"
        case .denied: return "Denied (user explicitly declined)"
        case .authorized: return "Authorized (user allowed notifications)"
        case .provisional: return "Provisional (silent notifications allowed)"
        case .ephemeral: return "Ephemeral (temporary authorization)"
        @unknown default: return "Unknown"
        }
    }
}

extension UNNotificationSetting {
    var description: String {
        switch self {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }
}
