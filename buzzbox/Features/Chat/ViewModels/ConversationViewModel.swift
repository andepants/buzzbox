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
            print("❌ [DM-CREATE] Unexpected error in createDMWithCreator:")
            print("   Error type: \(type(of: error))")
            print("   Error: \(error)")
            print("   Localized description: \(error.localizedDescription)")
            if let nsError = error as? NSError {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   User info: \(nsError.userInfo)")
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
        print("🔵 [CONVERSATION] Creating conversation: current=\(currentUserID), recipient=\(userID)")
        isLoading = true
        defer { isLoading = false }

        // Step 1: Validate recipient exists
        print("🔵 [CONVERSATION] Step 1: Fetching recipient user...")
        guard let recipient = try? await conversationService.getUser(userID: userID) else {
            print("❌ [CONVERSATION] Recipient not found: \(userID)")
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }
        print("✅ [CONVERSATION] Recipient found: \(recipient.email) (type: \(recipient.userType.rawValue))")

        // Step 2: Validate current user exists
        print("🔵 [CONVERSATION] Step 2: Fetching current user...")
        guard let sender = try? await conversationService.getUser(userID: currentUserID) else {
            print("❌ [CONVERSATION] Sender not found: \(currentUserID)")
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }
        print("✅ [CONVERSATION] Sender found: \(sender.email) (type: \(sender.userType.rawValue))")

        // Step 3: Validate DM permissions (Story 5.4)
        print("🔵 [CONVERSATION] Step 3: Validating DM permissions...")
        do {
            try conversationService.canCreateDM(from: sender, to: recipient)
            print("✅ [CONVERSATION] DM permissions validated")
        } catch let dmError as DMValidationError {
            print("❌ [CONVERSATION] DM validation failed: \(dmError.localizedDescription)")
            let error = ConversationError.dmRestricted(dmError.localizedDescription)
            self.error = error
            throw error
        }

        // Step 4: Check if user is blocked
        print("🔵 [CONVERSATION] Step 4: Checking blocked status...")
        if try await conversationService.isBlocked(userID: userID, currentUserID: currentUserID) {
            print("❌ [CONVERSATION] User is blocked")
            let error = ConversationError.userBlocked
            self.error = error
            throw error
        }
        print("✅ [CONVERSATION] User not blocked")

        // Step 5: Generate deterministic conversation ID
        // Pattern: sorted participant IDs joined with underscore
        // Example: "user123_user456" (always same regardless of who initiates)
        let participants = [currentUserID, userID].sorted()
        let conversationID = participants.joined(separator: "_")
        print("🔵 [CONVERSATION] Step 5: Generated conversation ID: \(conversationID)")

        // Step 6: Check local SwiftData first (optimistic)
        print("🔵 [CONVERSATION] Step 6: Checking local SwiftData...")
        let localDescriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )

        if let existing = try? modelContext.fetch(localDescriptor).first {
            print("✅ [CONVERSATION] Found existing conversation locally: \(conversationID)")
            return existing
        }
        print("🔵 [CONVERSATION] No existing conversation found locally")

        // Step 7: Check RTDB for existing conversation (handles simultaneous creation)
        print("🔵 [CONVERSATION] Step 7: Checking RTDB for existing conversation...")
        do {
            if let remoteConversation = try await conversationService.findConversation(id: conversationID) {
                print("✅ [CONVERSATION] Found existing conversation in RTDB: \(conversationID)")
                // Sync remote conversation to local SwiftData
                modelContext.insert(remoteConversation)
                try modelContext.save()

                // Haptic feedback
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif

                print("✅ [CONVERSATION] Synced remote conversation to local: \(conversationID)")
                return remoteConversation
            }
            print("🔵 [CONVERSATION] No existing conversation in RTDB")
        } catch {
            print("⚠️ [CONVERSATION] Error checking RTDB (will create new): \(error)")
        }

        // Step 8: Create new conversation
        print("🔵 [CONVERSATION] Step 8: Creating new conversation entity...")
        let conversation = ConversationEntity(
            id: conversationID, // Deterministic!
            participantIDs: participants,
            displayName: nil,
            isGroup: false,
            createdAt: Date(),
            syncStatus: .pending
        )

        // Step 9: Save locally first (optimistic UI)
        print("🔵 [CONVERSATION] Step 9: Saving conversation to SwiftData...")
        do {
            modelContext.insert(conversation)
            try modelContext.save()
            print("✅ [CONVERSATION] Created new conversation locally: \(conversationID)")
        } catch {
            print("❌ [CONVERSATION] Failed to save conversation to SwiftData: \(error)")
            throw error
        }

        // Step 10: Sync to RTDB in background
        print("🔵 [CONVERSATION] Step 10: Starting background RTDB sync...")
        Task { @MainActor in
            do {
                try await conversationService.syncConversation(conversation)
                conversation.syncStatus = .synced
                try? modelContext.save()

                // Haptic feedback
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif

                print("✅ [CONVERSATION] Conversation synced to RTDB: \(conversationID)")
            } catch {
                print("❌ [CONVERSATION] Failed to sync conversation to RTDB:")
                print("   Error: \(error)")
                print("   Localized: \(error.localizedDescription)")
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
            print("⚠️ Cannot start listener: No authenticated user")
            return
        }

        print("🎧 [LISTENER] Starting RTDB listener for user: \(currentUserID)")

        let conversationsRef = Database.database().reference().child("conversations")

        realtimeListenerHandle = conversationsRef.observe(.value) { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("📡 [LISTENER] Received snapshot with \(snapshot.childrenCount) conversations")
                await self.processConversationSnapshot(snapshot, currentUserID: currentUserID)
            }
        }

        print("👂 Started real-time RTDB listener for conversations")
    }

    /// Stops the real-time RTDB listener
    func stopRealtimeListener() {
        if let handle = realtimeListenerHandle {
            Database.database().reference().child("conversations").removeObserver(withHandle: handle)
            realtimeListenerHandle = nil
            print("🛑 Stopped real-time RTDB listener")
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
            print("🔄 Manual sync complete")
        } catch {
            self.error = .networkError
            print("❌ Manual sync failed: \(error)")
        }
    }

    /// Processes conversation snapshot from RTDB
    private func processConversationSnapshot(_ snapshot: DataSnapshot, currentUserID: String) async {
        print("🔄 [SYNC] Processing conversations for user: \(currentUserID)")
        var processedCount = 0
        var skippedCount = 0

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any] else {
                print("⚠️ [SYNC] Skipping conversation \(child.key): invalid data format")
                continue
            }

            let conversationID = child.key
            let isGroup = conversationData["isGroup"] as? Bool ?? false
            let groupName = conversationData["groupName"] as? String ?? "Unknown"

            // Parse participantIDs from RTDB object format {uid: true} to array [uid]
            let participantIDsDict = conversationData["participantIDs"] as? [String: Any] ?? [:]
            let participantIDs = Array(participantIDsDict.keys)

            print("📋 [SYNC] Conversation: \(conversationID) | isGroup: \(isGroup) | name: \(groupName) | participants: \(participantIDs.count)")

            guard participantIDs.contains(currentUserID) else {
                print("⏭️  [SYNC] Skipping \(conversationID): user not in participantIDs (\(participantIDs.count) participants)")
                skippedCount += 1
                continue
            }

            // Parse adminUserIDs from RTDB object format
            let adminUserIDsDict = conversationData["adminUserIDs"] as? [String: Any] ?? [:]
            let adminUserIDs = Array(adminUserIDsDict.keys)

            // Parse group fields (already declared above for logging)
            let groupPhotoURL = conversationData["groupPhotoURL"] as? String
            let isCreatorOnly = conversationData["isCreatorOnly"] as? Bool ?? false

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
                    createdAt: Date(timeIntervalSince1970: createdAtMillis / 1000),
                    syncStatus: .synced
                )

                // Update last message fields
                conversation.lastMessageText = conversationData["lastMessage"] as? String
                conversation.lastMessageAt = Date(timeIntervalSince1970: lastMessageMillis / 1000)
                conversation.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                conversation.updatedAt = Date(timeIntervalSince1970: updatedAtMillis / 1000)

                modelContext.insert(conversation)
                print("➕ [SYNC] New conversation: \(conversationID) | isGroup: \(isGroup) | name: \(groupName)")
                processedCount += 1
            } else if let existing = existing {
                // Update existing conversation
                existing.participantIDs = participantIDs
                existing.adminUserIDs = adminUserIDs
                existing.displayName = groupName
                existing.groupPhotoURL = groupPhotoURL
                existing.isGroup = isGroup
                existing.isCreatorOnly = isCreatorOnly
                existing.lastMessageText = conversationData["lastMessage"] as? String
                existing.lastMessageAt = Date(timeIntervalSince1970: lastMessageMillis / 1000)
                existing.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                existing.updatedAt = Date(timeIntervalSince1970: updatedAtMillis / 1000)
                print("🔄 [SYNC] Updated conversation: \(conversationID) | isGroup: \(isGroup)")
                processedCount += 1
            }

            try? modelContext.save()
        }

        print("✅ [SYNC] Complete: \(processedCount) conversations synced, \(skippedCount) skipped")
    }

    // MARK: - Cleanup

    deinit {
        // Clean up listener in nonisolated context
        // Database reference calls are safe to make from any thread
        if let handle = realtimeListenerHandle {
            Database.database().reference().child("conversations").removeObserver(withHandle: handle)
            print("🛑 Stopped real-time RTDB listener (deinit)")
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
