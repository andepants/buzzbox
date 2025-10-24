/// ConversationRowView.swift
///
/// Row view for displaying a single conversation in the list
/// Shows recipient info, last message, timestamp, unread badge
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase

/// Row view displaying conversation summary
struct ConversationRowView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @Environment(\.modelContext) private var modelContext

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

                    // 🆕 AI Category Badge (Story 6.11)
                    if let category = conversation.aiCategory {
                        categoryBadge(for: category)
                    }

                    // 🆕 Business Score Badge (Story 6.11)
                    if let score = conversation.aiBusinessScore {
                        businessScoreBadge(score: score)
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

            // Chevron arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 🆕 Sentiment border layer (Story 6.11)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(sentimentBorderColor, lineWidth: sentimentBorderWidth)
        )
        // Main gradient border
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        // 🆕 Spam opacity (Story 6.11)
        .opacity(conversation.aiCategory == "spam" ? 0.5 : 1.0)
        .onAppear {
            // 🆕 Debug logging for AI features (Story 6.11)
            print("🎨 [ROW] Conv \(conversation.id.prefix(8)) appeared:")
            print("    └─ Sentiment: \(conversation.aiSentiment ?? "nil") (border: \(sentimentBorderColor), width: \(sentimentBorderWidth))")
            print("    └─ Category: \(conversation.aiCategory ?? "nil")")
            print("    └─ Business Score: \(conversation.aiBusinessScore?.description ?? "nil")")
            print("    └─ Message Count Since Analysis: \(conversation.messageCountSinceAnalysis)")
        }
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

    // MARK: - 🆕 AI Badge Subviews (Story 6.11)

    /// Category badge for conversation
    private func categoryBadge(for category: String) -> some View {
        HStack(spacing: 3) {
            // Icon for certain categories
            if category == "urgent" {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
            } else if category == "super_fan" {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
            } else if category == "business" {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 10))
            }

            // Text
            Text(categoryDisplayText(for: category))
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(categoryColor(for: category))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }

    /// Business score badge (0-10)
    private func businessScoreBadge(score: Int) -> some View {
        Text("\(score)/10")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(businessScoreColor(for: score))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    // MARK: - AI Analysis Helper Methods (Story 6.11)

    private var sentimentBorderColor: Color {
        guard let sentiment = conversation.aiSentiment else { return .clear }

        switch sentiment {
        case "positive":
            return .green.opacity(0.3)
        case "negative":
            return .red.opacity(0.3)
        case "urgent":
            return .orange.opacity(0.4)
        default:
            return .gray.opacity(0.15)
        }
    }

    private var sentimentBorderWidth: CGFloat {
        guard let sentiment = conversation.aiSentiment else { return 0 }

        switch sentiment {
        case "neutral":
            return 1
        default:
            return 2
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "fan":
            return .blue
        case "super_fan":
            return .purple
        case "business":
            return .green
        case "spam":
            return .gray
        case "urgent":
            return .orange
        default:
            return .blue
        }
    }

    private func categoryDisplayText(for category: String) -> String {
        switch category {
        case "super_fan":
            return "S-fan"
        case "business":
            return "Biz"
        default:
            return category.capitalized
        }
    }

    private func businessScoreColor(for score: Int) -> Color {
        switch score {
        case 7...10:
            return .green
        case 4...6:
            return .yellow
        case 0...3:
            return .red
        default:
            return .gray
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

        recipientUser = try? await ConversationService.shared.getUser(userID: recipientID, modelContext: modelContext)

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
