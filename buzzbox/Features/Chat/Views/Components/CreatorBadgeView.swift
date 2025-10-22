/// CreatorBadgeView.swift
///
/// Visual badge to identify the creator (Andrew Heim Dev) in the UI
/// [Source: Epic 5, Story 5.2 - User Type Auto-Assignment]
///
/// Displays a verified-style badge next to the creator's name to
/// distinguish them from regular fans/members.

import SwiftUI

/// Badge view for displaying creator status
struct CreatorBadgeView: View {
    /// Size variant for the badge
    enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 20
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 11
            case .large: return 13
            }
        }
    }

    // MARK: - Properties

    /// Size of the badge
    let size: Size

    /// Optional text label (defaults to "Creator")
    let label: String?

    // MARK: - Initialization

    /// Initialize creator badge
    /// - Parameters:
    ///   - size: Size variant (small, medium, large)
    ///   - label: Optional text label (nil for icon only)
    init(size: Size = .medium, label: String? = nil) {
        self.size = size
        self.label = label
    }

    // MARK: - Body

    var body: some View {
        if let label = label {
            // Badge with label
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size.fontSize, weight: .semibold))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.system(size: size.fontSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .accessibilityLabel("Creator badge")
            .accessibilityHint("This user is the creator of the platform")
        } else {
            // Icon-only badge
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: size.dimension, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .accessibilityLabel("Creator")
                .accessibilityHint("This user is the creator of the platform")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Icon only variants
        HStack(spacing: 20) {
            CreatorBadgeView(size: .small)
            CreatorBadgeView(size: .medium)
            CreatorBadgeView(size: .large)
        }

        Divider()

        // With label variants
        VStack(spacing: 12) {
            CreatorBadgeView(size: .small, label: "Creator")
            CreatorBadgeView(size: .medium, label: "Creator")
            CreatorBadgeView(size: .large, label: "Creator")
        }
    }
    .padding()
}
