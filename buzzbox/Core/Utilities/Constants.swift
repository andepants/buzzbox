/// Constants.swift
///
/// Global constants for the Buzzbox application
///
/// Created: 2025-10-23
/// [Source: Story 6.3.5 - FAQ Auto-Responder iOS Integration]

import Foundation

/// Global constants for the application
enum Constants {
    // MARK: - Creator Configuration

    /// Creator's Firebase Auth UID (Andrew Heim)
    /// This matches CREATOR_UID from Cloud Functions
    /// Used to identify messages TO the creator for FAQ auto-response
    static let CREATOR_UID = "pzkN1Va8GiWGrdKhMT6HekMTOyE2"

    /// Creator's email address
    static let CREATOR_EMAIL = "andrewsheim@gmail.com"

    // MARK: - AI Settings

    /// UserDefaults key for FAQ auto-response toggle
    static let FAQ_AUTO_RESPONSE_ENABLED_KEY = "ai.faqAutoResponse.enabled"
}
