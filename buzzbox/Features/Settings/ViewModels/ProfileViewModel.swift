/// ProfileViewModel.swift
/// ViewModel for profile management
/// [Source: Epic 1, Story 1.5]
///
/// Manages user profile editing including display name validation,
/// profile picture upload, and synchronization with Firebase services.

import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// Profile management view model
@MainActor
@Observable
final class ProfileViewModel {
    // MARK: - Published State

    /// Display name input
    var displayName: String = ""

    /// Profile photo URL
    var photoURL: URL?

    /// Loading state for save operation
    var isLoading: Bool = false

    /// Upload progress state
    var isUploading: Bool = false

    /// Display name availability check state
    var isCheckingAvailability: Bool = false

    /// Display name availability flag
    var displayNameAvailable: Bool = false

    /// Display name error message
    var displayNameError: String = ""

    /// General error message
    var errorMessage: String?

    /// Show error alert
    var showError: Bool = false

    /// Show success alert
    var showSuccess: Bool = false

    /// Has unsaved changes
    var hasChanges: Bool = false

    // MARK: - Dependencies

    private let authService: AuthService
    private let storageService: StorageService
    private let displayNameService: DisplayNameService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Original Values

    private var originalDisplayName: String = ""
    private var originalPhotoURL: URL?

    // MARK: - Initialization

    /// Initialize ProfileViewModel with optional dependencies
    /// - Parameters:
    ///   - authService: AuthService instance
    ///   - storageService: StorageService instance
    ///   - displayNameService: DisplayNameService instance
    init(
        authService: AuthService = AuthService(),
        storageService: StorageService = StorageService(),
        displayNameService: DisplayNameService = DisplayNameService()
    ) {
        self.authService = authService
        self.storageService = storageService
        self.displayNameService = displayNameService

        // Load current user profile
        loadCurrentProfile()
    }

    // MARK: - Profile Loading

    /// Load current user profile from AuthService
    func loadCurrentProfile() {
        guard let currentUser = authService.currentUser else {
            return
        }

        displayName = currentUser.displayName
        originalDisplayName = currentUser.displayName

        if let photoURLString = currentUser.photoURL {
            photoURL = URL(string: photoURLString)
            originalPhotoURL = photoURL
        }
    }

    // MARK: - Display Name Validation

    /// Check displayName availability with debouncing
    /// - Parameter newName: New display name to check
    func checkDisplayNameAvailability(_ newName: String) async {
        guard !newName.isEmpty else {
            displayNameError = ""
            displayNameAvailable = false
            hasChanges = false
            return
        }

        // If name unchanged, skip check
        guard newName != originalDisplayName else {
            displayNameError = ""
            displayNameAvailable = true
            hasChanges = photoURL != originalPhotoURL
            return
        }

        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        // Validate format
        guard authService.isValidDisplayName(newName) else {
            displayNameError = "Invalid username format. Use 3-30 characters, letters, numbers, periods, and underscores."
            displayNameAvailable = false
            return
        }

        // Check availability
        do {
            let isAvailable = try await displayNameService.checkAvailability(newName)

            if isAvailable {
                displayNameError = ""
                displayNameAvailable = true
                hasChanges = true
            } else {
                displayNameError = "This username is already taken."
                displayNameAvailable = false
            }
        } catch {
            displayNameError = "Failed to check availability."
            displayNameAvailable = false
        }
    }

    // MARK: - Image Upload

    /// Upload profile image to Firebase Storage
    /// - Parameter image: UIImage to upload
    func uploadProfileImage(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }

        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                throw StorageError.invalidDownloadURL
            }

            let path = "profile_pictures/\(userId)/profile.jpg"

            let downloadURL = try await storageService.uploadImage(image, path: path)
            photoURL = downloadURL
            hasChanges = true

            // Success haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    // MARK: - Profile Update

    /// Update profile with new displayName and/or photoURL
    /// - Parameter modelContext: SwiftData ModelContext for local persistence
    func updateProfile(modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Determine what changed
            let displayNameChanged = displayName != originalDisplayName
            let photoChanged = photoURL != originalPhotoURL

            // Update profile via AuthService
            try await authService.updateUserProfile(
                displayName: displayNameChanged ? displayName : nil,
                photoURL: photoChanged ? photoURL : nil,
                modelContext: modelContext
            )

            // Update original values
            originalDisplayName = displayName
            originalPhotoURL = photoURL
            hasChanges = false
            showSuccess = true

            // Success haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    // MARK: - Computed Properties

    /// Can save profile (has changes and no errors)
    var canSave: Bool {
        return !isLoading &&
               !displayName.isEmpty &&
               displayNameError.isEmpty &&
               hasChanges &&
               (displayName == originalDisplayName || displayNameAvailable)
    }
}
