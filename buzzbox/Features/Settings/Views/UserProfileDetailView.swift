/// UserProfileDetailView.swift
///
/// View for displaying another user's profile
/// Shows profile info, creator badge, and conditional messaging button
///
/// Created: 2025-10-22
/// [Source: Story 5.4 - DM Restrictions - AC10/AC11]

import SwiftUI
import FirebaseAuth

/// View for displaying another user's public profile
struct UserProfileDetailView: View {
    // MARK: - Properties

    /// The user whose profile is being viewed
    let user: UserEntity

    /// Current logged-in user
    let currentUser: User?

    /// Callback when message button is tapped
    let onMessageTapped: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    profileHeader

                    // Creator badge (if applicable)
                    if user.isCreator {
                        creatorBadge
                    }

                    // Profile info
                    profileInfo

                    // Message button
                    messageButton

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Cannot Send Message", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    /// Profile header with photo and name
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile photo
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
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else {
                // Default avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }

            // Display name
            Text(user.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    /// Creator badge
    private var creatorBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16))
                .foregroundStyle(.yellow)

            Text("Creator")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.2))
        )
    }

    /// Profile information
    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Email
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Email")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(user.email)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
            }

            Divider()

            // User type
            HStack(spacing: 12) {
                Image(systemName: user.isCreator ? "star.fill" : "person.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Role")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(user.isCreator ? "Creator" : "Fan")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    /// Message button (conditional based on DM restrictions)
    private var messageButton: some View {
        VStack(spacing: 12) {
            Button {
                handleMessageTapped()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Send Message")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSendMessage ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canSendMessage)

            // Tooltip for disabled button
            if !canSendMessage {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                    Text("Only Andrew accepts DMs")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    /// Whether the current user can send a message to this user
    private var canSendMessage: Bool {
        // Creator can message anyone
        if currentUser?.isCreator == true {
            return true
        }

        // Fans can only message the creator
        if currentUser?.isFan == true {
            return user.isCreator
        }

        // Default: not allowed
        return false
    }

    // MARK: - Methods

    /// Handle message button tap
    private func handleMessageTapped() {
        guard canSendMessage else {
            errorMessage = "You can only send direct messages to Andrew"
            showError = true
            return
        }

        // Call the callback with user ID
        onMessageTapped?(user.id)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Creator Profile - Viewed by Fan") {
    UserProfileDetailView(
        user: UserEntity(
            id: "creator-123",
            email: "andrewsheim@gmail.com",
            displayName: "Andrew Heim Dev",
            photoURL: nil,
            userType: .creator,
            isPublic: true
        ),
        currentUser: User(
            id: "fan-456",
            email: "fan@test.com",
            displayName: "Test Fan",
            photoURL: nil,
            userType: .fan,
            isPublic: false
        ),
        onMessageTapped: { userID in
        }
    )
}

#Preview("Fan Profile - Viewed by Fan") {
    UserProfileDetailView(
        user: UserEntity(
            id: "fan-789",
            email: "otherfan@test.com",
            displayName: "Other Fan",
            photoURL: nil,
            userType: .fan,
            isPublic: false
        ),
        currentUser: User(
            id: "fan-456",
            email: "fan@test.com",
            displayName: "Test Fan",
            photoURL: nil,
            userType: .fan,
            isPublic: false
        ),
        onMessageTapped: { userID in
        }
    )
}

#Preview("Fan Profile - Viewed by Creator") {
    UserProfileDetailView(
        user: UserEntity(
            id: "fan-789",
            email: "fan@test.com",
            displayName: "Test Fan",
            photoURL: nil,
            userType: .fan,
            isPublic: false
        ),
        currentUser: User(
            id: "creator-123",
            email: "andrewsheim@gmail.com",
            displayName: "Andrew Heim Dev",
            photoURL: nil,
            userType: .creator,
            isPublic: true
        ),
        onMessageTapped: { userID in
        }
    )
}
