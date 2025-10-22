/// MessageValidator.swift
///
/// Validates message content before sending (empty check, length, UTF-8 encoding).
/// Ensures messages meet requirements before optimistic UI and RTDB sync.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages]

import Foundation

/// Message validation utility
struct MessageValidator {
    // MARK: - Constants

    static let maxLength = 10_000
    static let minLength = 1

    // MARK: - Validation Errors

    enum ValidationError: LocalizedError {
        case empty
        case tooLong
        case invalidCharacters

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Message cannot be empty"
            case .tooLong:
                return "Message is too long (max 10,000 characters)"
            case .invalidCharacters:
                return "Message contains invalid characters"
            }
        }
    }

    // MARK: - Validation Methods

    /// Validates message text before sending
    /// - Parameter text: Message text to validate
    /// - Throws: ValidationError if message is invalid
    static func validate(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check minimum length
        guard trimmed.count >= minLength else {
            throw ValidationError.empty
        }

        // Check maximum length
        guard trimmed.count <= maxLength else {
            throw ValidationError.tooLong
        }

        // UTF-8 encoding validation (ensure valid text)
        guard trimmed.data(using: .utf8) != nil else {
            throw ValidationError.invalidCharacters
        }
    }
}
