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
    private var realtimeListenerHandle: DatabaseHandle?

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
        guard let recipient = try? await conversationService.getUser(userID: userID) else {
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }

        // Step 2: Validate current user exists
        guard let sender = try? await conversationService.getUser(userID: currentUserID) else {
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

        // Step 3: Generate deterministic conversation ID
        // Pattern: sorted participant IDs joined with underscore
        // Example: "user123_user456" (always same regardless of who initiates)
        let participants = [currentUserID, userID].sorted()
        let conversationID = participants.joined(separator: "_")

        // Step 4: Check local SwiftData first (optimistic)
        let localDescriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )

        if let existing = try? modelContext.fetch(localDescriptor).first {
            print("✅ Found existing conversation locally: \(conversationID)")
            return existing
        }

        // Step 5: Check RTDB for existing conversation (handles simultaneous creation)
        if let remoteConversation = try await conversationService.findConversation(id: conversationID) {
            // Sync remote conversation to local SwiftData
            modelContext.insert(remoteConversation)
            try modelContext.save()

            // Haptic feedback
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif

            print("✅ Synced remote conversation to local: \(conversationID)")
            return remoteConversation
        }

        // Step 6: Create new conversation
        let conversation = ConversationEntity(
            id: conversationID, // Deterministic!
            participantIDs: participants,
            displayName: nil,
            isGroup: false,
            createdAt: Date(),
            syncStatus: .pending
        )

        // Step 7: Save locally first (optimistic UI)
        modelContext.insert(conversation)
        try modelContext.save()

        print("✅ Created new conversation locally: \(conversationID)")

        // Step 8: Sync to RTDB in background
        Task { @MainActor in
            do {
                try await conversationService.syncConversation(conversation)
                conversation.syncStatus = .synced
                try? modelContext.save()

                // Haptic feedback
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif

                print("✅ Conversation synced to RTDB: \(conversationID)")
            } catch {
                conversation.syncStatus = .failed
                self.error = .creationFailed
                try? modelContext.save()
                print("❌ Failed to sync conversation to RTDB: \(error)")
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

        let conversationsRef = Database.database().reference().child("conversations")

        realtimeListenerHandle = conversationsRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            Task { @MainActor in
                await self.processConversationSnapshot(snapshot, currentUserID: currentUserID)
            }
        }

        print("👂 Started real-time RTDB listener for conversations")
    }

    /// Stops the real-time RTDB listener
    nonisolated func stopRealtimeListener() {
        Task { @MainActor in
            if let handle = realtimeListenerHandle {
                Database.database().reference().child("conversations").removeObserver(withHandle: handle)
                realtimeListenerHandle = nil
                print("🛑 Stopped real-time RTDB listener")
            }
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
        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any] else { continue }

            // Check if current user is participant
            let participantIDs = conversationData["participantIDs"] as? [String] ?? []
            guard participantIDs.contains(currentUserID) else { continue }

            let conversationID = child.key

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
                    displayName: nil,
                    isGroup: false,
                    createdAt: Date(
                        timeIntervalSince1970: conversationData["createdAt"] as? TimeInterval ?? 0
                    ),
                    syncStatus: .synced
                )

                // Update last message fields
                conversation.lastMessageText = conversationData["lastMessage"] as? String
                conversation.lastMessageAt = Date(
                    timeIntervalSince1970: conversationData["lastMessageTimestamp"] as? TimeInterval ?? 0
                )
                conversation.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                conversation.updatedAt = Date(
                    timeIntervalSince1970: conversationData["updatedAt"] as? TimeInterval ?? 0
                )

                modelContext.insert(conversation)
                print("➕ New conversation from RTDB: \(conversationID)")
            } else if let existing = existing {
                // Update existing conversation
                existing.lastMessageText = conversationData["lastMessage"] as? String
                existing.lastMessageAt = Date(
                    timeIntervalSince1970: conversationData["lastMessageTimestamp"] as? TimeInterval ?? 0
                )
                existing.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                existing.updatedAt = Date(
                    timeIntervalSince1970: conversationData["updatedAt"] as? TimeInterval ?? 0
                )
                print("🔄 Updated conversation: \(conversationID)")
            }

            try? modelContext.save()
        }
    }

    // MARK: - Cleanup

    deinit {
        stopRealtimeListener()
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
