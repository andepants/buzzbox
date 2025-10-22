/// ConversationRowView.swift
///
/// Row view for displaying a single conversation in the list
/// Shows recipient info, last message, timestamp, unread badge
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

/// Row view displaying conversation summary
struct ConversationRowView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @State private var recipientUser: UserEntity?
    @State private var presenceStatus: PresenceStatus?
    @State private var presenceHandle: DatabaseHandle?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture with online indicator
            ZStack(alignment: .bottomTrailing) {
                profilePicture

                // ✅ Online indicator (green dot)
                // [Source: Story 2.8 - User Presence & Online Status]
                if presenceStatus?.isOnline == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }

            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                // Name and timestamp row
                HStack {
                    // Show # prefix for channels (groups)
                    if conversation.isGroup {
                        Text(conversation.displayName ?? "Channel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text(recipientUser?.displayName ?? "Loading...")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    // ✅ Creator badge (for 1:1 conversations)
                    // [Source: Story 5.2 - User Type Auto-Assignment]
                    if !conversation.isGroup && recipientUser?.userType == .creator {
                        CreatorBadgeView(size: .small)
                    }

                    // Lock icon for creator-only channels
                    if conversation.isGroup && conversation.isCreatorOnly {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

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
                    // ✅ Show presence status or last message
                    // [Source: Story 2.8 - User Presence & Online Status]
                    if let status = presenceStatus, conversation.lastMessageText == nil {
                        Text(status.displayText)
                            .font(.system(size: 14))
                            .foregroundStyle(status.isOnline ? .green : .secondary)
                            .lineLimit(1)
                    } else {
                        Text(conversation.lastMessageText ?? "No messages yet")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .task {
            await loadRecipientAndPresence()
        }
        .onDisappear {
            stopPresenceListener()
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

    /// Load recipient user and start presence listener
    /// [Source: Story 2.8 - User Presence & Online Status]
    private func loadRecipientAndPresence() async {
        // Skip loading recipient for channels (groups)
        guard !conversation.isGroup else { return }

        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        recipientUser = try? await ConversationService.shared.getUser(userID: recipientID)

        // ✅ Start listening to presence
        presenceHandle = UserPresenceService.shared.listenToPresence(userID: recipientID) { status in
            presenceStatus = status
        }
    }

    /// Stop listening to presence updates
    /// [Source: Story 2.8 - User Presence & Online Status]
    private func stopPresenceListener() {
        // Skip for channels (groups)
        guard !conversation.isGroup else { return }

        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        UserPresenceService.shared.stopListening(userID: recipientID)
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
