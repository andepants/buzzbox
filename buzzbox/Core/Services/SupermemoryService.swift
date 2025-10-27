/**
 * Supermemory Service for Buzzbox
 *
 * Handles Firebase Cloud Functions integration for Supermemory RAG:
 * - Storing Q&A pairs from creator replies (write path)
 * - Searching memories for AI context enhancement (read path)
 *
 * Security: API key is stored securely in Firebase Cloud Functions, never in iOS app
 * Authorization: Creator-only access enforced server-side
 *
 * [Source: Story 9.1 - Supermemory Service Infrastructure]
 */

import Foundation
@preconcurrency import FirebaseFunctions
import FirebaseAuth
import SwiftData
import Network

// MARK: - Response Types

/// Response from addSupermemoryMemory Cloud Function
struct AddMemoryResponse: @unchecked Sendable {
    let success: Bool
    let memoryId: String?
    let timestamp: String
}

nonisolated extension AddMemoryResponse: Codable {}

/// Response from searchSupermemoryMemories Cloud Function
struct SearchMemoriesResponse: @unchecked Sendable {
    let memories: [Memory]
    let searchedAt: String
}

nonisolated extension SearchMemoriesResponse: Codable {}

// MARK: - Error Types

/// Error types for Supermemory operations
enum SupermemoryError: LocalizedError, Sendable {
    case notConfigured
    case invalidContent
    case invalidResponse(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supermemory not configured or user not authorized"
        case .invalidContent:
            return "Content cannot be empty"
        case .invalidResponse(let code):
            return "Invalid response: \(code)"
        case .decodingError(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timeout"
        }
    }
}

// MARK: - Service

/// Service for managing Supermemory RAG integration via Firebase Cloud Functions
/// Note: API key is stored securely in Firebase, never in the iOS app
/// Provides secure access to memory storage and search functionality
@Observable
@MainActor
final class SupermemoryService {

    // MARK: - Singleton

    static let shared = SupermemoryService()

    // MARK: - Configuration

    private let functions = Functions.functions()

    // MARK: - Published Properties

    /// Total memories stored (local counter)
    private(set) var totalMemoriesStored: Int = 0

    /// Last sync date
    private(set) var lastSyncDate: Date?

    /// Pending memories count
    private(set) var pendingMemoriesCount: Int = 0

    // MARK: - Private Properties

    /// ModelContext for offline queue
    private var modelContext: ModelContext?

    /// Network monitor for connectivity changes
    private var pathMonitor: NWPathMonitor?

    /// Dispatch queue for network monitoring
    private let monitorQueue = DispatchQueue(label: "com.buzzbox.supermemory.network")

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Check if Supermemory is enabled for current user
    /// Only creator (Andrew) can use Supermemory features
    var isEnabled: Bool {
        // Check Firebase Auth directly to avoid circular dependency
        guard let userEmail = Auth.auth().currentUser?.email else { return false }
        return userEmail.lowercased() == "andrewsheim@gmail.com"
    }

    /// Configure service with ModelContext for offline queue
    /// Call this from app initialization
    /// [Source: Story 9.4 - Offline Queue]
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        startNetworkMonitoring()
        updatePendingCount()
    }

    /// Start monitoring network connectivity
    /// Triggers queue processing when online
    private func startNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { @MainActor in
                    await self?.processPendingMemories()
                }
            }
        }
        pathMonitor?.start(queue: monitorQueue)
        print("📡 [SUPERMEMORY] Network monitoring started")
    }

    // MARK: - Memory Operations

    /// Add a memory to Supermemory via Firebase Cloud Function
    /// With offline queue fallback for reliability
    /// - Parameters:
    ///   - content: The Q&A content to store
    ///   - metadata: Optional metadata (conversationID, timestamp, etc.)
    /// [Source: Story 9.4 - Offline Queue]
    func addMemory(content: String, metadata: [String: String]? = nil) async throws {
        // Validate input
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SupermemoryError.invalidContent
        }

        do {
            // Try Cloud Function call first
            try await addMemoryViaCloudFunction(content: content, metadata: metadata)

            // Update stats on success
            await MainActor.run {
                totalMemoriesStored += 1
                lastSyncDate = Date()
            }

        } catch {
            // If failed and retryable, queue for later
            if isRetryableError(error) {
                await queueMemory(content: content, metadata: metadata ?? [:])
                print("📥 [SUPERMEMORY] Queued memory for offline sync")
            } else {
                print("❌ [SUPERMEMORY] Non-retryable error: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Add memory via Cloud Function (internal method)
    private func addMemoryViaCloudFunction(
        content: String,
        metadata: [String: String]?
    ) async throws {
        let callable = functions.httpsCallable("addSupermemoryMemory")

        let data: [String: Any] = [
            "content": content,
            "metadata": metadata ?? [:]
        ]

        let result = try await callable.call(data)

        // Parse response
        guard let resultData = result.data as? [String: Any],
              let success = resultData["success"] as? Bool,
              success else {
            throw SupermemoryError.invalidResponse(statusCode: 500)
        }

        print("✅ [SUPERMEMORY] Memory stored via Cloud Function")
    }

    /// Search memories in Supermemory via Firebase Cloud Function
    /// - Parameters:
    ///   - query: Search query text
    ///   - limit: Maximum number of results (default: 3)
    /// - Returns: Array of Memory objects, empty on failure (graceful degradation)
    func searchMemories(query: String, limit: Int = 3) async throws -> [Memory] {
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let callable = functions.httpsCallable("searchSupermemoryMemories")

        let data: [String: Any] = [
            "query": query,
            "limit": limit
        ]

        do {
            // Call directly without timeout wrapper to avoid Sendable issues
            let result = try await callable.call(data)

            // Parse response
            guard let resultData = result.data as? [String: Any],
                  let memoriesArray = resultData["memories"] as? [[String: Any]] else {
                print("⚠️ Invalid response format from Cloud Function")
                return []
            }

            // Convert to Memory objects
            let memories = memoriesArray.compactMap { dict -> Memory? in
                guard let id = dict["id"] as? String,
                      let content = dict["content"] as? String else {
                    return nil
                }

                let metadata = dict["metadata"] as? [String: String]
                let score = dict["score"] as? Double

                return Memory(id: id, content: content, metadata: metadata, score: score)
            }

            print("✅ Found \(memories.count) memories via Cloud Function")
            return memories

        } catch {
            // Graceful degradation: return empty array on any error
            print("⚠️ Search failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Offline Queue (Story 9.4)

    /// Queue memory for later sync
    private func queueMemory(content: String, metadata: [String: String]) async {
        guard let modelContext = modelContext else { return }

        await MainActor.run {
            let pending = PendingMemory(content: content, metadata: metadata)
            modelContext.insert(pending)
            try? modelContext.save()
            updatePendingCount()
        }
    }

    /// Process all pending memories with exponential backoff
    /// - Parameter forceRetry: If true, bypass exponential backoff (for manual retry button)
    func processPendingMemories(forceRetry: Bool = false) async {
        guard let modelContext = modelContext else { return }

        let descriptor = FetchDescriptor<PendingMemory>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let pending = try? modelContext.fetch(descriptor) else {
            return
        }

        guard !pending.isEmpty else { return }

        print("🔄 [SUPERMEMORY] Processing \(pending.count) pending memories\(forceRetry ? " (forced retry)" : "")")

        // Process up to 5 memories at a time
        for memory in pending.prefix(5) {
            // Check if we should wait due to exponential backoff (unless forced)
            if !forceRetry, let lastAttempt = memory.lastAttempt {
                let delay = backoffDelay(for: memory.retryCount)
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
                if timeSinceLastAttempt < delay {
                    print("⏳ [SUPERMEMORY] Skipping memory (backoff: \(Int(delay - timeSinceLastAttempt))s remaining)")
                    continue
                }
            }

            do {
                // Attempt sync via Cloud Function
                try await addMemoryViaCloudFunction(
                    content: memory.content,
                    metadata: memory.metadata
                )

                // Success: Remove from queue
                await MainActor.run {
                    modelContext.delete(memory)
                    try? modelContext.save()
                    totalMemoriesStored += 1
                    lastSyncDate = Date()
                }
                print("✅ [SUPERMEMORY] Synced pending memory")

            } catch {
                // Update retry count
                await MainActor.run {
                    memory.retryCount += 1
                    memory.lastAttempt = Date()

                    // Discard after 3 attempts
                    if memory.retryCount >= 3 {
                        print("❌ [SUPERMEMORY] Discarding memory after 3 attempts")
                        modelContext.delete(memory)
                    }

                    try? modelContext.save()
                }
            }
        }

        await MainActor.run {
            updatePendingCount()
        }
    }

    /// Calculate exponential backoff delay
    private func backoffDelay(for retryCount: Int) -> TimeInterval {
        switch retryCount {
        case 0: return 5      // 5 seconds
        case 1: return 30     // 30 seconds
        case 2: return 120    // 2 minutes
        default: return 300   // 5 minutes
        }
    }

    /// Determine if error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        if let supermemoryError = error as? SupermemoryError {
            switch supermemoryError {
            case .notConfigured, .decodingError, .invalidContent:
                return false
            case .invalidResponse(let code):
                return code >= 500 || code == 429 // Server errors or rate limit
            case .networkError, .timeout:
                return true
            }
        }

        // Check Firebase Functions errors
        if let nsError = error as NSError?, nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code)
            switch code {
            case .unauthenticated, .permissionDenied, .invalidArgument:
                return false
            default:
                return true
            }
        }

        return true // Default to retryable
    }

    /// Update published pending count
    private func updatePendingCount() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<PendingMemory>()
        pendingMemoriesCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

}
