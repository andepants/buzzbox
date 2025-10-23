/// DMValidationError.swift
///
/// Error types for DM (Direct Message) validation
/// Enforces single-creator platform restrictions where fans can only message Andrew
///
/// Created: 2025-10-22
/// [Source: Story 5.4 - DM Restrictions]

import Foundation

/// Errors that can occur when validating DM creation permissions
enum DMValidationError: Error, LocalizedError {
    /// Both users are fans - fans cannot DM each other
    case bothFans

    /// Recipient is invalid or not found
    case invalidRecipient

    var errorDescription: String? {
        switch self {
        case .bothFans:
            return "You can only send direct messages to Andrew"
        case .invalidRecipient:
            return "Invalid recipient"
        }
    }
}
