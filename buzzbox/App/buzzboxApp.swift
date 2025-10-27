//
//  buzzboxApp.swift
//  buzzbox
//
//  Created by Andrew Heim on 10/21/25.
//

import SwiftUI
import SwiftData
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
import FirebaseDatabase

/// Main entry point for the Buzzbox app
/// Configured for Swift 6, iOS 17+, with SwiftData persistence
/// [Source: Epic 1, Story 1.3 - Added RootView and scenePhase handling]
/// [Source: Story 2.0B, 3.7 - Added AppDelegate for push notifications]
@main
struct buzzboxApp: App {
    // MARK: - Properties

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastActiveDate = Date()
    @State private var showPrivacyOverlay = false
    @State private var appearanceSettings = AppearanceSettings()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared

    // MARK: - Initialization

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
    }

    // MARK: - SwiftData Container

    /// Uses AppContainer singleton for centralized ModelContext access
    /// [Source: Story 2.1 - Create New Conversation]
    var sharedModelContainer: ModelContainer {
        AppContainer.shared.modelContainer
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .preferredColorScheme(appearanceSettings.mode.colorScheme)
                    .environment(appearanceSettings)
                    .environmentObject(authViewModel)
                    .environmentObject(networkMonitor)

                // Privacy overlay when app backgrounds
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                }
            }
            .modelContainer(sharedModelContainer)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onAppear {
                // Configure SupermemoryService with ModelContext (Story 9.4)
                SupermemoryService.shared.configure(
                    modelContext: AppContainer.shared.mainContext
                )
            }
        }
    }

    // MARK: - Lifecycle Handling

    /// Handles app lifecycle transitions
    /// Note: Service lifecycle is now managed in MainTabView (authenticated area only)
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            showPrivacyOverlay = false

            // Refresh auth token if needed (if > 1 hour in background)
            Task {
                await authViewModel.refreshAuthIfNeeded(lastActiveDate: lastActiveDate)
            }

            // Process pending Supermemory memories (Story 9.4)
            Task {
                await SupermemoryService.shared.processPendingMemories()
            }

            // COMMENTED OUT: FCM token refresh (APNs/FCM disabled to prevent duplicate notifications)
            // Ensure FCM token is registered (helps with existing users)
            // appDelegate.refreshFCMToken()

            lastActiveDate = Date()

        case .inactive:
            // App becoming inactive (e.g., system dialog shown)
            showPrivacyOverlay = true

        case .background:
            // App moved to background
            showPrivacyOverlay = true

        @unknown default:
            break
        }
    }
}
