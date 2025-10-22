/// GroupInfoView.swift
/// Group information screen showing participants, admin controls, and group settings
/// [Source: Story 3.2 - Group Info Screen]
///
/// Displays:
/// - Group photo and name
/// - Complete participant list with admin badges
/// - Admin-only controls (Edit Group, Add Participants, Remove Participant)
/// - Leave Group functionality with confirmation

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

/// Main group information view
struct GroupInfoView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var participants: [UserEntity] = []
    @State private var showEditSheet = false
    @State private var showAddParticipants = false
    @State private var showLeaveConfirmation = false
    @State private var showAdminTransferDialog = false
    @State private var showMinimumParticipantWarning = false
    @State private var participantToRemove: UserEntity?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Realtime listener for participant changes
    @State private var participantListenerHandle: DatabaseHandle?

    /// Check if current user is admin
    private var isAdmin: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return conversation.adminUserIDs.contains(currentUserID)
    }

    /// Get current user ID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    // MARK: - Body

    var body: some View {
        List {
            // MARK: - Group Header Section
            Section {
                VStack(spacing: 16) {
                    // Group photo
                    AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())

                    // Group name
                    Text(conversation.displayName ?? "Unnamed Group")
                        .font(.system(size: 22, weight: .bold))

                    // Participant count
                    Text("\(conversation.participantIDs.count) participants")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    // Edit Group button (admin-only)
                    if isAdmin {
                        Button("Edit Group Info") {
                            showEditSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // MARK: - Participants Section
            Section("Participants") {
                ForEach(participants) { participant in
                    ParticipantRow(
                        participant: participant,
                        isAdmin: conversation.adminUserIDs.contains(participant.id),
                        canRemove: isAdmin && participant.id != currentUserID,
                        onRemove: { removeParticipant(participant) }
                    )
                }

                // Add Participants button (admin-only)
                if isAdmin {
                    Button {
                        showAddParticipants = true
                    } label: {
                        Label("Add Participants", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }

            // MARK: - Actions Section
            Section {
                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadParticipants()
            startParticipantListener()
        }
        .onDisappear {
            stopParticipantListener()
        }
        .confirmationDialog(
            "Leave Group",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task {
                    await leaveGroup()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave this group? You will no longer receive messages from this conversation.")
        }
        .alert("Transfer Admin Rights", isPresented: $showAdminTransferDialog) {
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are the last admin. Please transfer admin rights to another member before leaving, or the oldest member will automatically become admin.")
        }
        .sheet(isPresented: $showEditSheet) {
            Text("Edit Group - Coming in Story 3.4")
                .padding()
        }
        .sheet(isPresented: $showAddParticipants) {
            AddParticipantsView(conversation: conversation)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            "Cannot Remove Participant",
            isPresented: $showMinimumParticipantWarning,
            titleVisibility: .visible
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Groups must have at least 2 participants. Removing this participant would archive the group.")
        }
    }

    // MARK: - Private Methods

    /// Load participants from SwiftData
    private func loadParticipants() async {
        let participantIDs = conversation.participantIDs

        // Fetch from SwiftData
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate<UserEntity> { user in
                participantIDs.contains(user.id)
            }
        )

        do {
            let fetchedUsers = try modelContext.fetch(descriptor)
            participants = fetchedUsers

            // Fetch missing users from Firestore
            let fetchedIDs = Set(fetchedUsers.map { $0.id })
            let missingIDs = Set(participantIDs).subtracting(fetchedIDs)

            for userID in missingIDs {
                if let user = try? await fetchUserFromFirestore(userID: userID) {
                    // Insert into SwiftData
                    let userEntity = UserEntity(
                        id: user.id,
                        email: user.email,
                        displayName: user.displayName,
                        photoURL: user.photoURL
                    )
                    modelContext.insert(userEntity)
                    participants.append(userEntity)
                } else {
                    // User deleted - create placeholder
                    let deletedUser = UserEntity(
                        id: userID,
                        email: "deleted@example.com",
                        displayName: "Deleted User"
                    )
                    participants.append(deletedUser)
                }
            }

            try? modelContext.save()

        } catch {
            print("❌ Error loading participants: \(error)")
            errorMessage = "Failed to load participants"
        }
    }

    /// Fetch user from Firestore
    private func fetchUserFromFirestore(userID: String) async throws -> UserEntity? {
        let document = try await Firestore.firestore()
            .collection("users")
            .document(userID)
            .getDocument()

        guard let data = document.data() else { return nil }

        return UserEntity(
            id: userID,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "Unknown",
            photoURL: data["profilePictureURL"] as? String
        )
    }

    /// Leave group with admin transfer check
    private func leaveGroup() async {
        isLoading = true
        defer { isLoading = false }

        let isLastAdmin = conversation.adminUserIDs.count == 1 &&
                          conversation.adminUserIDs.contains(currentUserID)
        let hasOtherParticipants = conversation.participantIDs.count > 1

        // Check if last admin
        if isLastAdmin && hasOtherParticipants {
            // Auto-assign to oldest participant (first in array)
            if let newAdmin = conversation.participantIDs.first(where: { $0 != currentUserID }) {
                conversation.adminUserIDs.append(newAdmin)
            }
        }

        // Get display name for system message
        let displayName = participants.first(where: { $0.id == currentUserID })?.displayName ?? "Someone"

        // Remove self from participants and admins
        conversation.participantIDs.removeAll { $0 == currentUserID }
        conversation.adminUserIDs.removeAll { $0 == currentUserID }
        conversation.isArchived = true
        conversation.syncStatus = .pending
        conversation.updatedAt = Date()

        do {
            try modelContext.save()

            // Sync to RTDB
            try await ConversationService.shared.syncConversation(conversation)

            // Send system message
            let systemMessageText = "\(displayName) left the group"
            try await ConversationService.shared.sendSystemMessage(
                text: systemMessageText,
                conversationID: conversation.id,
                messageID: UUID().uuidString
            )

            // Navigate back
            dismiss()

        } catch {
            print("❌ Error leaving group: \(error)")
            errorMessage = "Failed to leave group"
        }
    }

    /// Remove participant (admin-only)
    private func removeParticipant(_ participant: UserEntity) {
        Task {
            isLoading = true
            defer { isLoading = false }

            // Check if participant still in group (concurrent removal prevention)
            guard conversation.participantIDs.contains(participant.id) else {
                print("⚠️ Participant already removed")
                return
            }

            // Check minimum participant count BEFORE removal
            if conversation.participantIDs.count <= 2 {
                print("⚠️ Cannot remove participant: minimum 2 participants required")
                showMinimumParticipantWarning = true
                return
            }

            // Get admin name for system message
            let adminName = participants.first(where: { $0.id == currentUserID })?.displayName ?? "Admin"

            // Remove participant
            conversation.participantIDs.removeAll { $0 == participant.id }
            conversation.adminUserIDs.removeAll { $0 == participant.id }
            conversation.updatedAt = Date()
            conversation.syncStatus = .pending

            do {
                try modelContext.save()

                // Sync to RTDB
                try await ConversationService.shared.syncConversation(conversation)

                // Clean up typing indicator for removed participant
                await cleanupTypingIndicator(for: participant.id)

                // Send system message
                let systemMessageText = "\(adminName) removed \(participant.displayName)"
                try await ConversationService.shared.sendSystemMessage(
                    text: systemMessageText,
                    conversationID: conversation.id,
                    messageID: UUID().uuidString
                )

                // Reload participants
                await loadParticipants()

            } catch {
                print("❌ Error removing participant: \(error)")
                errorMessage = "Failed to remove participant"
            }
        }
    }

    /// Clean up typing indicator for removed participant
    private func cleanupTypingIndicator(for userID: String) async {
        await TypingIndicatorService.shared.stopTyping(
            conversationID: conversation.id,
            userID: userID
        )
        print("✅ Cleaned up typing indicator for removed user: \(userID)")
    }

    /// Start listening to participant changes (auto-dismiss if removed)
    private func startParticipantListener() {
        let ref = Database.database().reference()
            .child("conversations")
            .child(conversation.id)
            .child("participantIDs")

        participantListenerHandle = ref.observe(.value) { snapshot in
            guard let participantIDs = snapshot.value as? [String: Bool] else { return }

            // If current user removed, dismiss view
            if !participantIDs.keys.contains(currentUserID) {
                dismiss()
            }
        }
    }

    /// Stop listening to participant changes
    private func stopParticipantListener() {
        if let handle = participantListenerHandle {
            let ref = Database.database().reference()
                .child("conversations")
                .child(conversation.id)
                .child("participantIDs")
            ref.removeObserver(withHandle: handle)
        }
    }
}

// MARK: - ParticipantRow

/// Row view for displaying a single participant
struct ParticipantRow: View {
    let participant: UserEntity
    let isAdmin: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: participant.photoURL ?? "")) { image in
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

            // Name and admin badge
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.displayName)
                    .font(.body)

                if isAdmin {
                    Text("Group Admin")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            // Remove button (admin-only)
            if canRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupInfoView(
            conversation: ConversationEntity(
                id: "test-group",
                participantIDs: ["user1", "user2", "user3"],
                displayName: "Test Group",
                adminUserIDs: ["user1"],
                isGroup: true
            )
        )
        .modelContainer(for: [UserEntity.self, ConversationEntity.self])
    }
}
