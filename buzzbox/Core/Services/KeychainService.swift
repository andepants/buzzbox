/// KeychainService.swift
/// Handles secure storage of Firebase auth tokens in iOS Keychain
/// [Source: Epic 1, Story 1.2]
///
/// Provides secure storage and retrieval of authentication tokens using
/// the iOS Keychain. Tokens are automatically encrypted by iOS and only
/// accessible when the device is unlocked.

import Foundation
import Security

/// Manages secure storage of authentication tokens in iOS Keychain
final class KeychainService {
    // MARK: - Properties

    /// Service identifier for Keychain items
    private let service = "com.theheimlife.buzzbox"

    /// Account identifier for auth token
    private let account = "firebase_auth_token"

    // MARK: - Public Methods

    /// Saves auth token to Keychain
    /// - Parameter token: Firebase ID token to store securely
    /// - Throws: KeychainError.saveFailed if save operation fails
    func save(token: String) throws {
        let data = Data(token.utf8)

        // Create query dictionary for Keychain item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete old token first (if exists)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new token to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }

    /// Retrieves auth token from Keychain
    /// - Returns: Firebase ID token if found, nil otherwise
    func retrieve() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Deletes auth token from Keychain
    /// - Throws: KeychainError.deleteFailed if delete operation fails
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success if deleted OR item didn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations
enum KeychainError: Error, LocalizedError {
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save authentication token securely."
        case .deleteFailed:
            return "Failed to delete authentication token."
        }
    }
}
