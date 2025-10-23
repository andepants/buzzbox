/// GroupCreationView.swift
///
/// View for creating new group conversations with multiple participants.
/// Allows setting group name, photo, and selecting 2+ participants.
///
/// Features:
/// - Group photo selection via ImagePicker
/// - Participant selection via ParticipantPickerView
/// - Validation: min 2 participants, 1-50 char name
/// - Offline-first with SwiftData
/// - Real-time sync to Firebase RTDB
/// - System message creation on group creation
///
/// Created: 2025-10-22

import SwiftUI
import SwiftData
import FirebaseAuth

/// View for creating group conversations
struct GroupCreationView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// Group name input
    @State private var groupName = ""

    /// Selected group photo
    @State private var groupPhoto: UIImage?

    /// Selected participant user IDs
    @State private var selectedUserIDs: Set<String> = []

    /// Show image picker
    @State private var showImagePicker = false

    /// Photo upload progress (0.0 to 1.0)
    @State private var uploadProgress: Double = 0.0

    /// Is uploading photo
    @State private var isUploading = false

    /// Is creating group
    @State private var isCreating = false

    /// Error message
    @State private var errorMessage: String?

    /// Show error alert
    @State private var showError = false

    // MARK: - Computed Properties

    /// Current user ID from Firebase Auth
    private var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    /// Current user display name from Firebase Auth
    private var currentUserDisplayName: String? {
        Auth.auth().currentUser?.displayName
    }

    /// Trimmed group name
    private var trimmedGroupName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Is form valid
    private var isFormValid: Bool {
        !trimmedGroupName.isEmpty &&
        trimmedGroupName.count >= 1 &&
        trimmedGroupName.count <= 50 &&
        selectedUserIDs.count >= 2 &&
        selectedUserIDs.count <= 256 &&
        !isCreating
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Group Photo Section
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showImagePicker = true
                        } label: {
                            if let photo = groupPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay {
                                        VStack(spacing: 4) {
                                            Image(systemName: "camera.fill")
                                                .font(.title2)
                                            Text("Add Photo")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                            }
                        }
                        .accessibilityLabel("Select group photo")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    // Upload progress
                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress, total: 1.0)
                            Text("Uploading photo...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Channel Photo")
                }

                // Channel Name Section
                Section {
                    TextField("Enter channel name", text: $groupName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    Text("\(trimmedGroupName.count)/50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Channel Name")
                } footer: {
                    Text("Name must be 1-50 characters")
                }

                // Participants Section
                Section {
                    ParticipantPickerView(selectedUserIDs: $selectedUserIDs)
                        .frame(height: 300)
                } header: {
                    Text("Add Participants (\(selectedUserIDs.count) selected)")
                } footer: {
                    Text("Select 2-256 participants")
                }
            }
            .navigationTitle("New Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(!isFormValid)
                    .bold()
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $groupPhoto)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Creating channel...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(.regularMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - Methods

    /// Create group conversation
    private func createGroup() async {
        guard let currentUserID = currentUserID else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        isCreating = true

        do {
            // 1. Build participant IDs (selected users + current user)
            var participantIDs = Array(selectedUserIDs)
            if !participantIDs.contains(currentUserID) {
                participantIDs.append(currentUserID)
            }

            // 2. Create ConversationEntity locally
            let conversationID = UUID().uuidString
            let conversation = ConversationEntity(
                id: conversationID,
                participantIDs: participantIDs,
                displayName: trimmedGroupName,
                groupPhotoURL: nil,
                adminUserIDs: [currentUserID],
                isGroup: true,
                createdAt: Date(),
                syncStatus: .pending
            )

            // 3. Save to SwiftData
            modelContext.insert(conversation)
            try modelContext.save()

            // 4. Upload group photo if provided
            if let photo = groupPhoto {
                await uploadGroupPhoto(photo, conversationID: conversationID, conversation: conversation)
            }

            // 5. Sync conversation to RTDB (background task)
            Task {
                try? await ConversationService.shared.syncConversation(conversation)
            }

            // 6. Create system message
            let displayName = currentUserDisplayName ?? "Someone"
            let systemMessageText = "\(displayName) created the group"

            Task {
                try? await ConversationService.shared.sendSystemMessage(
                    text: systemMessageText,
                    conversationID: conversationID
                )
            }

            // 7. Update conversation sync status
            await MainActor.run {
                conversation.syncStatus = .synced
                try? modelContext.save()
            }


            // Dismiss view
            await MainActor.run {
                isCreating = false
                dismiss()
            }

        } catch {
            await MainActor.run {
                isCreating = false
                errorMessage = "Failed to create channel: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    /// Upload group photo
    private func uploadGroupPhoto(
        _ image: UIImage,
        conversationID: String,
        conversation: ConversationEntity
    ) async {
        isUploading = true
        uploadProgress = 0.0

        do {
            // Simulate progress (Firebase Storage doesn't provide easy progress tracking in async/await)
            uploadProgress = 0.3

            let downloadURL = try await StorageService().uploadGroupPhoto(image, groupID: conversationID)

            uploadProgress = 1.0

            // Update conversation with photo URL
            await MainActor.run {
                conversation.groupPhotoURL = downloadURL
                try? modelContext.save()
            }


        } catch {
            await MainActor.run {
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                showError = true
            }
        }

        await MainActor.run {
            isUploading = false
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ConversationEntity.self, configurations: config)

    return GroupCreationView()
        .modelContainer(container)
}
