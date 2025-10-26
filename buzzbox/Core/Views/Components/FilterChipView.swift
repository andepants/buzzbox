/// FilterChipView.swift
///
/// Reusable filter chip component for AI category filtering.
/// Features icon, label, count badge, and haptic feedback.
///
/// Created: 2025-10-25
/// [Source: Story 8.6 - Creator Inbox Smart Filter]

import SwiftUI

/// Filter chip view for conversation category filtering
struct FilterChipView: View {
    // MARK: - Properties

    let category: AICategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: {
            action()
            #if os(iOS)
            HapticFeedback.impact(.light)
            #endif
        }) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : Color.gray.opacity(0.15))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.displayName), \(count) conversations")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to filter by \(category.displayName.lowercased())")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        FilterChipView(category: .all, count: 25, isSelected: true) {
            print("All tapped")
        }

        FilterChipView(category: .fan, count: 10, isSelected: false) {
            print("Fan tapped")
        }

        FilterChipView(category: .urgent, count: 3, isSelected: false) {
            print("Urgent tapped")
        }

        FilterChipView(category: .spam, count: 0, isSelected: false) {
            print("Spam tapped")
        }
    }
    .padding()
}
