# System Architecture

### 3.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      iOS App (Swift 6)                          │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  SwiftUI Views (Passive UI)                              │  │
│  │  - ConversationListView, MessageThreadView, etc.         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓ @StateObject                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ViewModels (@MainActor, ObservableObject)               │  │
│  │  - Manage @Published state, handle user actions          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓ Protocol Injection                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Service Layer (async/await)                             │  │
│  │  - AuthService, MessagingService, AIService, etc.        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Repository Layer (Data Source Abstraction)              │  │
│  │  - Sync SwiftData ↔ Firestore                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│         ↓                                    ↓                  │
│  ┌──────────────┐                  ┌──────────────────┐        │
│  │  SwiftData   │                  │  URLSession      │        │
│  │  (Local)     │                  │  (Network)       │        │
│  └──────────────┘                  └──────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Firebase Backend (GCP)                        │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Firebase   │  │  Firestore   │  │   Firebase   │         │
│  │     Auth     │  │  (NoSQL DB)  │  │   Storage    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                           ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        Cloud Functions (Node.js 18)                      │  │
│  │  - onMessageCreated (auto-categorization)                │  │
│  │  - generateSmartReply (context-aware drafts)             │  │
│  │  - detectFAQ (FAQ matching)                              │  │
│  │  - analyzeSentiment (emotional analysis)                 │  │
│  │  - scoreOpportunity (business value scoring)             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          External AI Services                            │  │
│  │  - OpenAI API (GPT-4)                                    │  │
│  │  - Supermemory API (RAG for conversation context)        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Component Responsibilities

| Layer | Responsibility | Technology |
|-------|----------------|------------|
| **Views** | Render UI, capture user input | SwiftUI |
| **ViewModels** | Manage state, orchestrate services | @MainActor, Combine |
| **Services** | Business logic, API calls | async/await, URLSession |
| **Repository** | Data abstraction, sync logic | SwiftData, Firestore |
| **SwiftData** | Local persistence, offline storage | SwiftData |
| **Firestore** | Real-time cloud database | Firebase Firestore |
| **Cloud Functions** | AI processing, serverless logic | Node.js, OpenAI |
| **FCM** | Push notifications | Firebase Cloud Messaging |
