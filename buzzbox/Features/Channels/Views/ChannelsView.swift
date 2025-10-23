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
    @State private var showProfile = false
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
        List {
            // Network status banner
            if !networkMonitor.isConnected {
                NetworkStatusBanner()
            }

            // Message Andrew button for fans (Story 5.6: AC 7)
            if authViewModel.currentUser?.isFan == true {
                messageAndrewButton
            }

            // Channels or empty state
            if filteredChannels.isEmpty && searchText.isEmpty {
                emptyStateView
            } else if filteredChannels.isEmpty {
                emptySearchView
            } else {
                channelsList
            }
        }
        .searchable(text: $searchText, prompt: "Search channels")
        .navigationTitle("Channels")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                profileButton
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
        .sheet(isPresented: $showProfile) {
            ProfileView()
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

    /// Message Andrew button for fans (Story 5.6: AC 7 - Secondary location)
    private var messageAndrewButton: some View {
        Button {
            Task {
                await createDMWithCreator()
            }
        } label: {
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Message Andrew")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .accessibilityLabel("Message Andrew")
        .accessibilityHint("Start a direct message conversation with Andrew")
    }

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

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Channels",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Channels will appear here when created by admins")
        )
        .listRowSeparator(.hidden)
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No channels match '\(searchText)'")
        )
        .listRowSeparator(.hidden)
    }

    private var channelsList: some View {
        ForEach(filteredChannels) { channel in
            NavigationLink(value: channel) {
                ConversationRowView(conversation: channel)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    toggleMute(channel)
                } label: {
                    Label(
                        channel.isMuted ? "Unmute" : "Mute",
                        systemImage: channel.isMuted ? "bell" : "bell.slash"
                    )
                }
                .tint(.orange)
            }
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
        .navigationDestination(for: ConversationEntity.self) { channel in
            MessageThreadView(conversation: channel)
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    /// Create DM with creator (Andrew) - Story 5.6: AC 7
    private func createDMWithCreator() async {
        guard let viewModel = viewModel else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let _ = try await viewModel.createDMWithCreator(currentUserID: currentUserID)
        } catch {
            print("❌ Failed to create DM with creator: \(error)")
            // Error is already set in viewModel.error and will be displayed in UI
        }
    }

    private func togglePin(_ channel: ConversationEntity) {
        channel.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        print("\(channel.isPinned ? "📌" : "📍") \(channel.isPinned ? "Pinned" : "Unpinned"): \(channel.displayName ?? channel.id)")
    }

    private func toggleMute(_ channel: ConversationEntity) {
        channel.isMuted.toggle()
        try? modelContext.save()

        print("\(channel.isMuted ? "🔇" : "🔔") \(channel.isMuted ? "Muted" : "Unmuted"): \(channel.displayName ?? channel.id)")
    }

    private func toggleUnread(_ channel: ConversationEntity) {
        channel.unreadCount = channel.unreadCount > 0 ? 0 : 1
        try? modelContext.save()

        print("\(channel.unreadCount > 0 ? "📬" : "📭") \(channel.unreadCount > 0 ? "Marked unread" : "Marked read"): \(channel.displayName ?? channel.id)")
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
