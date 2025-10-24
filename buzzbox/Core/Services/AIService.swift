/**
 * AI Service for Buzzbox
 *
 * Handles Firebase Cloud Functions integration for AI features:
 * - FAQ auto-responder (Feature 3)
 * - Smart reply generation (Feature 2 + Advanced)
 *
 * Note: Auto-processing (categorization, sentiment, scoring) happens
 * automatically via Cloud Function triggers - no client code needed
 *
 * [Source: Epic 6 - AI-Powered Creator Inbox]
 * [Story: 6.5 - iOS AI Service Integration]
 */

import Foundation
@preconcurrency import FirebaseFunctions

// MARK: - Response Types

/// FAQ response structure from Cloud Function
struct FAQResponse: @unchecked Sendable {
    let isFAQ: Bool
    let answer: String?
    let matchedQuestion: String?
}

nonisolated extension FAQResponse: Codable {}

/// Smart reply response structure from Cloud Function
struct SmartReplyResponse: @unchecked Sendable {
    struct Drafts: @unchecked Sendable {
        let short: String
        let medium: String
        let detailed: String
    }
    let drafts: Drafts
}

nonisolated extension SmartReplyResponse: Codable {}
nonisolated extension SmartReplyResponse.Drafts: Codable {}

/// AI service for Firebase Cloud Functions integration
/// Handles FAQ auto-responder and smart reply generation
/// Note: Auto-processing (categorization, sentiment, scoring) happens automatically via Cloud Function triggers
@Observable
final class AIService {

    // MARK: - Configuration

    nonisolated(unsafe) private let functions = Functions.functions()

    // MARK: - FAQ Auto-Responder (Feature 3)

    /// Check if message matches FAQ and return auto-response
    /// - Parameter text: Message text to check against FAQs
    /// - Returns: FAQ response with match result and answer if found
    nonisolated func checkFAQ(_ text: String) async throws -> FAQResponse {
        do {
            let callable = functions.httpsCallable("checkFAQ")
            let result = try await callable.call(["text": text])

            let data = try JSONSerialization.data(withJSONObject: result.data)
            let decoder = JSONDecoder()
            return try decoder.decode(FAQResponse.self, from: data)
        } catch {
            // Log error but don't throw - return non-FAQ response
            print("FAQ check failed: \(error)")
            return FAQResponse(isFAQ: false, answer: nil, matchedQuestion: nil)
        }
    }

    // MARK: - Context-Aware Smart Replies (Feature 2 + Advanced)

    /// Generate 3 context-aware smart replies in creator's voice
    /// - Parameters:
    ///   - conversationId: ID of the conversation for context
    ///   - messageText: The message to generate replies for
    /// - Returns: Array of 3 reply drafts (short, medium, detailed)
    nonisolated func generateSmartReplies(
        conversationId: String,
        messageText: String
    ) async throws -> [String] {
        do {
            let callable = functions.httpsCallable("generateSmartReplies")
            let result = try await callable.call([
                "conversationId": conversationId,
                "messageText": messageText
            ])

            let data = try JSONSerialization.data(withJSONObject: result.data)
            let decoder = JSONDecoder()
            let response = try decoder.decode(SmartReplyResponse.self, from: data)

            return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
        } catch {
            // Re-throw for smart replies - user initiated action should show error
            throw AIServiceError.smartReplyFailed(error)
        }
    }

    /// Generate a single targeted smart reply
    /// - Parameters:
    ///   - conversationId: ID of the conversation for context
    ///   - messageText: The message to generate a reply for
    ///   - replyType: Type of reply (short, funny, professional)
    /// - Returns: Single AI-generated reply draft
    nonisolated func generateSingleSmartReply(
        conversationId: String,
        messageText: String,
        replyType: String
    ) async throws -> String {
        do {
            let callable = functions.httpsCallable("generateSmartReplies")
            let result = try await callable.call([
                "conversationId": conversationId,
                "messageText": messageText,
                "replyType": replyType
            ])

            let data = try JSONSerialization.data(withJSONObject: result.data)
            let decoder = JSONDecoder()
            let response = try decoder.decode(SmartReplyResponse.self, from: data)

            // Extract the specific reply type
            switch replyType {
            case "short":
                return response.drafts.short
            case "funny":
                return response.drafts.medium // Map funny to medium
            case "professional":
                return response.drafts.detailed // Map professional to detailed
            default:
                return response.drafts.medium
            }
        } catch {
            throw AIServiceError.smartReplyFailed(error)
        }
    }
}

// MARK: - Error Types

enum AIServiceError: LocalizedError {
    case smartReplyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .smartReplyFailed:
            return "Failed to generate smart replies. Please try again."
        }
    }
}
