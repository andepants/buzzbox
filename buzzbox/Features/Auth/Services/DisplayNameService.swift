/// DisplayNameService.swift
/// Manages displayName uniqueness enforcement via Firestore `/displayNames` collection
/// [Source: Epic 1, Story 1.1]
///
/// Handles Instagram-style username validation and reservation using Firestore
/// as the single source of truth for uniqueness checks.

import Foundation
import FirebaseFirestore

/// Service for managing display name uniqueness
@MainActor
final class DisplayNameService {
    // MARK: - Properties

    private let db: Firestore

    // MARK: - Initialization

    /// Initialize with optional Firestore instance (useful for testing)
    /// - Parameter firestore: Firestore instance (defaults to shared instance)
    init(firestore: Firestore = Firestore.firestore()) {
        self.db = firestore
    }

    // MARK: - Public Methods

    /// Check if a display name is available
    /// - Parameter name: The display name to check
    /// - Returns: `true` if available, `false` if taken
    /// - Throws: Firestore errors
    func checkAvailability(_ name: String) async throws -> Bool {
        let doc = try await db.collection("displayNames").document(name).getDocument()
        return !doc.exists
    }

    /// Reserve a display name for a user
    /// - Parameters:
    ///   - name: The display name to reserve
    ///   - userId: The Firebase Auth UID of the user
    /// - Throws: Firestore errors
    func reserveDisplayName(_ name: String, userId: String) async throws {
        try await db.collection("displayNames").document(name).setData([
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    /// Release a display name (for account deletion or name change)
    /// - Parameter name: The display name to release
    /// - Throws: Firestore errors
    func releaseDisplayName(_ name: String) async throws {
        try await db.collection("displayNames").document(name).delete()
    }

    /// Release displayName claim from /displayNames collection with ownership verification
    /// - Parameters:
    ///   - name: DisplayName to release
    ///   - userId: User ID that owns the displayName
    /// - Throws: DisplayNameError if user doesn't own the name
    func releaseDisplayName(_ name: String, userId: String) async throws {
        // Verify ownership before deleting
        let doc = try await db.collection("displayNames").document(name).getDocument()

        guard let data = doc.data(),
              let ownerUserId = data["userId"] as? String,
              ownerUserId == userId else {
            throw DisplayNameError.notOwned
        }

        // Delete the claim
        try await db.collection("displayNames").document(name).delete()
    }
}

// MARK: - Display Name Errors

/// Errors that can occur during display name operations
enum DisplayNameError: Error, LocalizedError {
    case notOwned

    var errorDescription: String? {
        switch self {
        case .notOwned:
            return "You don't own this display name."
        }
    }
}
