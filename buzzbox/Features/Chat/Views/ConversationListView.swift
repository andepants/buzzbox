/// ConversationListView.swift
///
/// Main view showing list of conversations
/// Features real-time updates, search, swipe actions, pull-to-refresh, network status
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase

/// Main view displaying all conversations with real-time updates
struct ConversationListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext

    // Query non-archived conversations sorted by last message timestamp
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isArchived == false
        },
        sort: [SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)]
    ) private var conversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var showRecipientPicker = false
    @State private var showGroupCreation = false
    @State private var showProfile = false
    @State private var searchText = ""
    @EnvironmentObject var networkMonitor: NetworkMonitor

    // MARK: - Computed Properties

    var filteredConversations: [ConversationEntity] {
        if searchText.isEmpty {
            return Array(conversations)
        }
        return conversations.filter { conversation in
            // Search by last message content
            if let lastMessage = conversation.lastMessageText,
               lastMessage.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // TODO: Search by recipient name when recipient loading is implemented
            return false
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Network status banner
                if !networkMonitor.isConnected {
                    NetworkStatusBanner()
                }

                // Conversations or empty state
                if filteredConversations.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else if filteredConversations.isEmpty {
                    emptySearchView
                } else {
                    conversationsList
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    profileButton
                }

                ToolbarItem(placement: .topBarLeading) {
                    newGroupButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    newMessageButton
                }
            }
            .refreshable {
                await viewModel?.syncConversations()
            }
            .task {
                setupViewModel()
                await viewModel?.startRealtimeListener()
            }
            .onDisappear {
                viewModel?.stopRealtimeListener()
            }
            .sheet(isPresented: $showRecipientPicker) {
                RecipientPickerView { userID in
                    Task {
                        await createConversation(withUserID: userID)
                    }
                }
            }
            .sheet(isPresented: $showGroupCreation) {
                GroupCreationView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // MARK: - Subviews

    private var profileButton: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("Profile")
        .accessibilityHint("View and edit your profile")
    }

    private var newGroupButton: some View {
        Button {
            showGroupCreation = true
        } label: {
            Image(systemName: "person.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("New Channel")
        .accessibilityHint("Create a channel conversation with multiple participants")
    }

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
            "No Conversations",
            systemImage: "message",
            description: Text("Tap + to start messaging")
        )
        .listRowSeparator(.hidden)
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No conversations match '\(searchText)'")
        )
        .listRowSeparator(.hidden)
    }

    private var conversationsList: some View {
        ForEach(filteredConversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRowView(conversation: conversation)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    archiveConversation(conversation)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .contextMenu {
                Button {
                    togglePin(conversation)
                } label: {
                    Label(
                        conversation.isPinned ? "Unpin" : "Pin",
                        systemImage: conversation.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button {
                    toggleUnread(conversation)
                } label: {
                    Label(
                        conversation.unreadCount > 0 ? "Mark as Read" : "Mark as Unread",
                        systemImage: "envelope.badge"
                    )
                }

                Button {
                    archiveConversation(conversation)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }

                Button(role: .destructive) {
                    deleteConversation(conversation)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationDestination(for: ConversationEntity.self) { conversation in
            MessageThreadView(conversation: conversation)
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    private func createConversation(withUserID userID: String) async {
        guard let viewModel = viewModel else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let _ = try await viewModel.createConversation(
                withUserID: userID,
                currentUserID: currentUserID
            )
        } catch {
            print("❌ Failed to create conversation: \(error)")
        }
    }

    private func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        try? modelContext.save()

        // Sync to RTDB
        Task {
            try? await ConversationService.shared.syncConversation(conversation)
        }

        print("📦 Archived conversation: \(conversation.id)")
    }

    private func togglePin(_ conversation: ConversationEntity) {
        conversation.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        print("\(conversation.isPinned ? "📌" : "📍") \(conversation.isPinned ? "Pinned" : "Unpinned"): \(conversation.id)")
    }

    private func toggleUnread(_ conversation: ConversationEntity) {
        conversation.unreadCount = conversation.unreadCount > 0 ? 0 : 1
        try? modelContext.save()

        print("\(conversation.unreadCount > 0 ? "📬" : "📭") \(conversation.unreadCount > 0 ? "Marked unread" : "Marked read"): \(conversation.id)")
    }

    private func deleteConversation(_ conversation: ConversationEntity) {
        modelContext.delete(conversation)
        try? modelContext.save()

        // Delete from RTDB
        Task {
            let conversationRef = Database.database().reference().child("conversations/\(conversation.id)")
            try? await conversationRef.removeValue()
        }

        print("🗑️ Deleted conversation: \(conversation.id)")
    }
}

// MARK: - Preview

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self])
        .environmentObject(NetworkMonitor.shared)
}
