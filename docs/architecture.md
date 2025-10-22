# Sorted - High-Level Technical Architecture

**Version:** 1.0
**Last Updated:** October 20, 2025
**Project Type:** iOS Native AI-Powered Messaging App
**Timeline:** 7-Day Sprint (MVP → Early → Final)
**Target:** iOS 17+ with Swift 6, TestFlight Deployment

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture](#3-system-architecture)
4. [Data Architecture](#4-data-architecture)
5. [Application Layers](#5-application-layers)
6. [AI Integration Architecture](#6-ai-integration-architecture)
7. [Offline-First Strategy](#7-offline-first-strategy)
8. [Security Architecture](#8-security-architecture)
9. [Deployment Architecture](#9-deployment-architecture)
10. [Performance & Scalability](#10-performance--scalability)

---

## 1. Architecture Overview

### 1.1 Core Principles

**Mobile-First, Offline-First, AI-Enhanced**

Sorted is built with four foundational principles:

1. **Offline-First**: Write local first, sync to cloud. App works without network.
2. **AI as Copilot**: AI suggests, user decides. Never auto-send messages.
3. **Native iOS**: Pure SwiftUI, leveraging iOS 17+ features and Swift 6 concurrency.
4. **Modular Design**: Clear separation of concerns, protocol-based architecture.

### 1.2 Key Architectural Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **SwiftUI Only** | Modern, declarative, iOS 17+ features | No UIKit fallback |
| **SwiftData + Firestore** | Offline-first with cloud sync | Sync complexity |
| **Cloud Functions for AI** | Secure API keys, cost control | 2-3s latency |
| **MVVM Pattern** | Clear separation, testability | More structure |
| **Protocol-Based DI** | Testability, flexibility | More protocols |

---

## 2. Technology Stack

### 2.1 iOS Technologies (Non-Negotiable)

```
Language:           Swift 6
UI Framework:       SwiftUI (iOS 17+)
Concurrency:        Swift Concurrency (async/await, @MainActor)
Local Database:     SwiftData
Secure Storage:     Keychain Services
Networking:         URLSession
Package Manager:    Swift Package Manager (SPM)
Min iOS Version:    iOS 17.0
```

### 2.2 Backend Services (Firebase)

```
Authentication:     Firebase Auth
Database:           Cloud Firestore (Real-time NoSQL)
Push Notifications: Firebase Cloud Messaging (FCM)
Storage:            Firebase Storage (Media files)
Serverless:         Cloud Functions (Node.js 18)
Analytics:          Firebase Analytics
Crash Reporting:    Firebase Crashlytics
```

### 2.3 AI Services

```
Primary AI:         OpenAI GPT-4 (via Cloud Functions)
Alternative:        Anthropic Claude 3.5 Sonnet
RAG System:         Supermemory API (conversation context)
Vector DB:          Built into Supermemory
Embeddings:         OpenAI text-embedding-3-small
```

### 2.4 Required Dependencies (SPM)

```
Firebase iOS SDK 10.20+    (Auth, Firestore, Messaging, Storage)
Kingfisher 7.10+           (Image loading & caching)
PopupView 2.8+             (Toasts & alerts)
ActivityIndicatorView 1.1+ (Loading states)
MediaPicker 1.0+           (Image/video selection)
SwiftUI Introspect 1.1+    (UIKit access for keyboard handling)
OpenAI Swift 1.8+          (Optional - can use URLSession)
```

---

## 3. System Architecture

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

---

## 4. Data Architecture

### 4.1 Core Data Models

**User**
- id, email, displayName, photoURL
- aiPreferences (toggles for AI features)
- faqs (FAQ library for creator)
- createdAt, updatedAt

**Conversation**
- id, participantIDs, participants
- lastMessage, unreadCount
- isPinned, isMuted
- createdAt, updatedAt

**Message**
- id, conversationID, senderID, sender
- text, attachments, status
- AI Metadata: category, sentiment, opportunityScore, faqMatch, smartReplyDraft
- Sync Metadata: syncStatus, retryCount
- readBy (read receipts)
- createdAt, updatedAt

**Attachment**
- id, type (image/video/audio/document)
- url (remote), localURL, thumbnailURL
- fileSize, mimeType, uploadStatus

### 4.2 SwiftData Schema

SwiftData uses `@Model` classes for local persistence:

- **UserEntity**: Local user data and preferences
- **ConversationEntity**: Conversation metadata, relationships to messages
- **MessageEntity**: Message content, AI metadata, sync status
- **AttachmentEntity**: Media files with upload tracking
- **FAQEntity**: FAQ library for auto-responder feature

**Relationships:**
- UserEntity → [ConversationEntity] (one-to-many)
- UserEntity → [FAQEntity] (one-to-many)
- ConversationEntity → [MessageEntity] (one-to-many, cascade delete)
- MessageEntity → [AttachmentEntity] (one-to-many, cascade delete)

**Implementation Details:**
📖 See [SwiftData Implementation Guide](./swiftdata-implementation-guide.md) for:
- Complete @Model entity code with all properties and relationships
- ModelContainer setup in App.swift
- @Query examples in ViewModels and Views
- Background sync coordinator patterns

### 4.3 Firestore Schema

**Collections Structure:**

```
/users/{userId}
  - User profile data
  - AI preferences
  - FAQ library

/users/{userId}/conversations/{conversationId}
  - User's conversation metadata
  - Last message preview
  - Unread count

/conversations/{conversationId}
  - Shared conversation data
  - participantIDs

/conversations/{conversationId}/messages/{messageId}
  - Message content
  - AI metadata (category, sentiment, etc.)
  - Read receipts

/conversations/{conversationId}/participants/{userId}
  - Participant join timestamp
  - Last read message ID
  - Notification preferences
```

**Security Rules:**
- Users can only read/write their own data
- Conversation access requires being a participant
- Messages readable only by conversation participants
- Server-side validation via Cloud Functions

### 4.4 SwiftData ↔ Firestore Sync Strategy

**Write Path (Optimistic UI):**
1. User action (send message) → Write to SwiftData immediately
2. Display message instantly in UI (optimistic update)
3. Mark message as `syncStatus: .pending`
4. Attempt Firestore sync in background
5. Update `syncStatus: .synced` on success, `.failed` on error

**Read Path (Cache-First):**
1. Fetch from SwiftData first (instant, works offline)
2. If online, fetch from Firestore in background
3. Update SwiftData cache with Firestore data
4. SwiftData change notifications trigger UI updates

**Conflict Resolution:** Last-write-wins based on server timestamp.

**Offline Queue:**
- Messages with `syncStatus: .pending` are queued
- BackgroundSyncService monitors network status
- When online, process queue with exponential backoff retries
- Max 3 retry attempts before marking as failed

---

## 5. Application Layers

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

---

## 6. AI Integration Architecture

### 6.1 AI Feature Flow

**Automatic (Triggered):**
1. User sends/receives message → Firestore write
2. Cloud Function trigger: `onMessageCreated`
3. Auto-categorize message (Fan/Business/Spam/Urgent)
4. If Business: Auto-score opportunity (0-100)
5. Update Firestore message document with AI metadata
6. Real-time listener in iOS app receives update
7. UI automatically displays category badge and score

**On-Demand (Callable):**
1. User taps "Draft Reply" button
2. iOS app calls Cloud Function: `generateSmartReplyCallable`
3. Cloud Function fetches context from Supermemory (RAG)
4. Cloud Function fetches creator's writing style from Firestore
5. Build prompt with context + style, call OpenAI GPT-4
6. Return generated draft to iOS app
7. Display draft in editable card, user can edit/send/dismiss

### 6.2 Cloud Functions Architecture

**5 Core Functions:**

1. **onMessageCreated** (Triggered)
   - Auto-categorize: Fan/Business/Spam/Urgent
   - If Business: Score opportunity
   - Update message document
   - Execution: ~2 seconds

2. **generateSmartReplyCallable** (Callable)
   - Fetch context from Supermemory
   - Fetch creator's voice patterns
   - Generate personalized reply via GPT-4
   - Execution: ~3 seconds

3. **detectFAQCallable** (Callable)
   - Match incoming message to FAQ library
   - Return suggested answer if confidence > 70%
   - Execution: ~2 seconds

4. **analyzeSentimentCallable** (Callable)
   - Analyze emotional tone (positive/negative/urgent/neutral)
   - Determine intensity (low/medium/high)
   - Execution: ~2 seconds

5. **scoreOpportunityCallable** (Callable)
   - Score business messages (0-100)
   - Breakdown: monetary value, brand fit, legitimacy, urgency
   - Execution: ~3 seconds

**Environment Variables:**
- `OPENAI_API_KEY`: Stored in Cloud Functions config (never in iOS app)
- `SUPERMEMORY_API_KEY`: Stored in Cloud Functions config
- `FIREBASE_*`: Admin SDK credentials

### 6.3 RAG Pipeline (Supermemory)

**Context Retrieval:**
- iOS app stores conversations to Supermemory periodically
- When generating smart reply, Cloud Function queries Supermemory
- Vector search returns top 5 relevant past conversation snippets
- Snippets provide context for personalized AI responses

**Storage Strategy:**
- Store after every 10 messages in a conversation
- Store when conversation is archived or completed
- Privacy: User can disable Supermemory storage in settings

**Implementation Details:**
📖 See [Supermemory Integration Guide](./supermemory-integration-guide.md) for:
- Authentication setup with Bearer tokens
- Cloud Functions for automatic message storage
- RAG query implementation for smart replies
- Error handling with retry strategies
- Privacy controls and data deletion patterns

### 6.4 AI Cost Optimization

- **Caching:** Cache AI responses for similar messages (7-day TTL)
- **Rate Limiting:** 100 AI requests per user per hour
- **Model Selection:** GPT-3.5-turbo for categorization, GPT-4 for smart replies
- **Selective Processing:** Only run expensive features on-demand
- **Prompt Optimization:** Keep prompts concise, use function calling

---

## 7. Offline-First Strategy

### 7.1 Offline Architecture

**Core Principle:** App works seamlessly without network. Users never see errors or blocked actions.

**Write Operations:**
1. User action → Write to SwiftData immediately
2. Display change instantly (optimistic UI)
3. Queue for background sync
4. Sync when network available
5. Update UI with final status

**Read Operations:**
1. Read from SwiftData first (instant)
2. Fetch from Firestore in background if online
3. Update SwiftData cache
4. UI updates automatically via SwiftData observation

**Network Monitoring:**
- Continuously monitor network status with `NWPathMonitor`
- Display offline banner when disconnected
- Trigger sync queue processing when connection restored

**Sync Queue:**
- All pending operations stored in SwiftData with `syncStatus: .pending`
- BackgroundSyncService processes queue when online
- Exponential backoff for failed sync attempts
- Max 3 retries before marking as failed

**Conflict Resolution:**
- Last-write-wins based on Firestore server timestamp
- Local changes always take precedence until synced
- If sync fails after 3 attempts, show user error with retry option

### 7.2 Offline UI Indicators

- **Message Status:** Sending (clock) → Sent (single check) → Delivered (double check)
- **Offline Banner:** "Offline - Messages will sync when connected"
- **Failed Messages:** Red exclamation mark, tap to retry
- **Sync Queue:** Badge showing number of pending messages

---

## 8. Security Architecture

### 8.1 Security Layers

**Layer 1: Transport Security**
- All network traffic over TLS/SSL
- Certificate pinning (optional future enhancement)

**Layer 2: Authentication**
- Firebase Auth with email/password
- JWT tokens for API authentication
- Token refresh flow (tokens expire after 1 hour)
- Tokens stored in iOS Keychain (secure enclave)

**Layer 3: Authorization**
- Firestore Security Rules enforce access control
- Users can only read/write their own data
- Conversation access requires participant verification
- Cloud Functions validate user permissions

**Layer 4: Data Security**
- Keychain for auth tokens
- SwiftData encryption at rest (iOS built-in)
- Firestore encryption at rest (Google managed)

**Layer 5: API Key Security**
- OpenAI/Supermemory API keys NEVER in iOS app
- Keys stored in Cloud Functions environment variables
- Keys rotated quarterly
- Usage monitored for anomalies

### 8.2 Input Sanitization

- Limit message length (10,000 characters)
- Strip control characters
- Validate email format
- Validate password strength (8+ characters)
- Sanitize AI prompts to prevent injection attacks

### 8.3 Privacy Considerations

- Messages stored locally in SwiftData (encrypted by iOS)
- Supermemory storage opt-in (user can disable)
- Clear data deletion (account deletion removes all Firestore data)
- GDPR compliant (data export/deletion on request)

---

## 9. Deployment Architecture

### 9.1 Environment Strategy

**Three Environments:**

| Environment | Purpose | Firebase Project | TestFlight | Users |
|-------------|---------|------------------|------------|-------|
| **Development** | Local dev | sorted-dev | No | Developers |
| **Staging** | Internal testing | sorted-staging | Internal | Team |
| **Production** | Live app | sorted-prod | External → App Store | End users |

**Development:**
- Firebase emulators for Auth, Firestore, Functions
- Mock AI responses (no actual OpenAI calls)
- Hot reload, fast iteration

**Staging:**
- Real Firebase backend (staging project)
- Real AI with rate limits (50 req/user/hour)
- Internal TestFlight distribution
- Team testing, bug fixes

**Production:**
- Production Firebase project
- Full AI access (100 req/user/hour)
- External TestFlight → App Store
- Real users

### 9.2 Build Configurations

**Xcode Schemes:**
- Sorted-Dev (Debug build, emulators)
- Sorted-Staging (Release build, staging Firebase)
- Sorted-Production (Release build, production Firebase)

**Bundle IDs:**
- Development: `com.sorted.app.dev`
- Staging: `com.sorted.app.staging`
- Production: `com.sorted.app`

### 9.3 TestFlight Distribution

**Day 7 Deployment:**
1. Archive build in Xcode
2. Upload to App Store Connect
3. Add to TestFlight (Internal Testing first)
4. Write release notes
5. Add testers (up to 100 internal, 10,000 external)
6. Submit for Beta App Review (external testing)

**TestFlight Groups:**
- Internal: Team members, immediate access
- External: Beta testers, requires Beta App Review (~24-48 hours)

### 9.4 Cloud Functions Deployment

Deploy via Firebase CLI:
```bash
firebase deploy --only functions --project sorted-prod
```

Set environment variables:
```bash
firebase functions:config:set openai.api_key="sk-..." --project sorted-prod
```

---

## 10. Performance & Scalability

### 10.1 Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| App Launch (Cold) | < 2s | < 3s |
| Message Send (Optimistic) | < 100ms | < 200ms |
| Message Sync | < 500ms | < 1s |
| Conversation List Load | < 500ms | < 1s |
| AI Categorization | < 2s | < 3s |
| AI Smart Reply | < 3s | < 5s |
| Scroll Performance | 60 FPS | 30 FPS |

### 10.2 Optimization Strategies

**Lazy Loading:**
- Load messages in batches (20 at a time)
- Load more when user scrolls near end
- Virtual scrolling for long conversations

**Image Caching:**
- Kingfisher for aggressive memory + disk caching
- 100 MB memory cache, 500 MB disk cache
- Prefetch images for upcoming conversations

**Pagination:**
- Firestore queries limited to 20 documents
- Cursor-based pagination for infinite scroll
- Cache pages locally in SwiftData

**Background Processing:**
- Sync queue processed in background
- Image uploads in background tasks
- AI requests batched when possible

### 10.3 Scalability Considerations

**Firestore Limits:**
- Document size: 1 MB (use subcollections for messages)
- Concurrent writes: 10,000/sec
- Use batched writes to stay under limits

**Cloud Functions Limits:**
- Max execution time: 540s (keep functions short)
- Max memory: 8 GB
- Set max instances per function to control costs

**Cost Optimization:**
- Cache AI responses (reduce OpenAI calls)
- Rate limit AI requests (100/user/hour)
- Use GPT-3.5 for simple tasks, GPT-4 only when needed
- Monitor Firestore reads/writes, optimize queries

---

## Appendix: 7-Day Sprint Milestones

**Day 1 (MVP - 24 Hours):**
- ✅ Real-time messaging functional
- ✅ Offline persistence with SwiftData
- ✅ Push notifications configured
- ✅ Group chat working

**Day 4 (Early - 96 Hours):**
- ✅ All 5 AI features operational
- ✅ Cloud Functions deployed
- ✅ AI response times < 3s
- ✅ 85%+ categorization accuracy

**Day 7 (Final - 168 Hours):**
- ✅ Context-aware smart replies with Supermemory
- ✅ Polished UI/UX
- ✅ TestFlight build ready
- ✅ No critical bugs

---

**END OF HIGH-LEVEL ARCHITECTURE**

*This architecture provides strategic direction for the 7-day sprint. Implementation details will be defined at the epic/story level during development.*