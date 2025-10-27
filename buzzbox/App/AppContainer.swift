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
            FAQEntity.self,
            PendingMemory.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ [APP CONTAINER] ModelContainer created successfully")
        } catch {
            // If schema migration fails, try to delete and recreate
            print("⚠️ [APP CONTAINER] ModelContainer creation failed, attempting recovery...")
            print("    └─ Error: \(error.localizedDescription)")

            // Try to get the default store URL and delete it
            let url = modelConfiguration.url
            do {
                try FileManager.default.removeItem(at: url)
                print("    └─ Deleted corrupted database at: \(url.path)")
            } catch {
                print("    └─ Could not delete database: \(error.localizedDescription)")
            }

            // Try again with fresh database
            do {
                self.modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("    └─ ✅ ModelContainer recreated successfully")
            } catch {
                // ⚠️ CRITICAL FIX: Don't use fatalError - create an in-memory fallback
                print("    └─ ❌ Failed to recreate ModelContainer, using in-memory fallback")
                print("    └─ Error: \(error.localizedDescription)")

                // Create in-memory container as last resort
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )

                do {
                    self.modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [memoryConfig]
                    )
                    print("    └─ ✅ In-memory ModelContainer created (data will not persist)")
                } catch {
                    // This should never happen with in-memory, but if it does, we have no choice
                    fatalError("❌ FATAL: Could not create even in-memory ModelContainer: \(error)")
                }
            }
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
