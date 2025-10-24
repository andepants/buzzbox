/// FAQBadgeView.swift
///
/// Visual badge to identify FAQ auto-responses with blue glassmorphism styling.
/// Displays a small "FAQ" badge in the corner of message bubbles.
///
/// Created: 2025-10-24

import SwiftUI

/// Badge view for displaying FAQ auto-response indicator
struct FAQBadgeView: View {
    // MARK: - Body

    var body: some View {
        Text("FAQ")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                // Glassmorphism effect with blue tint
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)

                    // Blue gradient overlay
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                // Blue gradient border
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            .accessibilityLabel("FAQ auto-response")
            .accessibilityHint("This message was automatically generated from FAQ database")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // On light background
        FAQBadgeView()
            .padding()
            .background(Color.white)

        // On dark background
        FAQBadgeView()
            .padding()
            .background(Color.black)

        // On message bubble (simulated)
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This is your answer to the FAQ question.")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .overlay(alignment: .topLeading) {
                        FAQBadgeView()
                            .offset(x: -8, y: -8)
                    }
            }
        }
        .padding()
    }
    .padding()
}
