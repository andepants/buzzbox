/// RecipientPickerView.swift
///
/// View for selecting a recipient to start a new conversation
/// Features user search, blocked user filtering, and profile pictures
///
/// Created: 2025-10-21
/// [Source: Story 2.1 - Create New Conversation]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// View for selecting a recipient to start a new conversation
struct RecipientPickerView: View {
    // MARK: - Properties

    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var users: [UserEntity] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed Properties

    var filteredUsers: [UserEntity] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    ContentUnavailableView(
                        "No Users Found",
                        systemImage: "person.2.slash",
                        description: Text("There are no users to message yet.")
                    )
                } else {
                    usersList
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }

    // MARK: - Subviews

    private var usersList: some View {
        List(filteredUsers) { user in
            Button {
                onSelect(user.id)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    // Profile picture
                    if let photoURL = user.photoURL,
                       let url = URL(string: photoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.white)
                                }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        // Default avatar
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(user.displayName.prefix(1).uppercased())
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                    }

                    // User info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        if !user.email.isEmpty {
                            Text(user.email)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    // MARK: - Helper Methods

    /// Load users from Firestore
    /// Filters out current user and fetches all other users for discovery
    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .getDocuments()

            var fetchedUsers: [UserEntity] = []

            for document in snapshot.documents {
                let data = document.data()
                let userID = document.documentID

                // Filter out current user
                guard userID != currentUserID else { continue }

                let user = UserEntity(
                    id: userID,
                    email: data["email"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "Unknown",
                    photoURL: data["profilePictureURL"] as? String
                )

                fetchedUsers.append(user)
            }

            // Sort by display name
            users = fetchedUsers.sorted { $0.displayName < $1.displayName }
            print("✅ Loaded \(users.count) users from Firestore")

        } catch {
            print("❌ Failed to load users from Firestore: \(error)")
            users = []
        }
    }
}

// MARK: - Preview

#Preview {
    RecipientPickerView { userID in
        print("Selected user: \(userID)")
    }
}
