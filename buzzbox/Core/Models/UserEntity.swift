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
