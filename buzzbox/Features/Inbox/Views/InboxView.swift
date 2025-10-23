/// InboxView.swift
///
/// Creator's inbox view showing all fan DM conversations
/// Filters to show only one-on-one conversations (isGroup = false)
/// Sorted by most recent message first with real-time updates
///
/// Created: 2025-10-22
/// [Source: Story 5.5 - Creator Inbox View]

import SwiftUI
import SwiftData
import FirebaseAuth

/// Creator's inbox view for managing fan DMs
/// Only visible to users with userType = .creator
struct InboxView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    // Query DM conversations only (isGroup = false), sorted by most recent
    // Note: Cannot sort by isPinned (Bool) in @Query for SwiftData models
    // Sorting by pinned status is handled in filteredConversations computed property
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            !conversation.isGroup && !conversation.isArchived
        },
        sort: [
            SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)
        ]
    ) private var dmConversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var searchText = ""

    // MARK: - Initialization

    /// Initializer for InboxView
    /// Note: @Query properties don't need to be passed as parameters
    init() {
        // SwiftData @Query is automatically initialized by the system
    }

    // MARK: - Computed Properties

    /// Total unread count across all DM conversations
    var totalUnread: Int {
        dmConversations.reduce(0) { $0 + $1.unreadCount }
    }

    /// Filtered conversations based on search text, sorted by pinned status
    var filteredConversations: [ConversationEntity] {
        let filtered: [ConversationEntity]
        if searchText.isEmpty {
            filtered = Array(dmConversations)
        } else {
            filtered = dmConversations.filter { conversation in
                if let lastMessage = conversation.lastMessageText,
                   lastMessage.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }

        // Sort by pinned status first, then by updatedAt
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned // Pinned items first
            }
            return lhs.updatedAt > rhs.updatedAt // Then by most recent
        }
    }

    // MARK: - Body

    var body: some View {
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
        .searchable(text: $searchText, prompt: "Search fan messages")
        .navigationTitle("Inbox")
        .navigationDestination(for: ConversationEntity.self) { conversation in
            MessageThreadView(conversation: conversation)
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
            viewModel = nil  // Explicitly release ViewModel
        }
        .alert("Error", isPresented: .constant(viewModel?.error != nil)) {
            Button("OK") {
                viewModel?.error = nil
            }
        } message: {
            if let error = viewModel?.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Fan Messages Yet",
            systemImage: "tray",
            description: Text("Fan DM conversations will appear here.\nFans can message you from the app.")
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
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    toggleUnread(conversation)
                } label: {
                    Label(
                        conversation.unreadCount > 0 ? "Read" : "Unread",
                        systemImage: conversation.unreadCount > 0 ? "envelope.open" : "envelope.badge"
                    )
                }
                .tint(.blue)
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
            }
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    private func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        try? modelContext.save()

        // Sync to Firebase
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
}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(AuthViewModel())
}
