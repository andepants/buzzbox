/// AppContainer.swift
///
/// Singleton container for app-wide ModelContext access
/// Provides centralized SwiftData container management
///
/// Created: 2025-10-21
/// [Source: Story 2.1 - Create New Conversation, Epic 2 Pattern 1]

import Foundation
import SwiftData

/// Singleton container for app-wide ModelContext and ModelContainer access
@MainActor
final class AppContainer {
    // MARK: - Properties

    static let shared = AppContainer()

    /// Shared ModelContainer for SwiftData
    let modelContainer: ModelContainer

    /// Main actor model context for UI operations
    var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    private init() {
        let schema = Schema([
            MessageEntity.self,
            ConversationEntity.self,
            UserEntity.self,
            AttachmentEntity.self,
            FAQEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ AppContainer initialized successfully")
        } catch {
            fatalError("❌ Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Creates a new background context for async operations
    /// - Returns: New ModelContext for background operations
    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        return context
    }
}
