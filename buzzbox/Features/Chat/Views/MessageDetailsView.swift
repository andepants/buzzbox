/// MessageDetailsView.swift
///
/// Modal view that displays detailed information about a message including:
/// - Message status (sending, sent, delivered, read)
/// - Timestamp information
/// - Read receipts for all participants
///
/// Created: 2025-10-23
/// [Debug helper for message delivery tracking]

import SwiftUI
import FirebaseAuth

/// Message details modal for debugging and viewing read receipts
struct MessageDetailsView: View {
    // MARK: - Properties

    let message: MessageEntity
    let conversation: ConversationEntity
    let participants: [UserEntity]

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    /// Format the message timestamp
    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        if let serverTimestamp = message.serverTimestamp {
            return formatter.string(from: serverTimestamp)
        } else {
            return formatter.string(from: message.localCreatedAt)
        }
    }

    /// Get read status for each participant
    private var readReceipts: [(user: UserEntity, readAt: Date?)] {
        participants
            .filter { $0.id != message.senderID } // Exclude sender
            .map { user in
                let readAt = message.readBy[user.id]
                return (user: user, readAt: readAt)
            }
            .sorted { lhs, rhs in
                // Sort by read time (most recent first), unread last
                switch (lhs.readAt, rhs.readAt) {
                case (.some(let lhsDate), .some(let rhsDate)):
                    return lhsDate > rhsDate
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.user.displayName < rhs.user.displayName
                }
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Message Info Section
                Section("Message Info") {
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            statusIcon
                            Text(statusText)
                                .foregroundColor(.secondary)
                        }
                    }

                    LabeledContent("Sync Status") {
                        Text(syncStatusText)
                            .foregroundColor(syncStatusColor)
                    }

                    LabeledContent("Sent") {
                        Text(timestampText)
                            .foregroundColor(.secondary)
                    }

                    if let serverTimestamp = message.serverTimestamp {
                        LabeledContent("Server Time") {
                            Text(serverTimestamp, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }

                    LabeledContent("Message ID") {
                        Text(message.id.prefix(8))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // Read Receipts Section
                if !readReceipts.isEmpty {
                    Section {
                        ForEach(readReceipts, id: \.user.id) { receipt in
                            HStack {
                                // User avatar/initial
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(String(receipt.user.displayName.prefix(1)))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(receipt.user.displayName)
                                        .font(.body)

                                    if let readAt = receipt.readAt {
                                        Text(formatReadTime(readAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Not read yet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                // Read indicator
                                if receipt.readAt != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Read By (\(readReceipts.filter { $0.readAt != nil }.count)/\(readReceipts.count))")
                    }
                }

                // Debug Info Section (only in development)
                #if DEBUG
                Section("Debug Info") {
                    LabeledContent("Conversation ID") {
                        Text(conversation.id.prefix(8))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    LabeledContent("Conversation Type") {
                        Text(conversation.isGroup ? "Channel" : "DM")
                            .foregroundColor(.secondary)
                    }

                    LabeledContent("Total Participants") {
                        Text("\(conversation.participantIDs.count)")
                            .foregroundColor(.secondary)
                    }
                }
                #endif
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .foregroundColor(.secondary)
        case .delivered:
            ZStack(alignment: .trailing) {
                Image(systemName: "checkmark")
                    .foregroundColor(.secondary)
                    .offset(x: -3)
                Image(systemName: "checkmark")
                    .foregroundColor(.secondary)
            }
        case .read:
            ZStack(alignment: .trailing) {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .offset(x: -3)
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }

    private var statusText: String {
        switch message.status {
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        }
    }

    private var syncStatusText: String {
        switch message.syncStatus {
        case .pending: return "Pending"
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }

    private var syncStatusColor: Color {
        switch message.syncStatus {
        case .pending: return .orange
        case .synced: return .green
        case .failed: return .red
        }
    }

    // MARK: - Helper Methods

    /// Format read time with relative date
    private func formatReadTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Read at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Read yesterday at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "Read \(formatter.string(from: date))"
        }
    }
}
