/// EditGroupInfoView.swift
/// Admin-only view for editing group name and photo
/// [Source: Story 3.4 - Edit Group Name and Photo]
///
/// Features:
/// - Change group name with validation (1-50 characters)
/// - Upload new group photo via ImagePicker
/// - Photo upload progress tracking
/// - Concurrent edit conflict detection
/// - System message for name changes
/// - Real-time sync to RTDB

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

/// View for editing group information (admin-only)
struct EditGroupInfoView: View {
    // MARK: - Constants

    private enum Constants {
        static let maxPhotoSize = 5 * 1024 * 1024  // 5MB
        static let highCompression: CGFloat = 0.4
        static let standardCompression: CGFloat = 0.8
    }

    // MARK: - Properties

    let conversation: ConversationEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var groupName: String
    @State private var groupPhoto: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var uploadError: Error?
    @State private var showRetryButton = false
    @State private var showConflictAlert = false
    @State private var conflictMessage: String = ""

    /// Storage upload task for cancellation support
    @State private var uploadTask: StorageUploadTask?

    /// Current user ID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    /// Initialize with conversation
    init(conversation: ConversationEntity) {
        self.conversation = conversation
        _groupName = State(initialValue: conversation.displayName ?? "")
    }

    /// Check if save button should be enabled
    private var canSave: Bool {
        !groupName.isEmpty && groupName.count <= 50 && !isSaving && !isUploading
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Group photo button
                    HStack {
                        Spacer()

                        Button(action: { showImagePicker = true }) {
                            if let photo = groupPhoto {
                                // Show newly selected photo
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                // Show current group photo or placeholder
                                AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.white)
                                        }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // Group name text field
                    TextField("Group Name", text: $groupName)
                        .font(.system(size: 18))

                    // Character count
                    Text("\(groupName.count)/50 characters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $groupPhoto)
            }
            .overlay {
                // Upload progress overlay
                if isUploading {
                    VStack(spacing: 12) {
                        ProgressView(value: uploadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 200)

                        Text("Uploading... \(Int(uploadProgress * 100))%")
                            .font(.caption)

                        Button("Cancel Upload") {
                            cancelUpload()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }

                // Saving overlay
                if isSaving {
                    ProgressView("Saving changes...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") {
                    errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
            .alert("Upload Failed", isPresented: $showRetryButton, presenting: uploadError) { error in
                Button("Retry") {
                    Task {
                        if let photo = groupPhoto {
                            do {
                                let photoURL = try await uploadGroupPhoto(photo)
                                conversation.groupPhotoURL = photoURL
                                showRetryButton = false
                                uploadError = nil
                            } catch {
                                uploadError = error
                                // Alert will stay visible to show updated error
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    showRetryButton = false
                    uploadError = nil
                    groupPhoto = nil // Reset to original photo
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert("Conflict Detected", isPresented: $showConflictAlert) {
                Button("Overwrite", role: .destructive) {
                    Task {
                        await saveChanges(forceOverwrite: true)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(conflictMessage)
            }
        }
    }

    // MARK: - Private Methods

    /// Cancel edit and dismiss
    private func cancelEdit() {
        // Cancel upload if in progress
        if isUploading {
            cancelUpload()
        }
        dismiss()
    }

    /// Cancel photo upload
    private func cancelUpload() {
        uploadTask?.cancel()
        isUploading = false
        uploadProgress = 0
        groupPhoto = nil // Revert to old photo
    }

    /// Save changes to group info
    private func saveChanges(forceOverwrite: Bool = false) async {
        // Validate group name
        guard !groupName.isEmpty && groupName.count <= 50 else {
            errorMessage = "Group name must be between 1 and 50 characters"
            return
        }

        // Reset error state when starting new save
        uploadError = nil
        showRetryButton = false

        isSaving = true
        defer { isSaving = false }

        let oldName = conversation.displayName

        // Check for concurrent edits (unless forced overwrite)
        if !forceOverwrite {
            if await hasConflict() {
                return // Conflict alert is shown
            }
        }

        // Upload new photo if changed
        if let photo = groupPhoto {
            do {
                let photoURL = try await uploadGroupPhoto(photo)
                conversation.groupPhotoURL = photoURL
            } catch {
                print("❌ Photo upload failed: \(error)")
                uploadError = error
                showRetryButton = true
                return
            }
        }

        // Update group name
        conversation.displayName = groupName
        conversation.updatedAt = Date()
        conversation.syncStatus = .pending

        do {
            try modelContext.save()

            // Sync to RTDB
            try await ConversationService.shared.syncConversation(conversation)

            // Send system message if name changed
            if oldName != groupName {
                await sendNameChangeSystemMessage(oldName: oldName, newName: groupName)
            }

            dismiss()

        } catch {
            print("❌ Error saving changes: \(error)")
            errorMessage = "Failed to save changes"
        }
    }

    /// Check for concurrent edit conflicts
    private func hasConflict() async -> Bool {
        do {
            let ref = Database.database().reference()
                .child("conversations")
                .child(conversation.id)
                .child("groupName")

            let snapshot = try await ref.getData()
            let latestName = snapshot.value as? String

            // Check if another admin changed the name
            if let latestName = latestName, latestName != conversation.displayName {
                conflictMessage = "Group name was updated by another admin to \"\(latestName)\". Do you want to overwrite?"
                showConflictAlert = true
                return true
            }

            return false

        } catch {
            print("⚠️ Error checking for conflicts: \(error)")
            // Allow save on error
            return false
        }
    }

    /// Upload group photo with progress tracking
    private func uploadGroupPhoto(_ image: UIImage) async throws -> String {
        isUploading = true
        uploadProgress = 0

        // Reset error state when starting upload
        uploadError = nil
        showRetryButton = false

        defer {
            isUploading = false
            uploadTask = nil
        }

        // Compress image if needed (max 5MB)
        var imageData = image.jpegData(compressionQuality: Constants.standardCompression)

        if let data = imageData, data.count > Constants.maxPhotoSize {
            // Compress more aggressively
            imageData = image.jpegData(compressionQuality: Constants.highCompression)

            if let data = imageData, data.count > Constants.maxPhotoSize {
                throw StorageError.fileTooLarge
            }
        }

        guard let data = imageData else {
            throw StorageError.imageCompressionFailed
        }

        // Upload to Firebase Storage
        nonisolated(unsafe) let storageRef = Storage.storage().reference()
        nonisolated(unsafe) let photoRef = storageRef.child("group_photos/\(conversation.id)/photo.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000"

        // Create upload task with progress tracking
        uploadTask = photoRef.putData(data, metadata: metadata)

        // Observe progress
        uploadTask?.observe(.progress) { [self] snapshot in
            if let progress = snapshot.progress {
                Task { @MainActor in
                    uploadProgress = progress.fractionCompleted
                }
            }
        }

        // Wait for upload to complete
        if let task = uploadTask {
            _ = try await task
        }

        // Get download URL
        let downloadURL = try await photoRef.downloadURL()

        return downloadURL.absoluteString
    }

    /// Send system message for name change
    private func sendNameChangeSystemMessage(oldName: String?, newName: String) async {
        do {
            // Get admin display name
            let adminName = try await fetchDisplayName(for: currentUserID)

            let messageText = "\(adminName) changed the group name to \"\(newName)\""

            try await ConversationService.shared.sendSystemMessage(
                text: messageText,
                conversationID: conversation.id
            )

            print("✅ System message sent for name change")

        } catch {
            print("❌ Error sending system message: \(error)")
        }
    }

    /// Fetch display name for user
    private func fetchDisplayName(for userID: String) async throws -> String {
        // Try to fetch from SwiftData first
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate<UserEntity> { user in
                user.id == userID
            }
        )

        if let user = try? modelContext.fetch(descriptor).first {
            return user.displayName
        }

        // Fallback to RTDB
        if let user = try await ConversationService.shared.getUser(userID: userID) {
            return user.displayName
        }

        return "Someone"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditGroupInfoView(
            conversation: ConversationEntity(
                id: "test-group",
                participantIDs: ["user1", "user2", "user3"],
                displayName: "Test Group",
                adminUserIDs: ["user1"],
                isGroup: true
            )
        )
        .modelContainer(for: [ConversationEntity.self, UserEntity.self])
    }
}
