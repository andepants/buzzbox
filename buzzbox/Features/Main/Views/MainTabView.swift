/// MainTabView.swift
///
/// Main tab navigation with conditional tabs based on user type
/// Fans see: Channels | DMs | Profile
/// Creator sees: Channels | Inbox | Profile
///
/// Created: 2025-10-22
/// [Source: Story 5.6 - Simplified Navigation]
/// [Updated: Deep link navigation for push notifications]

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

    // Navigation state for deep linking
    @State private var dmNavigationPath = NavigationPath()
    @State private var channelsNavigationPath = NavigationPath()

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
            NavigationStack(path: $channelsNavigationPath) {
                ChannelsView()
                    .navigationDestination(for: ConversationEntity.self) { conversation in
                        MessageThreadView(conversation: conversation)
                    }
            }
            .tabItem {
                Label("Channels", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            // Tab 2: Inbox (Creator) or DMs (Fan)
            NavigationStack(path: $dmNavigationPath) {
                if isCreator {
                    InboxView()
                } else {
                    FanDMView()
                }
            }
            .navigationDestination(for: ConversationEntity.self) { conversation in
                MessageThreadView(conversation: conversation)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenConversation"))) { notification in
            handleDeepLink(notification: notification)
        }
    }

    // MARK: - Deep Linking

    /// Handles deep link when user taps push notification
    /// Switches to the DMs tab where the user can tap the conversation
    /// Note: Simplified to avoid UI freeze from complex navigation + async operations
    private func handleDeepLink(notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo,
              let conversationID = userInfo["conversationID"] as? String else {
            return
        }


        // Simply switch to DMs tab
        // User can then tap the conversation from the list
        selectedTab = 1

        // Note: We don't automatically navigate to the conversation to avoid:
        // 1. UI freeze from multiple async operations in MessageThreadView.task
        // 2. Complex state management issues
        // 3. Race conditions between navigation and data loading
        // The conversation will be visible in the list for the user to tap
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
        .environmentObject(AuthViewModel())
        .environmentObject(NetworkMonitor.shared)
}
