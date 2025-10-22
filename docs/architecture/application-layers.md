# Application Layers

### 5.1 MVVM Architecture

```
View Layer (SwiftUI)
  ↓ @StateObject / @ObservedObject
ViewModel Layer (@MainActor)
  ↓ Protocol Injection
Service Layer (async/await)
  ↓ Data Operations
Repository Layer (SwiftData + Firestore)
  ↓ Local + Remote
Data Layer (Models)
```

**View Layer:**
- Pure SwiftUI views, no business logic
- Subscribe to ViewModel via `@Published` properties
- Send user actions to ViewModel methods
- Never access Services or Repositories directly

**ViewModel Layer:**
- Annotated with `@MainActor` for UI thread safety
- Conform to `ObservableObject`
- Manage UI state with `@Published` properties
- Orchestrate Service layer calls
- Transform Model data for Views

**Service Layer:**
- Protocol-based for testability
- Use async/await for all operations
- Handle errors, retries, rate limiting
- Call Repository layer for data

**Repository Layer:**
- Abstract SwiftData and Firestore
- Manage sync between local and remote
- Handle offline queue
- Conflict resolution

**Model Layer:**
- Sendable structs for Swift 6 concurrency
- Codable for Firestore
- SwiftData `@Model` classes for persistence

### 5.2 Dependency Injection Pattern

All services use protocol-based dependency injection:

- Define protocol (e.g., `MessagingServiceProtocol`)
- ViewModel accepts protocol in initializer with default production implementation
- Tests inject mock implementations
- Enables parallel development and comprehensive testing

### 5.3 Navigation

- **NavigationStack** (iOS 17+) for conversation → message thread navigation
- **Sheet presentation** for modals (new message, settings, FAQs)
- **TabView** for bottom navigation (All Messages, Priority, Business, Profile)
- **Deep linking** via URL schemes for push notification handling
