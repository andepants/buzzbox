/// AuthViewModel.swift
/// ViewModel for authentication screens (sign up, login)
/// [Source: Epic 1, Story 1.1]
///
/// Manages form state, validation, and coordinates with AuthService
/// for user sign up and login operations.

import Foundation
import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

/// Authentication view model
@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Form State

    /// Email input
    @Published var email: String = ""

    /// Password input
    @Published var password: String = ""

    /// Confirm password input (sign up only)
    @Published var confirmPassword: String = ""

    /// Display name input (sign up only)
    @Published var displayName: String = ""

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Show error alert
    @Published var showError: Bool = false

    /// Display name availability status
    @Published var displayNameAvailability: DisplayNameAvailability = .unknown

    /// Login attempt count (for shake animation)
    @Published var loginAttemptCount: Int = 0

    /// Current authenticated user
    @Published var currentUser: User?

    /// Authentication status
    @Published var isAuthenticated: Bool = false

    /// Password reset email sent flag
    @Published var resetEmailSent: Bool = false

    // MARK: - Dependencies

    private let authService: AuthService
    private var displayNameCheckTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize with optional AuthService (useful for testing)
    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    // MARK: - Computed Properties

    /// Form validation state
    var isFormValid: Bool {
        let valid = isEmailValid &&
               isPasswordValid &&
               passwordsMatch &&
               isDisplayNameValid &&
               displayNameAvailability == .available

        return valid
    }

    /// Email validation
    var isEmailValid: Bool {
        authService.isValidEmail(email)
    }

    /// Password validation
    var isPasswordValid: Bool {
        authService.isValidPassword(password)
    }

    /// Passwords match
    var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }

    /// Display name format validation
    var isDisplayNameValid: Bool {
        authService.isValidDisplayName(displayName)
    }

    // MARK: - Display Name Availability

    /// Check display name availability (debounced)
    func checkDisplayNameAvailability() {
        // Cancel previous task
        displayNameCheckTask?.cancel()

        // Reset if invalid format
        guard isDisplayNameValid else {
            displayNameAvailability = .unknown
            return
        }

        // Debounce check (500ms)
        displayNameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))

            guard !Task.isCancelled else {
                return
            }

            do {
                let service = DisplayNameService()
                let isAvailable = try await service.checkAvailability(displayName)
                displayNameAvailability = isAvailable ? .available : .taken
            } catch {
                displayNameAvailability = .unknown
            }
        }
    }

    // MARK: - Sign Up

    /// Sign up a new user
    /// - Parameter modelContext: SwiftData ModelContext
    /// - Throws: AuthError for validation/Firebase errors
    func signUp(modelContext: ModelContext) async throws {
        // Clear previous errors
        errorMessage = nil

        // Validate form
        guard isFormValid else {
            errorMessage = "Please fix the errors before continuing"
            return
        }

        // Set loading state
        isLoading = true
        defer { isLoading = false }

        do {
            // Create user via AuthService
            let user = try await authService.createUser(
                email: email,
                password: password,
                displayName: displayName,
                modelContext: modelContext
            )

            // Update local state
            currentUser = user
            isAuthenticated = true

            // Success - navigation handled by parent view observing isAuthenticated
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            throw error
        }
    }

    // MARK: - Auto-Login

    /// Checks authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        // Get ModelContext from environment (injected by parent view)
        // For now, we'll handle this without ModelContext to avoid circular dependency
        // The actual user fetch will happen when needed

        do {
            // Check if Firebase has a current user (Firebase persists automatically)
            if let firebaseUser = Auth.auth().currentUser {
                // Attempt to refresh token to verify it's still valid
                let idToken = try await firebaseUser.getIDToken()

                // Update Keychain with refreshed token
                let keychainService = KeychainService()
                try keychainService.save(token: idToken)

                // Create minimal user object (full data can be fetched later if needed)
                currentUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? "",
                    photoURL: firebaseUser.photoURL?.absoluteString,
                    createdAt: Date()
                )

                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        } catch {
            isAuthenticated = false

            // Clear invalid token
            let keychainService = KeychainService()
            try? keychainService.delete()
        }
    }

    /// Refreshes auth token if app was in background for > 1 hour
    func refreshAuthIfNeeded(lastActiveDate: Date) async {
        guard isAuthenticated else { return }

        do {
            try await authService.refreshAuthIfNeeded(lastActiveDate: lastActiveDate)
        } catch {
            // Token refresh failed - force re-login
            isAuthenticated = false
            currentUser = nil
        }
    }

    // MARK: - Login

    /// Log in an existing user
    /// - Parameter modelContext: SwiftData ModelContext
    func login(modelContext: ModelContext) async {
        // Clear previous errors
        errorMessage = nil
        showError = false

        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password"
            showError = true
            return
        }

        // Set loading state
        isLoading = true
        defer { isLoading = false }

        do {
            // Sign in via AuthService
            let user = try await authService.signIn(
                email: email,
                password: password,
                modelContext: modelContext
            )

            // Update local state
            currentUser = user
            isAuthenticated = true

            // Success - navigation handled by parent view observing isAuthenticated
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            showError = true
            loginAttemptCount += 1
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            showError = true
            loginAttemptCount += 1
        }
    }

    // MARK: - Password Reset

    /// Sends password reset email
    /// - Parameter email: User's email address
    func sendPasswordReset(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.resetPassword(email: email)
            resetEmailSent = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            throw error
        }
    }

    // MARK: - Validation Messages

    /// Get email validation message
    var emailValidationMessage: String? {
        guard !email.isEmpty else { return nil }
        return isEmailValid ? nil : "Please enter a valid email address"
    }

    /// Get password validation message
    var passwordValidationMessage: String? {
        guard !password.isEmpty else { return nil }
        return isPasswordValid ? nil : "Password must be at least 8 characters"
    }

    /// Get password match validation message
    var passwordMatchValidationMessage: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Passwords do not match"
    }

    /// Get display name validation message
    var displayNameValidationMessage: String? {
        guard !displayName.isEmpty else { return nil }

        if !isDisplayNameValid {
            return "3-30 characters, letters, numbers, periods, underscores only"
        }

        switch displayNameAvailability {
        case .available:
            return nil
        case .taken:
            return "This display name is already taken"
        case .unknown:
            return nil
        }
    }

    // MARK: - Logout

    /// Logs out current user
    func logout() async {
        do {
            try await authService.signOut()

            // Reset all published properties
            isAuthenticated = false
            currentUser = nil
            email = ""
            password = ""
            confirmPassword = ""
            displayName = ""
            errorMessage = nil
            showError = false
            resetEmailSent = false
            displayNameAvailability = .unknown
            loginAttemptCount = 0

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // VoiceOver announcement
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "You have been logged out"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Supporting Types

/// Display name availability status
enum DisplayNameAvailability {
    case unknown
    case available
    case taken
}
