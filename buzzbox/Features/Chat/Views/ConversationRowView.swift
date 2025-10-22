/// ConversationRowView.swift
///
/// Row view for displaying a single conversation in the list
/// Shows recipient info, last message, timestamp, unread badge
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI
import FirebaseAuth

/// Row view displaying conversation summary
struct ConversationRowView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @State private var recipientUser: UserEntity?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            profilePicture

            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                // Name and timestamp row
                HStack {
                    Text(recipientUser?.displayName ?? "Loading...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(lastMessageAt, style: .relative)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                // Last message and unread badge
                HStack(alignment: .top, spacing: 8) {
                    Text(conversation.lastMessageText ?? "No messages yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .task {
            await loadRecipientUser()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open conversation")
    }

    // MARK: - Subviews

    private var profilePicture: some View {
        Group {
            if let photoURL = recipientUser?.photoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderAvatar
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                if let displayName = recipientUser?.displayName {
                    Text(displayName.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                }
            }
    }

    private var unreadBadge: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 22, height: 22)

            Text("\(conversation.unreadCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Computed Properties

    private var accessibilityDescription: String {
        var description = "\(recipientUser?.displayName ?? "Unknown")"

        if conversation.isPinned {
            description += ", pinned"
        }

        if conversation.unreadCount > 0 {
            description += ", \(conversation.unreadCount) unread \(conversation.unreadCount == 1 ? "message" : "messages")"
        }

        if let lastMessage = conversation.lastMessageText {
            description += ", last message: \(lastMessage)"
        }

        return description
    }

    // MARK: - Helper Methods

    private func loadRecipientUser() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        recipientUser = try? await ConversationService.shared.getUser(userID: recipientID)
    }
}

// MARK: - Preview

#Preview {
    List {
        ConversationRowView(
            conversation: ConversationEntity(
                id: "preview",
                participantIDs: ["user1", "user2"],
                displayName: nil,
                isGroup: false
            )
        )
    }
}
