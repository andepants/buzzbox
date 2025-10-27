/**
 * PendingMemory Model for Supermemory Offline Queue
 *
 * Stores failed memory additions for retry when network becomes available
 * Implements exponential backoff to respect rate limits
 *
 * [Source: Story 9.4 - Offline Queue & Error Handling]
 */

import Foundation
import SwiftData

/// Represents a memory waiting to be synced to Supermemory
/// Used for offline queue and retry logic with exponential backoff
@Model
final class PendingMemory {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// The Q&A content to store
    var content: String

    /// Metadata for the memory
    var metadata: [String: String]

    /// When this memory was first created
    var createdAt: Date

    /// Number of retry attempts (0 = first attempt)
    var retryCount: Int

    /// Timestamp of last retry attempt
    var lastAttempt: Date?

    /// Initialize a new pending memory
    /// - Parameters:
    ///   - content: Q&A content
    ///   - metadata: Memory metadata
    init(content: String, metadata: [String: String]) {
        self.id = UUID()
        self.content = content
        self.metadata = metadata
        self.createdAt = Date()
        self.retryCount = 0
        self.lastAttempt = nil
    }
}
