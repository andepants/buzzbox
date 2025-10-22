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

/// Main entry point for the Buzzbox app
/// Configured for Swift 6, iOS 17+, with SwiftData persistence
@main
struct buzzboxApp: App {

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
        print("   Project ID: \(FirebaseApp.app()?.options.projectID ?? "unknown")")
        print("   Bundle ID: \(FirebaseApp.app()?.options.bundleID ?? "unknown")")
    }

    var sharedModelContainer: ModelContainer = {
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
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ SwiftData ModelContainer initialized successfully")
            print("   Entities: MessageEntity, ConversationEntity, UserEntity, AttachmentEntity, FAQEntity")
            return container
        } catch {
            fatalError("❌ Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
