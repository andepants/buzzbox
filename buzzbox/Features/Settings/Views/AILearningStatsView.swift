/**
 * AI Learning Stats View for Supermemory
 *
 * Displays memory storage statistics in the creator's profile
 * Shows total memories learned, pending sync count, and last sync time
 *
 * [Source: Story 9.5 - Memory Stats UI]
 */

import SwiftUI

/// Displays AI learning statistics in Profile
/// Creator-only feature showing Supermemory metrics
struct AILearningStatsView: View {
    @State private var isProcessing = false

    // Access shared service
    private var supermemoryService: SupermemoryService {
        SupermemoryService.shared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.blue)
                Text("AI Learning Stats")
                    .font(.headline)
                Spacer()
                StatusIndicator(enabled: supermemoryService.isEnabled)
            }

            if supermemoryService.isEnabled {
                // Total Memories
                StatRow(
                    icon: "checkmark.circle.fill",
                    label: "Learned from",
                    value: "\(supermemoryService.totalMemoriesStored) conversations",
                    color: .green
                )

                // Pending Sync
                if supermemoryService.pendingMemoriesCount > 0 {
                    Button {
                        Task {
                            isProcessing = true
                            await supermemoryService.processPendingMemories(forceRetry: true)
                            isProcessing = false
                        }
                    } label: {
                        HStack {
                            StatRow(
                                icon: isProcessing ? "arrow.triangle.2.circlepath" : "exclamationmark.circle.fill",
                                label: "Pending sync",
                                value: "\(supermemoryService.pendingMemoriesCount) memories",
                                color: .orange
                            )
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Last Sync
                if let lastSync = supermemoryService.lastSyncDate {
                    StatRow(
                        icon: "clock",
                        label: "Last synced",
                        value: lastSync.timeAgoDisplay(),
                        color: .secondary
                    )
                }
            } else {
                Text("Supermemory not configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Status indicator badge
struct StatusIndicator: View {
    let enabled: Bool

    var body: some View {
        Circle()
            .fill(enabled ? Color.green : Color.gray)
            .frame(width: 10, height: 10)
    }
}

/// Individual stat row
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label + ":")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns relative time string (e.g., "2 min ago")
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    AILearningStatsView()
        .padding()
}
