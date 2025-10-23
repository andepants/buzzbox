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
import FirebaseFirestore
import Combine
import Kingfisher

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

    let authService: AuthService
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
    /// - Parameter modelContext: SwiftData ModelContext for local persistence
    func checkAuthStatus(modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Check if Firebase has a current user (Firebase persists automatically)
            guard let firebaseUser = Auth.auth().currentUser else {
                isAuthenticated = false
                return
            }

            // Attempt to refresh token to verify it's still valid
            let idToken = try await firebaseUser.getIDToken()

            // Update Keychain with refreshed token
            let keychainService = KeychainService()
            try keychainService.save(token: idToken)

            // Fetch full user data from Firestore to get photoURL and other fields
            let uid = firebaseUser.uid
            let firestore = Firestore.firestore()
            let userDoc = try await firestore.collection("users").document(uid).getDocument()

            guard let data = userDoc.data() else {
                // User document not found in Firestore - clear auth
                isAuthenticated = false
                try? keychainService.delete()
                return
            }

            // Parse full user data from Firestore
            let email = data["email"] as? String ?? firebaseUser.email ?? ""
            let displayName = data["displayName"] as? String ?? firebaseUser.displayName ?? ""
            let photoURL = data["photoURL"] as? String
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

            // Parse userType (email-based logic takes precedence for creator)
            let userType: UserType
            if email.lowercased() == CREATOR_EMAIL.lowercased() {
                userType = .creator
            } else if let userTypeRaw = data["userType"] as? String,
                      let parsedType = UserType(rawValue: userTypeRaw) {
                userType = parsedType
            } else {
                userType = .fan
            }
            let isPublic = data["isPublic"] as? Bool ?? (userType == .creator)

            // Create full user object with Firestore data
            currentUser = User(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: photoURL,
                createdAt: createdAt,
                userType: userType,
                isPublic: isPublic
            )

            // Update local SwiftData UserEntity (upsert pattern)
            // This ensures profile images and other critical data persist across app restarts
            let descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate { $0.id == uid }
            )
            let existingUsers = try modelContext.fetch(descriptor)

            if let existingUser = existingUsers.first {
                // Update existing user with latest data from Firestore
                existingUser.email = email
                existingUser.displayName = displayName
                existingUser.photoURL = photoURL
                existingUser.userType = userType
                existingUser.isPublic = isPublic
            } else {
                // Create new user entity if doesn't exist
                let userEntity = UserEntity(
                    id: uid,
                    email: email,
                    displayName: displayName,
                    photoURL: photoURL,
                    createdAt: createdAt,
                    userType: userType,
                    isPublic: isPublic
                )
                modelContext.insert(userEntity)
            }
            try modelContext.save()

            // Note: authService.currentUser will be updated via Firebase Auth state listener
            // No need to manually sync here

            isAuthenticated = true
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
        return isPasswordValid ? nil : "Password must be at least 6 characters"
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

    // MARK: - Form Reset

    /// Resets login form fields
    func resetLoginFields() {
        email = ""
        password = ""
        errorMessage = nil
        showError = false
    }

    /// Resets sign up form fields
    func resetSignUpFields() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
        showError = false
        displayNameAvailability = .unknown
    }

    // MARK: - Logout

    /// Logs out current user and clears ALL data
    /// - Parameter modelContext: SwiftData ModelContext for clearing local data
    func logout(modelContext: ModelContext) async {

        // CRITICAL: Complete cleanup BEFORE optimistic UI reset
        // This ensures the next user starts with a completely clean slate

        // 1. Remove all Firebase listeners FIRST (prevents post-logout observer fires)
        await UserPresenceService.shared.removeAllListeners()

        // 2. Set user offline in Realtime Database (non-blocking, with timeout)
        await UserPresenceService.shared.setOffline()

        // 3. Sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
        } catch {
            // Don't throw - continue cleanup
        }

        // 4. Delete auth token from Keychain
        let keychainService = KeychainService()
        do {
            try keychainService.delete()
        } catch {
            // Continue cleanup even if Keychain fails
        }

        // 5. Clear ALL UserDefaults (not just tab selection)
        // This ensures no stale state persists between users
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // 6. Clear all SwiftData entities
        await clearAllLocalData(modelContext: modelContext)

        // 7. Clear Kingfisher image cache
        await Task.detached(priority: .background) {
            KingfisherManager.shared.cache.clearMemoryCache()
            KingfisherManager.shared.cache.clearDiskCache()
        }.value

        // OPTIMISTIC UI: Reset auth state AFTER cleanup for instant UI redirect
        // This ensures user sees LoginView instantly
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

        // Haptic feedback (immediate, after cleanup)
        HapticFeedback.impact(.medium)

        // VoiceOver announcement (immediate)
        UIAccessibility.post(
            notification: .screenChanged,
            argument: "You have been logged out"
        )
    }

    /// Clear all SwiftData entities on logout
    /// - Parameter modelContext: SwiftData ModelContext
    private func clearAllLocalData(modelContext: ModelContext) async {

        do {
            // Delete all UserEntity records
            try modelContext.delete(model: UserEntity.self)

            // Delete all ConversationEntity records
            try modelContext.delete(model: ConversationEntity.self)

            // Delete all MessageEntity records
            try modelContext.delete(model: MessageEntity.self)

            // Delete all FAQEntity records
            try modelContext.delete(model: FAQEntity.self)

            // Delete all AttachmentEntity records
            try modelContext.delete(model: AttachmentEntity.self)

            try modelContext.save()

        } catch {
            // Non-critical error, continue logout
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
