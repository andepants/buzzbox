/// RootView.swift
/// Root view that handles authentication state and conditional navigation
/// [Source: Epic 1, Story 1.3]
/// [Source: Story 2.0B, 3.7 - Added deep linking for push notifications]
///
/// This view serves as the entry point for the app after launch.
/// It checks for persistent authentication and routes to either
/// the login screen or main app based on auth status.
///
/// Handles deep linking when user taps push notifications:
/// - Observes "OpenConversation" notification from AppDelegate
/// - Fetches ConversationEntity by ID
/// - Presents MessageThreadView for that conversation

import SwiftUI
import SwiftData

struct RootView: View {
    // MARK: - Properties

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    // Navigation state for deep linking
    @State private var selectedConversation: ConversationEntity?
    @State private var showMessageThread = false

    // MARK: - Body

    var body: some View {
        Group {
            if authViewModel.isLoading {
                // Loading state during auth check
                LoadingView()
            } else if authViewModel.isAuthenticated {
                // User authenticated - show main app with tab navigation
                MainTabView()
                    .sheet(isPresented: $showMessageThread) {
                        if let conversation = selectedConversation {
                            MessageThreadView(conversation: conversation)
                        }
                    }
            } else {
                // User not authenticated - show login
                LoginView()
            }
        }
        .task {
            // Check auth status on app launch
            await authViewModel.checkAuthStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenConversation"))) { notification in
            // Handle deep link from push notification
            handleDeepLink(notification: notification)
        }
    }

    // MARK: - Deep Linking

    /// Handles deep link when user taps push notification
    /// Fetches conversation by ID and presents MessageThreadView
    private func handleDeepLink(notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo,
              let conversationID = userInfo["conversationID"] as? String else {
            print("⚠️ No conversationID in notification userInfo")
            return
        }

        print("📱 Handling deep link for conversation: \(conversationID)")

        // Fetch conversation from SwiftData
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate<ConversationEntity> { conv in
                conv.id == conversationID
            }
        )

        do {
            if let conversation = try modelContext.fetch(descriptor).first {
                // Present MessageThreadView
                selectedConversation = conversation
                showMessageThread = true
                print("✅ Opening conversation: \(conversation.displayName ?? conversation.id)")
            } else {
                print("⚠️ Conversation not found: \(conversationID)")
            }
        } catch {
            print("❌ Failed to fetch conversation: \(error.localizedDescription)")
        }
    }
}

// MARK: - Loading View

/// Loading view shown during auth check on app launch
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // App logo/branding
                Image(systemName: "envelope.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Note: ConversationListView is now implemented in Features/Chat/Views/ConversationListView.swift

// MARK: - Preview

#Preview {
    RootView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
}
