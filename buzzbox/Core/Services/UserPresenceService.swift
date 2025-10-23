/// UserPresenceService.swift
///
/// Manages user online/offline status using Firebase Realtime Database.
/// Uses .onDisconnect() for automatic cleanup when app crashes or network drops.
///
/// Created: 2025-10-22
/// [Source: Story 2.8 - User Presence & Online Status]

import Foundation
import FirebaseDatabase
import FirebaseAuth
import UIKit

/// User presence status model
struct PresenceStatus {
    let isOnline: Bool
    let lastSeen: Date

    /// Display text for presence status
    var displayText: String {
        if isOnline {
            return "Online"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        }
    }
}

/// Service for managing user presence with Firebase Realtime Database
@MainActor
final class UserPresenceService {
    // MARK: - Properties

    static let shared = UserPresenceService()

    nonisolated(unsafe) private let database = Database.database().reference()
    nonisolated(unsafe) private var presenceListeners: [String: DatabaseHandle] = [:]

    // Store NotificationCenter observers for cleanup
    nonisolated(unsafe) private var lifecycleObservers: [NSObjectProtocol] = []

    // Track current screen for notification filtering
    nonisolated(unsafe) private var currentConversationID: String?

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Set Presence

    /// Set user as online with auto-cleanup on disconnect
    func setOnline() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }

        let presenceRef = database.child("userPresence/\(userID)")

        do {
            // Set online status
            try await presenceRef.child("online").setValue(true)
            try await presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

            // ✅ CRITICAL: Auto-cleanup on disconnect (app crash, force quit, network drop)
            try await presenceRef.child("online").onDisconnectRemoveValue()
            try await presenceRef.child("lastSeen").onDisconnectSetValue(ServerValue.timestamp())
        } catch {
            // Silent failure - presence is non-critical
        }
    }

    /// Set user as offline and cancel disconnect operations
    /// - Note: Has timeout protection to prevent blocking during logout
    func setOffline() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }

        let presenceRef = database.child("userPresence/\(userID)")

        // Use a timeout to prevent indefinite blocking
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(3))
        }

        let offlineTask = Task {
            // Cancel pending onDisconnect operations (may fail if already disconnected)
            try? await presenceRef.child("online").cancelDisconnectOperations()
            try? await presenceRef.child("lastSeen").cancelDisconnectOperations()

            // Set offline status
            try await presenceRef.child("online").setValue(false)
            try await presenceRef.child("lastSeen").setValue(ServerValue.timestamp())
        }

        // Wait for either task to complete (with timeout)
        do {
            _ = try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await offlineTask.value
                }
                group.addTask {
                    try await timeoutTask.value
                    throw TimeoutError()
                }

                // Return on first completion
                try await group.next()
                group.cancelAll()
            }
        } catch {
            // Silent failure - presence is non-critical
        }
    }

    /// Update current screen/conversation the user is viewing
    /// This allows other users and Cloud Functions to know if user is actively viewing a conversation
    /// - Parameter conversationID: The conversation ID being viewed, or nil if not in any conversation
    func updateCurrentScreen(conversationID: String?) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }

        // Update local cache
        self.currentConversationID = conversationID

        let presenceRef = database.child("userPresence/\(userID)")

        do {
            if let conversationID = conversationID {
                // User is viewing a specific conversation
                try await presenceRef.child("currentScreen").setValue("conversation")
                try await presenceRef.child("currentConversationID").setValue(conversationID)

                // Auto-clear on disconnect
                try await presenceRef.child("currentScreen").onDisconnectRemoveValue()
                try await presenceRef.child("currentConversationID").onDisconnectRemoveValue()
            } else {
                // User left the conversation screen
                try await presenceRef.child("currentScreen").removeValue()
                try await presenceRef.child("currentConversationID").removeValue()
            }
        } catch {
            // Silent failure - screen tracking is non-critical
        }
    }

    /// Get the current conversation ID being viewed (local cache)
    func getCurrentConversationID() -> String? {
        return currentConversationID
    }

    /// Timeout error
    private struct TimeoutError: Error {}

    // MARK: - App Lifecycle

    /// Setup observers for app lifecycle events
    private func setupAppLifecycleObservers() {
        // App enters foreground
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.setOnline()
            }
        }
        lifecycleObservers.append(foregroundObserver)

        // App enters background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.setOffline()
            }
        }
        lifecycleObservers.append(backgroundObserver)

        // App will terminate
        let terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.setOffline()
            }
        }
        lifecycleObservers.append(terminateObserver)
    }

    // MARK: - Listen to Presence

    /// Listen to a user's presence status in real-time
    /// - Parameters:
    ///   - userID: The user ID to observe
    ///   - onChange: Callback with updated presence status
    /// - Returns: Database handle for cleanup
    func listenToPresence(
        userID: String,
        onChange: @escaping (PresenceStatus) -> Void
    ) -> DatabaseHandle {
        let presenceRef = database.child("userPresence/\(userID)")

        let handle = presenceRef.observe(.value) { snapshot in
            let isOnline = snapshot.childSnapshot(forPath: "online").value as? Bool ?? false
            let lastSeenTimestamp = snapshot.childSnapshot(forPath: "lastSeen").value as? TimeInterval ?? 0

            let status = PresenceStatus(
                isOnline: isOnline,
                lastSeen: Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
            )

            Task { @MainActor in
                onChange(status)
            }
        }

        presenceListeners[userID] = handle
        return handle
    }

    /// Stop listening to a user's presence
    /// - Parameter userID: The user ID to stop observing
    func stopListening(userID: String) {
        guard let handle = presenceListeners[userID] else { return }

        database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        presenceListeners.removeValue(forKey: userID)
    }

    // MARK: - Cleanup

    /// Remove all active presence listeners (call on logout)
    func removeAllListeners() async {
        // Remove Firebase RTDB listeners
        for (userID, handle) in presenceListeners {
            database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        }
        presenceListeners.removeAll()

        // Remove NotificationCenter observers
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
    }

    deinit {
        // Cleanup all Firebase RTDB listeners
        for (userID, handle) in presenceListeners {
            database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        }

        // Cleanup all NotificationCenter observers
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
