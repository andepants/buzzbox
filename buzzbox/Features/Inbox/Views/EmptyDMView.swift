/// EmptyDMView.swift
///
/// Empty state view shown to fans when they have no DM with Andrew
/// Displays helpful message and "Message Andrew" button
///
/// Created: 2025-10-22
/// [Source: Story 5.5 - Creator Inbox View]

import SwiftUI

/// Empty state view for fans with no DM to creator
struct EmptyDMView: View {
    // MARK: - Properties

    @Binding var isCreatingDM: Bool
    let onMessageAndrew: () async -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "envelope.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)

                // Title and description
                VStack(spacing: 12) {
                    Text("No Messages Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Start a conversation with Andrew to get help, ask questions, or share feedback.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Message Andrew button
                Button {
                    Task {
                        await onMessageAndrew()
                    }
                } label: {
                    HStack(spacing: 12) {
                        if isCreatingDM {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Text(isCreatingDM ? "Creating Conversation..." : "Message Andrew")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isCreatingDM)
                .accessibilityLabel("Message Andrew")
                .accessibilityHint("Start a direct message conversation with Andrew")

                Spacer()
            }
            .navigationTitle("DMs")
        }
    }
}

// MARK: - Preview

#Preview {
    EmptyDMView(
        isCreatingDM: .constant(false),
        onMessageAndrew: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}
