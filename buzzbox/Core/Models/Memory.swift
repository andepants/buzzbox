/**
 * Memory Model for Supermemory RAG Integration
 *
 * Represents a memory retrieved from Supermemory via Firebase Cloud Functions
 * Used for RAG (Retrieval-Augmented Generation) context in AI drafts
 *
 * [Source: Story 9.1 - Supermemory Service Infrastructure]
 */

import Foundation

/// Represents a memory retrieved from Supermemory
/// Used for RAG (Retrieval-Augmented Generation) context in AI drafts
struct Memory: Identifiable, Codable, Sendable {
    /// Unique identifier for the memory
    let id: String

    /// The memory content (typically Q&A format)
    let content: String

    /// Optional metadata (conversationID, timestamp, category, etc.)
    let metadata: [String: String]?

    /// Relevance score from search (0.0 to 1.0)
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case metadata
        case score
    }
}
