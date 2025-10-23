/// ChannelCardView.swift
///
/// Card/tile component for displaying channels in a grid layout
/// Features large emoji icon, channel name, description, and unread badge
///
/// Created: 2025-10-23
/// [Source: Channel UI Enhancement]

import SwiftUI

/// Reusable card view for displaying channel information in a list
struct ChannelCardView: View {
    // MARK: - Properties

    let channel: ConversationEntity

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Emoji Icon (left)
            Text(channel.channelEmoji ?? "💬")
                .font(.system(size: 36))
                .frame(width: 48, height: 48)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

            // Channel Info (center)
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName ?? "#unknown")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let description = channel.channelDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Unread Badge (right)
            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator).opacity(0.5)),
            alignment: .bottom
        )
    }
}

// MARK: - Preview

#Preview("General Channel") {
    ChannelCardView(
        channel: ConversationEntity(
            id: "general",
            participantIDs: ["user1"],
            displayName: "#general",
            isGroup: true,
            channelEmoji: "💬",
            channelDescription: "General discussion and community chat"
        )
    )
}

#Preview("Announcements Channel") {
    ChannelCardView(
        channel: ConversationEntity(
            id: "announcements",
            participantIDs: ["user1"],
            displayName: "#announcements",
            isGroup: true,
            isCreatorOnly: true,
            channelEmoji: "📢",
            channelDescription: "Important updates from Andrew"
        )
    )
}

#Preview("With Unread Badge") {
    let channel = ConversationEntity(
        id: "off-topic",
        participantIDs: ["user1"],
        displayName: "#off-topic",
        isGroup: true,
        channelEmoji: "🎮",
        channelDescription: "Casual conversations and off-topic chat"
    )
    channel.unreadCount = 5

    return ChannelCardView(channel: channel)
}

#Preview("List Layout") {
    let channels = [
        ConversationEntity(
            id: "general",
            participantIDs: ["user1"],
            displayName: "#general",
            isGroup: true,
            channelEmoji: "💬",
            channelDescription: "General discussion"
        ),
        ConversationEntity(
            id: "announcements",
            participantIDs: ["user1"],
            displayName: "#announcements",
            isGroup: true,
            channelEmoji: "📢",
            channelDescription: "Important updates"
        ),
        ConversationEntity(
            id: "off-topic",
            participantIDs: ["user1"],
            displayName: "#off-topic",
            isGroup: true,
            channelEmoji: "🎮",
            channelDescription: "Casual chat"
        )
    ]

    return ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(channels) { channel in
                ChannelCardView(channel: channel)
            }
        }
    }
}
