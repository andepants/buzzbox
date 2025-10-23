/// RootView.swift
/// Root view that handles authentication state and conditional navigation
/// [Source: Epic 1, Story 1.3]
/// [Updated: Deep linking now handled in MainTabView for better navigation integration]
///
/// This view serves as the entry point for the app after launch.
/// It checks for persistent authentication and routes to either
/// the login screen or main app based on auth status.

import SwiftUI
import SwiftData

struct RootView: View {
    // MARK: - Properties

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        Group {
            if authViewModel.isLoading {
                // Loading state during auth check
                LoadingView()
            } else if authViewModel.isAuthenticated {
                // User authenticated - show main app with tab navigation
                // MainTabView now handles deep linking internally
                MainTabView()
            } else {
                // User not authenticated - show login
                LoginView()
            }
        }
        .notificationBanner() // Show in-app notification banners
        .task {
            // Check auth status on app launch and sync to SwiftData
            await authViewModel.checkAuthStatus(modelContext: modelContext)
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
