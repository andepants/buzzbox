/// AICategory.swift
///
/// Enum for AI-detected conversation categories with display properties.
/// Used for filtering conversations in the Creator Inbox.
///
/// Created: 2025-10-25
/// [Source: Story 8.6 - Creator Inbox Smart Filter]

import SwiftUI

/// AI-detected conversation category for filtering
enum AICategory: String, CaseIterable, Codable {
    case all = "all"
    case fan = "fan"
    case superFan = "super_fan"
    case business = "business"
    case spam = "spam"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .fan: return "Fan"
        case .superFan: return "Super Fan"
        case .business: return "Business"
        case .spam: return "Spam"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.fill"
        case .fan: return "heart.fill"
        case .superFan: return "star.fill"
        case .business: return "briefcase.fill"
        case .spam: return "trash.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .fan: return .pink
        case .superFan: return .purple
        case .business: return .green
        case .spam: return .red
        case .urgent: return .orange
        }
    }

    /// Validate raw string from AI against enum cases
    static func validate(_ rawValue: String?) -> AICategory? {
        guard let raw = rawValue else { return nil }
        return AICategory(rawValue: raw)
    }
}
