/// ConversationEntity.swift
///
/// SwiftData model for conversation storage with participant management.
/// Maintains conversation state, unread counts, and message relationships.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class ConversationEntity {
    // MARK: - Core Properties

    /// Unique conversation identifier (matches Firestore document ID)
    @Attribute(.unique) var id: String

    /// Array of participant user IDs
    var participantIDs: [String]

    /// Conversation display name (for groups)
    var displayName: String?

    /// Conversation avatar URL (for groups) - Legacy field
    var avatarURL: String?

    /// Group photo URL (Firebase Storage URL for group photos)
    var groupPhotoURL: String?

    /// Array of admin user IDs (can modify group settings)
    var adminUserIDs: [String]

    /// Is this a group conversation?
    var isGroup: Bool

    /// Is this a creator-only channel (only creator can post)?
    var isCreatorOnly: Bool

    /// Creation timestamp
    var createdAt: Date

    /// Last update timestamp (when last message was sent)
    var updatedAt: Date

    // MARK: - Conversation State

    /// Is conversation pinned?
    var isPinned: Bool

    /// Is conversation muted?
    var isMuted: Bool

    /// Is conversation archived?
    var isArchived: Bool

    /// Unread message count
    var unreadCount: Int

    /// Last message preview text
    var lastMessageText: String?

    /// Last message timestamp
    var lastMessageAt: Date?

    /// Last message sender ID
    var lastMessageSenderID: String?

    // MARK: - Sync Status

    /// Sync status for offline-first architecture
    var syncStatus: SyncStatus

    // MARK: - AI Metadata

    /// Supermemory conversation ID for RAG context
    var supermemoryConversationID: String?

    // MARK: - Relationships

    /// All messages in this conversation (cascade delete)
    @Relationship(deleteRule: .cascade)
    var messages: [MessageEntity]

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        participantIDs: [String],
        displayName: String? = nil,
        groupPhotoURL: String? = nil,
        adminUserIDs: [String] = [],
        isGroup: Bool = false,
        isCreatorOnly: Bool = false,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.participantIDs = participantIDs
        self.displayName = displayName
        self.groupPhotoURL = groupPhotoURL
        self.adminUserIDs = adminUserIDs
        self.isGroup = isGroup
        self.isCreatorOnly = isCreatorOnly
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isPinned = false
        self.isMuted = false
        self.isArchived = false
        self.unreadCount = 0
        self.syncStatus = syncStatus
        self.messages = []
    }

    // MARK: - Helper Methods

    /// Update conversation with latest message
    func updateWithMessage(_ message: MessageEntity) {
        self.lastMessageText = message.text
        self.lastMessageAt = message.localCreatedAt
        self.lastMessageSenderID = message.senderID
        self.updatedAt = Date()
    }

    /// Increment unread count
    func incrementUnreadCount() {
        self.unreadCount += 1
    }

    /// Reset unread count (when conversation is opened)
    func markAsRead() {
        self.unreadCount = 0
    }

    /// Get sorted messages (newest first)
    var sortedMessages: [MessageEntity] {
        messages.sorted { $0.localCreatedAt > $1.localCreatedAt }
    }

    /// Get messages pending sync
    var pendingSyncMessages: [MessageEntity] {
        messages.filter { $0.isPendingSync }
    }

    /// Get recipient ID (other participant in one-on-one conversation)
    /// For use in ConversationViewModel to avoid async property access
    func getRecipientID(currentUserID: String) -> String? {
        participantIDs.first(where: { $0 != currentUserID })
    }

    /// Check if user can post to this conversation
    /// - Parameter isCreator: Whether the current user is the creator
    /// - Returns: True if user can post, false otherwise
    func canUserPost(isCreator: Bool) -> Bool {
        // If not a creator-only channel, everyone can post
        guard isCreatorOnly else { return true }

        // Only creator can post to creator-only channels
        return isCreator
    }
}
