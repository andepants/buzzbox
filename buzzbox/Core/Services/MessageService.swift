/// MessageService.swift
///
/// Service for managing message read receipts in group conversations.
/// Syncs read status between SwiftData and Firebase Realtime Database.
///
/// Created: 2025-10-22
/// [Source: Story 3.6 - Group Read Receipts]

import Foundation
import SwiftData
@preconcurrency import FirebaseDatabase
import FirebaseAuth

/// Service for tracking message read receipts
@MainActor
final class MessageService {
    // MARK: - Singleton

    static let shared = MessageService()

    // MARK: - Properties

    nonisolated(unsafe) private let database: DatabaseReference

    // MARK: - Initialization

    private init() {
        self.database = Database.database().reference()
    }

    // MARK: - Public Methods

    /// Mark a message as read by the current user
    /// Updates both RTDB and SwiftData
    /// - Parameters:
    ///   - messageID: The message ID to mark as read
    ///   - conversationID: The conversation ID containing the message
    ///   - modelContext: SwiftData ModelContext for local updates
    func markAsRead(
        messageID: String,
        conversationID: String,
        modelContext: ModelContext
    ) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw MessageServiceError.notAuthenticated
        }

        let timestamp = Date()

        // 1. Update RTDB (server timestamp in milliseconds)
        let messageRef = database
            .child("messages")
            .child(conversationID)
            .child(messageID)
            .child("readBy")
            .child(currentUserID)

        try await messageRef.setValue(timestamp.timeIntervalSince1970 * 1000)

        // 2. Update local SwiftData
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate<MessageEntity> { msg in
                msg.id == messageID
            }
        )

        if let message = try? modelContext.fetch(descriptor).first {
            message.readBy[currentUserID] = timestamp
            try? modelContext.save()
        }
    }

    /// Mark multiple messages as read (batch operation)
    /// - Parameters:
    ///   - messages: Array of messages to mark as read
    ///   - conversationID: The conversation ID containing the messages
    ///   - modelContext: SwiftData ModelContext for local updates
    func markMessagesAsRead(
        messages: [MessageEntity],
        conversationID: String,
        modelContext: ModelContext
    ) async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        for message in messages {
            // Only mark messages from other users as read
            guard message.senderID != currentUserID else { continue }

            // Skip if already read by current user
            guard message.readBy[currentUserID] == nil else { continue }

            // Mark as read
            try? await markAsRead(
                messageID: message.id,
                conversationID: conversationID,
                modelContext: modelContext
            )
        }
    }

    /// Listen to read receipt updates for a conversation
    /// - Parameters:
    ///   - conversationID: The conversation ID to listen to
    ///   - completion: Called when read receipts are updated (message ID -> read receipts map)
    /// - Returns: Database listener handle (for cleanup)
    nonisolated func listenToReadReceipts(
        conversationID: String,
        completion: @escaping @MainActor (String, [String: Date]) -> Void
    ) -> DatabaseHandle {
        let messagesRef = database
            .child("messages")
            .child(conversationID)

        let handle = messagesRef.observe(.childChanged) { snapshot in
            guard let messageData = snapshot.value as? [String: Any],
                  let readByData = messageData["readBy"] as? [String: Double] else {
                return
            }

            let messageID = snapshot.key

            // Convert timestamps from milliseconds to Date
            let readByDates = readByData.mapValues { Date(timeIntervalSince1970: $0 / 1000) }

            // Call completion handler on main actor
            Task { @MainActor in
                completion(messageID, readByDates)
            }
        }

        return handle
    }

    /// Stop listening to read receipt updates
    /// - Parameters:
    ///   - conversationID: The conversation ID to stop listening to
    ///   - handle: The database handle to remove
    nonisolated func stopListening(conversationID: String, handle: DatabaseHandle) {
        let messagesRef = database
            .child("messages")
            .child(conversationID)

        messagesRef.removeObserver(withHandle: handle)
    }
}

// MARK: - Errors

enum MessageServiceError: Error {
    case notAuthenticated
    case messageNotFound
    case syncFailed(String)
}
