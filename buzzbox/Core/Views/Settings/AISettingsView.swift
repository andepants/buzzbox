/**
 * AI Settings View for Buzzbox
 *
 * Allows the creator to control AI behavior:
 * - Enable/disable FAQ auto-response
 * - Enable/disable auto-processing
 *
 * [Source: Epic 6 - AI-Powered Creator Inbox]
 * [Story: 6.9 - AI Settings UI]
 */

import SwiftUI

struct AISettingsView: View {
    @AppStorage("ai.faqAutoResponse.enabled") private var faqAutoResponseEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("FAQ Auto-Response", isOn: $faqAutoResponseEnabled)
                Text("Automatically send FAQ answers when fans ask common questions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Auto-Response")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-Categorization")
                        .font(.headline)
                    Text("Enabled (always on)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Messages are automatically analyzed with AI for categorization, sentiment, and scoring")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("AI Processing")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Replies")
                        .font(.headline)
                    Text("Always available via 'Draft Reply' button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Manual Features")
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
