/// ConversationService.swift
///
/// Service for managing conversations in Firebase Realtime Database
/// Handles conversation sync, retrieval, user validation, and blocking checks
///
/// Created: 2025-10-21
/// [Source: Story 2.1 - Create New Conversation]

import Foundation
@preconcurrency import FirebaseDatabase
@preconcurrency import FirebaseFirestore
import SwiftData

/// Service for managing conversations in Firebase Realtime Database
final class ConversationService {
    // MARK: - Properties

    static let shared = ConversationService()

    nonisolated(unsafe) private let database = Database.database().reference()

    // MARK: - Initialization

    private init() {}

    // MARK: - Conversation Operations

    /// Syncs a conversation to RTDB (supports both 1:1 and group conversations)
    /// - Parameter conversation: ConversationEntity to sync
    /// - Throws: Database errors
    nonisolated func syncConversation(_ conversation: ConversationEntity) async throws {
        let conversationRef = database.child("conversations/\(conversation.id)")

        // Convert participantIDs array to object format for RTDB security rules
        let participantIDsDict = conversation.participantIDs.reduce(into: [String: Bool]()) {
            $0[$1] = true
        }

        // Convert adminUserIDs array to object format
        let adminUserIDsDict = conversation.adminUserIDs.reduce(into: [String: Bool]()) {
            $0[$1] = true
        }

        var conversationData: [String: Any] = [
            "participantIDs": participantIDsDict,
            "lastMessage": conversation.lastMessageText ?? "",
            "lastMessageTimestamp": ServerValue.timestamp(),
            "createdAt": conversation.createdAt.timeIntervalSince1970 * 1000, // Convert to milliseconds
            "updatedAt": ServerValue.timestamp(),
            "unreadCount": conversation.unreadCount
        ]

        // Add group-specific fields if this is a group conversation
        if conversation.isGroup {
            conversationData["isGroup"] = true
            conversationData["groupName"] = conversation.displayName ?? ""
            conversationData["groupPhotoURL"] = conversation.groupPhotoURL ?? ""
            conversationData["adminUserIDs"] = adminUserIDsDict
            conversationData["isCreatorOnly"] = conversation.isCreatorOnly
        } else {
            conversationData["isGroup"] = false
            conversationData["isCreatorOnly"] = false
        }

        try await conversationRef.setValue(conversationData)
        print("✅ Conversation synced to RTDB: \(conversation.id) (isGroup: \(conversation.isGroup))")
    }

    /// Finds a conversation by ID in RTDB
    /// - Parameter id: Conversation ID
    /// - Returns: ConversationEntity if found, nil otherwise
    /// - Throws: Database errors
    nonisolated func findConversation(id: String) async throws -> ConversationEntity? {
        let conversationRef = database.child("conversations/\(id)")
        let snapshot = try await conversationRef.getData()

        guard snapshot.exists(),
              let conversationData = snapshot.value as? [String: Any] else {
            return nil
        }

        print("📥 Found conversation in RTDB: \(id)")

        return ConversationEntity(
            id: id,
            participantIDs: conversationData["participantIDs"] as? [String] ?? [],
            displayName: nil,
            isGroup: false,
            createdAt: Date(
                timeIntervalSince1970: conversationData["createdAt"] as? TimeInterval ?? 0
            ),
            syncStatus: .synced
        )
    }

    /// Gets a user by ID from Firestore
    /// - Parameter userID: User ID
    /// - Returns: UserEntity if found, nil otherwise
    /// - Throws: Database errors
    nonisolated func getUser(userID: String) async throws -> UserEntity? {
        let userRef = Firestore.firestore().collection("users").document(userID)
        let snapshot = try await userRef.getDocument()

        guard snapshot.exists,
              let userData = snapshot.data() else {
            print("⚠️ User not found in Firestore: \(userID)")
            return nil
        }

        print("✅ User found in Firestore: \(userID)")

        return UserEntity(
            id: userID,
            email: userData["email"] as? String ?? "",
            displayName: userData["displayName"] as? String ?? "",
            photoURL: userData["profilePictureURL"] as? String
        )
    }

    /// Checks if a user is blocked
    /// - Parameter userID: User ID to check
    /// - Returns: True if blocked, false otherwise
    /// - Throws: Database errors
    nonisolated func isBlocked(userID: String, currentUserID: String) async throws -> Bool {
        let blockedRef = database.child("users/\(currentUserID)/blockedUsers/\(userID)")
        let snapshot = try await blockedRef.getData()

        let isBlocked = snapshot.exists()
        if isBlocked {
            print("🚫 User is blocked: \(userID)")
        }

        return isBlocked
    }

    // MARK: - Channel Operations

    /// Adds a user to a channel by updating participantIDs in Firestore and RTDB
    /// - Parameters:
    ///   - userID: User ID to add
    ///   - channelID: Channel ID (conversation ID)
    /// - Throws: Database errors
    nonisolated func addUserToChannel(userID: String, channelID: String) async throws {
        // 1. Update Firestore conversation document
        let firestoreRef = Firestore.firestore().collection("conversations").document(channelID)

        // Add user to participantIDs array (using FieldValue.arrayUnion for atomic operation)
        try await firestoreRef.updateData([
            "participantIDs": FieldValue.arrayUnion([userID])
        ])

        print("✅ User \(userID) added to channel \(channelID) in Firestore")

        // 2. Update RTDB conversation (convert array to object format for security rules)
        let rtdbRef = database.child("conversations/\(channelID)/participantIDs/\(userID)")
        try await rtdbRef.setValue(true)

        print("✅ User \(userID) added to channel \(channelID) in RTDB")
    }

    /// Auto-joins user to all default channels on signup
    /// - Parameter userID: User ID to add to channels
    /// - Throws: Database errors
    nonisolated func autoJoinDefaultChannels(userID: String) async throws {
        let defaultChannelIDs = ["general", "announcements", "off-topic"]

        print("🔵 Auto-joining user \(userID) to default channels...")

        for channelID in defaultChannelIDs {
            do {
                try await addUserToChannel(userID: userID, channelID: channelID)
            } catch {
                // Log but don't fail - allow signup to succeed even if auto-join fails
                print("⚠️ Failed to add user to channel \(channelID): \(error.localizedDescription)")
            }
        }

        print("✅ User \(userID) auto-joined to default channels")
    }

    // MARK: - System Messages

    /// Creates and sends a system message to RTDB
    /// - Parameters:
    ///   - text: System message text (e.g., "Alice created the group")
    ///   - conversationID: Conversation ID
    ///   - messageID: Optional message ID (generates UUID if not provided)
    /// - Throws: Database errors
    nonisolated func sendSystemMessage(
        text: String,
        conversationID: String,
        messageID: String = UUID().uuidString
    ) async throws {
        let messageRef = database.child("messages/\(conversationID)/\(messageID)")

        let messageData: [String: Any] = [
            "senderID": "system",
            "text": text,
            "serverTimestamp": ServerValue.timestamp(),
            "status": "sent",
            "isSystemMessage": true
        ]

        try await messageRef.setValue(messageData)
        print("✅ System message sent to RTDB: \(messageID)")
    }
}
