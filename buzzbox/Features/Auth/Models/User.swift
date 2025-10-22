/// User.swift
/// Swift model representing authenticated user data
/// [Source: Epic 1, Story 1.1]
///
/// This is a lightweight Sendable struct used for transferring user data
/// between services and ViewModels. The persistent storage uses UserEntity (SwiftData).

import Foundation

/// Represents an authenticated user in the app
/// Sendable conformance ensures safe usage across concurrency boundaries
struct User: Sendable, Codable, Identifiable {
    /// Firebase Auth UID
    let id: String

    /// User's email address
    var email: String

    /// User's chosen display name (Instagram-style)
    var displayName: String

    /// Optional profile photo URL
    var photoURL: String?

    /// Account creation timestamp
    let createdAt: Date

    /// Initialize a new User instance
    /// - Parameters:
    ///   - id: Firebase Auth UID
    ///   - email: User's email address
    ///   - displayName: User's display name
    ///   - photoURL: Optional profile photo URL
    ///   - createdAt: Account creation timestamp (defaults to current date)
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
    }
}
