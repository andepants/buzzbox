/// DataSeedingService.swift
///
/// Service for seeding realistic test data into the app
/// Safe for production - only uses existing authenticated users
///
/// Created: 2025-10-25

import Foundation
import SwiftData
import FirebaseAuth
@preconcurrency import FirebaseDatabase

/// Service for seeding realistic test conversations and messages
@MainActor
final class DataSeedingService {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let conversationService: ConversationService
    nonisolated(unsafe) private let database: DatabaseReference

    // MARK: - Constants

    private let creatorEmail = "andrewsheim@gmail.com"
    private let minConversations = 5
    private let maxConversations = 10
    private let minMessagesPerConvo = 3
    private let maxMessagesPerConvo = 8
    private let maxDaysBack = 7

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.conversationService = ConversationService.shared
        self.database = Database.database().reference()
    }

    // MARK: - Public Methods

    /// Clear all DM conversations and seed with realistic test data
    /// - Throws: Seeding errors
    func clearAndSeedConversations() async throws {
        print("🌱 [SEEDING] Starting data seeding process...")

        // 1. Fetch existing users from Firestore
        print("📥 [SEEDING] Fetching existing users from Firestore...")
        try await conversationService.syncInitialUsers(modelContext: modelContext)

        let allUsers = try modelContext.fetch(FetchDescriptor<UserEntity>())
        print("✅ [SEEDING] Found \(allUsers.count) users")

        // 2. Identify creator and fans
        guard let creator = allUsers.first(where: { $0.email.lowercased() == creatorEmail.lowercased() }) else {
            throw SeedingError.creatorNotFound
        }

        let fans = allUsers.filter { $0.isFan }
        print("👤 [SEEDING] Creator: \(creator.displayName) (\(creator.email))")
        print("👥 [SEEDING] Fans: \(fans.count)")

        guard !fans.isEmpty else {
            throw SeedingError.noFansFound
        }

        // 3. Clear all DM conversations (preserve channels)
        print("🗑️ [SEEDING] Clearing existing DM conversations...")
        try await clearAllDMConversations()

        // 4. Seed conversations with guaranteed archetypes for inbox variety
        let conversationCount = min(Int.random(in: minConversations...maxConversations), fans.count)
        let selectedFans = fans.shuffled().prefix(conversationCount)

        // Guaranteed conversation archetypes (6 minimum for comprehensive testing)
        var conversationTypes: [ConversationType] = [
            .fan,         // Regular fan
            .superFan,    // Enthusiastic super fan
            .business,    // Business opportunity
            .spam,        // Spammer
            .negativeFan, // Frustrated fan
            .mixed        // Balanced variety
        ]

        print("🎲 [SEEDING] Creating \(conversationCount) conversations...")
        print("📊 [SEEDING] Guaranteed archetypes: fan, super fan, business, spam, negative fan, mixed")

        // Fill remaining slots with variety (if count > 6)
        while conversationTypes.count < conversationCount {
            conversationTypes.append([.fan, .superFan, .mixed].randomElement()!)
        }

        // Shuffle for realistic ordering
        conversationTypes.shuffle()

        for (index, fan) in selectedFans.enumerated() {
            let type = conversationTypes[index]
            print("💬 [SEEDING] [\(index + 1)/\(conversationCount)] Creating \(type) conversation with \(fan.displayName)...")
            try await seedConversation(creator: creator, fan: fan, type: type)
        }

        print("✅ [SEEDING] Successfully seeded \(conversationCount) conversations with variety!")
    }

    // MARK: - Private Methods

    /// Clear all DM conversations (SwiftData + RTDB)
    private nonisolated func clearAllDMConversations() async throws {
        // 1. Clear from SwiftData
        await MainActor.run {
            let descriptor = FetchDescriptor<ConversationEntity>(
                predicate: #Predicate { $0.isGroup == false }
            )

            do {
                let dmConversations = try modelContext.fetch(descriptor)
                print("🗑️ [SEEDING] Deleting \(dmConversations.count) DM conversations from SwiftData...")

                for conversation in dmConversations {
                    modelContext.delete(conversation)
                }

                try modelContext.save()
            } catch {
                print("❌ [SEEDING] Error clearing SwiftData: \(error)")
            }
        }

        // 2. Clear from RTDB
        print("🗑️ [SEEDING] Clearing DM conversations from RTDB...")

        // Get all conversations from RTDB
        let conversationsRef = database.child("conversations")
        let snapshot: DataSnapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataSnapshot, Error>) in
            conversationsRef.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "DataSeeding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
            }
        }

        guard snapshot.exists() else {
            print("ℹ️ [SEEDING] No conversations in RTDB to clear")
            return
        }

        var deletedCount = 0

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any],
                  let isGroup = conversationData["isGroup"] as? Bool,
                  !isGroup else {
                // Skip group conversations (channels)
                continue
            }

            let conversationID = child.key

            // Delete conversation from RTDB
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                database.child("conversations/\(conversationID)").removeValue { error, _ in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            // Delete all messages for this conversation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                database.child("messages/\(conversationID)").removeValue { error, _ in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            deletedCount += 1
        }

        print("✅ [SEEDING] Deleted \(deletedCount) DM conversations from RTDB")
    }

    /// Seed a single conversation between creator and fan
    private func seedConversation(creator: UserEntity, fan: UserEntity, type: ConversationType) async throws {
        // 1. Create conversation ID (deterministic)
        let participantIDs = [creator.id, fan.id].sorted()
        let conversationID = participantIDs.joined(separator: "_")

        // 2. Create conversation entity
        let conversation = ConversationEntity(
            id: conversationID,
            participantIDs: participantIDs,
            displayName: nil,
            groupPhotoURL: nil,
            adminUserIDs: [],
            isGroup: false,
            isCreatorOnly: false,
            channelEmoji: nil,
            channelDescription: nil,
            createdAt: Date().addingTimeInterval(-Double.random(in: 3...7) * 86400), // 3-7 days ago
            syncStatus: .synced
        )

        modelContext.insert(conversation)

        // 3. Generate realistic messages based on conversation type
        let messageCount = Int.random(in: minMessagesPerConvo...maxMessagesPerConvo)
        let seedMessages = generateRealisticMessages(
            conversationID: conversationID,
            creatorID: creator.id,
            fanID: fan.id,
            count: messageCount,
            conversationType: type
        )

        // 4. Create and sync messages
        for seedMessage in seedMessages {
            let message = MessageEntity(
                id: UUID().uuidString,
                conversationID: conversationID,
                senderID: seedMessage.senderID,
                text: seedMessage.text,
                localCreatedAt: seedMessage.timestamp,
                serverTimestamp: seedMessage.timestamp,
                sequenceNumber: nil,
                status: .delivered,
                syncStatus: .synced
            )

            // Apply AI metadata if available
            if let metadata = seedMessage.metadata {
                message.category = metadata.category
                message.categoryConfidence = metadata.categoryConfidence
                message.sentiment = metadata.sentiment
                message.sentimentIntensity = metadata.sentimentIntensity
                message.opportunityScore = metadata.opportunityScore
                message.faqMatchID = metadata.faqMatchID
                message.faqConfidence = metadata.faqConfidence
                message.aiProcessedAt = seedMessage.timestamp
            }

            modelContext.insert(message)

            // Extract data for RTDB sync (must be done on MainActor)
            let syncData = MessageSyncData(
                id: message.id,
                conversationID: message.conversationID,
                senderID: message.senderID,
                text: message.text,
                timestamp: message.serverTimestamp?.timeIntervalSince1970 ?? message.localCreatedAt.timeIntervalSince1970,
                status: message.status.rawValue,
                isSystemMessage: message.isSystemMessage,
                category: message.category?.rawValue,
                categoryConfidence: message.categoryConfidence,
                sentiment: message.sentiment?.rawValue,
                sentimentIntensity: message.sentimentIntensity?.rawValue,
                opportunityScore: message.opportunityScore,
                faqMatchID: message.faqMatchID,
                faqConfidence: message.faqConfidence
            )

            // Sync to RTDB
            try await syncMessageToRTDB(syncData)

            // Update conversation with last message
            if message.localCreatedAt > (conversation.lastMessageAt ?? Date.distantPast) {
                conversation.updateWithMessage(message)
            }
        }

        // 5. Sync conversation to RTDB
        try await conversationService.syncConversation(conversation)

        try modelContext.save()
        print("✅ [SEEDING] Created \(messageCount) messages in conversation with \(fan.displayName)")
    }

    /// Generate realistic messages for a conversation
    private func generateRealisticMessages(
        conversationID: String,
        creatorID: String,
        fanID: String,
        count: Int,
        conversationType: ConversationType
    ) -> [SeedMessage] {
        var messages: [SeedMessage] = []
        var currentTime = Date().addingTimeInterval(-Double.random(in: 2...7) * 86400) // Start 2-7 days ago

        // Message type distribution based on conversation archetype
        var messageTypes: [MessageType] = []

        switch conversationType {
        case .fan:
            // Regular fan: 60% positive engagement, 30% casual, 10% FAQ
            print("📊 [SEEDING] Fan archetype: Casual positive supporter")
            let positiveCount = Int(Double(count) * 0.6)
            let casualCount = Int(Double(count) * 0.3)
            messageTypes.append(contentsOf: Array(repeating: .fanEngagement, count: max(1, positiveCount)))
            messageTypes.append(contentsOf: Array(repeating: .casual, count: max(1, casualCount)))
            messageTypes.append(.faq)

        case .superFan:
            // Super fan: 80% highly positive engagement, 20% casual
            print("📊 [SEEDING] Super Fan archetype: Enthusiastic supporter")
            let positiveCount = Int(Double(count) * 0.8)
            messageTypes.append(contentsOf: Array(repeating: .fanEngagement, count: max(2, positiveCount)))
            messageTypes.append(contentsOf: Array(repeating: .casual, count: max(1, count - positiveCount)))

        case .business:
            // Business: 70% business, 20% casual, 10% positive fan
            print("📊 [SEEDING] Business archetype: Professional opportunity seeker")
            let businessCount = Int(Double(count) * 0.7)
            messageTypes.append(contentsOf: Array(repeating: .business, count: max(2, businessCount)))
            messageTypes.append(contentsOf: Array(repeating: .casual, count: max(1, Int(Double(count) * 0.2))))
            messageTypes.append(.fanEngagement)

        case .spam:
            // Spam: 70% spam, 30% low-quality engagement
            print("📊 [SEEDING] Spam archetype: Low-quality solicitations")
            let spamCount = Int(Double(count) * 0.7)
            messageTypes.append(contentsOf: Array(repeating: .spam, count: max(2, spamCount)))
            messageTypes.append(contentsOf: Array(repeating: .casual, count: max(1, count - spamCount)))

        case .negativeFan:
            // Negative fan: 60% negative, 30% casual, 10% urgent
            print("📊 [SEEDING] Negative Fan archetype: Frustrated supporter")
            let negativeCount = Int(Double(count) * 0.6)
            messageTypes.append(contentsOf: Array(repeating: .negativeFan, count: max(2, negativeCount)))
            messageTypes.append(contentsOf: Array(repeating: .casual, count: max(1, Int(Double(count) * 0.3))))
            messageTypes.append(.urgent)

        case .mixed:
            // Mixed: Balanced variety for comprehensive testing
            print("📊 [SEEDING] Mixed archetype: Comprehensive AI testing")
            messageTypes.append(.faq)
            messageTypes.append(.business)
            messageTypes.append(.spam)
            messageTypes.append(.urgent)
            messageTypes.append(.negativeFan)
            messageTypes.append(.fanEngagement)
            // Fill remaining with variety
            while messageTypes.count < count {
                messageTypes.append([.faq, .casual, .fanEngagement].randomElement()!)
            }
        }

        // Ensure we hit the target count
        while messageTypes.count < count {
            messageTypes.append(.fanEngagement)
        }

        // Trim if we exceeded
        if messageTypes.count > count {
            messageTypes = Array(messageTypes.prefix(count))
        }

        // Shuffle for realistic chronological ordering
        messageTypes.shuffle()

        // Generate messages
        for messageType in messageTypes {
            let (text, metadata, isFanSender) = generateMessage(type: messageType)

            messages.append(SeedMessage(
                text: text,
                senderID: isFanSender ? fanID : creatorID,
                timestamp: currentTime,
                metadata: metadata
            ))

            // Add creator response for some messages (60% chance)
            if isFanSender && Double.random(in: 0...1) < 0.6 {
                currentTime = currentTime.addingTimeInterval(Double.random(in: 300...3600)) // 5 min - 1 hour later

                messages.append(SeedMessage(
                    text: SeedData.creatorResponses.randomElement()!,
                    senderID: creatorID,
                    timestamp: currentTime,
                    metadata: SeedData.neutralMetadata()
                ))
            }

            // Advance time (15 min - 2 hours between messages)
            currentTime = currentTime.addingTimeInterval(Double.random(in: 900...7200))
        }

        return messages
    }

    /// Generate a single message based on type
    private func generateMessage(type: MessageType) -> (text: String, metadata: MessageMetadata?, isFanSender: Bool) {
        switch type {
        case .faq:
            let faq = SeedData.faqQuestions.randomElement()!
            return (
                faq.text,
                SeedData.faqMetadata(faqMatchID: faq.faqMatchID, confidence: faq.confidence),
                true
            )

        case .business:
            let business = SeedData.businessMessages.randomElement()!
            return (
                business.text,
                SeedData.businessMetadata(score: business.score),
                true
            )

        case .fanEngagement:
            return (
                SeedData.fanEngagementMessages.randomElement()!,
                SeedData.fanMetadata(),
                true
            )

        case .urgent:
            return (
                SeedData.urgentMessages.randomElement()!,
                SeedData.urgentMetadata(),
                true
            )

        case .casual:
            return (
                SeedData.casualQuestions.randomElement()!,
                SeedData.neutralMetadata(),
                true
            )

        case .spam:
            return (
                SeedData.spamMessages.randomElement()!,
                SeedData.spamMetadata(),
                true
            )

        case .negativeFan:
            return (
                SeedData.negativeFanMessages.randomElement()!,
                SeedData.negativeFanMetadata(),
                true
            )
        }
    }

    /// Sync a message to RTDB
    private nonisolated func syncMessageToRTDB(_ syncData: MessageSyncData) async throws {
        let messageRef = database.child("messages/\(syncData.conversationID)/\(syncData.id)")

        var messageData: [String: Any] = [
            "senderID": syncData.senderID,
            "text": syncData.text,
            "serverTimestamp": syncData.timestamp,
            "status": syncData.status,
            "isSystemMessage": syncData.isSystemMessage
        ]

        // Add AI metadata if available
        if let category = syncData.category {
            messageData["category"] = category
            messageData["categoryConfidence"] = syncData.categoryConfidence ?? 0
        }

        if let sentiment = syncData.sentiment {
            messageData["sentiment"] = sentiment
        }

        if let sentimentIntensity = syncData.sentimentIntensity {
            messageData["sentimentIntensity"] = sentimentIntensity
        }

        if let opportunityScore = syncData.opportunityScore {
            messageData["opportunityScore"] = opportunityScore
        }

        if let faqMatchID = syncData.faqMatchID {
            messageData["faqMatchID"] = faqMatchID
            messageData["faqConfidence"] = syncData.faqConfidence ?? 0
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            messageRef.setValue(messageData) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Conversation archetype for inbox variety
private enum ConversationType {
    case fan         // Regular casual supporter
    case superFan    // Enthusiastic supporter (high engagement)
    case business    // Professional opportunity seeker
    case spam        // Low-quality solicitations
    case negativeFan // Frustrated/disappointed supporter
    case mixed       // Balanced variety (tests all features)
}

/// Message type for seeding
private enum MessageType {
    case faq
    case business
    case fanEngagement
    case urgent
    case casual
    case spam
    case negativeFan
}

/// Data structure for syncing message to RTDB (decoupled from SwiftData)
private struct MessageSyncData {
    let id: String
    let conversationID: String
    let senderID: String
    let text: String
    let timestamp: TimeInterval
    let status: String
    let isSystemMessage: Bool
    let category: String?
    let categoryConfidence: Double?
    let sentiment: String?
    let sentimentIntensity: String?
    let opportunityScore: Int?
    let faqMatchID: String?
    let faqConfidence: Double?
}

// MARK: - Errors

enum SeedingError: LocalizedError {
    case creatorNotFound
    case noFansFound

    var errorDescription: String? {
        switch self {
        case .creatorNotFound:
            return "Creator account (andrewsheim@gmail.com) not found. Please ensure the creator is signed up."
        case .noFansFound:
            return "No fan accounts found. Please create at least one fan account before seeding."
        }
    }
}
