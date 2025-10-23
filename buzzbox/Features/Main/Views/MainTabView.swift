/// MainTabView.swift
///
/// Main tab navigation with conditional tabs based on user type
/// Fans see: Channels | DMs | Profile
/// Creator sees: Channels | Inbox | Profile
///
/// Created: 2025-10-22
/// [Source: Story 5.6 - Simplified Navigation]

import SwiftUI
import SwiftData

/// Main tab view with conditional navigation for creator vs fans
struct MainTabView: View {
    // MARK: - Properties

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.modelContext) private var modelContext

    // Tab selection with persistence
    @AppStorage("selectedTab") private var selectedTab = 0

    // Query DM conversations for unread badge count
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            !conversation.isGroup && !conversation.isArchived
        }
    ) private var dmConversations: [ConversationEntity]

    // MARK: - Initialization

    /// Initializer for MainTabView
    /// Note: @Query properties don't need to be passed as parameters
    init() {
        // SwiftData @Query is automatically initialized by the system
    }

    // MARK: - Computed Properties

    /// Total unread count for Inbox/DMs tab
    var inboxUnreadCount: Int {
        dmConversations.reduce(0) { $0 + $1.unreadCount }
    }

    /// Check if current user is creator
    var isCreator: Bool {
        authViewModel.currentUser?.isCreator ?? false
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Channels (Everyone)
            NavigationStack {
                ChannelsView()
            }
            .tabItem {
                Label("Channels", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            // Tab 2: Inbox (Creator) or DMs (Fan)
            NavigationStack {
                if isCreator {
                    InboxView()
                } else {
                    FanDMView()
                }
            }
            .tabItem {
                Label(
                    isCreator ? "Inbox" : "DMs",
                    systemImage: isCreator ? "tray" : "message"
                )
            }
            .badge(inboxUnreadCount > 0 ? inboxUnreadCount : 0)
            .tag(1)

            // Tab 3: Profile (Everyone)
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(2)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor.shared)
}
