/// ChannelsView.swift
///
/// Main view showing list of channels (group conversations)
/// Features real-time updates, search, swipe actions, pull-to-refresh
/// No "New Group" button - channels are pre-seeded by admin
///
/// Created: 2025-10-22
/// [Source: Story 5.6 - Simplified Navigation]

import SwiftUI
import SwiftData
import FirebaseAuth

/// Main view displaying all channels (groups) with real-time updates
struct ChannelsView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext

    // Query group conversations only (isGroup = true), sorted by last message
    // Note: Cannot sort by isPinned (Bool) in @Query for SwiftData models
    // Sorting by pinned status is handled in filteredChannels computed property
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isGroup && conversation.isArchived == false
        },
        sort: [
            SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)
        ]
    ) private var channels: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var searchText = ""
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Initialization

    /// Initializer for ChannelsView
    /// Note: @Query properties don't need to be passed as parameters
    init() {
        // SwiftData @Query is automatically initialized by the system
    }

    // MARK: - Computed Properties

    var filteredChannels: [ConversationEntity] {
        let filtered: [ConversationEntity]
        if searchText.isEmpty {
            filtered = Array(channels)
        } else {
            filtered = channels.filter { channel in
                // Search by channel name
                if let displayName = channel.displayName,
                   displayName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                // Search by last message content
                if let lastMessage = channel.lastMessageText,
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
        ScrollView {
            VStack(spacing: 16) {
                // Network status banner
                if !networkMonitor.isConnected {
                    NetworkStatusBanner()
                }

                // Channels or empty state
                if filteredChannels.isEmpty && searchText.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if filteredChannels.isEmpty {
                    emptySearchView
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    channelsList
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search channels")
        .navigationTitle("Channels")
        .navigationDestination(for: ConversationEntity.self) { channel in
            MessageThreadView(conversation: channel)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel?.syncConversations()
                    }
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel?.isLoading ?? false)
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
            "No Channels",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Channels will appear here when created by admins")
        )
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No channels match '\(searchText)'")
        )
    }

    private var channelsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredChannels) { channel in
                NavigationLink(value: channel) {
                    ChannelCardView(channel: channel)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                    }
                )
                .contextMenu {
                    Button {
                        togglePin(channel)
                    } label: {
                        Label(
                            channel.isPinned ? "Unpin" : "Pin",
                            systemImage: channel.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        toggleMute(channel)
                    } label: {
                        Label(
                            channel.isMuted ? "Unmute" : "Mute",
                            systemImage: channel.isMuted ? "bell" : "bell.slash"
                        )
                    }

                    Button {
                        toggleUnread(channel)
                    } label: {
                        Label(
                            channel.unreadCount > 0 ? "Mark as Read" : "Mark as Unread",
                            systemImage: "envelope.badge"
                        )
                    }
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

    private func togglePin(_ channel: ConversationEntity) {
        channel.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        HapticFeedback.impact(.light)
        #endif

    }

    private func toggleMute(_ channel: ConversationEntity) {
        channel.isMuted.toggle()
        try? modelContext.save()

    }

    private func toggleUnread(_ channel: ConversationEntity) {
        channel.unreadCount = channel.unreadCount > 0 ? 0 : 1
        try? modelContext.save()

    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChannelsView()
    }
    .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
    .environmentObject(NetworkMonitor.shared)
    .environmentObject(AuthViewModel())
}
