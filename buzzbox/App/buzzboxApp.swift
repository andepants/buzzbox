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
@main
struct buzzboxApp: App {
    // MARK: - Properties

    @Environment(\.scenePhase) private var scenePhase
    @State private var lastActiveDate = Date()
    @State private var showPrivacyOverlay = false
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
                    .environmentObject(authViewModel)
                    .environmentObject(networkMonitor)
                    .onAppear {
                        // ✅ Set user online when app launches
                        // [Source: Story 2.8 - User Presence & Online Status]
                        Task { @MainActor in
                            UserPresenceService.shared.setOnline()
                        }
                    }

                // Privacy overlay when app backgrounds
                if showPrivacyOverlay {
                    PrivacyOverlayView()
                }
            }
            .modelContainer(sharedModelContainer)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    // MARK: - Lifecycle Handling

    /// Handles app lifecycle transitions
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            showPrivacyOverlay = false

            // Refresh auth token if needed (if > 1 hour in background)
            Task {
                await authViewModel.refreshAuthIfNeeded(lastActiveDate: lastActiveDate)
            }

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
