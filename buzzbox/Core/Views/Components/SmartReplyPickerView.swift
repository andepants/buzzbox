/// SmartReplyPickerView.swift
///
/// Sheet view for selecting AI-generated smart reply drafts.
/// Displays 3 options (short, medium, detailed) in creator's voice.
///
/// Created: 2025-10-23
/// [Source: Story 6.7 - AI UI Components]

import SwiftUI

/// Smart reply picker sheet
/// Displays 3 AI-generated reply options for creator to select
struct SmartReplyPickerView: View {
    let drafts: [String]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                    Button {
                        onSelect(draft)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(draftLabel(index))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(draft.count) chars")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(draft)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("✨ AI-Generated Replies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss", action: onDismiss)
                }
            }
        }
    }

    private func draftLabel(_ index: Int) -> String {
        ["📝 Short", "💬 Medium", "📄 Detailed"][index]
    }
}

#Preview {
    SmartReplyPickerView(
        drafts: [
            "Thanks so much! 🙌",
            "Hey! Really appreciate the kind words. Means a lot!",
            "Hey! Thanks so much for watching. It really means a lot to know the content is helpful. Always trying to make it as useful as possible!"
        ],
        onSelect: { draft in
            print("Selected: \(draft)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
