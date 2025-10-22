/// FAQEntity.swift
///
/// SwiftData model for FAQ library storage.
/// Stores frequently asked questions and their answers.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class FAQEntity {
    // MARK: - Core Properties

    /// Unique FAQ identifier
    @Attribute(.unique) var id: String

    /// FAQ category (equipment, software, business, etc.)
    var category: FAQCategory

    /// Question pattern (what the user might ask)
    var questionPattern: String

    /// Pre-written answer
    var answer: String

    /// Number of times this FAQ was used
    var usageCount: Int

    /// Last time this FAQ was used
    var lastUsedAt: Date?

    /// Is this FAQ enabled?
    var isEnabled: Bool

    /// Creation timestamp
    var createdAt: Date

    /// Last update timestamp
    var updatedAt: Date

    // MARK: - Relationships

    /// Owner user (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \UserEntity.faqs)
    var user: UserEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        category: FAQCategory,
        questionPattern: String,
        answer: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.questionPattern = questionPattern
        self.answer = answer
        self.usageCount = 0
        self.isEnabled = true
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    // MARK: - Helper Methods

    /// Increment usage count
    func recordUsage() {
        self.usageCount += 1
        self.lastUsedAt = Date()
        self.updatedAt = Date()
    }

    /// Update FAQ content
    func update(questionPattern: String? = nil, answer: String? = nil) {
        if let questionPattern = questionPattern {
            self.questionPattern = questionPattern
        }
        if let answer = answer {
            self.answer = answer
        }
        self.updatedAt = Date()
    }
}

// MARK: - Supporting Enums

enum FAQCategory: String, Codable, CaseIterable {
    case equipment = "Equipment"
    case software = "Software"
    case business = "Business"
    case personal = "Personal"
    case career = "Career"
    case other = "Other"
}
