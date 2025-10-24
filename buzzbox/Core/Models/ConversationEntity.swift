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

    // MARK: - Channel Metadata

    /// Channel emoji icon (for visual identity in card view)
    var channelEmoji: String?

    /// Channel description (short description of channel purpose)
    var channelDescription: String?

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

    // MARK: - AI Conversation Analysis (Story 6.11)

    /// Overall conversation sentiment (positive, negative, neutral, urgent)
    var aiSentiment: String?

    /// Conversation category (fan, super_fan, business, spam, urgent)
    var aiCategory: String?

    /// Business opportunity score (0-10, only set if category is 'business')
    var aiBusinessScore: Int?

    /// Timestamp when conversation was last analyzed by AI
    var aiAnalyzedAt: Date?

    /// Number of new messages since last analysis (for triggering re-analysis)
    var messageCountSinceAnalysis: Int

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
        channelEmoji: String? = nil,
        channelDescription: String? = nil,
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
        self.channelEmoji = channelEmoji
        self.channelDescription = channelDescription
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isPinned = false
        self.isMuted = false
        self.isArchived = false
        self.unreadCount = 0
        self.syncStatus = syncStatus
        self.messages = []

        // AI Conversation Analysis (Story 6.11)
        // Default to neutral sentiment and fan category for new conversations
        self.aiSentiment = "neutral"
        self.aiCategory = "fan"
        self.aiBusinessScore = nil
        self.aiAnalyzedAt = nil
        self.messageCountSinceAnalysis = 0
    }

    // MARK: - Helper Methods

    /// Update conversation with latest message
    func updateWithMessage(_ message: MessageEntity) {
        self.lastMessageText = message.text
        self.lastMessageAt = message.localCreatedAt
        self.lastMessageSenderID = message.senderID
        self.updatedAt = Date()

        // 🆕 Story 6.11: Increment message count for AI analysis triggering
        self.messageCountSinceAnalysis += 1
        print("📊 [ENTITY] Message count incremented for conv \(self.id.prefix(8)): \(self.messageCountSinceAnalysis)")
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
        guard isCreatorOnly else {
            return true
        }

        // Only creator can post to creator-only channels
        let result = isCreator
        return result
    }
}
