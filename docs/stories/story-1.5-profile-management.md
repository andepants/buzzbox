---
# Story 1.5: User Profile Management

id: STORY-1.5
title: "User Profile Management (Display Name & Photo)"
epic: "Epic 1: User Authentication & Profiles"
status: draft
priority: P0  # Critical blocker
estimate: 5  # Story points
assigned_to: null
created_date: "2025-10-20"
sprint_day: 1  # Day 1 of 7-day sprint

---

## Description

**As a** content creator
**I need** to set my display name and profile picture
**So that** others can identify me and personalize my profile

This story implements complete user profile management including display name editing with Instagram-style validation and uniqueness enforcement, profile picture upload to Firebase Storage, and synchronization across Firestore and SwiftData. Profile pictures are displayed using Kingfisher for optimal caching and performance.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Profile settings screen accessible from main app
- [ ] Display name field (editable with validation)
- [ ] **DisplayName change validates uniqueness before saving**
- [ ] **Release old displayName claim in `/displayNames/` collection**
- [ ] Profile picture (tap to change)
- [ ] Image picker for selecting profile photo
- [ ] Upload progress indicator
- [ ] Save button
- [ ] Success message after save
- [ ] Profile updates sync to Firestore
- [ ] Profile updates sync to local SwiftData UserEntity
- [ ] **User presence updated in Realtime Database on profile changes**
- [ ] Photo Library permission requested with proper Info.plist description
- [ ] Images compressed before upload (max 2048x2048, 85% JPEG quality, < 500KB)
- [ ] Profile pictures cached using Kingfisher
- [ ] Loading states with skeleton screens

---

## Technical Tasks

**Implementation steps:**

1. **Create Profile View** (`Features/Settings/Views/ProfileView.swift`)
   - AsyncImage or KFImage showing current profile picture
   - Display name TextField
   - "Change Photo" button
   - Save button
   - **iOS-specific**: PhotosPicker for image selection (iOS 16+)
   - **iOS-specific**: Photo Library permission handling
   - **iOS-specific**: Image compression before upload
   - **iOS-specific**: Loading states with ActivityIndicatorView

2. **Create Profile ViewModel** (`Features/Settings/ViewModels/ProfileViewModel.swift`)
   - `@Published var displayName: String`
   - `@Published var photoURL: URL?`
   - `@Published var isUploading: Bool`
   - `@Published var isCheckingAvailability: Bool`
   - `@Published var displayNameAvailable: Bool`
   - `@Published var displayNameError: String`
   - `func updateProfile() async throws`
   - `func uploadProfileImage(_ image: UIImage) async throws -> URL`
   - Debounced displayName availability check (500ms)

3. **Add to AuthService** (`Features/Auth/Services/AuthService.swift`)
   - `func updateUserProfile(displayName: String?, photoURL: URL?) async throws`
   - **If displayName changed:**
     - Check availability via DisplayNameService
     - Release old claim from `/displayNames/{oldName}`
     - Reserve new claim in `/displayNames/{newName}`
   - Update Firestore user document
   - Update local SwiftData UserEntity
   - **Update Realtime Database presence** (optional: add displayName for quick lookup)

4. **Create StorageService** (`Core/Services/StorageService.swift`)
   - `func uploadImage(_ image: UIImage, path: String) async throws -> URL`
   - Firebase Storage upload to `/profile_pictures/{userId}/{filename}`
   - Image compression before upload (0.85 quality, max 2048x2048px, target < 500KB)
   - Return HTTPS download URL (not gs:// reference URL)
   - Security: Storage Rules enforce max size & ownership

5. **Image Picker Integration**
   - Use `PhotosPicker` (iOS 16+)
   - Handle Photo Library permission
   - Handle permission denial gracefully

6. **Add Info.plist Permissions**
   - `NSPhotoLibraryUsageDescription`: "We need access to your photos to set your profile picture."

7. **Kingfisher Integration**
   - Install Kingfisher via SPM
   - Configure cache limits in app initialization
   - Use `KFImage` for profile picture display with loading indicators

8. **Testing**
   - Unit tests for profile update logic
   - Unit tests for displayName change flow (release + reserve)
   - Integration test: Upload image to Firebase Storage
   - Test image compression (verify < 500KB)
   - Test displayName uniqueness enforcement

---

## Technical Specifications

### Files to Create/Modify

```
Features/Settings/Views/ProfileView.swift (create)
Features/Settings/ViewModels/ProfileViewModel.swift (create)
Features/Auth/Services/AuthService.swift (modify - add updateUserProfile())
Core/Services/StorageService.swift (create)
Info.plist (modify - add NSPhotoLibraryUsageDescription)
```

### Code Examples

**StorageService.swift:**

```swift
/// StorageService.swift
/// Handles Firebase Storage operations for profile pictures and media
/// [Source: Epic 1, Story 1.5]

import Foundation
import FirebaseStorage
import UIKit

/// Manages Firebase Storage operations for images and media uploads
final class StorageService {
    private let storage = Storage.storage()

    /// Upload image to Firebase Storage and return publicly accessible download URL
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - path: Storage path (e.g., "profile_pictures/{userId}/profile.jpg")
    /// - Returns: HTTPS download URL (not gs:// reference URL)
    /// - Throws: StorageError if upload fails
    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        // 1. Compress image to target quality and size
        guard let compressedImage = compressImage(image) else {
            throw StorageError.imageCompressionFailed
        }

        // 2. Validate file size (5MB max enforced by Storage Rules)
        let maxSize = 5 * 1024 * 1024 // 5MB
        guard compressedImage.count <= maxSize else {
            throw StorageError.fileTooLarge
        }

        // 3. Create storage reference
        let storageRef = storage.reference().child(path)

        // 4. Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year

        let _ = try await storageRef.putDataAsync(compressedImage, metadata: metadata)

        // 5. CRITICAL: Get download URL (HTTPS, not gs://)
        // This URL is what we store in Firestore and use with Kingfisher
        let downloadURL = try await storageRef.downloadURL()

        // 6. Verify URL is HTTPS (required for Kingfisher & AsyncImage)
        guard downloadURL.scheme == "https" else {
            throw StorageError.invalidDownloadURL
        }

        return downloadURL
    }

    /// Compress image to target size and quality
    /// - Parameter image: UIImage to compress
    /// - Returns: Compressed JPEG data
    private func compressImage(_ image: UIImage) -> Data? {
        // Target: 2048x2048 max dimension, 85% JPEG quality, < 500KB
        let maxDimension: CGFloat = 2048
        let targetSize: Int = 500 * 1024 // 500KB

        // Resize if needed
        let resizedImage = image.resized(toMaxDimension: maxDimension)

        // Start with 85% quality
        var quality: CGFloat = 0.85
        var imageData = resizedImage.jpegData(compressionQuality: quality)

        // Reduce quality if still too large
        while let data = imageData, data.count > targetSize && quality > 0.1 {
            quality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: quality)
        }

        return imageData
    }

    /// Delete image from Firebase Storage
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
}

enum StorageError: Error, LocalizedError {
    case imageCompressionFailed
    case fileTooLarge
    case invalidDownloadURL

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different image."
        case .fileTooLarge:
            return "Image is too large. Maximum size is 5MB."
        case .invalidDownloadURL:
            return "Failed to get valid download URL from Firebase Storage."
        }
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    /// Resize image to maximum dimension while maintaining aspect ratio
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = max(size.width, size.height) / maxDimension
        if scale <= 1 { return self }

        let newSize = CGSize(width: size.width / scale, height: size.height / scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
```

**AuthService.swift - updateUserProfile():**

```swift
/// AuthService.swift
/// Handles user profile updates
/// [Source: Epic 1, Story 1.5]

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

extension AuthService {
    /// Updates user profile (displayName and/or photoURL)
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - photoURL: New profile picture URL (optional)
    /// - Throws: AuthError if update fails
    func updateUserProfile(displayName: String?, photoURL: URL?) async throws {
        guard let currentUser = auth.currentUser else {
            throw AuthError.userNotFound
        }

        let uid = currentUser.uid

        // 1. Handle displayName change (if provided)
        if let newDisplayName = displayName {
            // Fetch current displayName from Firestore
            let userDoc = try await firestore.collection("users").document(uid).getDocument()
            let currentDisplayName = userDoc.data()?["displayName"] as? String

            // Only process if displayName actually changed
            if newDisplayName != currentDisplayName {
                // Validate format
                guard isValidDisplayName(newDisplayName) else {
                    throw AuthError.invalidDisplayName
                }

                // Check availability
                let displayNameService = DisplayNameService()
                let isAvailable = try await displayNameService.checkAvailability(newDisplayName)
                guard isAvailable else {
                    throw AuthError.displayNameTaken
                }

                // Release old displayName claim
                if let oldDisplayName = currentDisplayName {
                    try await displayNameService.releaseDisplayName(oldDisplayName, userId: uid)
                }

                // Reserve new displayName
                try await displayNameService.reserveDisplayName(newDisplayName, userId: uid)
            }
        }

        // 2. Prepare update data
        var updateData: [String: Any] = [:]
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL.absoluteString
        }

        // 3. Update Firestore user document
        try await firestore.collection("users").document(uid).updateData(updateData)

        // 4. Update Realtime Database presence (optional: add displayName for quick lookup)
        if let displayName = displayName {
            let presenceRef = database.reference().child("userPresence").child(uid)
            try await presenceRef.updateChildValues(["displayName": displayName])
        }

        // 5. Update local SwiftData UserEntity
        // (Implementation depends on SwiftData ModelContext)
    }
}
```

**DisplayNameService.swift - Add releaseDisplayName():**

```swift
/// DisplayNameService.swift
/// Manages displayName uniqueness enforcement
/// [Source: Epic 1, Story 1.5]

import Foundation
import FirebaseFirestore

extension DisplayNameService {
    /// Releases displayName claim from /displayNames collection
    /// - Parameters:
    ///   - name: DisplayName to release
    ///   - userId: User ID that owns the displayName
    func releaseDisplayName(_ name: String, userId: String) async throws {
        // Verify ownership before deleting
        let doc = try await db.collection("displayNames").document(name).getDocument()

        guard let data = doc.data(),
              let ownerUserId = data["userId"] as? String,
              ownerUserId == userId else {
            throw DisplayNameError.notOwned
        }

        // Delete the claim
        try await db.collection("displayNames").document(name).delete()
    }
}

enum DisplayNameError: Error, LocalizedError {
    case notOwned

    var errorDescription: String? {
        switch self {
        case .notOwned:
            return "You don't own this display name."
        }
    }
}
```

**ProfileView.swift:**

```swift
/// ProfileView.swift
/// User profile management screen
/// [Source: Epic 1, Story 1.5]

import SwiftUI
import Kingfisher
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Picture
                    ZStack {
                        if let photoURL = viewModel.photoURL {
                            KFImage(photoURL)
                                .placeholder {
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                }
                                .retry(maxCount: 3, interval: .seconds(2))
                                .cacheOriginalImage()
                                .fade(duration: 0.25)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }

                        // Upload progress overlay
                        if viewModel.isUploading {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 120, height: 120)

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    }
                    .accessibilityLabel("Profile picture")
                    .accessibilityHint("Double tap to change")

                    // Change Photo Button
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Change Photo", systemImage: "photo")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                await viewModel.uploadProfileImage(uiImage)
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical)

                    // Display Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(.gray)

                        TextField("Username", text: $viewModel.displayName)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disabled(viewModel.isLoading)
                            .accessibilityLabel("Username")

                        // Availability indicator
                        if viewModel.isCheckingAvailability {
                            HStack {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                                Text("Checking availability...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else if !viewModel.displayNameError.isEmpty {
                            Text(viewModel.displayNameError)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if viewModel.displayNameAvailable && !viewModel.displayName.isEmpty {
                            Label("Available", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Save Button
                    Button(action: {
                        Task {
                            await viewModel.updateProfile()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 20, height: 20)
                                Text("Saving...")
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canSave || viewModel.isLoading)
                    .padding(.horizontal)
                    .accessibilityIdentifier("saveButton")
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Profile Updated", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your profile has been updated successfully.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to update profile.")
            }
        }
    }

    private var canSave: Bool {
        !viewModel.isLoading &&
        !viewModel.displayName.isEmpty &&
        viewModel.displayNameError.isEmpty &&
        viewModel.hasChanges
    }
}
```

**ProfileViewModel.swift:**

```swift
/// ProfileViewModel.swift
/// ViewModel for profile management
/// [Source: Epic 1, Story 1.5]

import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var photoURL: URL?
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var isCheckingAvailability = false
    @Published var displayNameAvailable = false
    @Published var displayNameError = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var hasChanges = false

    private let authService = AuthService()
    private let storageService = StorageService()
    private var cancellables = Set<AnyCancellable>()
    private var originalDisplayName = ""
    private var originalPhotoURL: URL?

    init() {
        // Load current user profile
        loadCurrentProfile()

        // Set up debounced displayName availability check
        $displayName
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newName in
                Task { await self?.checkDisplayNameAvailability(newName) }
            }
            .store(in: &cancellables)
    }

    /// Load current user profile
    func loadCurrentProfile() {
        // Load from AuthService or SwiftData
        // For now, using placeholder
        displayName = "current_username"
        originalDisplayName = displayName
        photoURL = nil
        originalPhotoURL = photoURL
    }

    /// Check displayName availability
    func checkDisplayNameAvailability(_ name: String) async {
        guard !name.isEmpty else {
            displayNameError = ""
            displayNameAvailable = false
            return
        }

        // If name unchanged, skip check
        guard name != originalDisplayName else {
            displayNameError = ""
            displayNameAvailable = true
            hasChanges = false
            return
        }

        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        // Validate format
        let authService = AuthService()
        guard authService.isValidDisplayName(name) else {
            displayNameError = "Invalid username format. Use 3-30 characters, letters, numbers, periods, and underscores."
            displayNameAvailable = false
            return
        }

        // Check availability
        do {
            let displayNameService = DisplayNameService()
            let isAvailable = try await displayNameService.checkAvailability(name)

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

    /// Upload profile image
    func uploadProfileImage(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }

        do {
            let userId = Auth.auth().currentUser?.uid ?? "unknown"
            let path = "profile_pictures/\(userId)/profile.jpg"

            let downloadURL = try await storageService.uploadImage(image, path: path)
            photoURL = downloadURL
            hasChanges = true

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Update profile
    func updateProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.updateUserProfile(
                displayName: displayName,
                photoURL: photoURL
            )

            originalDisplayName = displayName
            originalPhotoURL = photoURL
            hasChanges = false
            showSuccess = true

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
```

### Dependencies

**Required:**
- Story 1.1 (User Sign Up) must be complete
- Story 1.2 (User Login) must be complete
- Firebase SDK installed and configured
- SwiftData ModelContainer configured in App.swift
- Kingfisher installed via SPM

**Blocks:**
- None (standalone feature)

**External:**
- Firebase Storage enabled and configured
- Firebase Storage Rules deployed
- Photo Library permission in Info.plist

---

## Testing & Validation

### Test Procedure

1. **Test Photo Picker**
   - Tap "Change Photo"
   - PhotosPicker should open
   - Select image from library
   - Image should upload with progress indicator
   - Profile picture should update

2. **Test Photo Library Permission**
   - Fresh app install
   - Tap "Change Photo"
   - Permission alert should show with description from Info.plist
   - Grant permission → PhotosPicker should open
   - Deny permission → Should show alert directing to Settings

3. **Test DisplayName Validation**
   - Enter invalid characters → Should show error
   - Enter name < 3 characters → Should show error
   - Enter name > 30 characters → Should show error
   - Enter taken name → Should show "already taken"
   - Enter available name → Should show green checkmark

4. **Test DisplayName Change**
   - Change displayName to available name
   - Tap "Save Changes"
   - Should show success alert
   - Verify old claim released in Firestore `/displayNames/`
   - Verify new claim created in Firestore `/displayNames/`

5. **Test Image Compression**
   - Select large image (> 5MB original)
   - Upload should succeed
   - Verify uploaded image < 500KB in Firebase Console

6. **Test Kingfisher Caching**
   - Upload profile picture
   - Close and reopen app
   - Profile picture should load from cache (instant)

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS Simulator (iPhone 16)
- [ ] Photo picker works correctly
- [ ] Photo Library permission requested
- [ ] Images uploaded to Firebase Storage
- [ ] Images compressed to < 500KB
- [ ] DisplayName validation works
- [ ] DisplayName uniqueness enforced
- [ ] Old displayName claim released
- [ ] Profile updates sync to Firestore
- [ ] Kingfisher caching works
- [ ] Loading states shown appropriately
- [ ] Error states handled gracefully

---

## References

**Architecture Docs:**
- [Source: docs/architecture/technology-stack.md] - Firebase Storage, Kingfisher
- [Source: docs/architecture/data-architecture.md] - UserEntity SwiftData model
- [Source: docs/architecture/security-architecture.md] - Storage Rules, permissions
- [Source: docs/swiftdata-implementation-guide.md] - UserEntity implementation

**PRD Sections:**
- PRD Section 8.1.3: Profile management specifications
- PRD Section 10.3: Firebase Storage schema

**Epic:**
- docs/epics/epic-1-user-authentication-profiles.md

**Related Stories:**
- Story 1.1: User Sign Up (prerequisite - displayName validation)
- Story 1.2: User Login (prerequisite)

---

## Notes & Considerations

### Implementation Notes

**iOS Mobile-Specific Considerations:**

1. **Photo Picker Integration (Critical)**
   - **Required:** Add Photo Library permission to Info.plist:
     ```xml
     <key>NSPhotoLibraryUsageDescription</key>
     <string>We need access to your photos to set your profile picture.</string>
     ```
   - Use `PhotosPicker` (iOS 16+) instead of UIKit's `PHPickerViewController`
   - Handle permission denial gracefully: Show `.alert()` directing user to Settings app
   - Optional: Add camera permission for taking new photo

2. **Image Handling**
   - Compress images on-device before upload (reduce cellular data usage):
     - Max dimension: 2048x2048 pixels
     - Quality: 85% JPEG compression
     - Target size: < 500KB per image
   - Show upload progress indicator using `StorageService` progress callback
   - Allow cancellation of upload (stop Firebase upload task)
   - Image cropping: Use `.aspectRatio(contentMode: .fill)` + `.frame()` + `.clipShape(Circle())`

3. **Loading States**
   - Show skeleton loader for profile picture while downloading from Firebase
   - Kingfisher loading: Use `ProgressView` in `.placeholder { }` closure
   - Disable "Save" button during upload: `.disabled(viewModel.isUploading)`
   - Show upload progress percentage: "Uploading... 47%"

4. **Form UX**
   - DisplayName field: Same validation as signup (real-time availability check with debounce)
   - Show "saving..." feedback in button text during save operation
   - Haptic feedback on save success:
     ```swift
     UINotificationFeedbackGenerator().notificationOccurred(.success)
     ```
   - Optimistic UI: Update profile picture immediately in UI, rollback on failure

5. **Accessibility**
   - Profile picture: `.accessibilityLabel("Profile picture")`, `.accessibilityHint("Double tap to change")`
   - VoiceOver: Announce upload progress percentage changes
   - Support Dynamic Type for all text (displayName, labels)
   - High contrast mode support for validation indicators

6. **Memory Management**
   - Kingfisher automatically caches images (disk + memory)
   - Configure cache limits in app initialization:
     ```swift
     KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024 // 50MB
     KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024 // 200MB
     ```
   - Clear cached profile pictures on logout:
     ```swift
     KingfisherManager.shared.cache.clearCache()
     ```

### Edge Cases

- User selects image > 5MB (compress and retry)
- Upload fails mid-transfer (show retry option)
- DisplayName change conflicts with another user's claim (show error)
- Network failure during upload (show offline indicator)
- Photo Library permission denied (show Settings redirect)

### Performance Considerations

- Image compression happens on-device (CPU intensive, show loading)
- Upload should complete in < 10 seconds for 500KB image on good network
- Kingfisher cache reduces Firebase Storage reads significantly
- Debounce displayName check to avoid excessive Firestore queries (500ms)

### Security Considerations

- Firebase Storage Rules enforce:
  - Max file size: 5MB
  - Only authenticated users can upload
  - Users can only upload to their own `/profile_pictures/{userId}/` path
  - Only image MIME types allowed (image/jpeg, image/png)

**Firebase Storage Rules (already deployed):**
```
match /profile_pictures/{userId}/{allPaths=**} {
  allow read: if true;
  allow write: if request.auth != null
              && request.auth.uid == userId
              && request.resource.size < 5 * 1024 * 1024
              && request.resource.contentType.matches('image/.*');
}
```

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-20
**Last updated:** 2025-10-20
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 1: User Authentication & Profiles
**Story points:** 5
**Priority:** P0 (Critical blocker)

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review
- [ ] **Ready** - Story reviewed and ready for development
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Draft
