/// AIMetadataBadgeView.swift
///
/// Displays AI metadata badges for messages (category, sentiment, opportunity score).
/// Shows color-coded badges with icons for quick visual scanning.
///
/// Created: 2025-10-23
/// [Source: Story 6.7 - AI UI Components]

import SwiftUI

/// Displays AI metadata badges for messages
/// Shows category, sentiment, and opportunity score with color coding
struct AIMetadataBadgeView: View {
    let category: MessageCategory?
    let sentiment: MessageSentiment?
    let score: Int?

    var body: some View {
        HStack(spacing: 8) {
            if let category {
                categoryBadge(category)
            }

            if let sentiment {
                sentimentBadge(sentiment)
            }

            if let score, category == .business {
                scoreBadge(score)
            }
        }
        .font(.caption2)
    }

    // MARK: - Category Badge

    @ViewBuilder
    private func categoryBadge(_ category: MessageCategory) -> some View {
        Label {
            Text(category.rawValue.capitalized)
        } icon: {
            Image(systemName: categoryIcon(category))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(categoryColor(category).opacity(0.2))
        .foregroundStyle(categoryColor(category))
        .clipShape(Capsule())
    }

    private func categoryIcon(_ category: MessageCategory) -> String {
        switch category {
        case .fan:
            return "heart.fill"
        case .business:
            return "briefcase.fill"
        case .spam:
            return "trash.fill"
        case .urgent:
            return "exclamationmark.triangle.fill"
        }
    }

    private func categoryColor(_ category: MessageCategory) -> Color {
        switch category {
        case .fan:
            return .blue
        case .business:
            return .purple
        case .spam:
            return .gray
        case .urgent:
            return .red
        }
    }

    // MARK: - Sentiment Badge

    @ViewBuilder
    private func sentimentBadge(_ sentiment: MessageSentiment) -> some View {
        Circle()
            .fill(sentimentColor(sentiment))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .strokeBorder(sentimentColor(sentiment).opacity(0.5), lineWidth: 1)
            )
            .help(sentiment.rawValue.capitalized) // Tooltip on hover
    }

    private func sentimentColor(_ sentiment: MessageSentiment) -> Color {
        switch sentiment {
        case .positive:
            return .green
        case .negative:
            return .red
        case .urgent:
            return .orange
        case .neutral:
            return .gray
        }
    }

    // MARK: - Opportunity Score Badge

    @ViewBuilder
    private func scoreBadge(_ score: Int) -> some View {
        Label {
            Text("\(score)")
        } icon: {
            Image(systemName: "star.fill")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(scoreColor(score).opacity(0.2))
        .foregroundStyle(scoreColor(score))
        .clipShape(Capsule())
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 50...79:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Fan Message") {
    AIMetadataBadgeView(
        category: .fan,
        sentiment: .positive,
        score: nil
    )
    .padding()
}

#Preview("Business Message") {
    AIMetadataBadgeView(
        category: .business,
        sentiment: .neutral,
        score: 85
    )
    .padding()
}

#Preview("Urgent Message") {
    AIMetadataBadgeView(
        category: .urgent,
        sentiment: .urgent,
        score: nil
    )
    .padding()
}

#Preview("Spam Message") {
    AIMetadataBadgeView(
        category: .spam,
        sentiment: .neutral,
        score: nil
    )
    .padding()
}
