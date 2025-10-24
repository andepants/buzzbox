/**
 * FloatingFABView.swift
 *
 * Expandable floating action button for smart reply generation.
 * Inspired by iOS Camera app's mode selector.
 * Fully accessible with VoiceOver and reduced motion support.
 *
 * Created: 2025-10-24
 * [Source: Story 6.10 - Floating FAB Smart Replies]
 */

import SwiftUI

// MARK: - Reply Type Enum

/// Reply type for FAB buttons
enum SmartReplyType: String, CaseIterable {
    case short
    case funny
    case professional

    var icon: String {
        switch self {
        case .short: return "text.bubble"
        case .funny: return "face.smiling"
        case .professional: return "briefcase"
        }
    }

    var color: Color {
        switch self {
        case .short: return .blue
        case .funny: return .orange
        case .professional: return .purple
        }
    }

    var label: String {
        switch self {
        case .short: return "Short"
        case .funny: return "Funny"
        case .professional: return "Pro"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .short: return "Generate short reply"
        case .funny: return "Generate funny reply"
        case .professional: return "Generate professional reply"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .short: return "Quick one to two sentence response"
        case .funny: return "Playful and humorous response"
        case .professional: return "Detailed professional response"
        }
    }
}

// MARK: - FloatingFABView

/// Floating FAB view for smart reply generation
struct FloatingFABView: View {

    // MARK: - Properties

    /// Whether FABs are expanded
    @State private var isExpanded = false

    /// Currently loading reply type
    @State private var loadingType: SmartReplyType?

    /// Error state
    @State private var showError = false
    @State private var errorMessage = ""

    /// Callback when reply is generated
    let onReplyGenerated: (String) -> Void

    /// Callback to generate reply
    let generateReply: (SmartReplyType) async throws -> String

    // Accessibility
    @AccessibilityFocusState private var isMainFABFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Short button (appears on left)
            if isExpanded {
                fabButton(for: .short)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .trailing)),
                        removal: .scale.combined(with: .move(edge: .trailing))
                    ))
            }

            // Main FAB (center)
            mainFABButton

            // Funny button (right of center)
            if isExpanded {
                fabButton(for: .funny)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .leading)),
                        removal: .scale.combined(with: .move(edge: .leading))
                    ))
            }

            // Professional button (far right)
            if isExpanded {
                fabButton(for: .professional)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .leading)),
                        removal: .scale.combined(with: .move(edge: .leading))
                    ))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                // Alert dismisses automatically
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Main FAB Button

    private var mainFABButton: some View {
        Button {
            withAnimation(reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.3)) {
                isExpanded.toggle()
            }
            #if os(iOS)
            HapticFeedback.impact(.medium)
            #endif

            // Accessibility announcement
            let announcement = isExpanded ? "Reply options expanded" : "Reply options collapsed"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                Image(systemName: isExpanded ? "xmark" : "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .disabled(loadingType != nil)
        .accessibilityLabel("AI Smart Replies")
        .accessibilityHint("Double-tap to expand reply options")
        .accessibilityFocused($isMainFABFocused)
    }

    // MARK: - Individual FAB Buttons

    @ViewBuilder
    private func fabButton(for type: SmartReplyType) -> some View {
        Button {
            Task {
                await handleReplyGeneration(type: type)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(type.color.gradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                    if loadingType == type {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("Generating reply")
                    } else {
                        Image(systemName: type.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                Text(type.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(type.color)
            }
        }
        .disabled(loadingType != nil)
        .opacity(loadingType != nil && loadingType != type ? 0.5 : 1.0)
        .accessibilityLabel(type.accessibilityLabel)
        .accessibilityHint(type.accessibilityHint)
        .accessibilityAddTraits(loadingType == type ? .updatesFrequently : [])
    }

    // MARK: - Private Methods

    /// Handle reply generation for a specific type
    private func handleReplyGeneration(type: SmartReplyType) async {
        loadingType = type
        defer { loadingType = nil }

        #if os(iOS)
        HapticFeedback.impact(.light)
        #endif

        // Accessibility announcement
        UIAccessibility.post(notification: .announcement, argument: "Generating AI reply")

        do {
            let reply = try await generateReply(type)

            // Collapse FABs
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.2)) {
                isExpanded = false
            }

            // Populate input
            onReplyGenerated(reply)

            #if os(iOS)
            HapticFeedback.notification(.success)
            #endif

            // Accessibility announcement
            UIAccessibility.post(notification: .announcement, argument: "Reply generated")

        } catch {
            print("Failed to generate reply: \(error)")

            // ERROR HANDLING: Collapse FABs on error
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.2)) {
                isExpanded = false
            }

            // Show error alert
            errorMessage = "Failed to generate AI reply. Please try again."
            showError = true

            #if os(iOS)
            HapticFeedback.notification(.error)
            #endif

            // Accessibility announcement
            UIAccessibility.post(notification: .announcement, argument: errorMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        FloatingFABView(
            onReplyGenerated: { reply in
                print("Generated: \(reply)")
            },
            generateReply: { type in
                // Mock delay
                try await Task.sleep(for: .seconds(1.5))

                switch type {
                case .short:
                    return "Thanks! 🙌"
                case .funny:
                    return "Haha that's awesome! You just made my day! 😄"
                case .professional:
                    return "Thank you for reaching out! I really appreciate your message and I'd love to hear more about what you're working on. Let me know how I can help!"
                }
            }
        )

        // Mock input field
        HStack {
            TextField("Message", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .background(Color(.systemGray6))
    }
}
