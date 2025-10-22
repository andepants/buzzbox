/// MessageBubbleView.swift
///
/// Displays a single message bubble with text, timestamp, and status indicators.
/// Shows different styles for sent vs received messages.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages]

import SwiftUI
import FirebaseAuth

/// Message bubble view for displaying individual messages
struct MessageBubbleView: View {
    // MARK: - Properties

    let message: MessageEntity

    // MARK: - Computed Properties

    private var isCurrentUser: Bool {
        message.senderID == Auth.auth().currentUser?.uid
    }

    private var bubbleColor: Color {
        isCurrentUser ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        isCurrentUser ? .white : .primary
    }

    private var statusIcon: String? {
        switch message.syncStatus {
        case .pending:
            return "clock"
        case .synced:
            return "checkmark"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    // MARK: - Body

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message text
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                    .accessibilityLabel("Message from \(isCurrentUser ? "you" : "sender")")
                    .accessibilityValue(message.text)

                // Timestamp and status
                HStack(spacing: 4) {
                    Text(formatTimestamp(message.localCreatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isCurrentUser, let icon = statusIcon {
                        Image(systemName: icon)
                            .font(.caption2)
                            .foregroundColor(message.syncStatus == .failed ? .red : .secondary)
                    }
                }
            }

            if !isCurrentUser {
                Spacer()
            }
        }
    }

    // MARK: - Private Methods

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
