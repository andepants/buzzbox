/// AppDelegate.swift
/// Handles push notification setup and deep linking
/// [Source: Story 2.0B - Cloud Functions FCM (foundation)]
/// [Source: Story 3.7 - Group Message Notifications]
///
/// This AppDelegate handles:
/// - FCM token registration and updates
/// - Notification permissions
/// - Deep linking when user taps notifications
/// - Works for both 1:1 and group conversations

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
        // Set notification delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission denied: \(error.localizedDescription)")
            }
        }

        // Register for remote notifications
        application.registerForRemoteNotifications()
    }

    // MARK: - FCM Token Handling

    /// Called when APNs token is registered
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token registered with Firebase Messaging")
    }

    /// Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate

    /// Called when FCM token is refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCM token is nil")
            return
        }

        print("✅ FCM token received: \(fcmToken)")

        // Store token in Firestore for Cloud Functions to use
        Task {
            await saveFCMToken(fcmToken)
        }
    }

    /// Saves FCM token to Firestore for current user
    private func saveFCMToken(_ token: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot save FCM token: No authenticated user")
            return
        }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .updateData(["fcmToken": token])
            print("✅ FCM token saved to Firestore for user: \(userID)")
        } catch {
            print("❌ Failed to save FCM token: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
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
            print("📱 User tapped notification for conversation: \(conversationID)")

            // Post NotificationCenter event to open conversation
            // RootView will observe this and present MessageThreadView
            NotificationCenter.default.post(
                name: Notification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationID": conversationID]
            )
        } else {
            print("⚠️ No conversationID found in notification payload")
        }

        completionHandler()
    }
}
