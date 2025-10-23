/// FanDMView.swift
///
/// Simplified DM view for fans showing only their conversation with Andrew
/// If no DM exists, shows empty state with "Message Andrew" button
///
/// Created: 2025-10-22
/// [Source: Story 5.5 - Creator Inbox View]

import SwiftUI
import SwiftData
import FirebaseAuth

/// Fan's simplified DM view
/// Shows single conversation with creator or empty state
struct FanDMView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    // Query all DM conversations
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            !conversation.isGroup && !conversation.isArchived
        },
        sort: [SortDescriptor(\ConversationEntity.lastMessageAt, order: .reverse)]
    ) private var dmConversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var isCreatingDM = false

    // MARK: - Computed Properties

    /// Find conversation with creator (Andrew)
    /// Since fans can only DM with Andrew (Story 5.4 DM restrictions),
    /// any DM they have will be with Andrew
    var andrewConversation: ConversationEntity? {
        dmConversations.first
    }

    /// Unread count for Andrew conversation
    var andrewUnreadCount: Int {
        andrewConversation?.unreadCount ?? 0
    }

    // MARK: - Body

    var body: some View {
        if let conversation = andrewConversation {
            // Show chat directly (skip list screen)
            MessageThreadView(conversation: conversation)
                .task {
                    setupViewModel()
                    await viewModel?.startRealtimeListener()
                }
                .onDisappear {
                    viewModel?.stopRealtimeListener()
                    viewModel = nil  // Explicitly release ViewModel
                }
        } else {
            // No conversation with Andrew - show empty state
            EmptyDMView(
                isCreatingDM: $isCreatingDM,
                onMessageAndrew: {
                    await createDMWithAndrew()
                }
            )
            .task {
                setupViewModel()
            }
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    /// Create DM with creator (Andrew)
    private func createDMWithAndrew() async {
        guard let viewModel = viewModel else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        isCreatingDM = true
        defer { isCreatingDM = false }

        do {
            let _ = try await viewModel.createDMWithCreator(currentUserID: currentUserID)
            print("✅ Created DM with Andrew")
        } catch {
            print("❌ Failed to create DM with Andrew: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    FanDMView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(AuthViewModel())
}
