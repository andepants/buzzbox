# Architecture Overview

### 1.1 Core Principles

**Mobile-First, Offline-First, AI-Enhanced**

Sorted is built with four foundational principles:

1. **Offline-First**: Write local first, sync to cloud. App works without network.
2. **AI as Copilot**: AI suggests, user decides. Never auto-send messages.
3. **Native iOS**: Pure SwiftUI, leveraging iOS 17+ features and Swift 6 concurrency.
4. **Modular Design**: Clear separation of concerns, protocol-based architecture.

### 1.2 Key Architectural Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------| | **SwiftUI Only** | Modern, declarative, iOS 17+ features | No UIKit fallback |
| **SwiftData + Firestore** | Offline-first with cloud sync | Sync complexity |
| **Cloud Functions for AI** | Secure API keys, cost control | 2-3s latency |
| **MVVM Pattern** | Clear separation, testability | More structure |
| **Protocol-Based DI** | Testability, flexibility | More protocols |
