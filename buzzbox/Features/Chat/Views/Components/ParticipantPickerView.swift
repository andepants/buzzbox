/// ParticipantPickerView.swift
///
/// Multi-select user picker for creating group conversations.
/// Fetches users from Firestore and allows selection with checkmark indicators.
/// Filters out current user and provides search capability.
///
/// Usage:
/// ```swift
/// @State private var selectedUserIDs: Set<String> = []
///
/// Section("Participants") {
///     ParticipantPickerView(selectedUserIDs: $selectedUserIDs)
/// }
/// ```
///
/// Created: 2025-10-22

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// View for selecting multiple participants for group conversations
struct ParticipantPickerView: View {
    // MARK: - Properties

    /// Binding to selected user IDs
    @Binding var selectedUserIDs: Set<String>

    /// Array of available users from Firestore
    @State private var users: [UserInfo] = []

    /// Loading state
    @State private var isLoading = true

    /// Error state
    @State private var errorMessage: String?

    /// Search text
    @State private var searchText = ""

    /// Current user ID from Firebase Auth
    private var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Body

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading users...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadUsers() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if users.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No users found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search users", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // User list
                List(filteredUsers) { user in
                    Button {
                        toggleSelection(for: user.id)
                    } label: {
                        HStack(spacing: 12) {
                            // Avatar placeholder
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(user.initials)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }

                            // User info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Selection checkmark
                            if selectedUserIDs.contains(user.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .task {
            await loadUsers()
        }
    }

    // MARK: - Computed Properties

    /// Filtered users based on search text
    private var filteredUsers: [UserInfo] {
        if searchText.isEmpty {
            return users
        }
        return users.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Methods

    /// Toggle user selection
    private func toggleSelection(for userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    /// Load users from Firestore
    private func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users")
                .order(by: "displayName")
                .getDocuments()

            var loadedUsers: [UserInfo] = []

            for document in snapshot.documents {
                let data = document.data()
                let userID = document.documentID

                // Skip current user
                if userID == currentUserID {
                    continue
                }

                let displayName = data["displayName"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? ""

                let userInfo = UserInfo(
                    id: userID,
                    displayName: displayName,
                    email: email
                )
                loadedUsers.append(userInfo)
            }

            await MainActor.run {
                self.users = loadedUsers
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load users: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Types

/// Lightweight user info for participant selection
struct UserInfo: Identifiable, Hashable {
    let id: String
    let displayName: String
    let email: String

    /// User initials for avatar placeholder
    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(displayName.prefix(2)).uppercased()
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedUserIDs: Set<String> = []

        var body: some View {
            NavigationStack {
                VStack {
                    Text("Selected: \(selectedUserIDs.count)")
                        .font(.headline)
                        .padding()

                    ParticipantPickerView(selectedUserIDs: $selectedUserIDs)
                }
                .navigationTitle("Select Participants")
            }
        }
    }

    return PreviewWrapper()
}
