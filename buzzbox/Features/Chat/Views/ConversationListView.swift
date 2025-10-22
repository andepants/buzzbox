/// ConversationListView.swift
///
/// Main view showing list of conversations
/// Features "New Message" button, conversation list, and navigation
///
/// Created: 2025-10-21
/// [Source: Story 2.1 - Create New Conversation]

import SwiftUI
import SwiftData
import FirebaseAuth

/// Main view displaying all conversations
struct ConversationListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConversationEntity.updatedAt, order: .reverse)
    private var conversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var showRecipientPicker = false
    @State private var selectedConversation: ConversationEntity?
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    newMessageButton
                }
            }
            .sheet(isPresented: $showRecipientPicker) {
                RecipientPickerView { userID in
                    Task {
                        await createConversation(withUserID: userID)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                setupViewModel()
            }
        }
    }

    // MARK: - Subviews

    private var newMessageButton: some View {
        Button {
            showRecipientPicker = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("New Message")
        .accessibilityHint("Start a new conversation")
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Messages",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Tap the compose button to start a new conversation")
        )
    }

    private var conversationsList: some View {
        List(conversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRowView(conversation: conversation)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: ConversationEntity.self) { conversation in
            // TODO: Navigate to MessageThreadView
            Text("Conversation: \(conversation.id)")
                .navigationTitle("Chat")
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    private func createConversation(withUserID userID: String) async {
        guard let viewModel = viewModel else {
            errorMessage = "ViewModel not initialized"
            showError = true
            return
        }

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to create a conversation"
            showError = true
            return
        }

        do {
            let conversation = try await viewModel.createConversation(
                withUserID: userID,
                currentUserID: currentUserID
            )

            // Navigate to the conversation
            selectedConversation = conversation
            print("✅ Created conversation: \(conversation.id)")

        } catch let error as ConversationError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Conversation Row View

/// Row view for displaying a single conversation in the list
struct ConversationRowView: View {
    let conversation: ConversationEntity

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 52, height: 52)
                .overlay {
                    Text(getInitials())
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                // Display name or recipient ID
                Text(conversation.displayName ?? "Conversation")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                // Last message preview
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Timestamp
                if let lastMessageAt = conversation.lastMessageAt {
                    Text(lastMessageAt, style: .time)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                // Unread badge
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }

                // Sync status indicator
                if conversation.syncStatus == .pending {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else if conversation.syncStatus == .failed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func getInitials() -> String {
        if let displayName = conversation.displayName {
            return String(displayName.prefix(1).uppercased())
        }
        return "?"
    }
}

// MARK: - Preview

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self])
}
