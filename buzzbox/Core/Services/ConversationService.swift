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

    // MARK: - DM Validation

    /// Validates whether a DM can be created between sender and recipient
    /// - Parameters:
    ///   - sender: User initiating the DM
    ///   - recipient: User receiving the DM
    /// - Throws: DMValidationError if validation fails
    /// - Note: Creator can DM anyone, fans can only DM creator
    nonisolated func canCreateDM(from sender: UserEntity, to recipient: UserEntity) throws {
        // Creator can DM anyone
        if sender.isCreator {
            return
        }

        // Fan can only DM creator
        if sender.isFan && recipient.isFan {
            throw DMValidationError.bothFans
        }

        // Fan can DM creator (allow)
        if sender.isFan && recipient.isCreator {
            return
        }
    }

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

    /// Gets a user by ID with SwiftData caching for instant access
    /// - Parameters:
    ///   - userID: User ID
    ///   - modelContext: Optional ModelContext for SwiftData caching (if provided, checks cache first)
    /// - Returns: UserEntity if found, nil otherwise
    /// - Throws: Database errors
    /// - Note: With modelContext, checks SwiftData cache first (fast <10ms), then Firestore fallback
    @MainActor
    func getUser(userID: String, modelContext: ModelContext?) async throws -> UserEntity? {
        // 1. Check SwiftData cache first (if modelContext provided)
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate { $0.id == userID }
            )

            if let cachedUser = try? modelContext.fetch(descriptor).first {
                return cachedUser
            }
        }

        // 2. Fallback to Firestore (slow network call)
        let userRef = Firestore.firestore().collection("users").document(userID)
        let snapshot = try await userRef.getDocument()

        guard snapshot.exists,
              let userData = snapshot.data() else {
            return nil
        }


        // Parse userType with fallback logic (matching AuthService pattern)
        let email = userData["email"] as? String ?? ""
        let userTypeRaw = userData["userType"] as? String
        let userType: UserType
        if let userTypeRaw = userTypeRaw, let parsedType = UserType(rawValue: userTypeRaw) {
            userType = parsedType
        } else {
            // Fallback: auto-assign based on email (andrewsheim@gmail.com = creator)
            userType = email.lowercased() == "andrewsheim@gmail.com" ? .creator : .fan
        }

        let user = UserEntity(
            id: userID,
            email: email,
            displayName: userData["displayName"] as? String ?? "",
            photoURL: userData["photoURL"] as? String,
            userType: userType
        )

        // 3. Cache in SwiftData for next time (if modelContext provided)
        if let modelContext = modelContext {
            modelContext.insert(user)
            try? modelContext.save()
        }

        return user
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
        }

        return isBlocked
    }

    // MARK: - Channel Operations

    /// Syncs all user's channels from RTDB to SwiftData (for initial load on login)
    /// - Parameters:
    ///   - userID: User ID to sync channels for
    ///   - modelContext: SwiftData ModelContext to save channels to
    /// - Note: This is called during login to pre-populate local database
    @MainActor
    func syncInitialChannels(userID: String, modelContext: ModelContext) async throws {

        // Fetch all conversations from RTDB
        let conversationsRef = database.child("conversations")
        let snapshot = try await conversationsRef.getData()

        guard snapshot.exists() else {
            return
        }

        var processedCount = 0
        var skippedCount = 0

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any] else {
                continue
            }

            let conversationID = child.key
            let isGroup = conversationData["isGroup"] as? Bool ?? false

            // Parse participantIDs from RTDB object format {uid: true} to array [uid]
            let participantIDsDict = conversationData["participantIDs"] as? [String: Any] ?? [:]
            let participantIDs = Array(participantIDsDict.keys)

            // Skip conversations user is not part of
            guard participantIDs.contains(userID) else {
                skippedCount += 1
                continue
            }

            // Parse adminUserIDs from RTDB object format
            let adminUserIDsDict = conversationData["adminUserIDs"] as? [String: Any] ?? [:]
            let adminUserIDs = Array(adminUserIDsDict.keys)

            // Parse group fields
            let groupName = conversationData["groupName"] as? String ?? "Unknown"
            let groupPhotoURL = conversationData["groupPhotoURL"] as? String
            let isCreatorOnly = conversationData["isCreatorOnly"] as? Bool ?? false
            let channelEmoji = conversationData["channelEmoji"] as? String
            let channelDescription = conversationData["channelDescription"] as? String

            // Parse timestamps (RTDB stores in milliseconds)
            let createdAtMillis = conversationData["createdAt"] as? Double ?? 0
            let updatedAtMillis = conversationData["updatedAt"] as? Double ?? 0
            let lastMessageMillis = conversationData["lastMessageTimestamp"] as? Double ?? 0

            // Check if exists locally
            let descriptor = FetchDescriptor<ConversationEntity>(
                predicate: #Predicate { $0.id == conversationID }
            )

            let existing = try? modelContext.fetch(descriptor).first

            if existing == nil {
                // New conversation from RTDB
                let conversation = ConversationEntity(
                    id: conversationID,
                    participantIDs: participantIDs,
                    displayName: groupName,
                    groupPhotoURL: groupPhotoURL,
                    adminUserIDs: adminUserIDs,
                    isGroup: isGroup,
                    isCreatorOnly: isCreatorOnly,
                    channelEmoji: channelEmoji,
                    channelDescription: channelDescription,
                    createdAt: Date(timeIntervalSince1970: createdAtMillis / 1000),
                    syncStatus: .synced
                )

                // Update last message fields
                conversation.lastMessageText = conversationData["lastMessage"] as? String
                conversation.lastMessageAt = Date(timeIntervalSince1970: lastMessageMillis / 1000)
                conversation.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                conversation.updatedAt = Date(timeIntervalSince1970: updatedAtMillis / 1000)

                modelContext.insert(conversation)
                processedCount += 1
            } else if let existing = existing {
                // Update existing conversation
                existing.participantIDs = participantIDs
                existing.adminUserIDs = adminUserIDs
                existing.displayName = groupName
                existing.groupPhotoURL = groupPhotoURL
                existing.isGroup = isGroup
                existing.isCreatorOnly = isCreatorOnly
                existing.channelEmoji = channelEmoji
                existing.channelDescription = channelDescription
                existing.lastMessageText = conversationData["lastMessage"] as? String
                existing.lastMessageAt = Date(timeIntervalSince1970: lastMessageMillis / 1000)
                existing.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                existing.updatedAt = Date(timeIntervalSince1970: updatedAtMillis / 1000)
                processedCount += 1
            }
        }

        // Save all changes to SwiftData
        try modelContext.save()

    }

    /// Syncs all users from Firestore to SwiftData for instant local access
    /// - Parameter modelContext: SwiftData ModelContext to save users to
    /// - Note: This is called during login to pre-populate user cache (eliminates network calls during channel switching)
    @MainActor
    func syncInitialUsers(modelContext: ModelContext) async throws {

        // Fetch all users from Firestore
        let usersRef = Firestore.firestore().collection("users")
        let snapshot = try await usersRef.getDocuments()

        var cachedCount = 0
        var updatedCount = 0

        for document in snapshot.documents {
            let userID = document.documentID
            let userData = document.data()

            // Parse userType with fallback logic
            let email = userData["email"] as? String ?? ""
            let userTypeRaw = userData["userType"] as? String
            let userType: UserType
            if let userTypeRaw = userTypeRaw, let parsedType = UserType(rawValue: userTypeRaw) {
                userType = parsedType
            } else {
                // Fallback: auto-assign based on email
                userType = email.lowercased() == "andrewsheim@gmail.com" ? .creator : .fan
            }

            // Check if user exists in SwiftData
            let descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate { $0.id == userID }
            )

            let existing = try? modelContext.fetch(descriptor).first

            if existing == nil {
                // New user - insert into SwiftData
                let user = UserEntity(
                    id: userID,
                    email: email,
                    displayName: userData["displayName"] as? String ?? "",
                    photoURL: userData["photoURL"] as? String,
                    userType: userType
                )
                modelContext.insert(user)
                cachedCount += 1
            } else if let existing = existing {
                // Update existing user with latest data
                existing.email = email
                existing.displayName = userData["displayName"] as? String ?? ""
                existing.photoURL = userData["photoURL"] as? String
                existing.userType = userType
                updatedCount += 1
            }
        }

        // Save all changes to SwiftData
        try modelContext.save()

    }

    /// Ensures user is in all default channels (idempotent - safe to call multiple times)
    /// - Parameter userID: User ID to add to channels
    /// - Note: This is called on app launch to handle users who signed up before auto-join was implemented
    nonisolated func ensureUserInDefaultChannels(userID: String) async throws {
        let defaultChannelIDs = ["general", "announcements", "off-topic"]


        for channelID in defaultChannelIDs {
            // Check if user is already in channel (RTDB check)
            let participantRef = database.child("conversations/\(channelID)/participantIDs/\(userID)")
            let snapshot = try await participantRef.getData()

            if snapshot.exists() {
                continue
            }

            // User not in channel - add them
            do {
                try await addUserToChannel(userID: userID, channelID: channelID)
            } catch {
                // Log but don't fail - allow app to continue
            }
        }

    }

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


        // 2. Update RTDB conversation (convert array to object format for security rules)
        let rtdbRef = database.child("conversations/\(channelID)/participantIDs/\(userID)")
        try await rtdbRef.setValue(true)

    }

    /// Auto-joins user to all default channels on signup
    /// - Parameter userID: User ID to add to channels
    /// - Throws: Database errors
    nonisolated func autoJoinDefaultChannels(userID: String) async throws {
        let defaultChannelIDs = ["general", "announcements", "off-topic"]


        for channelID in defaultChannelIDs {
            do {
                try await addUserToChannel(userID: userID, channelID: channelID)
            } catch {
                // Log but don't fail - allow signup to succeed even if auto-join fails
            }
        }

    }

    // MARK: - Auto-Create DM with Creator

    /// Auto-creates a DM conversation between a new fan and the creator (Andrew)
    /// - Parameters:
    ///   - fanUserID: The new fan's user ID
    ///   - creatorEmail: Creator's email (andrewsheim@gmail.com)
    /// - Returns: The conversation ID for the DM
    /// - Throws: Database errors
    /// - Note: This is called during signup to automatically establish a DM with Andrew
    nonisolated func autoCreateDMWithCreator(
        fanUserID: String,
        creatorEmail: String
    ) async throws -> String {

        // 1. Find creator user in Firestore
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("email", isEqualTo: creatorEmail)
            .limit(to: 1)
            .getDocuments()

        guard let creatorDoc = snapshot.documents.first else {
            throw NSError(domain: "ConversationService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Creator not found"
            ])
        }

        let creatorID = creatorDoc.documentID

        // 2. Generate deterministic conversation ID (sorted participant IDs)
        let participants = [fanUserID, creatorID].sorted()
        let conversationID = participants.joined(separator: "_")


        // 3. Check if conversation already exists in RTDB
        let conversationRef = database.child("conversations/\(conversationID)")
        let existingSnapshot = try await conversationRef.getData()

        if existingSnapshot.exists() {
            return conversationID
        }

        // 4. Create conversation in RTDB
        let participantIDsDict = participants.reduce(into: [String: Bool]()) {
            $0[$1] = true
        }

        let conversationData: [String: Any] = [
            "participantIDs": participantIDsDict,
            "lastMessage": "",
            "lastMessageTimestamp": ServerValue.timestamp(),
            "createdAt": ServerValue.timestamp(),
            "updatedAt": ServerValue.timestamp(),
            "unreadCount": 0,
            "isGroup": false,
            "isCreatorOnly": false
        ]

        try await conversationRef.setValue(conversationData)

        return conversationID
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
    }

    /// Sends a welcome message from the creator to a new fan
    /// - Parameters:
    ///   - text: Welcome message text
    ///   - conversationID: Conversation ID
    ///   - senderID: Creator's user ID
    /// - Throws: Database errors
    /// - Note: Unlike system messages, this appears as a regular message from the creator
    nonisolated func sendWelcomeMessage(
        text: String,
        conversationID: String,
        senderID: String
    ) async throws {
        let messageID = UUID().uuidString
        let messageRef = database.child("messages/\(conversationID)/\(messageID)")

        let messageData: [String: Any] = [
            "senderID": senderID,
            "text": text,
            "serverTimestamp": ServerValue.timestamp(),
            "status": "sent",
            "isSystemMessage": false
        ]

        try await messageRef.setValue(messageData)

        // Update conversation's lastMessage and lastMessageTimestamp
        let conversationRef = database.child("conversations/\(conversationID)")
        try await conversationRef.updateChildValues([
            "lastMessage": text,
            "lastMessageTimestamp": ServerValue.timestamp(),
            "updatedAt": ServerValue.timestamp()
        ])
    }
}
