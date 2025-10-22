/// TypingIndicatorService.swift
///
/// Manages real-time typing indicators using Firebase Realtime Database ephemeral storage.
/// Features throttling, auto-cleanup on disconnect, and auto-stop after 3 seconds.
///
/// Thread-safe: All methods run on @MainActor to ensure safe timer and state management.
///
/// Created: 2025-10-22
/// [Source: Story 2.6 - Real-Time Typing Indicators, RTDB Code Examples lines 1655-1735]

import Foundation
import FirebaseDatabase

/// Service for managing typing indicators with ephemeral RTDB storage
@MainActor
final class TypingIndicatorService {
    // MARK: - Constants

    /// Throttle duration - maximum 1 typing event per this interval
    private static let throttleDuration: TimeInterval = 3.0

    /// Auto-stop duration - typing indicator auto-stops after this interval
    private static let autoStopDuration: TimeInterval = 3.0

    // MARK: - Properties

    /// Shared singleton instance
    static let shared = TypingIndicatorService()

    /// Firebase Realtime Database reference
    private let database = Database.database().reference()

    /// Throttle timers to prevent excessive updates (max 1 per 3 seconds)
    private var throttleTimers: [String: Timer] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Starts typing indicator for a user in a conversation.
    /// Thread-safe: Can be called from any thread.
    /// - Parameters:
    ///   - conversationID: The conversation ID
    ///   - userID: The user ID who is typing
    /// - Note: Automatically throttled to max 1 event per 3 seconds
    /// - Warning: Firebase errors are logged but not thrown
    func startTyping(conversationID: String, userID: String) {
        // Throttle typing events (max 1 per 3 seconds)
        let key = "\(conversationID)_\(userID)"

        if throttleTimers[key] != nil {
            return // Already typing, don't send duplicate event
        }

        let typingRef = database
            .child("conversations/\(conversationID)/typing/\(userID)")

        // Set typing state with error handling
        typingRef.setValue(true) { error, _ in
            if let error = error {
                print("⚠️ TypingIndicatorService: Failed to set typing status: \(error.localizedDescription)")
            }
        }

        // Auto-cleanup on disconnect (RTDB feature!)
        typingRef.onDisconnectRemoveValue { error, _ in
            if let error = error {
                print("⚠️ TypingIndicatorService: Failed to set disconnect cleanup: \(error.localizedDescription)")
            }
        }

        // Throttle for configured duration
        throttleTimers[key] = Timer.scheduledTimer(
            withTimeInterval: Self.throttleDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.throttleTimers[key] = nil

                // Auto-stop typing after configured duration
                self?.stopTyping(conversationID: conversationID, userID: userID)
            }
        }
    }

    /// Stops typing indicator for a user in a conversation.
    /// Thread-safe: Can be called from any thread.
    /// - Parameters:
    ///   - conversationID: The conversation ID
    ///   - userID: The user ID who stopped typing
    /// - Warning: Firebase errors are logged but not thrown
    func stopTyping(conversationID: String, userID: String) {
        let key = "\(conversationID)_\(userID)"
        throttleTimers[key]?.invalidate()
        throttleTimers[key] = nil

        let typingRef = database
            .child("conversations/\(conversationID)/typing/\(userID)")

        // Remove typing state with error handling
        typingRef.removeValue { error, _ in
            if let error = error {
                print("⚠️ TypingIndicatorService: Failed to remove typing status: \(error.localizedDescription)")
            }
        }
    }

    /// Listens to typing indicators in a conversation.
    /// Thread-safe: onChange callback is dispatched to @MainActor.
    /// - Parameters:
    ///   - conversationID: The conversation ID to listen to
    ///   - onChange: Callback with Set of user IDs currently typing (called on main thread)
    /// - Returns: DatabaseHandle for cleanup
    func listenToTypingIndicators(
        conversationID: String,
        onChange: @escaping @MainActor (Set<String>) -> Void
    ) -> DatabaseHandle {
        let typingRef = database
            .child("conversations/\(conversationID)/typing")

        return typingRef.observe(.value) { snapshot in
            var typingUserIDs = Set<String>()

            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let isTyping = child.value as? Bool, isTyping {
                    typingUserIDs.insert(child.key)
                }
            }

            // Dispatch to main thread for SwiftUI updates
            Task { @MainActor in
                onChange(typingUserIDs)
            }
        }
    }

    /// Stops listening to typing indicators.
    /// Thread-safe: Can be called from any thread.
    /// - Parameters:
    ///   - conversationID: The conversation ID
    ///   - handle: The DatabaseHandle returned by listenToTypingIndicators
    func stopListening(conversationID: String, handle: DatabaseHandle) {
        database
            .child("conversations/\(conversationID)/typing")
            .removeObserver(withHandle: handle)
    }

    // MARK: - Group Typing Formatting

    /// Format typing text for multiple users in group conversations
    /// [Source: Story 3.5 - Group Typing Indicators, lines 125-145]
    /// - Parameters:
    ///   - userIDs: Set of user IDs currently typing
    ///   - participants: Array of UserEntity participants to resolve display names
    /// - Returns: Formatted typing text string
    /// - Note: Formats as follows:
    ///   - 0 typers: "" (empty)
    ///   - 1 typer: "Alice is typing..."
    ///   - 2 typers: "Alice and Bob are typing..."
    ///   - 3 typers: "Alice, Bob, and Charlie are typing..."
    ///   - 4+ typers: "Alice, Bob, and 2 others are typing..."
    func formatTypingText(userIDs: Set<String>, participants: [UserEntity]) -> String {
        let typingUsers = participants.filter { userIDs.contains($0.id) }

        switch typingUsers.count {
        case 0:
            return ""
        case 1:
            return "\(typingUsers[0].displayName) is typing..."
        case 2:
            return "\(typingUsers[0].displayName) and \(typingUsers[1].displayName) are typing..."
        case 3:
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(typingUsers[2].displayName) are typing..."
        default:
            let others = typingUsers.count - 2
            return "\(typingUsers[0].displayName), \(typingUsers[1].displayName), and \(others) others are typing..."
        }
    }
}
