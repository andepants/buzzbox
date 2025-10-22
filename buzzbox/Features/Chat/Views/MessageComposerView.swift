/// MessageComposerView.swift
///
/// Message input composer with character counter and send button.
/// Supports multi-line input (1-5 lines) and validates message length.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages, RTDB Code Examples lines 1117-1192]

import SwiftUI

/// Message composer view with text input and send button
struct MessageComposerView: View {
    // MARK: - Properties

    @Binding var text: String
    let characterLimit: Int
    let onSend: () async -> Void

    @FocusState private var isFocused: Bool
    @State private var isLoading = false

    // MARK: - Computed Properties

    var remainingCharacters: Int {
        characterLimit - text.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .focused($isFocused)
                    .onSubmit {
                        Task {
                            await send()
                        }
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message here")

                // Send button
                Button {
                    Task {
                        await send()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .accessibilityLabel("Send message")
                .accessibilityHint("Send the message you typed")
            }
            .padding(.horizontal)

            // Character counter (only show when near limit)
            if text.count > characterLimit * 9 / 10 {
                HStack {
                    Spacer()
                    Text("\(remainingCharacters) characters remaining")
                        .font(.caption)
                        .foregroundColor(remainingCharacters < 0 ? .red : .secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Private Methods

    private func send() async {
        isLoading = true
        await onSend()
        isLoading = false
        isFocused = true // Keep keyboard focused
    }
}
