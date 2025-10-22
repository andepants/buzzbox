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

/// ViewModel for managing conversation operations
@MainActor
@Observable
final class ConversationViewModel {
    // MARK: - Properties

    var isLoading = false
    var error: ConversationError?

    private let modelContext: ModelContext
    private let conversationService: ConversationService

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        conversationService: ConversationService = .shared
    ) {
        self.modelContext = modelContext
        self.conversationService = conversationService
    }

    // MARK: - Conversation Operations

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
        guard let _ = try? await conversationService.getUser(userID: userID) else {
            let error = ConversationError.recipientNotFound
            self.error = error
            throw error
        }

        // Step 2: Check if user is blocked
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
}

// MARK: - Conversation Errors

/// Errors that can occur during conversation operations
enum ConversationError: LocalizedError {
    case recipientNotFound
    case userBlocked
    case creationFailed
    case networkError

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
        }
    }
}
