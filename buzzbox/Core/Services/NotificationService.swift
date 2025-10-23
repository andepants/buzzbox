/// NotificationService.swift
/// Handles in-app and push notifications with simulator support
///
/// Features:
/// - Local notifications for simulator testing
/// - Foreground notification banners
/// - In-app toast notifications when user is in different conversation
/// - Works seamlessly on both simulator and device

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
        setupNotificationObserver()
    }

    // MARK: - Setup

    /// Listen for real-time messages to show in-app notifications
    private func setupNotificationObserver() {
        // This will be called from MessageService when new message arrives
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NewMessageReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Extract message data
            if let userInfo = notification.userInfo,
               let senderName = userInfo["senderName"] as? String,
               let messageText = userInfo["messageText"] as? String,
               let conversationID = userInfo["conversationID"] as? String,
               let senderID = userInfo["senderID"] as? String {

                // Only show if not from current user and not viewing this conversation
                guard senderID != Auth.auth().currentUser?.uid else { return }
                guard conversationID != self.currentConversationID else { return }

                Task {
                    await self.showInAppNotification(
                        title: senderName,
                        body: messageText,
                        conversationID: conversationID
                    )
                }
            }
        }
    }

    // MARK: - Public Methods

    /// Shows an in-app notification banner (works on simulator) with retry logic
    func showInAppNotification(
        title: String,
        body: String,
        conversationID: String
    ) async {
        
        // Check if user is viewing this conversation in UserPresenceService
        let userCurrentScreen = UserPresenceService.shared.getCurrentConversationID()

        // Don't show if user is already viewing this conversation
        if conversationID == currentConversationID || conversationID == userCurrentScreen {
            return
        }
        
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
                } else {
                }
            }
        }
    }

    /// Schedule a local notification (works on simulator) with retry logic
    func scheduleLocalNotification(
        title: String,
        body: String,
        conversationID: String
    ) async {

        // Check if user is viewing this conversation in UserPresenceService
        let userCurrentScreen = UserPresenceService.shared.getCurrentConversationID()

        // Don't schedule if user is viewing this conversation
        if conversationID == currentConversationID || conversationID == userCurrentScreen {
            return
        }
        
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

                // Schedule immediately
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
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
                } else {
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
    
    /// Logs notification attempt for debugging
    private func logNotificationAttempt(
        type: String,
        conversationID: String,
        attempt: Int,
        success: Bool,
        error: Error?
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let currentUserID = Auth.auth().currentUser?.uid ?? "unknown"
        
        if let error = error {
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
