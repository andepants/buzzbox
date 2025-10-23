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

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Set Presence

    /// Set user as online with auto-cleanup on disconnect
    func setOnline() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ [PRESENCE] setOnline skipped - no authenticated user")
            return
        }

        print("🟢 [PRESENCE] Setting user \(userID) as ONLINE...")
        let presenceRef = database.child("userPresence/\(userID)")

        do {
            // Set online status
            try await presenceRef.child("online").setValue(true)
            print("   ✓ [PRESENCE] Set online = true")

            try await presenceRef.child("lastSeen").setValue(ServerValue.timestamp())
            print("   ✓ [PRESENCE] Set lastSeen timestamp")

            // ✅ CRITICAL: Auto-cleanup on disconnect (app crash, force quit, network drop)
            try await presenceRef.child("online").onDisconnectRemoveValue()
            print("   ✓ [PRESENCE] Set onDisconnect for online")

            try await presenceRef.child("lastSeen").onDisconnectSetValue(ServerValue.timestamp())
            print("   ✓ [PRESENCE] Set onDisconnect for lastSeen")

            print("✅ [PRESENCE] User presence: ONLINE")
        } catch {
            print("❌ [PRESENCE] Failed to set online presence: \(error.localizedDescription)")
        }
    }

    /// Set user as offline and cancel disconnect operations
    /// - Note: Has timeout protection to prevent blocking during logout
    func setOffline() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ [PRESENCE] setOffline skipped - no authenticated user")
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
            print("✅ User presence: OFFLINE")
        } catch is TimeoutError {
            print("⚠️ [PRESENCE] setOffline timed out (non-critical)")
        } catch {
            print("⚠️ [PRESENCE] Failed to set offline presence (non-critical): \(error.localizedDescription)")
        }
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
        print("👂 [PRESENCE] Starting listener for user: \(userID)")
        let presenceRef = database.child("userPresence/\(userID)")

        let handle = presenceRef.observe(.value) { snapshot in
            print("📡 [PRESENCE] Received update for user: \(userID)")
            print("   Snapshot exists: \(snapshot.exists())")
            print("   Snapshot value: \(snapshot.value ?? "nil")")

            let isOnline = snapshot.childSnapshot(forPath: "online").value as? Bool ?? false
            let lastSeenTimestamp = snapshot.childSnapshot(forPath: "lastSeen").value as? TimeInterval ?? 0

            print("   Parsed: isOnline=\(isOnline), lastSeen=\(lastSeenTimestamp)")

            let status = PresenceStatus(
                isOnline: isOnline,
                lastSeen: Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
            )

            print("   Status: \(status.displayText)")

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
        print("🔵 [PRESENCE] Removing all active listeners...")

        // Remove Firebase RTDB listeners
        for (userID, handle) in presenceListeners {
            database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
            print("   ✓ Removed RTDB listener for user: \(userID)")
        }
        presenceListeners.removeAll()

        // Remove NotificationCenter observers
        let observerCount = lifecycleObservers.count
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
        print("   ✓ Removed \(observerCount) NotificationCenter observers")

        print("✅ [PRESENCE] All listeners removed")
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
