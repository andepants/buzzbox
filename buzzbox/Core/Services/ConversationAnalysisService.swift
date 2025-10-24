/**
 * Conversation Analysis Service for Buzzbox
 *
 * Handles Firebase Cloud Functions integration for conversation-level AI analysis:
 * - Overall sentiment detection (positive, negative, neutral, urgent)
 * - Fan categorization (fan, super_fan, business, spam, urgent)
 * - Business opportunity scoring (0-10 scale for business inquiries)
 *
 * [Source: Story 6.11 - Conversation-Level AI Analysis]
 */

import Foundation
@preconcurrency import FirebaseFunctions
import SwiftData

// MARK: - Response Types

/// Conversation analysis response structure from Cloud Function
struct ConversationAnalysisResponse: @unchecked Sendable {
    let sentiment: String
    let category: String
    let businessScore: Int?
    let cached: Bool
}

nonisolated extension ConversationAnalysisResponse: Codable {}

// MARK: - Service

/// Service for analyzing conversations with AI
/// [Source: Story 6.11 - Conversation-Level AI Analysis]
@Observable
@MainActor
final class ConversationAnalysisService {

    // MARK: - Singleton

    static let shared = ConversationAnalysisService()

    // MARK: - Configuration

    nonisolated(unsafe) private let functions = Functions.functions()

    // MARK: - Initialization

    private init() {}

    // MARK: - Analysis Methods

    /// Analyze a conversation and update local SwiftData entity
    /// - Parameters:
    ///   - conversation: ConversationEntity to analyze
    ///   - forceRefresh: Force re-analysis even if already analyzed
    /// - Returns: True if analysis was performed, false if cached
    func analyzeConversation(
        _ conversation: ConversationEntity,
        forceRefresh: Bool = false
    ) async throws -> Bool {
        print("\n🔵 [API] analyzeConversation called for: \(conversation.id.prefix(8))")
        print("🔵 [API] messageCountSinceAnalysis: \(conversation.messageCountSinceAnalysis)")
        print("🔵 [API] aiAnalyzedAt: \(conversation.aiAnalyzedAt?.description ?? "nil")")

        // Skip if already analyzed and no new messages (unless force refresh)
        if !forceRefresh,
           conversation.aiAnalyzedAt != nil,
           conversation.messageCountSinceAnalysis == 0 {
            print("🔴 [API] Skipping - already analyzed with no new messages\n")
            return false
        }

        print("🔵 [API] Calling Firebase Cloud Function 'analyzeConversation'...")

        // Call Cloud Function
        let callable = functions.httpsCallable("analyzeConversation")
        let result = try await callable.call([
            "conversationID": conversation.id,
            "forceRefresh": forceRefresh
        ])

        print("✅ [API] Firebase response received")

        // Parse result
        let data = try JSONSerialization.data(withJSONObject: result.data)
        let decoder = JSONDecoder()
        let response = try decoder.decode(ConversationAnalysisResponse.self, from: data)

        print("✅ [API] Parsed response: sentiment=\(response.sentiment), category=\(response.category), score=\(response.businessScore?.description ?? "nil"), cached=\(response.cached)")

        // Update local SwiftData entity
        conversation.aiSentiment = response.sentiment
        conversation.aiCategory = response.category
        conversation.aiBusinessScore = response.businessScore
        conversation.aiAnalyzedAt = Date()
        conversation.messageCountSinceAnalysis = 0

        print("✅ [API] SwiftData updated for conversation \(conversation.id.prefix(8))\n")

        return !response.cached
    }

    /// Analyze all conversations in inbox (batch operation)
    /// Only analyzes conversations with new messages since last analysis
    func analyzeAllConversations(_ conversations: [ConversationEntity]) async {
        print("\n🔵 [BATCH] Analyzing \(conversations.count) conversations...")

        for conversation in conversations {
            // Only analyze if there are new messages
            if conversation.messageCountSinceAnalysis > 0 {
                do {
                    print("🔵 [BATCH] Processing: \(conversation.id.prefix(8))")
                    _ = try await analyzeConversation(conversation)
                } catch {
                    print("❌ [BATCH] Failed to analyze \(conversation.id.prefix(8)): \(error)")
                }
            }
        }

        print("✅ [BATCH] Batch analysis complete\n")
    }
}

// MARK: - Error Types

enum ConversationAnalysisError: Error {
    case analysisFailed(Error)
    case invalidResponse
    case permissionDenied
}
