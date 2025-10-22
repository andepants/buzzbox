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
    private var presenceListeners: [String: DatabaseHandle] = [:]

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Set Presence

    /// Set user as online with auto-cleanup on disconnect
    func setOnline() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let presenceRef = database.child("userPresence/\(userID)")

        // Set online status
        presenceRef.child("online").setValue(true)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // ✅ CRITICAL: Auto-cleanup on disconnect (app crash, force quit, network drop)
        presenceRef.child("online").onDisconnectRemoveValue()
        presenceRef.child("lastSeen").onDisconnectSetValue(ServerValue.timestamp())

        print("✅ User presence: ONLINE")
    }

    /// Set user as offline and cancel disconnect operations
    func setOffline() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let presenceRef = database.child("userPresence/\(userID)")

        // Set offline status
        presenceRef.child("online").setValue(false)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // Cancel pending onDisconnect operations
        presenceRef.child("online").cancelDisconnectOperations()
        presenceRef.child("lastSeen").cancelDisconnectOperations()

        print("⚫ User presence: OFFLINE")
    }

    // MARK: - App Lifecycle

    /// Setup observers for app lifecycle events
    private func setupAppLifecycleObservers() {
        // App enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setOnline()
            }
        }

        // App enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setOffline()
            }
        }

        // App will terminate
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setOffline()
            }
        }
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

    deinit {
        // Cleanup all listeners
        for (userID, handle) in presenceListeners {
            database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        }
    }
}
