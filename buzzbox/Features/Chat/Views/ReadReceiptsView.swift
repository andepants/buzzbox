/// ReadReceiptsView.swift
///
/// Sheet view displaying read receipts for messages.
/// Shows read status for 1:1 conversations or detailed read/delivered lists for groups.
///
/// Created: 2025-10-22
/// [Source: Story 3.6 - Group Read Receipts, Story 3.10 - 1:1 Read Receipts]

import SwiftUI

/// Read receipts sheet for messages (1:1 and group)
struct ReadReceiptsView: View {
    // MARK: - Properties

    let message: MessageEntity
    let conversation: ConversationEntity
    let participants: [UserEntity]

    // MARK: - Computed Properties

    /// Participants who have read the message (sorted by most recent first)
    private var readParticipants: [UserEntity] {
        participants.filter { message.readBy[$0.id] != nil }
            .sorted { (message.readBy[$0.id] ?? Date()) > (message.readBy[$1.id] ?? Date()) }
    }

    /// Participants who haven't read the message (excluding sender)
    private var unreadParticipants: [UserEntity] {
        participants.filter { message.readBy[$0.id] == nil && $0.id != message.senderID }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if conversation.isGroup {
                groupReadReceiptsView
            } else {
                oneOnOneReadReceiptView
            }
        }
    }

    // MARK: - Group View

    /// Read receipts for group conversations (multi-recipient)
    private var groupReadReceiptsView: some View {
        List {
            // Read section
            if !readParticipants.isEmpty {
                Section("Read") {
                    ForEach(readParticipants) { participant in
                        HStack {
                            // Profile picture
                            AsyncImage(url: URL(string: participant.photoURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                            // Name and timestamp
                            VStack(alignment: .leading) {
                                Text(participant.displayName)
                                    .font(.system(size: 16))

                                if let readAt = message.readBy[participant.id] {
                                    Text(readAt, style: .relative)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Delivered section
            if !unreadParticipants.isEmpty {
                Section("Delivered") {
                    ForEach(unreadParticipants) { participant in
                        HStack {
                            // Profile picture
                            AsyncImage(url: URL(string: participant.photoURL ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                            // Name only (no timestamp for unread)
                            Text(participant.displayName)
                                .font(.system(size: 16))
                        }
                    }
                }
            }
        }
        .navigationTitle("Read By")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 1:1 View

    /// Read receipt info for one-on-one conversations (single recipient)
    private var oneOnOneReadReceiptView: some View {
        List {
            Section {
                // Sent timestamp
                HStack {
                    Text("Sent")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(message.serverTimestamp ?? message.localCreatedAt, style: .time)
                }

                // Delivery status
                HStack {
                    Text("Delivered")
                        .foregroundColor(.secondary)
                    Spacer()
                    if message.status == .delivered || message.status == .read {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    } else {
                        Text("Pending")
                            .foregroundColor(.secondary)
                    }
                }

                // Read status
                if let recipient = participants.first(where: { $0.id != message.senderID }),
                   let readAt = message.readBy[recipient.id] {
                    HStack {
                        Text("Read")
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(readAt, style: .time)
                            Text(readAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Text("Read")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Not yet")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Message Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
