/// AuthError.swift
/// Custom error types for authentication operations
/// [Source: Epic 1, Story 1.1]
///
/// Provides user-friendly error messages for Firebase Auth and validation errors

import Foundation

/// Authentication-specific errors
enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case passwordMismatch
    case invalidDisplayName
    case displayNameTaken
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case userNotFound
    case wrongPassword
    case userDisabled
    case tooManyRequests
    case unknownError(String)

    /// User-friendly error description
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPassword:
            return "Password must be at least 8 characters"
        case .passwordMismatch:
            return "Passwords do not match"
        case .invalidDisplayName:
            return "Display name must be 3-30 characters and contain only letters, numbers, periods, and underscores"
        case .displayNameTaken:
            return "This display name is already taken"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters"
        case .networkError:
            return "Network error. Please check your connection and try again"
        case .userNotFound:
            return "No account found with this email address"
        case .wrongPassword:
            return "Incorrect password. Please try again or use 'Forgot Password?'"
        case .userDisabled:
            return "This account has been disabled. Please contact support"
        case .tooManyRequests:
            return "Too many failed login attempts. Please try again later"
        case .unknownError(let message):
            return message
        }
    }
}
