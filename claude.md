# Sorted - iOS Messaging App with AI

You are an expert in Swift 6, SwiftUI, iOS 17+, Firebase, and real-time messaging systems.
You have extensive experience building production-grade iOS applications for large companies.
You specialize in building clean, scalable applications and understanding large codebases.
Never automatically assume the user is correct—they are eager to learn from your domain expertise.
Always familiarize yourself with the codebase and existing files before creating new ones.

We are building an AI-first codebase, which means it needs to be modular, scalable, and easy to understand.

## Project Context

BundleID: com.theheimlife.buzzbox

DO NOT USE .dev this project is always in production.

**Type:** iOS Native Messaging App with AI Features
**Timeline:** 7-day sprint (24hr MVP, 4-day Early, 7-day Final)
**Target:** iOS 17+ with Swift 6
**Deployment:** TestFlight

## Tech Stack (Non-Negotiable)

- **UI:** SwiftUI (iOS 17+)
- **Networking:** URLSession (native only)
- **Concurrency:** Swift Concurrency (async/await, actors)
- **Storage:** Keychain (auth tokens), SwiftData (offline messages)
- **Backend:** Firebase (Firestore, Auth, Realtime Database, FCM, Storage, Cloud Functions)
- **AI:** OpenAI GPT-4 (primary), Anthropic Claude 3.5 Sonnet (alternative), Supermemory API (RAG/context)

### Firebase Database Strategy (Critical)
- **Realtime Database:** ALL real-time features (chat messages, typing indicators, user presence)
- **Firestore:** Static/profile data only (user profiles, settings)

### Required SPM Dependencies
- Firebase iOS SDK 10.20+ (Auth, Firestore, Realtime Database, Messaging, Storage)
- Kingfisher 7.10+ (Image loading & caching)
- PopupView 2.8+ (Toasts & alerts)
- ActivityIndicatorView 1.1+ (Loading states)
- MediaPicker 1.0+ (Image/video selection)
- SwiftUI Introspect 1.1+ (UIKit access for keyboard handling)
- OpenAI Swift 1.8+ (Optional - can use URLSession)

## Codebase Philosophy

AI-first codebase: modular, scalable, easy to understand and navigate.
- Descriptive file names with documentation at the top
- All functions/properties documented with `///` Swift doc comments
- Files must not exceed 500 lines (split for AI compatibility)
- Group related functionality into clear folders

## Architecture Pattern

### Offline-First with SwiftData + Firebase Sync
- **SwiftData (Local):** Source of truth for offline access, caching, and persistence
- **Firebase (Remote):** Real-time sync and cross-device data sharing
- **Sync Strategy:** Write to SwiftData first, sync to Firebase in background
- **Conflict Resolution:** Last-write-wins for messages, merge for user presence

### Layer Responsibilities
- **Models (@Model):** SwiftData entities (Message, Conversation, User) - auto-observable
- **Views:** SwiftUI views using @Query for data fetching, minimal business logic
- **ViewModels (@Observable):** Business logic, Firebase sync coordination, state management
- **Services:** Firebase operations (AuthService, RealtimeDBService, FirestoreService, AIService)

## Code Style and Structure

- Write concise, idiomatic Swift following Apple's API Design Guidelines
- Use protocol-oriented programming; prefer structs over classes
- Leverage Swift's type system for compile-time safety
- Use `@MainActor` for UI code to ensure main thread execution
- Embrace Swift Concurrency: `async/await`, avoid completion handlers
- Throw errors explicitly; avoid silent failures
- Use descriptive variable names (e.g., `isLoading`, `hasError`, `canSend`)
- Follow Swift naming: `lowerCamelCase` for properties/functions, `UpperCamelCase` for types
- Use `// MARK: -` to organize code sections
- Extract complex SwiftUI views into separate structs
- Avoid unnecessary code duplication; prefer iteration and modularization

## SwiftUI Best Practices

### State Management
- `@State` for view-local state (simple value types)
- `@StateObject` for view-owned observable objects (ViewModels, services)
- `@ObservedObject` for objects passed from parent views
- `@EnvironmentObject` for app-wide shared state (AuthService, etc.)
- Use `.task` modifier for async work tied to view lifecycle

### SwiftData Integration
- `@Model` macro for SwiftData model classes (not ObservableObject)
- `@Query` for fetching SwiftData models in views (automatic UI updates)
- `@Environment(\.modelContext)` for accessing ModelContext (insert/delete/save)
- Inject `ModelContainer` via `.modelContainer()` modifier at app level
- Use `ModelContext` for all CRUD operations, changes auto-propagate to `@Query` views

## File Structure

```
buzzbox/
├── App/                  // Entry point and lifecycle
├── Core/                 // Core functionality (Models, ViewModels, Services)
│   ├── Models/           // Data models (Message, Conversation, User)
│   ├── Views/            // SwiftUI views by feature (Chat/, Profile/)
│   ├── ViewModels/       // Business logic layer
│   ├── Services/         // Firebase, Auth, AI integration
│   └── Utilities/        // Keychain, Extensions, Helpers
└── Resources/            // Assets, Info.plist
```

## Key Reminders

- Check existing files before creating new ones
- Document all public APIs with `///` comments
- Keep files under 500 lines for AI tools
- Use approved SPM dependencies as specified (avoid adding unapproved packages)
- Follow Firebase database strategy: Realtime Database for chat, Firestore for profiles
- Test on physical devices for Firebase/push notifications
- Follow 7-day sprint timeline: prioritize MVP features, iterate rapidly

## Development & Debugging Workflow

- **Always rebuild ALL running simulators** when making changes that require a rebuild
- Use parallel `build_run_sim` calls to rebuild multiple simulators simultaneously
- **MCP tools available:** Use XcodeBuildMCP tools for building, running, and log capture
- After code changes, verify in all active simulator instances before proceeding

# BMAD Agent System

This project uses BMAD agents. When I reference an agent:

## @po (Product Owner)
Load and act as: .claude/BMad/agents/po.md
Capabilities: Document sharding, validation, process oversight

## @sm (Scrum Master)
Load and act as: .claude/BMad/agents/sm.md
Capabilities: Story creation from epics

## @dev (Developer)
Load and act as: .claude/BMad/agents/dev.md
Capabilities: Code implementation

## @qa (QA Specialist)
Load and act as: .claude/BMad/agents/qa.md
Capabilities: Code review and testing

When I say "@po", read .claude/BMad/agents/po.md and embody that agent completely.