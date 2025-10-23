/// AddParticipantsView.swift
/// Sheet for adding participants to an existing group conversation
/// [Source: Story 3.3 - Add and Remove Participants]
///
/// Features:
/// - Multi-select contact picker with checkmark indicators
/// - Filters out users already in group
/// - "Add" button (disabled if no selection)
/// - "Cancel" button
/// - Batched system messages for bulk additions

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

/// View for adding participants to a group conversation
struct AddParticipantsView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedUserIDs: Set<String> = []
    @State private var availableUsers: [UserEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Get current user ID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No contacts available")
                            .font(.headline)

                        Text("All users are already in this group")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(availableUsers) { user in
                            Button {
                                toggleSelection(for: user.id)
                            } label: {
                                HStack(spacing: 12) {
                                    // Profile picture
                                    AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay {
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                            }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())

                                    // Name
                                    Text(user.displayName)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    // Checkmark indicator
                                    if selectedUserIDs.contains(user.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 22))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addParticipants()
                        }
                    }
                    .disabled(selectedUserIDs.isEmpty || isLoading)
                }
            }
            .task {
                await loadAvailableUsers()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") {
                    errorMessage = nil
                }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Private Methods

    /// Toggle user selection
    private func toggleSelection(for userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    /// Load available users (excluding current participants)
    private func loadAvailableUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch all users from Firestore
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .getDocuments()

            var users: [UserEntity] = []
            let currentParticipantIDs = Set(conversation.participantIDs)

            for document in snapshot.documents {
                let data = document.data()
                let userID = document.documentID

                // Filter: Skip users already in group and current user
                guard !currentParticipantIDs.contains(userID),
                      userID != currentUserID else {
                    continue
                }

                let user = UserEntity(
                    id: userID,
                    email: data["email"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "Unknown",
                    photoURL: data["profilePictureURL"] as? String
                )

                users.append(user)
            }

            // Sort by display name
            availableUsers = users.sorted { $0.displayName < $1.displayName }

        } catch {
            errorMessage = "Failed to load contacts"
        }
    }

    /// Add selected participants to group
    private func addParticipants() async {
        guard !selectedUserIDs.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Double-check: filter out users already in group (race condition prevention)
            let currentParticipantIDs = Set(conversation.participantIDs)
            let newUserIDs = Array(selectedUserIDs).filter {
                !currentParticipantIDs.contains($0)
            }

            guard !newUserIDs.isEmpty else {
                errorMessage = "Selected users are already in the group"
                return
            }

            // Get current user display name for system message
            let currentUser = availableUsers.first(where: { $0.id == currentUserID })
            let adminName = currentUser?.displayName ?? "Someone"

            // Append new participant IDs
            conversation.participantIDs.append(contentsOf: newUserIDs)
            conversation.updatedAt = Date()
            conversation.syncStatus = .pending
            try modelContext.save()

            // Sync to RTDB
            try await ConversationService.shared.syncConversation(conversation)

            // Send batched system message
            let systemMessageText: String
            if newUserIDs.count == 1 {
                // Single user added
                let addedUser = availableUsers.first(where: { $0.id == newUserIDs[0] })
                let addedUserName = addedUser?.displayName ?? "Someone"
                systemMessageText = "\(adminName) added \(addedUserName)"
            } else {
                // Multiple users added
                systemMessageText = "\(adminName) added \(newUserIDs.count) participants"
            }

            // Send system message to RTDB
            try await ConversationService.shared.sendSystemMessage(
                text: systemMessageText,
                conversationID: conversation.id,
                messageID: UUID().uuidString
            )


            // Dismiss sheet
            dismiss()

        } catch {
            errorMessage = "Failed to add participants"
        }
    }
}

// MARK: - Preview

#Preview {
    AddParticipantsView(
        conversation: ConversationEntity(
            id: "test-group",
            participantIDs: ["user1", "user2"],
            displayName: "Test Group",
            adminUserIDs: ["user1"],
            isGroup: true
        )
    )
    .modelContainer(for: [UserEntity.self, ConversationEntity.self])
}
