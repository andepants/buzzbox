/// NotificationService.swift
/// Handles in-app and push notifications with simulator support
///
/// **Notification System Overview:**
/// This app uses THREE notification systems that work together:
///
/// 1. **Custom In-App Banner** (`showInAppNotification`)
///    - Custom SwiftUI overlay at top of screen
///    - Works on: Simulator ✅ | Device ✅
///    - When: App is in foreground
///
/// 2. **Local Notifications** (`scheduleLocalNotification`)
///    - UNUserNotificationCenter native notifications
///    - Works on: Simulator ✅ | Device ✅
///    - When: App is in foreground or background
///    - Note: Primary notification method for simulator testing
///
/// 3. **FCM Push Notifications** (Cloud Function)
///    - Firebase Cloud Messaging via Cloud Functions
///    - Works on: Simulator ❌ | Device ✅ (requires APNs)
///    - When: App is in background or foreground
///    - Note: Requires physical device with APNs support
///
/// **Notification Flow:**
/// - User sends message → MessageThreadViewModel
/// - Triggers: showInAppNotification() + scheduleLocalNotification() (local)
/// - Triggers: Cloud Function sends FCM (remote, device only)
/// - AppDelegate.willPresent handles foreground display with [.banner, .sound, .badge]
///
/// **Simulator Testing:**
/// - Use local notifications (methods 1 & 2 above)
/// - FCM will NOT work on simulator (APNs limitation)
/// - All logging includes [SIMULATOR] prefix for clarity

import Foundation
import SwiftUI
import UserNotifications
import FirebaseAuth

@MainActor
@Observable
class NotificationService {
    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Published Properties

    /// Active in-app notification banner
    var activeNotification: InAppNotification?

    /// Currently visible conversation (prevents notif for current chat)
    var currentConversationID: String?
    
    // MARK: - Retry Configuration
    
    /// Maximum number of retry attempts for failed notifications
    private let maxRetryAttempts = 3
    
    /// Retry delays (in seconds) for each attempt - exponential backoff
    private let retryDelays: [Double] = [0.5, 1.0, 2.0]

    // MARK: - Models

    struct InAppNotification: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let conversationID: String
        let timestamp: Date

        /// Auto-dismiss after 5 seconds
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 5
        }
    }

    // MARK: - Initialization

    private init() {
        // NotificationService is now called directly from MessageThreadViewModel
        // No need for NotificationCenter observers
    }

    // MARK: - Public Methods

    /// Shows an in-app notification banner (works on simulator) with retry logic
    /// Shows an in-app notification banner (works on simulator) with retry logic
    func showInAppNotification(
        title: String,
        body: String,
        conversationID: String
    ) async {
        // ⚠️ CRITICAL: Only show notifications for authenticated users
        guard Auth.auth().currentUser != nil else {
            return
        }

        #if targetEnvironment(simulator)
        print("🔔 [NOTIF] [SIMULATOR] Showing IN-APP BANNER")
        #else
        print("🔔 [NOTIF] [DEVICE] Showing IN-APP BANNER")
        #endif
        
        // Attempt with retry logic
        for attempt in 1...maxRetryAttempts {
            do {
                
                // Create notification
                let notification = InAppNotification(
                    title: title,
                    body: body,
                    conversationID: conversationID,
                    timestamp: Date()
                )

                activeNotification = notification
                
                // Log notification attempt
                logNotificationAttempt(
                    type: "in-app-banner",
                    conversationID: conversationID,
                    attempt: attempt,
                    success: true,
                    error: nil
                )

                // Auto-dismiss after 5 seconds
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if activeNotification?.id == notification.id {
                    activeNotification = nil
                }
                
                return // Success, exit retry loop
                
            } catch {
                
                // Log failed attempt
                logNotificationAttempt(
                    type: "in-app-banner",
                    conversationID: conversationID,
                    attempt: attempt,
                    success: false,
                    error: error
                )
                
                // If not last attempt, wait before retrying
                if attempt < maxRetryAttempts {
                    let delay = retryDelays[attempt - 1]
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }

    /// Schedule a local notification (works on simulator) with retry logic
    ///
    /// **Important for Simulator Testing:**
    /// This is the PRIMARY notification method for iOS Simulator since FCM/APNs don't work on simulator.
    /// On device, this complements FCM push notifications.
    /// Schedule a local notification (works on simulator) with retry logic
    ///
    /// **Important for Simulator Testing:**
    /// This is the PRIMARY notification method for iOS Simulator since FCM/APNs don't work on simulator.
    /// On device, this complements FCM push notifications.
    func scheduleLocalNotification(
        title: String,
        body: String,
        conversationID: String
    ) async {
        // ⚠️ CRITICAL: Only schedule notifications for authenticated users
        guard Auth.auth().currentUser != nil else {
            return
        }

        #if targetEnvironment(simulator)
        print("🔔 [NOTIF] [SIMULATOR] Scheduling LOCAL NOTIFICATION (primary for simulator)")
        #else
        print("🔔 [NOTIF] [DEVICE] Scheduling LOCAL NOTIFICATION (complement to FCM)")
        #endif
        
        // Check notification authorization status
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        if settings.authorizationStatus == .denied {
            logNotificationAttempt(
                type: "local-notification",
                conversationID: conversationID,
                attempt: 1,
                success: false,
                error: NSError(domain: "NotificationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notifications denied by user"])
            )
            return
        }

        // Attempt with retry logic
        for attempt in 1...maxRetryAttempts {
            do {
                
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.badge = 1
                content.userInfo = ["conversationID": conversationID]

                // Schedule with minimal delay (10ms for nearly instant delivery)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: trigger
                )

                try await UNUserNotificationCenter.current().add(request)
                
                // Log success
                logNotificationAttempt(
                    type: "local-notification",
                    conversationID: conversationID,
                    attempt: attempt,
                    success: true,
                    error: nil
                )
                
                return // Success, exit retry loop
                
            } catch {
                
                // Log failed attempt
                logNotificationAttempt(
                    type: "local-notification",
                    conversationID: conversationID,
                    attempt: attempt,
                    success: false,
                    error: error
                )
                
                // If not last attempt, wait before retrying
                if attempt < maxRetryAttempts {
                    let delay = retryDelays[attempt - 1]
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }

    /// Clears all notification badges
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    /// Sets the currently visible conversation (prevents duplicate notifications)
    func setCurrentConversation(_ conversationID: String?) {
        self.currentConversationID = conversationID

        if conversationID != nil {
            // Clear badge when viewing a conversation
            clearBadge()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Logs notification attempt for debugging with enhanced context
    private func logNotificationAttempt(
        type: String,
        conversationID: String,
        attempt: Int,
        success: Bool,
        error: Error?
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let currentUserID = Auth.auth().currentUser?.uid ?? "unknown"
        let prefix = "🔔 [NOTIF]"

        // Check if user is viewing this conversation
        let isViewingConversation = conversationID == currentConversationID ||
                                    conversationID == UserPresenceService.shared.getCurrentConversationID()

        #if targetEnvironment(simulator)
        let environment = "[SIMULATOR]"
        let deliveryChannels = "in-app banner, local notification (FCM unavailable on simulator)"
        #else
        let environment = "[DEVICE]"
        let deliveryChannels = "in-app banner, local notification, FCM push"
        #endif

        if success {
            print("\(prefix) \(environment) ✅ SUCCESS | Type: \(type) | Attempt: \(attempt)/\(maxRetryAttempts)")
            print("    └─ ConversationID: \(conversationID)")
            print("    └─ UserID: \(currentUserID)")
            print("    └─ ViewingConversation: \(isViewingConversation ? "yes (still showing)" : "no")")
            print("    └─ DeliveryChannels: \(deliveryChannels)")
            print("    └─ Timestamp: \(timestamp)")
        } else if let error = error {
            print("\(prefix) \(environment) ❌ FAILURE | Type: \(type) | Attempt: \(attempt)/\(maxRetryAttempts)")
            print("    └─ ConversationID: \(conversationID)")
            print("    └─ UserID: \(currentUserID)")
            print("    └─ ViewingConversation: \(isViewingConversation ? "yes" : "no")")
            print("    └─ Error: \(error.localizedDescription)")
            print("    └─ Timestamp: \(timestamp)")
        }
    }
}

// MARK: - SwiftUI Extension

extension View {
    /// Displays in-app notification banner at top of view
    func notificationBanner() -> some View {
        self.overlay(alignment: .top) {
            NotificationBannerView()
        }
    }
}

// MARK: - Banner View

struct NotificationBannerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var notificationService = NotificationService.shared

    var body: some View {
        if let notification = notificationService.activeNotification {
            VStack(spacing: 0) {
                Button {
                    // Navigate to conversation
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenConversation"),
                        object: nil,
                        userInfo: ["conversationID": notification.conversationID]
                    )
                    notificationService.activeNotification = nil
                } label: {
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: "message.fill")
                            .font(.title3)
                            .foregroundStyle(.white)

                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)

                            Text(notification.body)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                        }

                        Spacer()

                        // Dismiss button
                        Button {
                            notificationService.activeNotification = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.gradient)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    )
                    .padding()
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notification.id)
        }
    }
}

#Preview("Notification Banner") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Button("Show Notification") {
                Task {
                    await NotificationService.shared.showInAppNotification(
                        title: "Andrew Heim Dev",
                        body: "Hey! Just wanted to check in and see how the app development is going. Let me know if you need anything!",
                        conversationID: "test-123"
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    .notificationBanner()
}
