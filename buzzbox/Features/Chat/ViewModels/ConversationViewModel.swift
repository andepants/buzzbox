/// ConversationViewModel.swift
///
/// ViewModel for conversation management with optimistic UI
/// Handles conversation creation, duplicate prevention, and RTDB sync
///
/// Created: 2025-10-21
/// [Source: Story 2.1 - Create New Conversation]

import SwiftUI
import SwiftData
import FirebaseDatabase
import FirebaseFirestore
import FirebaseAuth

/// ViewModel for managing conversation operations
@MainActor
@Observable
final class ConversationViewModel {
    // MARK: - Properties

    var isLoading = false
    var error: ConversationError?

    private let modelContext: ModelContext
    private let conversationService: ConversationService
    nonisolated(unsafe) private var realtimeListenerHandle: DatabaseHandle?

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        conversationService: ConversationService = .shared
    ) {
        self.modelContext = modelContext
        self.conversationService = conversationService
    }

    // MARK: - Conversation Operations

    /// Creates a DM with the creator (Andrew) - simplified for fans
    /// - Parameter currentUserID: Current authenticated user ID
    /// - Returns: ConversationEntity for DM with creator
    /// - Throws: ConversationError if creator not found or validation fails
    func createDMWithCreator(currentUserID: String) async throws -> ConversationEntity {
        isLoading = true
        defer { isLoading = false }

        // Get creator user from Firestore
        // Creator email is hardcoded (Story 5.2)
        let creatorEmail = "andrewsheim@gmail.com"

        do {
            // Find creator by querying Firestore users collection
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .whereField("email", isEqualTo: creatorEmail)
                .limit(to: 1)
                .getDocuments()

            guard let creatorDoc = snapshot.documents.first else {
                let error = ConversationError.recipientNotFound
                self.error = error
                throw error
            }

            let creatorID = creatorDoc.documentID

            // Create conversation with creator
            return try await createConversation(
                withUserID: creatorID,
                currentUserID: currentUserID
            )
        } catch let error as ConversationError {
            throw error
        } catch {
            // Log the actual error for debugging
            if let nsError = error as? NSError {
            }

            let convError = ConversationError.creationFailed
            self.error = convError
            throw convError
        }
    }

    /// Creates a new one-on-one conversation with deterministic ID
    /// - Parameters:
    ///   - userID: Recipient user ID
    ///   - currentUserID: Current authenticated user ID
    /// - Returns: ConversationEntity (new or existing)
    /// - Throws: ConversationError for validation/creation failures
    func createConversation(
        withUserID userID: String,
        currentUserID: String
    ) async throws -> ConversationEntity {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Validate recipient exists
        guard let recipient = try? await conversationService.getUser(userID: userID, modelContext: modelContext) else {
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }

        // Step 2: Validate current user exists
        guard let sender = try? await conversationService.getUser(userID: currentUserID, modelContext: modelContext) else {
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }

        // Step 3: Validate DM permissions (Story 5.4)
        do {
            try conversationService.canCreateDM(from: sender, to: recipient)
        } catch let dmError as DMValidationError {
            let error = ConversationError.dmRestricted(dmError.localizedDescription)
            self.error = error
            throw error
        }

        // Step 4: Check if user is blocked
        if try await conversationService.isBlocked(userID: userID, currentUserID: currentUserID) {
            let error = ConversationError.userBlocked
            self.error = error
            throw error
        }

        // Step 5: Generate deterministic conversation ID
        // Pattern: sorted participant IDs joined with underscore
        // Example: "user123_user456" (always same regardless of who initiates)
        let participants = [currentUserID, userID].sorted()
        let conversationID = participants.joined(separator: "_")

        // Step 6: Check local SwiftData first (optimistic)
        let localDescriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )

        if let existing = try? modelContext.fetch(localDescriptor).first {
            return existing
        }

        // Step 7: Check RTDB for existing conversation (handles simultaneous creation)
        do {
            if let remoteConversation = try await conversationService.findConversation(id: conversationID) {
                // Sync remote conversation to local SwiftData
                modelContext.insert(remoteConversation)
                try modelContext.save()

                // Haptic feedback
                #if os(iOS)
                HapticFeedback.impact(.light)
                #endif

                return remoteConversation
            }
        } catch {
        }

        // Step 8: Create new conversation
        let conversation = ConversationEntity(
            id: conversationID, // Deterministic!
            participantIDs: participants,
            displayName: nil,
            isGroup: false,
            createdAt: Date(),
            syncStatus: .pending
        )

        // Step 9: Save locally first (optimistic UI)
        do {
            modelContext.insert(conversation)
            try modelContext.save()
        } catch {
            throw error
        }

        // Step 10: Sync to RTDB in background
        Task { @MainActor in
            do {
                try await conversationService.syncConversation(conversation)
                conversation.syncStatus = .synced
                try? modelContext.save()

                // Haptic feedback
                #if os(iOS)
                HapticFeedback.impact(.light)
                #endif

            } catch {
                conversation.syncStatus = .failed
                self.error = .creationFailed
                try? modelContext.save()
            }
        }

        return conversation
    }

    // MARK: - Real-Time Listener

    /// Starts listening to RTDB for conversation updates
    /// [Source: Story 2.2 - Real-time RTDB listener]
    func startRealtimeListener() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }


        // Ensure user is in default channels (handles existing users + new users)
        // This is idempotent and safe to call on every app launch
        do {
            try await conversationService.ensureUserInDefaultChannels(userID: currentUserID)
        } catch {
            // Log but don't fail - allow app to continue
        }

        let conversationsRef = Database.database().reference().child("conversations")

        // FORCE INITIAL DATA LOAD: Get snapshot immediately before setting up listener
        // This eliminates race condition between @Query and listener
        do {
            let initialSnapshot = try await conversationsRef.getData()
            await processConversationSnapshot(initialSnapshot, currentUserID: currentUserID)
        } catch {
        }

        // Now set up real-time listener for ongoing updates
        realtimeListenerHandle = conversationsRef.observe(.value) { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.processConversationSnapshot(snapshot, currentUserID: currentUserID)
            }
        }

    }

    /// Stops the real-time RTDB listener
    func stopRealtimeListener() {
        if let handle = realtimeListenerHandle {
            Database.database().reference().child("conversations").removeObserver(withHandle: handle)
            realtimeListenerHandle = nil
        }
    }

    /// Manually sync conversations from RTDB (for pull-to-refresh)
    func syncConversations() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        defer { isLoading = false }

        let conversationsRef = Database.database().reference().child("conversations")

        do {
            let snapshot = try await conversationsRef.getData()
            await processConversationSnapshot(snapshot, currentUserID: currentUserID)
        } catch {
            self.error = .networkError
        }
    }

    /// Processes conversation snapshot from RTDB
    private func processConversationSnapshot(_ snapshot: DataSnapshot, currentUserID: String) async {
        var processedCount = 0
        var skippedCount = 0

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any] else {
                continue
            }

            let conversationID = child.key
            let isGroup = conversationData["isGroup"] as? Bool ?? false
            let groupName = conversationData["groupName"] as? String ?? "Unknown"

            // Parse participantIDs from RTDB object format {uid: true} to array [uid]
            let participantIDsDict = conversationData["participantIDs"] as? [String: Any] ?? [:]
            let participantIDs = Array(participantIDsDict.keys)

            guard participantIDs.contains(currentUserID) else {
                skippedCount += 1
                continue
            }

            // Parse adminUserIDs from RTDB object format
            let adminUserIDsDict = conversationData["adminUserIDs"] as? [String: Any] ?? [:]
            let adminUserIDs = Array(adminUserIDsDict.keys)

            // Parse group fields (already declared above for logging)
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

            try? modelContext.save()
        }

        if processedCount > 0 || skippedCount > 0 {
        }
    }

    // MARK: - Cleanup

    deinit {
        // Clean up listener in nonisolated context
        // Database reference calls are safe to make from any thread
        if let handle = realtimeListenerHandle {
            Database.database().reference().child("conversations").removeObserver(withHandle: handle)
        }
    }
}

// MARK: - Conversation Errors

/// Errors that can occur during conversation operations
enum ConversationError: LocalizedError {
    case recipientNotFound
    case userBlocked
    case creationFailed
    case networkError
    case dmRestricted(String)

    var errorDescription: String? {
        switch self {
        case .recipientNotFound:
            return "User not found. Please check the username and try again."
        case .userBlocked:
            return "You cannot message this user."
        case .creationFailed:
            return "Failed to create conversation. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .dmRestricted(let message):
            return message
        }
    }
}
