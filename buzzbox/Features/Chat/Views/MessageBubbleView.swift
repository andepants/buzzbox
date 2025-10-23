/// MessageBubbleView.swift
///
/// Displays a single message bubble with WhatsApp-style delivery status indicators.
/// Features smooth animations, retry functionality, and comprehensive accessibility.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages]
/// [Updated: Story 2.4 - Message Delivery Status Indicators]

import SwiftUI
import FirebaseAuth

/// Message bubble view with WhatsApp-style status indicators
struct MessageBubbleView: View {
    // MARK: - Properties

    let message: MessageEntity
    let conversation: ConversationEntity
    let participants: [UserEntity]

    /// Optional retry handler for failed messages (provided by parent view)
    var onRetry: ((MessageEntity) -> Void)? = nil

    /// State for showing read receipts sheet
    @State private var showReadReceipts = false

    // MARK: - Computed Properties

    /// Check if message is from current user
    private var isFromCurrentUser: Bool {
        message.senderID == Auth.auth().currentUser?.uid
    }

    /// Bubble background color
    private var bubbleColor: Color {
        isFromCurrentUser ? .blue : Color(.systemGray5)
    }

    /// Text color based on sender
    private var textColor: Color {
        isFromCurrentUser ? .white : .primary
    }

    /// Check if read receipts can be shown (own messages in all conversations, not system messages)
    private var canShowReadReceipts: Bool {
        isFromCurrentUser && !message.isSystemMessage
    }

    /// Get sender's display name from participants (for group/channel messages)
    private var senderDisplayName: String {
        guard let sender = participants.first(where: { $0.id == message.senderID }) else {
            return "Unknown"
        }
        return sender.displayName
    }

    /// Check if username should be shown (only for group messages from others)
    private var shouldShowUsername: Bool {
        conversation.isGroup && !isFromCurrentUser && !message.isSystemMessage
    }


    // MARK: - Body

    var body: some View {
        // System messages have special styling
        if message.isSystemMessage {
            systemMessageView
        } else {
            regularMessageView
        }
    }

    // MARK: - Message Views

    /// System message view (centered, gray text)
    private var systemMessageView: some View {
        HStack {
            Spacer()
            Text(message.text)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Spacer()
        }
        .accessibilityLabel("System message: \(message.text)")
    }

    /// Regular message bubble view
    private var regularMessageView: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Username label (only for group/channel messages from others)
                if shouldShowUsername {
                    Text(senderDisplayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }

                // Message bubble
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(18)

                // Timestamp + status
                HStack(spacing: 4) {
                    // Use server timestamp if available, fallback to local
                    Text(message.serverTimestamp ?? message.localCreatedAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: message.status)
                            .animation(.easeInOut(duration: 0.2), value: message.syncStatus)
                    }
                }
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
        .onTapGesture {
            // Show message details modal for own messages
            if canShowReadReceipts {
                showReadReceipts = true
            }
        }
        .sheet(isPresented: $showReadReceipts) {
            MessageDetailsView(message: message, conversation: conversation, participants: participants)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Status Icon

    /// WhatsApp-style status icon with animations
    /// Status icon with blue checkmark for read messages
    /// WhatsApp-style status icon with animations
    /// Status icon with blue checkmark for read messages
    /// Only shown in 1:1 DMs (hidden in group chats)
    @ViewBuilder
    private var statusIcon: some View {
        // Only show status icons in 1:1 DMs, not in group chats
        if !conversation.isGroup {
            switch message.syncStatus {
            case .pending:
                // Sending - clock icon
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Sending")

            case .failed:
                // Failed - show retry button
                Button {
                    retryMessage()
                } label: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Failed to send. Tap to retry.")

            case .synced:
                // Successfully synced - show delivery status
                switch message.status {
                case .sending:
                    // Should not happen when synced, but handle gracefully
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Sending")

                case .sent:
                    // Sent - single gray checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Sent")

                case .delivered:
                    // Delivered - double gray checkmarks (WhatsApp style)
                    ZStack(alignment: .trailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .offset(x: -3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Delivered")

                case .read:
                    // Read - double blue checkmarks (WhatsApp style)
                    ZStack(alignment: .trailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .offset(x: -3)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Read")
                }
            }
        }
    }

    // MARK: - Accessibility

    /// VoiceOver description combining message text and status
    private var accessibilityDescription: String {
        var description = message.text

        if isFromCurrentUser {
            description += ", "
            switch message.syncStatus {
            case .pending:
                description += "sending"
            case .failed:
                description += "failed to send, tap to retry"
            case .synced:
                switch message.status {
                case .sending:
                    description += "sending"
                case .sent:
                    description += "sent"
                case .delivered:
                    description += "delivered"
                case .read:
                    description += "read"
                }
            }
        } else {
            description += ", received"
        }

        return description
    }

    // MARK: - Private Methods

    /// Retry sending failed message via parent view handler
    private func retryMessage() {
        // Call parent view's retry handler if provided
        // This will be connected to MessageThreadViewModel.retryFailedMessage()
        // or SyncCoordinator.shared.retryMessage() in Story 2.5
        onRetry?(message)
    }
}
