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
            // Emoji Icon with glass effect (left)
            ZStack {
                // Glass circle background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.blue.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )

                Text(channel.channelEmoji ?? "💬")
                    .font(.system(size: 28))
            }

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

            // Unread Badge with glass effect (right)
            if channel.unreadCount > 0 {
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("\(channel.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(minWidth: 24, minHeight: 24)
                .padding(.horizontal, 4)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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
