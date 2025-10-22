# SwiftData Implementation Guide - Sorted

**Version:** 1.0
**Last Updated:** October 20, 2025
**Purpose:** Complete SwiftData implementation patterns with code examples for Sorted

---

## Table of Contents

1. [SwiftData @Model Entities](#1-swiftdata-model-entities)
2. [ModelContainer Setup](#2-modelcontainer-setup)
3. [@Query Usage in ViewModels](#3-query-usage-in-viewmodels)
4. [SwiftData ↔ Firestore Sync Patterns](#4-swiftdata--firestore-sync-patterns)
5. [Error Handling & Best Practices](#5-error-handling--best-practices)

---

## 1. SwiftData @Model Entities

### 1.1 Message Entity

The core message entity stores all message data locally with SwiftData.

```swift
/// MessageEntity.swift
///
/// SwiftData model for local message storage with offline-first capabilities.
/// Stores message content, AI metadata, and sync status for offline queue.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class MessageEntity {
    // MARK: - Core Properties

    /// Unique message identifier (matches Firestore document ID)
    @Attribute(.unique) var id: String

    /// Parent conversation ID
    var conversationID: String

    /// Sender's user ID
    var senderID: String

    /// Message text content
    var text: String

    /// Message creation timestamp
    var createdAt: Date

    /// Last update timestamp
    var updatedAt: Date

    // MARK: - Status & Sync

    /// Message delivery status (sending, sent, delivered, read)
    var status: MessageStatus

    /// Sync status for offline queue (pending, synced, failed)
    var syncStatus: SyncStatus

    /// Number of sync retry attempts
    var retryCount: Int

    /// Last sync attempt timestamp
    var lastSyncAttempt: Date?

    /// Sync error message (if failed)
    var syncError: String?

    // MARK: - Read Receipts

    /// Array of user IDs who have read this message
    var readBy: [String]

    // MARK: - AI Metadata

    /// AI-generated category (Fan, Business, Spam, Urgent)
    var category: MessageCategory?

    /// Confidence score for category (0.0 - 1.0)
    var categoryConfidence: Double?

    /// Sentiment analysis result
    var sentiment: MessageSentiment?

    /// Sentiment intensity (low, medium, high)
    var sentimentIntensity: SentimentIntensity?

    /// Opportunity score (0-100) for business messages
    var opportunityScore: Int?

    /// FAQ match ID (if detected)
    var faqMatchID: String?

    /// FAQ confidence score (0.0 - 1.0)
    var faqConfidence: Double?

    /// AI-generated draft reply
    var smartReplyDraft: String?

    /// Supermemory reference ID
    var supermemoryID: String?

    // MARK: - Relationships

    /// Parent conversation (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \ConversationEntity.messages)
    var conversation: ConversationEntity?

    /// Message attachments (cascade delete)
    @Relationship(deleteRule: .cascade)
    var attachments: [AttachmentEntity]

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        conversationID: String,
        senderID: String,
        text: String,
        createdAt: Date = Date(),
        status: MessageStatus = .sending,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.status = status
        self.syncStatus = syncStatus
        self.retryCount = 0
        self.readBy = []
        self.attachments = []
    }

    // MARK: - Helper Methods

    /// Mark message as synced with Firestore
    func markAsSynced() {
        self.syncStatus = .synced
        self.syncError = nil
        self.updatedAt = Date()
    }

    /// Mark message as failed sync with error
    func markAsFailed(error: String) {
        self.syncStatus = .failed
        self.syncError = error
        self.retryCount += 1
        self.lastSyncAttempt = Date()
        self.updatedAt = Date()
    }

    /// Check if message should be retried
    var shouldRetry: Bool {
        syncStatus == .failed && retryCount < 3
    }

    /// Check if message is pending sync
    var isPendingSync: Bool {
        syncStatus == .pending || (syncStatus == .failed && shouldRetry)
    }
}

// MARK: - Supporting Enums

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
}

enum SyncStatus: String, Codable {
    case pending
    case synced
    case failed
}

enum MessageCategory: String, Codable {
    case fan
    case business
    case spam
    case urgent
}

enum MessageSentiment: String, Codable {
    case positive
    case negative
    case urgent
    case neutral
}

enum SentimentIntensity: String, Codable {
    case low
    case medium
    case high
}
```

### 1.2 Conversation Entity

Stores conversation metadata and manages relationships with messages.

```swift
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

    /// Conversation avatar URL (for groups)
    var avatarURL: String?

    /// Is this a group conversation?
    var isGroup: Bool

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
        isGroup: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.participantIDs = participantIDs
        self.displayName = displayName
        self.isGroup = isGroup
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isPinned = false
        self.isMuted = false
        self.isArchived = false
        self.unreadCount = 0
        self.messages = []
    }

    // MARK: - Helper Methods

    /// Update conversation with latest message
    func updateWithMessage(_ message: MessageEntity) {
        self.lastMessageText = message.text
        self.lastMessageAt = message.createdAt
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
        messages.sorted { $0.createdAt > $1.createdAt }
    }

    /// Get messages pending sync
    var pendingSyncMessages: [MessageEntity] {
        messages.filter { $0.isPendingSync }
    }
}
```

### 1.3 User Entity

Stores local user data and preferences.

```swift
/// UserEntity.swift
///
/// SwiftData model for local user data, preferences, and FAQ library.
/// Stores current user profile and AI feature settings.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class UserEntity {
    // MARK: - Core Properties

    /// Unique user identifier (matches Firebase Auth UID)
    @Attribute(.unique) var id: String

    /// User email address
    var email: String

    /// Display name
    var displayName: String

    /// Profile photo URL
    var photoURL: String?

    /// Account creation timestamp
    var createdAt: Date

    /// Last profile update timestamp
    var updatedAt: Date

    // MARK: - AI Preferences

    /// Enable auto-categorization
    var enableCategorization: Bool

    /// Enable smart reply drafts
    var enableSmartReply: Bool

    /// Enable FAQ auto-detection
    var enableFAQ: Bool

    /// Enable sentiment analysis
    var enableSentiment: Bool

    /// Enable opportunity scoring
    var enableOpportunityScoring: Bool

    /// Allow Supermemory storage (privacy setting)
    var allowSupermemoryStorage: Bool

    // MARK: - FAQ Library

    /// User's FAQ library (cascade delete)
    @Relationship(deleteRule: .cascade)
    var faqs: [FAQEntity]

    // MARK: - Initialization

    init(
        id: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.updatedAt = createdAt

        // Default AI preferences (all enabled)
        self.enableCategorization = true
        self.enableSmartReply = true
        self.enableFAQ = true
        self.enableSentiment = true
        self.enableOpportunityScoring = true
        self.allowSupermemoryStorage = true

        self.faqs = []
    }

    // MARK: - Helper Methods

    /// Update profile information
    func updateProfile(displayName: String? = nil, photoURL: String? = nil) {
        if let displayName = displayName {
            self.displayName = displayName
        }
        if let photoURL = photoURL {
            self.photoURL = photoURL
        }
        self.updatedAt = Date()
    }

    /// Toggle AI feature
    func setAIFeature(_ feature: AIFeature, enabled: Bool) {
        switch feature {
        case .categorization:
            self.enableCategorization = enabled
        case .smartReply:
            self.enableSmartReply = enabled
        case .faq:
            self.enableFAQ = enabled
        case .sentiment:
            self.enableSentiment = enabled
        case .opportunityScoring:
            self.enableOpportunityScoring = enabled
        }
        self.updatedAt = Date()
    }
}

// MARK: - Supporting Enums

enum AIFeature {
    case categorization
    case smartReply
    case faq
    case sentiment
    case opportunityScoring
}
```

### 1.4 Attachment Entity

Stores media file metadata with upload tracking.

```swift
/// AttachmentEntity.swift
///
/// SwiftData model for message attachments (images, videos, files).
/// Tracks upload status and stores local/remote URLs.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class AttachmentEntity {
    // MARK: - Core Properties

    /// Unique attachment identifier
    @Attribute(.unique) var id: String

    /// Attachment type (image, video, audio, document)
    var type: AttachmentType

    /// Remote URL (Firebase Storage)
    var url: String?

    /// Local file URL (for offline access)
    var localURL: String?

    /// Thumbnail URL (for images/videos)
    var thumbnailURL: String?

    /// File size in bytes
    var fileSize: Int64

    /// MIME type
    var mimeType: String

    /// Original file name
    var fileName: String

    /// Upload status
    var uploadStatus: UploadStatus

    /// Upload progress (0.0 - 1.0)
    var uploadProgress: Double

    /// Upload error message (if failed)
    var uploadError: String?

    /// Creation timestamp
    var createdAt: Date

    // MARK: - Relationships

    /// Parent message (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \MessageEntity.attachments)
    var message: MessageEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        localURL: String,
        fileSize: Int64,
        mimeType: String,
        fileName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.localURL = localURL
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.fileName = fileName
        self.uploadStatus = .pending
        self.uploadProgress = 0.0
        self.createdAt = createdAt
    }

    // MARK: - Helper Methods

    /// Update upload progress
    func updateUploadProgress(_ progress: Double) {
        self.uploadProgress = min(max(progress, 0.0), 1.0)
    }

    /// Mark upload as completed
    func markAsUploaded(url: String, thumbnailURL: String? = nil) {
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.uploadStatus = .completed
        self.uploadProgress = 1.0
        self.uploadError = nil
    }

    /// Mark upload as failed
    func markAsFailed(error: String) {
        self.uploadStatus = .failed
        self.uploadError = error
    }

    /// Check if attachment is ready to display
    var isAvailable: Bool {
        uploadStatus == .completed && url != nil
    }
}

// MARK: - Supporting Enums

enum AttachmentType: String, Codable {
    case image
    case video
    case audio
    case document
}

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
}
```

### 1.5 FAQ Entity

Stores user's FAQ library for auto-responder feature.

```swift
/// FAQEntity.swift
///
/// SwiftData model for FAQ library storage.
/// Stores frequently asked questions and their answers.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class FAQEntity {
    // MARK: - Core Properties

    /// Unique FAQ identifier
    @Attribute(.unique) var id: String

    /// FAQ category (equipment, software, business, etc.)
    var category: FAQCategory

    /// Question pattern (what the user might ask)
    var questionPattern: String

    /// Pre-written answer
    var answer: String

    /// Number of times this FAQ was used
    var usageCount: Int

    /// Last time this FAQ was used
    var lastUsedAt: Date?

    /// Is this FAQ enabled?
    var isEnabled: Bool

    /// Creation timestamp
    var createdAt: Date

    /// Last update timestamp
    var updatedAt: Date

    // MARK: - Relationships

    /// Owner user (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \UserEntity.faqs)
    var user: UserEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        category: FAQCategory,
        questionPattern: String,
        answer: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.questionPattern = questionPattern
        self.answer = answer
        self.usageCount = 0
        self.isEnabled = true
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    // MARK: - Helper Methods

    /// Increment usage count
    func recordUsage() {
        self.usageCount += 1
        self.lastUsedAt = Date()
        self.updatedAt = Date()
    }

    /// Update FAQ content
    func update(questionPattern: String? = nil, answer: String? = nil) {
        if let questionPattern = questionPattern {
            self.questionPattern = questionPattern
        }
        if let answer = answer {
            self.answer = answer
        }
        self.updatedAt = Date()
    }
}

// MARK: - Supporting Enums

enum FAQCategory: String, Codable, CaseIterable {
    case equipment = "Equipment"
    case software = "Software"
    case business = "Business"
    case personal = "Personal"
    case career = "Career"
    case other = "Other"
}
```

---

## 2. ModelContainer Setup

### 2.1 App.swift Setup

Complete ModelContainer configuration in the main App file.

```swift
/// SortedApp.swift
///
/// Main app entry point with SwiftData ModelContainer configuration.
/// Sets up the data model schema and initializes the container.
///
/// Created: 2025-10-20

import SwiftUI
import SwiftData

@main
struct SortedApp: App {
    // MARK: - Properties

    /// Shared model container for the app
    let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        do {
            // Define the schema with all model types
            let schema = Schema([
                MessageEntity.self,
                ConversationEntity.self,
                UserEntity.self,
                AttachmentEntity.self,
                FAQEntity.self
            ])

            // Configure model container
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false, // Persist to disk
                allowsSave: true
            )

            // Create container
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            print("✅ SwiftData ModelContainer initialized successfully")

        } catch {
            fatalError("❌ Failed to initialize ModelContainer: \(error)")
        }
    }

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer) // Inject container into view hierarchy
        }
    }
}
```

### 2.2 Preview ModelContainer

For SwiftUI previews, create a preview-specific container.

```swift
/// PreviewContainer.swift
///
/// Preview-specific ModelContainer with sample data for SwiftUI previews.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@MainActor
class PreviewContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            MessageEntity.self,
            ConversationEntity.self,
            UserEntity.self,
            AttachmentEntity.self,
            FAQEntity.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true // In-memory only for previews
        )

        let container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        // Insert sample data
        let context = container.mainContext

        // Sample user
        let user = UserEntity(
            id: "preview-user-1",
            email: "sarah@example.com",
            displayName: "Sarah Chen"
        )
        context.insert(user)

        // Sample conversation
        let conversation = ConversationEntity(
            id: "preview-conv-1",
            participantIDs: ["preview-user-1", "preview-user-2"],
            displayName: "John Doe",
            isGroup: false
        )
        context.insert(conversation)

        // Sample messages
        let message1 = MessageEntity(
            conversationID: conversation.id,
            senderID: "preview-user-2",
            text: "Hey! Love your latest video!",
            status: .read,
            syncStatus: .synced
        )
        message1.category = .fan
        message1.categoryConfidence = 0.95
        context.insert(message1)

        let message2 = MessageEntity(
            conversationID: conversation.id,
            senderID: "preview-user-1",
            text: "Thanks so much! More content coming soon 🎥",
            status: .sent,
            syncStatus: .synced
        )
        context.insert(message2)

        conversation.messages = [message1, message2]
        conversation.updateWithMessage(message2)

        try? context.save()

        return container
    }()
}
```

---

## 3. @Query Usage in ViewModels

### 3.1 Conversation List ViewModel

Using @Query to fetch and observe conversations.

```swift
/// ConversationListViewModel.swift
///
/// ViewModel for conversation list screen using SwiftData @Query.
/// Fetches conversations sorted by last message timestamp.
///
/// Created: 2025-10-20

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class ConversationListViewModel: ObservableObject {
    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch Methods

    /// Fetch all conversations (not archived)
    func fetchConversations() -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { conversation in
                conversation.isArchived == false
            },
            sortBy: [
                SortDescriptor(\.lastMessageAt, order: .reverse)
            ]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch conversations: \(error.localizedDescription)"
            return []
        }
    }

    /// Fetch pinned conversations only
    func fetchPinnedConversations() -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { conversation in
                conversation.isPinned == true && conversation.isArchived == false
            },
            sortBy: [
                SortDescriptor(\.lastMessageAt, order: .reverse)
            ]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch pinned conversations: \(error.localizedDescription)"
            return []
        }
    }

    /// Fetch conversations with unread messages
    func fetchUnreadConversations() -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { conversation in
                conversation.unreadCount > 0 && conversation.isArchived == false
            },
            sortBy: [
                SortDescriptor(\.lastMessageAt, order: .reverse)
            ]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch unread conversations: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Conversation Actions

    /// Pin/unpin conversation
    func togglePin(conversation: ConversationEntity) {
        conversation.isPinned.toggle()
        saveContext()
    }

    /// Archive conversation
    func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        saveContext()
    }

    /// Delete conversation
    func deleteConversation(_ conversation: ConversationEntity) {
        modelContext.delete(conversation)
        saveContext()
    }

    // MARK: - Helper Methods

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
}
```

### 3.2 Message Thread ViewModel

Using @Query to fetch messages for a specific conversation.

```swift
/// MessageThreadViewModel.swift
///
/// ViewModel for message thread screen using SwiftData @Query.
/// Fetches messages for a specific conversation with pagination support.
///
/// Created: 2025-10-20

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class MessageThreadViewModel: ObservableObject {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let conversationID: String

    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var messageText = ""

    // MARK: - Constants

    private let messagesPerPage = 20

    // MARK: - Initialization

    init(modelContext: ModelContext, conversationID: String) {
        self.modelContext = modelContext
        self.conversationID = conversationID
    }

    // MARK: - Fetch Methods

    /// Fetch messages for this conversation
    func fetchMessages(limit: Int = 20, offset: Int = 0) -> [MessageEntity] {
        var descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.conversationID == conversationID
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )

        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch messages: \(error.localizedDescription)"
            return []
        }
    }

    /// Fetch messages pending sync
    func fetchPendingSyncMessages() -> [MessageEntity] {
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.conversationID == conversationID &&
                (message.syncStatus == .pending ||
                 (message.syncStatus == .failed && message.retryCount < 3))
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch pending messages: \(error.localizedDescription)"
            return []
        }
    }

    /// Get conversation
    func getConversation() -> ConversationEntity? {
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { conversation in
                conversation.id == conversationID
            }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            errorMessage = "Failed to fetch conversation: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Message Actions

    /// Send new message (optimistic UI)
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Get current user ID (would come from AuthService in real implementation)
        let currentUserID = "current-user-id" // TODO: Get from AuthService

        // Create message entity
        let message = MessageEntity(
            conversationID: conversationID,
            senderID: currentUserID,
            text: messageText,
            status: .sending,
            syncStatus: .pending
        )

        // Insert into SwiftData (optimistic UI)
        modelContext.insert(message)

        // Update conversation
        if let conversation = getConversation() {
            conversation.updateWithMessage(message)
        }

        // Save context
        saveContext()

        // Clear input
        messageText = ""

        // TODO: Trigger background sync to Firestore
        // This would be handled by a BackgroundSyncService
    }

    /// Mark conversation as read
    func markConversationAsRead() {
        if let conversation = getConversation() {
            conversation.markAsRead()
            saveContext()
        }
    }

    // MARK: - Helper Methods

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
}
```

### 3.3 Using @Query in SwiftUI Views

Direct @Query usage in views for automatic updates.

```swift
/// ConversationListView.swift
///
/// SwiftUI view using @Query for automatic conversation updates.
///
/// Created: 2025-10-20

import SwiftUI
import SwiftData

struct ConversationListView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Query

    /// All non-archived conversations, sorted by last message
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isArchived == false
        },
        sort: [
            SortDescriptor(\ConversationEntity.isPinned, order: .reverse),
            SortDescriptor(\ConversationEntity.lastMessageAt, order: .reverse)
        ]
    ) private var conversations: [ConversationEntity]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            togglePin(conversation)
                        } label: {
                            Label(
                                conversation.isPinned ? "Unpin" : "Pin",
                                systemImage: conversation.isPinned ? "pin.slash" : "pin"
                            )
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: ConversationEntity.self) { conversation in
                MessageThreadView(conversationID: conversation.id)
            }
        }
    }

    // MARK: - Actions

    private func togglePin(_ conversation: ConversationEntity) {
        conversation.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteConversation(_ conversation: ConversationEntity) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    ConversationListView()
        .modelContainer(PreviewContainer.shared)
}
```

---

## 4. SwiftData ↔ Firestore Sync Patterns

### 4.1 Write-First Pattern (Optimistic UI)

```swift
/// MessageSyncService.swift
///
/// Service handling SwiftData ↔ Firestore sync with optimistic UI pattern.
/// Writes to SwiftData first, then syncs to Firestore in background.
///
/// Created: 2025-10-20

import Foundation
import SwiftData
import FirebaseFirestore

actor MessageSyncService {
    // MARK: - Dependencies

    private let firestore: Firestore
    private let modelContext: ModelContext

    // MARK: - Initialization

    init(firestore: Firestore = Firestore.firestore(), modelContext: ModelContext) {
        self.firestore = firestore
        self.modelContext = modelContext
    }

    // MARK: - Sync Methods

    /// Sync message to Firestore (called after local SwiftData write)
    func syncMessageToFirestore(_ message: MessageEntity) async throws {
        // Convert SwiftData entity to Firestore document
        let messageData: [String: Any] = [
            "id": message.id,
            "conversationID": message.conversationID,
            "senderID": message.senderID,
            "text": message.text,
            "status": message.status.rawValue,
            "readBy": message.readBy,
            "createdAt": Timestamp(date: message.createdAt),
            "updatedAt": Timestamp(date: message.updatedAt)
        ]

        do {
            // Write to Firestore
            try await firestore
                .collection("conversations")
                .document(message.conversationID)
                .collection("messages")
                .document(message.id)
                .setData(messageData)

            // Mark as synced in SwiftData
            await MainActor.run {
                message.markAsSynced()
                try? modelContext.save()
            }

        } catch {
            // Mark as failed in SwiftData
            await MainActor.run {
                message.markAsFailed(error: error.localizedDescription)
                try? modelContext.save()
            }

            throw error
        }
    }

    /// Process sync queue (messages pending sync)
    func processSyncQueue() async {
        // Fetch pending messages from SwiftData
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.syncStatus == .pending ||
                (message.syncStatus == .failed && message.retryCount < 3)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let pendingMessages: [MessageEntity]
        do {
            pendingMessages = try await MainActor.run {
                try modelContext.fetch(descriptor)
            }
        } catch {
            print("❌ Failed to fetch pending messages: \(error)")
            return
        }

        // Sync each message
        for message in pendingMessages {
            do {
                try await syncMessageToFirestore(message)
                print("✅ Synced message: \(message.id)")
            } catch {
                print("❌ Failed to sync message \(message.id): \(error)")
            }
        }
    }
}
```

### 4.2 Read-First Pattern (Cache-First)

```swift
/// ConversationSyncService.swift
///
/// Service handling conversation sync with cache-first pattern.
/// Reads from SwiftData first, then syncs from Firestore in background.
///
/// Created: 2025-10-20

import Foundation
import SwiftData
import FirebaseFirestore

actor ConversationSyncService {
    // MARK: - Dependencies

    private let firestore: Firestore
    private let modelContext: ModelContext

    // MARK: - Initialization

    init(firestore: Firestore = Firestore.firestore(), modelContext: ModelContext) {
        self.firestore = firestore
        self.modelContext = modelContext
    }

    // MARK: - Sync Methods

    /// Fetch conversation from Firestore and update SwiftData cache
    func syncConversationFromFirestore(conversationID: String) async throws {
        // Fetch from Firestore
        let document = try await firestore
            .collection("conversations")
            .document(conversationID)
            .getDocument()

        guard let data = document.data() else {
            throw SyncError.documentNotFound
        }

        // Parse Firestore data
        let participantIDs = data["participants"] as? [String] ?? []
        let displayName = data["displayName"] as? String
        let avatarURL = data["avatarURL"] as? String
        let isGroup = data["isGroup"] as? Bool ?? false
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        // Update or create in SwiftData
        await MainActor.run {
            // Try to find existing conversation
            let descriptor = FetchDescriptor<ConversationEntity>(
                predicate: #Predicate { conversation in
                    conversation.id == conversationID
                }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                // Update existing
                existing.participantIDs = participantIDs
                existing.displayName = displayName
                existing.avatarURL = avatarURL
                existing.isGroup = isGroup
                existing.updatedAt = updatedAt
            } else {
                // Create new
                let conversation = ConversationEntity(
                    id: conversationID,
                    participantIDs: participantIDs,
                    displayName: displayName,
                    isGroup: isGroup
                )
                modelContext.insert(conversation)
            }

            try? modelContext.save()
        }
    }

    /// Sync all conversations for current user
    func syncAllConversations(userID: String) async throws {
        // Fetch from Firestore
        let snapshot = try await firestore
            .collection("users")
            .document(userID)
            .collection("conversations")
            .getDocuments()

        // Sync each conversation
        for document in snapshot.documents {
            let conversationID = document.documentID
            try await syncConversationFromFirestore(conversationID: conversationID)
        }
    }
}

// MARK: - Errors

enum SyncError: Error {
    case documentNotFound
    case invalidData
    case networkError
}
```

### 4.3 Background Sync Coordinator

```swift
/// BackgroundSyncCoordinator.swift
///
/// Coordinates background sync between SwiftData and Firestore.
/// Monitors network status and processes sync queue when online.
///
/// Created: 2025-10-20

import Foundation
import Network
import SwiftData

@MainActor
final class BackgroundSyncCoordinator: ObservableObject {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let messageSyncService: MessageSyncService
    private let conversationSyncService: ConversationSyncService

    // MARK: - Properties

    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var pendingSyncCount = 0

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.messageSyncService = MessageSyncService(modelContext: modelContext)
        self.conversationSyncService = ConversationSyncService(modelContext: modelContext)

        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                // If we just came online, process sync queue
                if wasOffline && self?.isOnline == true {
                    await self?.processSyncQueue()
                }
            }
        }

        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Methods

    /// Process sync queue (called when coming online)
    func processSyncQueue() async {
        guard !isSyncing else { return }

        isSyncing = true

        do {
            // Count pending messages
            updatePendingSyncCount()

            // Process message sync queue
            await messageSyncService.processSyncQueue()

            // Update count after sync
            updatePendingSyncCount()

        } catch {
            print("❌ Sync queue processing failed: \(error)")
        }

        isSyncing = false
    }

    /// Update pending sync count
    private func updatePendingSyncCount() {
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.syncStatus == .pending ||
                (message.syncStatus == .failed && message.retryCount < 3)
            }
        )

        if let messages = try? modelContext.fetch(descriptor) {
            pendingSyncCount = messages.count
        }
    }

    // MARK: - Manual Sync

    /// Manually trigger sync
    func sync() async {
        await processSyncQueue()
    }
}
```

---

## 5. Error Handling & Best Practices

### 5.1 Error Handling Pattern

```swift
/// DataLayerError.swift
///
/// Standardized error handling for SwiftData operations.
///
/// Created: 2025-10-20

import Foundation

enum DataLayerError: LocalizedError {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case syncFailed(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let details):
            return "Failed to fetch data: \(details)"
        case .saveFailed(let details):
            return "Failed to save data: \(details)"
        case .deleteFailed(let details):
            return "Failed to delete data: \(details)"
        case .syncFailed(let details):
            return "Failed to sync data: \(details)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        }
    }
}
```

### 5.2 Best Practices

**1. Always use @MainActor for UI-bound operations**
```swift
@MainActor
func updateUI() {
    // SwiftData operations that affect UI
}
```

**2. Use actors for background sync operations**
```swift
actor SyncService {
    func syncData() async {
        // Background sync logic
    }
}
```

**3. Handle errors gracefully with do-catch**
```swift
do {
    try modelContext.save()
} catch {
    print("❌ Save failed: \(error)")
    // Show user-friendly error message
}
```

**4. Use predicates for efficient queries**
```swift
// Efficient predicate query
#Predicate<MessageEntity> { message in
    message.conversationID == conversationID &&
    message.syncStatus == .pending
}
```

**5. Implement exponential backoff for failed syncs**
```swift
func calculateRetryDelay(attempt: Int) -> TimeInterval {
    return pow(2.0, Double(attempt)) // 1s, 2s, 4s, 8s...
}
```

**6. Clean up old data periodically**
```swift
func deleteOldMessages(olderThan days: Int) {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

    let descriptor = FetchDescriptor<MessageEntity>(
        predicate: #Predicate { message in
            message.createdAt < cutoffDate && message.syncStatus == .synced
        }
    )

    if let oldMessages = try? modelContext.fetch(descriptor) {
        for message in oldMessages {
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}
```

---

## Summary

This guide provides complete SwiftData implementation patterns for Sorted:

✅ **@Model Entities**: All 5 core entities with full property definitions and relationships
✅ **ModelContainer Setup**: App initialization with schema configuration
✅ **@Query Usage**: Examples in both ViewModels and Views with automatic updates
✅ **Sync Patterns**: Write-first (optimistic UI) and read-first (cache-first) patterns
✅ **Background Sync**: Network monitoring and automatic sync queue processing
✅ **Error Handling**: Standardized error types and recovery strategies

**Next Steps:**
1. Implement these patterns in the actual iOS app
2. Add unit tests for sync logic
3. Monitor sync performance and optimize as needed
4. Implement conflict resolution for concurrent edits

---

**END OF SWIFTDATA IMPLEMENTATION GUIDE**
