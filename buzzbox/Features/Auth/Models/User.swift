/// User.swift
/// Swift model representing authenticated user data
/// [Source: Epic 1, Story 1.1]
///
/// This is a lightweight Sendable struct used for transferring user data
/// between services and ViewModels. The persistent storage uses UserEntity (SwiftData).

import Foundation

// MARK: - Constants

/// Creator email constant (Andrew Heim Dev)
let CREATOR_EMAIL = "andrewsheim@gmail.com"

// MARK: - User Type Enum

/// Defines user type in the platform
enum UserType: String, Codable, Sendable {
    /// Creator of the platform (Andrew Heim Dev)
    case creator
    /// Fan/member of the community
    case fan
}

// MARK: - User Model

/// Represents an authenticated user in the app
/// Sendable conformance ensures safe usage across concurrency boundaries
struct User: Sendable, Codable, Identifiable, Equatable {
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

    /// User type (creator or fan)
    var userType: UserType

    /// Whether user profile is public
    var isPublic: Bool

    /// Initialize a new User instance
    /// - Parameters:
    ///   - id: Firebase Auth UID
    ///   - email: User's email address
    ///   - displayName: User's display name
    ///   - photoURL: Optional profile photo URL
    ///   - createdAt: Account creation timestamp (defaults to current date)
    ///   - userType: User type (auto-assigned based on email if not provided)
    ///   - isPublic: Whether profile is public (auto-assigned based on userType if not provided)
    init(
        id: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        createdAt: Date = Date(),
        userType: UserType? = nil,
        isPublic: Bool? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = createdAt

        // Auto-assign userType based on email if not provided
        if let userType = userType {
            self.userType = userType
        } else {
            self.userType = email.lowercased() == CREATOR_EMAIL.lowercased() ? .creator : .fan
        }

        // Auto-assign isPublic based on userType if not provided
        if let isPublic = isPublic {
            self.isPublic = isPublic
        } else {
            self.isPublic = self.userType == .creator
        }
    }

    /// Check if user is the creator
    var isCreator: Bool {
        userType == .creator
    }

    /// Check if user is a fan
    var isFan: Bool {
        userType == .fan
    }
}
