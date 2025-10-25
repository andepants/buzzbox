/// DataSeedingView.swift
///
/// Admin UI for seeding realistic test data
/// Only shown to creator account for development purposes
///
/// Created: 2025-10-25

import SwiftUI
import SwiftData

/// Admin view for seeding test data
struct DataSeedingView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var isSeeding = false
    @State private var showConfirmation = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🌱 Data Seeding Tool")
                            .font(.headline)

                        Text("This will clear all DM conversations and create 5-10 realistic test conversations with existing users.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Safe to use - only works with existing authenticated users and preserves all channels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("About")
                }

                // What Gets Seeded
                Section {
                    FeatureRow(
                        icon: "message.fill",
                        title: "5-10 DM Conversations",
                        subtitle: "Between creator and random fans"
                    )

                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "AI Metadata",
                        subtitle: "Categories, sentiment, FAQ matches"
                    )

                    FeatureRow(
                        icon: "clock.fill",
                        title: "Realistic Timestamps",
                        subtitle: "Messages spread over past week"
                    )

                    FeatureRow(
                        icon: "checkmark.shield.fill",
                        title: "Channels Preserved",
                        subtitle: "Group chats remain untouched"
                    )
                } header: {
                    Text("What Gets Seeded")
                }

                // Message Types
                Section {
                    FeatureRow(
                        icon: "questionmark.circle.fill",
                        title: "FAQ Questions",
                        subtitle: "Test FAQ auto-response feature",
                        color: .blue
                    )

                    FeatureRow(
                        icon: "briefcase.fill",
                        title: "Business Opportunities",
                        subtitle: "Test AI categorization & scoring",
                        color: .purple
                    )

                    FeatureRow(
                        icon: "heart.fill",
                        title: "Fan Engagement",
                        subtitle: "Positive sentiment messages",
                        color: .pink
                    )

                    FeatureRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Urgent Messages",
                        subtitle: "High priority detection",
                        color: .orange
                    )
                } header: {
                    Text("Message Types Included")
                }

                // Action Section
                Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Spacer()

                            if isSeeding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Clear & Seed Data", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSeeding)
                    .listRowBackground(Color.accentColor)
                } footer: {
                    if isSeeding {
                        Text("Seeding data... This may take 10-30 seconds.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This action will delete all existing DM conversations. Channels will be preserved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Seed Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isSeeding)
                }
            }
            .confirmationDialog(
                "Clear & Seed Data?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear & Seed", role: .destructive) {
                    Task {
                        await seedData()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all DM conversations and create 5-10 test conversations with realistic messages. Channels will not be affected.")
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Successfully seeded 5-10 conversations with realistic test data!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Methods

    /// Seed data using DataSeedingService
    private func seedData() async {
        isSeeding = true

        do {
            let service = DataSeedingService(modelContext: modelContext)
            try await service.clearAndSeedConversations()

            isSeeding = false
            showSuccess = true

        } catch {
            isSeeding = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Supporting Views

/// Row showing a feature with icon, title, and subtitle
private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    DataSeedingView()
        .modelContainer(for: [UserEntity.self, ConversationEntity.self, MessageEntity.self])
}
