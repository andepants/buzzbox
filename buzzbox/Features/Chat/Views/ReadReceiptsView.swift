/// ReadReceiptsView.swift
///
/// Sheet view displaying read receipts for group messages.
/// Shows which participants have read a message with timestamps.
///
/// Created: 2025-10-22
/// [Source: Story 3.6 - Group Read Receipts]

import SwiftUI

/// Read receipts sheet for group messages
struct ReadReceiptsView: View {
    // MARK: - Properties

    let message: MessageEntity
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
    }
}
