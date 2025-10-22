/// RootView.swift
/// Root view that handles authentication state and conditional navigation
/// [Source: Epic 1, Story 1.3]
///
/// This view serves as the entry point for the app after launch.
/// It checks for persistent authentication and routes to either
/// the login screen or main app based on auth status.

import SwiftUI
import SwiftData

struct RootView: View {
    // MARK: - Properties

    @EnvironmentObject private var authViewModel: AuthViewModel

    // MARK: - Body

    var body: some View {
        Group {
            if authViewModel.isLoading {
                // Loading state during auth check
                LoadingView()
            } else if authViewModel.isAuthenticated {
                // User authenticated - show main app
                ConversationListView()
            } else {
                // User not authenticated - show login
                LoginView()
            }
        }
        .task {
            // Check auth status on app launch
            await authViewModel.checkAuthStatus()
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

// MARK: - Temporary Placeholder

/// Temporary placeholder for conversation list (to be implemented in later stories)
struct ConversationListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Buzzbox")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Logged in successfully!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let user = authViewModel.currentUser {
                    VStack(spacing: 8) {
                        Text("Email: \(user.email)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text("Username: @\(user.displayName)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Text("Conversation list coming soon...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
}
