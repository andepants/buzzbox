/// TypingIndicatorView.swift
///
/// Animated typing indicator with sequential dot animation.
/// Displays "Typing" text with 3 animated dots that fade sequentially.
///
/// Created: 2025-10-22
/// [Source: Story 2.6 - Real-Time Typing Indicators, RTDB Code Examples lines 1737-1774]

import SwiftUI
import Combine

/// Typing indicator view with animated dots
struct TypingIndicatorView: View {
    // MARK: - Constants

    /// Animation interval for dot cycling
    private static let animationInterval: TimeInterval = 0.4

    // MARK: - Properties

    /// Animation phase (0, 1, or 2) for sequential dot animation
    @State private var animationPhase = 0

    /// Timer cancellable for proper cleanup
    @State private var timerCancellable: Cancellable?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            Text("Typing")
                .font(.caption)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(18)
        .onAppear {
            // Start timer when view appears
            timerCancellable = Timer.publish(
                every: Self.animationInterval,
                on: .main,
                in: .common
            )
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: Self.animationInterval)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
        .onDisappear {
            // Cancel timer when view disappears to prevent memory leak
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .accessibilityLabel("Typing indicator")
        .accessibilityHint("The other person is typing a message")
    }
}

// MARK: - Preview

#Preview {
    TypingIndicatorView()
        .padding()
}
