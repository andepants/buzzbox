# Sorted - Product Requirements Document v2.0

**Version:** 2.0 (AI-First Architecture Edition)
**Last Updated:** October 20, 2025
**Project Type:** iOS Native AI-Powered Messaging App for Content Creators
**Target Platform:** iOS 17+, Swift 6, SwiftUI
**Development Tool:** Claude Code + Xcode
**Deployment:** TestFlight → App Store
**Architecture Philosophy:** AI-First, Modular, Claude Code Optimized

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision & Goals](#2-product-vision--goals)
3. [AI-First Architecture Principles](#3-ai-first-architecture-principles)
4. [Swift 6 & iOS 17+ Technical Standards](#4-swift-6--ios-17-technical-standards)
5. [Timeline & Milestones](#5-timeline--milestones)
6. [User Personas & Use Cases](#6-user-personas--use-cases)
7. [System Architecture Overview](#7-system-architecture-overview)
8. [Feature Specifications](#8-feature-specifications)
9. [AI Features Deep Dive](#9-ai-features-deep-dive)
10. [Data Models & Schema](#10-data-models--schema)
11. [File Structure & Organization](#11-file-structure--organization)
12. [Code Standards & Documentation](#12-code-standards--documentation)
13. [Testing Strategy](#13-testing-strategy)
14. [Deployment & Distribution](#14-deployment--distribution)
15. [Success Metrics](#15-success-metrics)
16. [Epic Structure & Development Slices](#16-epic-structure--development-slices)
17. [Appendix A: Development Workflow with Claude Code](#17-appendix-a-development-workflow-with-claude-code)

---

## 1. Executive Summary

### 1.1 Product Overview

**Sorted** is an iOS-native messaging application specifically designed for content creators managing high-volume DM communications. Built with AI-first principles and modern Swift 6 concurrency, the app intelligently categorizes messages, drafts authentic responses, and surfaces business opportunities—all while maintaining a clean, maintainable codebase optimized for AI-assisted development.

### 1.2 What Makes This AI-First?

Unlike traditional development approaches, this project is architected for maximum AI tool compatibility:

- **Modular Design**: Every file under 500 lines for optimal AI context windows
- **Clear Naming**: Descriptive file and function names that AI tools can understand
- **Comprehensive Documentation**: Every file has a header explaining its purpose
- **Standard Comments**: All functions documented with purpose and parameters
- **Swift 6 Modern Patterns**: Leveraging latest concurrency and type safety features

### 1.3 Target User

Content creators (YouTubers, TikTokers, Influencers) who:
- Receive 50-500+ DMs daily across platforms
- Need to differentiate fan messages from business opportunities
- Want authentic engagement without spending hours on messages
- Value personal connection but lack time to respond to everyone
- Require organization without complexity

### 1.4 Core Value Proposition

**5 AI-Powered Features:**
1. **Auto-Categorization**: Fan/Business/Spam/Urgent classification
2. **Voice-Matched Drafting**: Responses that sound authentically like the creator
3. **Smart FAQ Handling**: Detect and auto-answer repetitive questions
4. **Sentiment Analysis**: Flag emotional or urgent messages
5. **Opportunity Scoring**: Rank business messages by potential value

### 1.5 Project Timeline

**7-Day Sprint Structure:**
- **Day 1 (Checkpoint 1 - MVP)**: Core messaging only, no AI
- **Day 4 (Checkpoint 2 - Early)**: All 5 AI features integrated
- **Day 7 (Checkpoint 3 - Final)**: Context-aware smart replies + polish

---

## 2. Product Vision & Goals

### 2.1 Product Vision

*"Empower content creators to maintain authentic fan connections and capture business opportunities without drowning in their inbox."*

### 2.2 Primary Goals

1. **Reduce Message Triage Time by 70%**: Auto-categorization surfaces what matters
2. **Maintain Authenticity**: AI drafts sound like the creator, not a bot
3. **Zero Missed Opportunities**: Business messages and urgent requests always surfaced
4. **Native iOS Excellence**: Fast, beautiful, follows platform conventions
5. **Privacy-First**: Creator data stays secure, transparent AI usage

### 2.3 Success Criteria (7-Day Sprint)

**Day 1 MVP:**
- ✅ User can send/receive messages in real-time
- ✅ Messages persist offline
- ✅ Push notifications work
- ✅ Basic group chat functional

**Day 4 Early:**
- ✅ All 5 AI features operational
- ✅ 85%+ categorization accuracy
- ✅ Draft responses match creator voice
- ✅ <3 second AI response times

**Day 7 Final:**
- ✅ Context-aware smart replies
- ✅ Polished UI/UX
- ✅ TestFlight build deployed
- ✅ Documentation complete

---

## 3. AI-First Architecture Principles

### 3.1 Core Principles

**1. Modularity Above All**
- Maximum 500 lines per file (hard limit)
- Single Responsibility Principle strictly enforced
- Each module does ONE thing well

**2. Explainable Structure**
- File names describe exact contents
- Folders organized by feature, not layer
- Clear separation: `Features/`, `Core/`, `Services/`

**3. Self-Documenting Code**
- File header: What this file does
- Function headers: Purpose, parameters, returns, throws
- Complex logic: Inline comments explaining "why", not "what"

**4. AI Tool Compatibility**
- Optimized for Claude Code's context windows
- Clear interfaces for AI to understand boundaries
- Predictable patterns across similar files

### 3.2 Why These Principles Matter for Claude Code

Claude Code excels when:
- It can understand entire files in one context
- Naming is descriptive and consistent
- Dependencies are explicit and minimal
- Code follows predictable patterns

### 3.3 File Size Management Strategy

**When approaching 500 lines:**
1. Extract view components into separate files
2. Move helper functions to utility files
3. Split large ViewModels by concern
4. Create protocol extensions in separate files

**Naming Convention for Split Files:**
- `MessageViewModel.swift` (Main ViewModel - 300 lines)
- `MessageViewModel+Networking.swift` (Networking extension - 150 lines)
- `MessageViewModel+AI.swift` (AI features extension - 200 lines)

---

## 4. Swift 6 & iOS 17+ Technical Standards

### 4.1 Swift 6 Concurrency Requirements

**Strict Concurrency Checking: ENABLED**

All code must pass Swift 6's strict concurrency checks using:

1. **Actors for State Management**
   - Use `@MainActor` for UI-bound ViewModels
   - Use custom `actor` for background services
   - Prevents data races at compile time

2. **Sendable Protocol**
   - All data models must conform to `Sendable`
   - Use `struct` for models (value semantics)
   - Mark closures as `@Sendable` when crossing actors

3. **Async/Await**
   - Use `async/await` for all asynchronous operations
   - Replace completion handlers with async functions
   - Leverage structured concurrency with `Task` groups

### 4.2 SwiftUI Best Practices (iOS 17+)

**Architecture: MVVM + Clean Architecture**

```
Feature/
├── View/              (SwiftUI Views - UI only)
├── ViewModel/         (State + Presentation Logic)
├── Model/             (Data structures)
├── Service/           (Business logic + API calls)
└── Repository/        (Data persistence)
```

**View Principles:**
- Views are declarative: Only render UI based on ViewModel state
- No business logic in Views
- Extract complex views into subviews (<200 lines per view)

**ViewModel Principles:**
- One ViewModel per screen/feature
- Use `@Published` for observable state
- All async operations use Swift concurrency
- ViewModels are `@MainActor` classes

**Data Flow Pattern:**
```
User Action → View → ViewModel → Service → Firebase
                ↑                            ↓
                └─────────  @Published  ─────┘
```

### 4.3 Forbidden Patterns

**DO NOT USE:**
- ❌ Massive View Controllers (MVC)
- ❌ Singletons (except for services like Firebase)
- ❌ Force unwrapping (`!`) except in tests
- ❌ Completion handlers (use async/await)
- ❌ UIKit (SwiftUI only, except for wrappers)
- ❌ Files over 500 lines

**USE INSTEAD:**
- ✅ MVVM with Clean Architecture
- ✅ Dependency Injection via initializers
- ✅ Optional chaining or guard statements
- ✅ Async/await and structured concurrency
- ✅ SwiftUI with UIKit wrappers when necessary
- ✅ Split files before hitting 500 lines

---

## 5. Timeline & Milestones

### 5.1 Checkpoint 1: MVP (Day 1 - 24 Hours)

**Goal:** Core messaging functionality that passes ALL essential criteria

**Must-Have Features (Essential Criteria Compliance):**

**Core Messaging:**
- ✅ One-to-one chat functionality
- ✅ Real-time message delivery between 2+ users
- ✅ Message persistence (survives app restarts/force quit)
- ✅ Optimistic UI updates (messages appear instantly before server confirmation)
- ✅ Online/offline status indicators
- ✅ Message timestamps
- ✅ User authentication (email/password via Firebase Auth)
- ✅ Basic group chat functionality (3+ users in one conversation)
- ✅ Message read receipts
- ✅ Push notifications (foreground + background via FCM)

**Real-Time Messaging Requirements:**
- ✅ Messages appear instantly for online recipients
- ✅ Offline message queue (sends when connectivity returns)
- ✅ Graceful handling of poor network (3G, packet loss, intermittent)
- ✅ Message delivery states: Sending → Sent → Delivered → Read
- ✅ Messages never lost (persisted before sending, retry on failure)
- ✅ Crash recovery (if app crashes mid-send, message still goes out)

**Media Support:**
- ✅ Basic image sending/receiving
- ✅ Profile pictures
- ✅ Display names

**Typing Indicators:**
- ✅ Show when users are typing

**Deliverables:**
- SwiftUI app with functional messaging UI
- Firebase Auth integration
- Firebase Firestore real-time sync
- SwiftData for offline persistence + message queue
- Push notification setup (FCM)
- Basic media upload (Firebase Storage)

**Testing Scenarios (All Must Pass):**
1. ✅ Two devices chatting in real-time
2. ✅ One device offline, receives messages when back online
3. ✅ Messages sent while app backgrounded
4. ✅ App force-quit and reopened → messages persist
5. ✅ Poor network conditions (airplane mode, throttled connection)
6. ✅ Rapid-fire messages (20+ messages sent quickly without loss)
7. ✅ Group chat with 3+ participants working correctly

**Deployment:**
- Running on iOS Simulator + TestFlight (internal)
- Backend deployed to Firebase

**Acceptance Criteria:**
- User can sign up/login successfully
- Send message appears instantly (optimistic UI)
- Message status progresses: Sending → Sent → Delivered → Read
- Messages received within 2 seconds on good network
- Messages persist after force quit
- Offline messages queue and send when online (with visual queue indicator)
- Network issues don't cause message loss
- Group chat with 3+ users works
- Push notifications trigger when app backgrounded
- Images can be sent and received
- Typing indicators work
- Read receipts display correctly

**Estimated File Count:** ~25 files, ~4,000 lines total

---

### 5.2 Checkpoint 2: Early (Day 4 - 96 Hours)

**Goal:** Add all 5 core AI features on top of solid MVP

**New Features (Additive - AI Agent Implementation):**

**AI Agent Architecture (Using OpenAI Agent SDK / Swarm):**
- ✅ Multi-agent orchestration for different AI tasks
- ✅ Conversation history retrieval (RAG pipeline via Supermemory)
- ✅ User preference storage
- ✅ Function calling capabilities
- ✅ Memory/state management across interactions
- ✅ Error handling and recovery

**5 Required AI Features:**
1. ✅ **Auto-categorization** (Fan/Business/Spam/Urgent)
2. ✅ **Response drafting** in creator's voice (using Supermemory context)
3. ✅ **FAQ auto-responder** (detect and suggest answers)
4. ✅ **Sentiment analysis** (flag emotional/urgent messages)
5. ✅ **Collaboration opportunity scoring** (rank business messages)

**Contextual AI Features (Option 2 Implementation):**
- ✅ Long-press message → Translate/Summarize/Extract Action menu
- ✅ Toolbar buttons for quick AI actions
- ✅ Inline AI suggestions as users type

**New Deliverables:**
- Firebase Cloud Functions for AI processing
- OpenAI Agent SDK (Swarm) integration for multi-agent orchestration
- OpenAI API integration (GPT-4 for all AI features)
- Supermemory API integration (RAG pipeline for conversation history)
- Category filter UI
- Draft reply UI with voice matching
- Priority inbox view (urgent/negative sentiment)
- AI action menu (long-press on messages)
- Inline AI toolbar buttons

**Agent Capabilities:**
- **Categorization Agent**: Classifies messages into categories
- **Draft Agent**: Generates responses using Supermemory context
- **FAQ Agent**: Detects and matches FAQs
- **Sentiment Agent**: Analyzes emotional tone
- **Opportunity Agent**: Scores business messages
- **Translation Agent**: Translates messages on demand
- **Summary Agent**: Summarizes long conversations

**Memory & State Management:**
- All messages stored in Supermemory for RAG
- User preferences stored (FAQ library, AI settings)
- Conversation context maintained across sessions
- Agent state persisted between interactions

**Acceptance Criteria:**
- New messages auto-categorized within 3 seconds
- Category filters work correctly
- Draft replies use Supermemory context and match creator's tone
- FAQ detection achieves 90%+ precision
- Sentiment flags urgent/negative messages correctly
- Opportunity scores visible and sortable on business messages
- Long-press menu shows: Translate, Summarize, Extract Action
- AI toolbar buttons functional
- All agents handle errors gracefully and retry
- Supermemory RAG pipeline retrieves relevant context

**Estimated File Count:** +20 files, ~5,000 new lines (~9,000 total)

---

### 5.3 Checkpoint 3: Final (Day 7 - 168 Hours)

**Goal:** Context-aware smart replies + polish + TestFlight

**Final Features:**

**A) Context-Aware Smart Replies (Advanced Agent Feature):**
- ✅ Generates authentic replies matching creator's personality
- ✅ Uses full conversation history from Supermemory
- ✅ References past conversations when relevant
- ✅ Maintains consistency across multiple conversations
- ✅ Adapts to different contexts (fan vs business vs urgent)

**UI Polish:**
- ✅ Polished UI with smooth animations
- ✅ Loading states for all AI features
- ✅ Error messages with retry options
- ✅ Skeleton screens during data load

**Onboarding:**
- ✅ Welcome flow explaining AI features
- ✅ Permission requests (notifications, camera for profile pics)
- ✅ Quick tutorial on AI features

**Settings:**
- ✅ FAQ management (add/edit/delete)
- ✅ AI preferences (enable/disable features)
- ✅ Privacy controls (what gets stored in Supermemory)

**Accessibility:**
- ✅ VoiceOver support for all screens
- ✅ Dynamic Type support
- ✅ Color contrast compliance (WCAG AA)
- ✅ Accessibility labels on all interactive elements

**Production Ready:**
- ✅ Error handling comprehensive
- ✅ Crash reporting configured
- ✅ Analytics events tracking
- ✅ TestFlight build deployed

**Acceptance Criteria:**
- Smart replies reference past conversations appropriately
- UI feels polished and professional
- All animations smooth (60fps)
- Loading states don't block UI
- Onboarding clearly explains value
- Settings allow customization
- App passes accessibility audit
- No critical bugs
- TestFlight build successfully distributed to external testers

**Estimated File Count:** +15 files, ~3,000 new lines (~12,000 total)
**Final Total:** ~60 files, all under 500 lines each

---

## 6. User Personas & Use Cases

### 6.1 Primary Persona: Mid-Tier Creator (Sarah)

**Background:**
- YouTube creator with 250K subscribers
- 150-300 DMs per day across Instagram, TikTok, YouTube
- Spends 2-3 hours daily on messages
- Misses important brand deals buried in fan messages
- Feels guilty not responding to fans
- Often forgets past conversations with repeat fans/brands

**Pain Points:**
1. **Triage Overload**: Can't quickly identify business opportunities
2. **Repetitive Questions**: Answers "what camera do you use?" 50x/week
3. **Lost Authenticity**: Copy-paste responses feel robotic
4. **Missed Opportunities**: Brand deals lost in message flood
5. **Emotional Fatigue**: Fans in crisis need immediate attention
6. **No Conversation Memory**: Can't remember what was discussed with repeat contacts

**Goals:**
- Reduce message triage time by 70%
- Never miss a business opportunity
- Maintain authentic fan connections
- Respond to emotional/urgent messages quickly
- Spend less time on repetitive questions
- Remember context from past conversations

**How Sorted Helps:**
- Auto-categorization surfaces business messages
- FAQ auto-responder handles repetitive questions
- AI drafts use Supermemory to maintain conversation context
- Sentiment analysis flags urgent emotional messages
- Opportunity scoring ranks brand deals by value
- Supermemory recalls past interactions for personalized responses

### 6.2 Use Case 1: Morning Message Triage

**Current Flow (Without Sorted):**
1. Opens Instagram DMs (15 messages) - manually scans each
2. Responds to 2 business inquiries
3. Skips most fan messages (no time)
4. Repeats for TikTok and YouTube
5. **Total time: 45 minutes**
6. **Result: 40 fan messages ignored**

**New Flow (With Sorted):**
1. Opens Sorted app
2. Sees 3 business messages in Business tab (auto-categorized)
3. Sees 2 urgent messages in Priority tab (sentiment-flagged)
4. Taps "Draft Reply" → AI uses Supermemory to recall past conversation context
5. AI suggests contextually-aware response in 30 seconds
6. Bulk-sends FAQ responses to 20 similar questions
7. **Total time: 12 minutes**
8. **Result: 25 messages answered, 0 missed opportunities, responses include relevant past context**

### 6.3 Use Case 3: Context-Aware Follow-Up

**Scenario:** A fan reaches out again after a previous conversation 2 weeks ago.

**Current Flow:**
1. Fan: "Hey! Did you end up trying that restaurant I recommended?"
2. Sarah has no memory of previous conversation
3. Responds generically: "Thanks for the suggestion!"
4. Fan feels ignored/forgotten
5. **Result: Lost connection with engaged fan**

**New Flow (With Sorted + Supermemory):**
1. Fan sends follow-up message
2. Supermemory retrieves previous conversation context
3. AI Draft: "Yes! I finally went last week and the pasta was amazing. Thanks again for the rec! 🍝"
4. Response shows Sarah remembers the conversation
5. **Result: Strengthened fan relationship, authentic engagement**

**Current Flow:**
1. Brand DM arrives mixed with 30 fan messages
2. Sarah misses it for 3 days
3. Brand moves to another creator
4. **Result: $2,000 opportunity lost**

**New Flow:**
1. Sorted categorizes as "Business"
2. Opportunity Scoring rates it 85/100 (high value)
3. Push notification: "High-value business opportunity"
4. Sarah responds within 1 hour
5. **Result: $2,000 deal secured**

---

## 7. System Architecture Overview

### 7.1 High-Level Architecture

**3-Tier Architecture:**

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Views     │  │ ViewModels  │  │   Models    │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│         │                 │                 │           │
│         └─────────────────┴─────────────────┘           │
│                          │                               │
│                   Services Layer                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Firebase │ OpenAI │ Supermemory │ SwiftData      │  │
│  │          │        │ (Long-term  │                │  │
│  │          │        │  Memory)    │                │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Firebase Backend                       │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Firestore│  │ Cloud Functions│  │ Cloud Storage │   │
│  └──────────┘  └──────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  External AI Services                    │
│  ┌──────────────┐           ┌──────────────────┐       │
│  │  OpenAI      │           │  Supermemory     │       │
│  │  (GPT-4)     │           │  (Long-term      │       │
│  │              │           │   Conversation   │       │
│  │              │           │   Memory)        │       │
│  └──────────────┘           └──────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

### 7.2 iOS App Architecture (MVVM + Clean)

**Layer Breakdown:**

```
Presentation Layer
  ├── SwiftUI Views (Dumb UI Components)
  └── ViewModels (@MainActor ObservableObjects)
          ↓
Domain Layer
  ├── Models (Sendable Structs)
  └── Use Cases / Interactors
          ↓
Data Layer
  ├── Repositories (Abstract Data Sources)
  └── Services (Concrete Implementations)
```

**Dependency Rule:** Outer layers depend on inner layers, never the reverse.

### 7.3 Data Flow: Real-Time Message Delivery

```
1. User A sends message
   ↓
2. View calls ViewModel.sendMessage()
   ↓
3. ViewModel calls Repository.send()
   ↓
4. Repository calls FirebaseService.sendMessage()
   ↓
5. Firestore listener in FirebaseService detects change
   ↓
6. **Message sent to Supermemory for long-term storage**
   ↓
7. Firestore triggers Cloud Function
   ↓
8. Cloud Function calls OpenAI (categorization)
   ↓
9. Cloud Function writes category to Firestore
   ↓
10. Firestore listener in FirebaseService detects change
   ↓
11. Repository updates local SwiftData cache
   ↓
12. Repository returns new message to ViewModel
   ↓
13. ViewModel updates @Published property
   ↓
14. SwiftUI auto-updates View
   ↓
15. User B sees message appear in real-time
```

---

## 8. Feature Specifications

### 8.1 Core Messaging (MVP - Day 1)

#### 8.1.1 Authentication
- Email/Password (Firebase Auth)
- Sign up with email validation
- Login with error handling
- Password reset via email
- Persistent login (Keychain token storage)

#### 8.1.2 Conversations
- Display all conversations
- Sort by most recent message
- Show unread count badge
- Show last message preview
- Pull-to-refresh
- Real-time updates

#### 8.1.3 Real-Time Messaging
- Send text messages
- Optimistic UI updates (instant feedback)
- Real-time delivery via Firestore listeners
- Offline queue (messages sent when reconnected)
- Message status indicators: Sending, Sent, Delivered, Read

#### 8.1.4 Group Chat
- Create group with 3+ participants
- Add/remove participants
- Group name and avatar
- All messaging features work in groups
- Read receipts show who read message

---

## 9. AI Features Deep Dive

### 9.1 Feature 1: Auto-Categorization

**Purpose:** Automatically sort messages into Fan, Business, Spam, or Urgent

**Technical Flow:**
1. New message arrives in Firestore
2. Firestore trigger fires Cloud Function: `categorizeMessage()`
3. Cloud Function calls OpenAI API with GPT-4
4. Prompt analyzes: message text, sender profile, conversation history
5. Returns: category (Fan/Business/Spam/Urgent) + confidence score
6. Writes to Firestore: `/messages/{messageId}/metadata/category`
7. iOS app Firestore listener detects change
8. MessageViewModel updates @Published property
9. SwiftUI re-renders with category badge

**Prompt Strategy:**
```
Categorize this message into one of these categories:
1. Fan: General fan engagement, compliments, casual questions
2. Business: Brand deals, sponsorships, collaborations
3. Spam: Scams, bots, irrelevant messages
4. Urgent: Time-sensitive requests, emotional distress

Message: "{messageText}"
Sender: {senderName}
Has previous conversation: {boolean}

Return JSON: {category, confidence, reasoning}
```

**Performance Targets:**
- Response time: <3 seconds
- Accuracy: 85%+ (validated on test dataset)
- Cost: <$0.001 per categorization

**Error Handling:**
- If OpenAI fails: Default to "Fan" category
- Log error to Firebase Analytics
- Retry once after 5 seconds

---

### 9.2 Feature 2: Voice-Matched Response Drafting

**Purpose:** Generate replies that sound authentically like the creator using their conversation history

**Technical Flow:**
1. User taps "Draft Reply" button
2. View calls DraftReplyViewModel.generateDraft()
3. ViewModel calls Cloud Function: `draftResponse()`
4. Cloud Function queries Supermemory API for creator's conversation context
5. Supermemory returns: relevant past conversations, creator's response patterns, conversation history
6. Cloud Function calls OpenAI API with conversation context from Supermemory
7. OpenAI generates response matching creator's style based on historical patterns
8. Cloud Function returns draft to iOS app
9. DraftReplyViewModel displays in MessageInputBar (editable)
10. Creator can send as-is, edit, or discard

**Supermemory Integration - Long-Term Conversation Memory:**

Supermemory stores and retrieves conversation history to provide contextual AI responses:

**What Gets Stored in Supermemory:**
1. **Full Conversation History**: All messages sent/received by the creator
2. **Creator Response Patterns**: How the creator typically responds to different types of messages
3. **Conversation Context**: Topics discussed, relationships with different users
4. **Temporal Context**: How creator's communication evolves over time
5. **Conversation Threads**: Complete message chains for context-aware responses

**How Supermemory Enhances AI Responses:**
- **Contextual Awareness**: AI understands ongoing conversations and past interactions
- **Personalization**: Responses reflect creator's unique communication style based on actual message history
- **Consistency**: AI maintains consistent tone and context across multiple conversations
- **Memory Recall**: References previous conversations when relevant ("As we discussed last week...")
- **Relationship Context**: Understands if sender is a repeat fan, potential client, or new contact

**Supermemory API Flow:**
```
1. Creator sends/receives messages → Stored in Supermemory
2. When drafting reply → Supermemory retrieves:
   - Current conversation thread
   - Past interactions with this sender
   - Creator's typical responses to similar messages
   - Relevant conversation context
3. OpenAI uses this context to generate authentic response
```

**Data Stored in Supermemory:**
- Message content and metadata
- Conversation threads and relationships
- Sender profiles and interaction history
- Creator's communication patterns extracted from history
- Temporal context (when conversations happened)

**Performance Targets:**
- Draft generation: <3 seconds (including Supermemory query)
- Acceptance rate: >60% (sent as-is or with minor edits)
- Context relevance: AI references past conversations when appropriate

**Implementation Reference:**
📖 See [Supermemory Integration Guide](./supermemory-integration-guide.md) for complete implementation including:
- Authentication setup (Bearer token, Cloud Functions configuration)
- Storing conversations (automatic storage, batch operations)
- RAG queries for context retrieval (smart replies, summaries)
- Error handling with retry strategies and fallback patterns
- Privacy controls and data deletion

---

### 9.3 Feature 3: FAQ Auto-Responder

**Purpose:** Detect repetitive questions and suggest pre-written answers

**Common FAQ Categories:**
1. Equipment: "what camera/mic/lights do you use?"
2. Software: "how do you edit videos?"
3. Business: "how can I work with you?"
4. Personal: "where are you from?" / "how old are you?"
5. Career: "how did you get started?" / "any tips for beginners?"

**Technical Flow:**
1. New message arrives
2. Cloud Function: `detectFAQ()` triggered
3. OpenAI API classifies if message is FAQ and which category
4. Cloud Function queries Firebase for creator's FAQ library
5. Matches question to closest FAQ answer
6. Returns suggested answer to iOS app
7. MessageThreadView shows "Suggested Answer" card
8. Creator can send, edit, or dismiss

**FAQ Library Management:**
- Creators manage FAQs in Settings
- Add/edit/delete FAQ items
- Structure: question pattern + answer + category
- Stored in Firebase: `/users/{creatorId}/faqs`

**Performance Targets:**
- Detection: <2 seconds
- Precision: 90%+ (no false positives)
- Recall: 70%+ (OK to miss some, but don't suggest wrong answers)

---

### 9.4 Feature 4: Sentiment Analysis

**Purpose:** Detect emotional tone and flag urgent messages

**Sentiment Types:**
- **Positive**: Excitement, gratitude, joy
- **Negative**: Sadness, frustration, anger
- **Urgent**: Crisis, immediate help needed, emotional distress
- **Neutral**: General questions, casual chat

**Technical Flow:**
1. New message arrives
2. Cloud Function: `analyzeSentiment()` triggered
3. OpenAI API analyzes: sentiment type + intensity (low/medium/high)
4. Cloud Function writes to Firestore: `/messages/{messageId}/sentiment`
5. If urgent OR (negative + high intensity): Add to Priority Inbox
6. Send push notification for high-priority messages
7. iOS app updates UI with sentiment badge

**Priority Inbox Logic:**
- Messages appear if:
  - `sentiment: "urgent"` (any intensity)
  - `sentiment: "negative"` AND `intensity: "high"`

**Performance Targets:**
- Analysis: <3 seconds
- Accuracy: 80%+ on test dataset
- False positive rate: <5% (critical for urgent classification)

---

### 9.5 Feature 5: Collaboration Opportunity Scoring

**Purpose:** Rank business messages by potential value and legitimacy

**Scoring Criteria (0-100 points):**

1. **Monetary Value (0-40 points)**
   - Mentioned budget
   - Brand size (follower count)
   - Past collaboration history

2. **Brand Fit (0-30 points)**
   - Alignment with creator's niche
   - Target audience overlap
   - Product/service relevance

3. **Legitimacy (0-20 points)**
   - Professional language
   - Verifiable sender (domain, social proof)
   - Specific proposal vs. vague inquiry

4. **Urgency (0-10 points)**
   - Deadline mentioned
   - Time-sensitive opportunity

**Technical Flow:**
1. Message categorized as "Business"
2. Cloud Function: `scoreOpportunity()` triggered
3. OpenAI API scores based on criteria above
4. Returns: total score + breakdown + reasoning
5. Cloud Function writes to Firestore
6. iOS app displays score badge on business messages
7. Business tab sorts by score (highest first)

**Performance Targets:**
- Scoring time: <3 seconds
- Accuracy: Validated by creator feedback (thumbs up/down)

---

## 10. Data Models & Schema

### 10.1 Firebase Firestore Schema

**Collections Structure:**

```
/users/{userId}
  - email: string
  - displayName: string
  - photoURL: string
  - createdAt: timestamp

  /faqs/{faqId}
    - category: string
    - questionPattern: string
    - answer: string
    - usageCount: number

/conversations/{conversationId}
  - participants: array<string>
  - lastMessage: map
  - unreadCount: map
  - createdAt: timestamp
  - updatedAt: timestamp
  - supermemoryId: string  // Reference to Supermemory conversation storage

/messages/{messageId}
  - conversationId: string
  - senderId: string
  - text: string
  - timestamp: timestamp
  - status: string
  - readBy: array<string>
  - metadata: map {
      category: string
      confidence: number
      sentiment: map
      opportunityScore: map
    }
```

**Note:** Full conversation history is stored in Supermemory for long-term memory and context retrieval, not duplicated in Firestore.

### 10.2 SwiftData Models (Local Persistence)

SwiftData models for local persistence using `@Model` macro.

**Core @Model Entities:**
- `MessageEntity`: Offline message storage with AI metadata and sync status
- `ConversationEntity`: Conversation metadata with message relationships
- `UserEntity`: Local user data, preferences, and FAQ library
- `AttachmentEntity`: Media files with upload progress tracking
- `FAQEntity`: FAQ library for auto-responder feature

**Key SwiftData Features:**
- Automatic persistence with `@Model` macro
- Relationship management with `@Relationship` macro (one-to-many, cascade deletes)
- Query capabilities with `@Query` property wrapper for automatic UI updates
- ModelContainer setup in App.swift with schema configuration
- SwiftData ↔ Firestore sync with optimistic UI and offline queue

**Implementation Reference:**
📖 See [SwiftData Implementation Guide](./swiftdata-implementation-guide.md) for complete code examples including:
- Full @Model entity definitions with all properties and relationships
- ModelContainer setup in SortedApp.swift
- @Query usage in ViewModels and Views
- Background sync patterns (write-first, read-first)
- Error handling and retry strategies

### 10.3 Swift Models (App)

All models conform to `Sendable` for Swift 6 concurrency safety:

**Core Models:**
- `Message`: id, conversationId, senderId, text, timestamp, status, readBy
- `Conversation`: id, participantIds, lastMessage, unreadCount
- `User`: id, email, displayName, photoURL

**AI Models:**
- `MessageCategory`: enum (Fan, Business, Spam, Urgent)
- `MessageSentiment`: type (positive/negative/urgent/neutral) + intensity
- `FAQItem`: category, questionPattern, answer, usageCount
- `ConversationMemory`: Supermemory context data for a conversation
- `OpportunityScore`: totalScore, breakdown, reasoning

---

## 11. File Structure & Organization

### 11.1 Complete Project Structure

```
Sorted/
├── App/
│   └── SortedApp.swift
│
├── Features/
│   ├── Auth/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Services/
│   │
│   ├── Chat/
│   │   ├── Views/
│   │   │   └── Components/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Repositories/
│   │
│   ├── AI/
│   │   ├── Views/
│   │   │   └── Components/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Services/
│   │
│   ├── SmartReply/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Services/
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   └── ViewModels/
│   │
│   └── Onboarding/
│       ├── Views/
│       └── ViewModels/
│
├── Core/
│   ├── Services/
│   ├── Persistence/
│   ├── Networking/
│   ├── Theme/
│   ├── Utilities/
│   └── Accessibility/
│
├── CloudFunctions/
│   ├── src/
│   │   ├── categorizeMessage.js
│   │   ├── draftResponse.js
│   │   ├── detectFAQ.js
│   │   ├── analyzeSentiment.js
│   │   └── scoreOpportunity.js
│   └── test/
│
├── Tests/
│   ├── SortedTests/
│   │   ├── ViewModelTests/
│   │   ├── ServiceTests/
│   │   └── ModelTests/
│   └── SortedUITests/
│
├── Resources/
│   ├── GoogleService-Info.plist
│   └── Assets.xcassets/
│
└── Documentation/
    ├── README.md
    ├── ARCHITECTURE.md
    └── API_DOCUMENTATION.md

TOTAL ESTIMATE:
- Swift files: ~60 files
- JavaScript files: ~5 Cloud Functions
- Total lines of code: ~12,000
- Average file size: ~200 lines
- Maximum file size: 500 lines (enforced)
```

### 11.2 File Organization Principles

1. **Feature-Based Structure**: Group by feature/domain, not technical layer
2. **Naming Convention**: `[FeatureName][ComponentType].swift`
3. **Extensions for Large Files**: Split using `+Extension` suffix
4. **Folder Depth**: Maximum 3 levels deep

---

## 12. Code Standards & Documentation

### 12.1 File Header Template

Every Swift file must start with this header:

```
/// [FileName].swift
///
/// [Brief description - 1-2 sentences]
///
/// Dependencies:
/// - [Dependency]: Brief explanation
///
/// Created: YYYY-MM-DD
/// Last Modified: YYYY-MM-DD
```

### 12.2 Function Documentation

All public functions must be documented:

```
/// [Brief description of what this function does]
///
/// - Parameters:
///   - paramName: Description
/// - Returns: Description
/// - Throws: Error types and when
///
/// Example:
/// ```swift
/// try await functionName(param: value)
/// ```
```

### 12.3 Code Organization Within Files

Use MARK comments for structure:

```
// MARK: - Published Properties
// MARK: - Private Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
```

### 12.4 Inline Comments Guidelines

**When to comment:**
- ✅ Explain WHY, not WHAT
- ✅ Complex algorithms or business logic
- ✅ Non-obvious decisions or workarounds

**When NOT to comment:**
- ❌ Self-explanatory code
- ❌ Obvious operations

---

## 13. Testing Strategy

### 13.1 Testing Philosophy

**Test Pyramid:**
```
         /\
        /  \  E2E UI Tests (10%)
       /____\
      /      \
     / Unit   \ Integration Tests (30%)
    /  Tests  \
   /___________\ Unit Tests (60%)
```

**Coverage Goals:**
- Unit Tests: 80%+ coverage
- Integration Tests: Key user flows
- UI Tests: Critical paths only

### 13.2 What to Test

**Unit Testing:**
- ✅ ViewModels (business logic)
- ✅ Services (API calls, mocked)
- ✅ Models (validation, computed properties)
- ✅ Utilities (pure functions)

**What NOT to Test:**
- ❌ SwiftUI Views (too brittle)
- ❌ Third-party libraries
- ❌ Firebase SDK methods

### 13.3 Integration Testing

Test Firebase integration with Firebase Emulator Suite for isolated testing.

### 13.4 UI Testing (Critical Paths Only)

Test only critical user flows:
- Login flow
- Send/receive message flow
- AI feature interactions

---

## 14. Deployment & Distribution

### 14.1 Build Configurations

**Three Environments:**
1. **Development**: Firebase Emulators, Mock AI responses
2. **Staging (TestFlight Internal)**: Firebase Dev Project, Real AI (rate limited)
3. **Production (TestFlight External → App Store)**: Full features

### 14.2 TestFlight Distribution

**Day 7 Checklist:**
- ✅ Archive build in Xcode
- ✅ Upload to App Store Connect
- ✅ Add build to TestFlight
- ✅ Write release notes explaining AI features
- ✅ Add internal testers (team)
- ✅ Add external testers (beta users)
- ✅ Submit for Beta App Review

### 14.3 Release Notes Template

```
Sorted - Beta v1.0.0

🎉 WHAT'S NEW:
• AI-powered message categorization
• Smart reply drafting in your voice
• FAQ auto-responder
• Sentiment analysis
• Opportunity scoring

🧪 WHAT TO TEST:
1. Check categorization accuracy
2. Try "Draft Reply" feature
3. Create FAQs in Settings
4. Priority Inbox functionality

⚠️ KNOWN ISSUES:
• AI takes 3-5 seconds
• Voice calibration needs 50+ messages

📝 FEEDBACK:
Use in-app feedback button!
```

---

## 15. Success Metrics

### 15.1 Product Metrics (Post-Launch)

**User Engagement:**
- Daily Active Users (DAU)
- Messages sent per user per day
- AI feature usage rate

**AI Performance:**
- Categorization accuracy
- Draft response acceptance rate (sent as-is vs edited)
- FAQ precision
- Sentiment analysis accuracy
- Context recall from Supermemory (how often AI references past conversations correctly)

**Time Savings:**
- Average time to triage inbox (before vs after)
- Messages processed per hour
- Response rate increase

### 15.2 Technical Metrics

**Performance:**
- App launch time: <2 seconds cold start
- Message send latency: <500ms (optimistic UI)
- AI response time: <3 seconds
- Crash-free rate: >99.5%

**Cost Tracking:**
- Firestore reads/writes per user
- Cloud Function invocations
- OpenAI API costs per user
- Storage costs

**Code Quality:**
- Test coverage: >80%
- Files over 500 lines: 0
- Compiler warnings: 0

### 15.3 7-Day Sprint Success Criteria

**Day 1 MVP (Must Have):**
- ✅ Real-time messaging works
- ✅ Offline persistence
- ✅ Push notifications
- ✅ Group chat

**Day 4 Early (Must Have):**
- ✅ All 5 AI features operational
- ✅ 85%+ categorization accuracy
- ✅ AI response times <3s

**Day 7 Final (Must Have):**
- ✅ Context-aware smart replies
- ✅ Polished UI
- ✅ TestFlight build
- ✅ No critical bugs

## 16. Epic Structure & Development Slices

### 16.1 Epic Overview

Development is organized into **vertical slices** - each epic delivers complete, working functionality that can be tested end-to-end. Epics build on each other incrementally.

---

### Epic 1: Foundation - User Authentication & Profile
**Phase:** MVP (Day 1)
**Priority:** P0 (Blocker)

**What It Does:**
- Users can create accounts and log in
- Profile pictures and display names
- Secure token storage
- Basic user management

**Key User Stories:**
- As a creator, I can sign up with email/password
- As a creator, I can log in to access my messages
- As a creator, I can set my display name and profile picture
- As a creator, I stay logged in after closing the app

**Acceptance:**
- Sign up flow works end-to-end
- Login persists across app restarts
- Profile data syncs to Firebase
- Token stored securely in Keychain

**Technical Dependencies:**
- Firebase Auth
- Firebase Firestore (user profiles)
- Firebase Storage (profile pictures)
- Keychain (token storage)

---

### Epic 2: Core Messaging - One-to-One Chat
**Phase:** MVP (Day 1)
**Priority:** P0 (Blocker)

**What It Does:**
- Real-time messaging between two users
- Message persistence and history
- Online/offline status
- Typing indicators
- Read receipts
- Message delivery states

**Key User Stories:**
- As a creator, I can send text messages to another user
- As a creator, I can see when someone is typing
- As a creator, I can see message delivery status (sending/sent/delivered/read)
- As a creator, I can see my message history after restarting the app
- As a creator, I can see if someone is online or offline
- As a creator, messages I send while offline queue and send when I reconnect

**Acceptance:**
- Messages appear instantly (optimistic UI)
- Real-time delivery within 2 seconds
- Typing indicators work
- Read receipts update correctly
- Messages persist after force quit
- Offline queue works without message loss
- Handles poor network gracefully

**Technical Dependencies:**
- Firebase Firestore (real-time sync)
- SwiftData (offline persistence + queue)
- WebSocket or Firestore listeners

---

### Epic 3: Media Support - Images & Files
**Phase:** MVP (Day 1)
**Priority:** P0 (Blocker)

**What It Does:**
- Send and receive images
- Image thumbnails in chat
- Full-size image viewer
- Upload progress indicators

**Key User Stories:**
- As a creator, I can send images to my conversations
- As a creator, I can tap an image to view it full-screen
- As a creator, I can see upload progress when sending images
- As a creator, images are stored and viewable after app restart

**Acceptance:**
- Image picker integrated
- Images upload to Firebase Storage
- Thumbnails display in chat
- Full-size viewer works
- Upload progress shown

**Technical Dependencies:**
- Firebase Storage
- PHPickerViewController (iOS)
- Image compression/optimization

---

### Epic 4: Group Chat - Multi-User Conversations
**Phase:** MVP (Day 1)
**Priority:** P0 (Blocker)

**What It Does:**
- Create group conversations (3+ users)
- Add/remove participants
- Group naming
- Message attribution in groups
- Read receipts for all participants

**Key User Stories:**
- As a creator, I can create a group with 3+ participants
- As a creator, I can add/remove people from groups
- As a creator, I can see who sent each message in a group
- As a creator, I can see who has read messages in a group
- As a creator, I can name my group chats

**Acceptance:**
- Groups support 3+ users
- Messages attributed correctly
- Read receipts show all readers
- Add/remove participants works
- Group list view shows all groups

**Technical Dependencies:**
- Firebase Firestore (group data model)
- Participant management logic

---

### Epic 5: Push Notifications
**Phase:** MVP (Day 1)
**Priority:** P0 (Blocker)

**What It Does:**
- Receive notifications when app is backgrounded
- Tap notification to open specific conversation
- Badge count on app icon
- Notification settings

**Key User Stories:**
- As a creator, I receive notifications when someone messages me
- As a creator, I can tap a notification to go directly to that conversation
- As a creator, I see a badge count of unread messages on the app icon
- As a creator, I can enable/disable notifications in settings

**Acceptance:**
- Notifications arrive when app backgrounded
- Deep linking to conversations works
- Badge count accurate
- Notification permissions handled

**Technical Dependencies:**
- Firebase Cloud Messaging (FCM)
- APNs (Apple Push Notification service)
- Deep linking implementation

---

### Epic 6: AI Agent Framework - Multi-Agent Orchestration
**Phase:** Early (Day 4)
**Priority:** P1 (Critical)

**What It Does:**
- Sets up OpenAI Agent SDK (Swarm) infrastructure
- Multi-agent orchestration system
- Supermemory RAG pipeline integration
- Function calling framework
- Error handling and recovery
- State management across agents

**Key User Stories:**
- As a system, I can orchestrate multiple AI agents for different tasks
- As a system, I can retrieve conversation context from Supermemory
- As a system, I can handle AI errors gracefully and retry
- As a system, I can maintain state across agent interactions

**Acceptance:**
- OpenAI Swarm SDK integrated
- Multiple agents can be orchestrated
- Supermemory RAG pipeline working
- Function calling operational
- Error recovery implemented
- State persists between calls

**Technical Dependencies:**
- OpenAI Agent SDK (Swarm)
- Supermemory API
- Firebase Cloud Functions (agent hosting)
- OpenAI API (GPT-4)

---

### Epic 7: Auto-Categorization Agent
**Phase:** Early (Day 4)
**Priority:** P1 (Critical)

**What It Does:**
- Automatically categorizes incoming messages
- Categories: Fan, Business, Spam, Urgent
- Confidence scoring
- Category filters in UI
- User can manually override

**Key User Stories:**
- As a creator, incoming messages are automatically categorized
- As a creator, I can filter my inbox by category
- As a creator, I can see the AI's confidence in its categorization
- As a creator, I can manually change a message's category
- As a creator, urgent messages are highlighted immediately

**Acceptance:**
- Messages categorized within 3 seconds
- 85%+ accuracy on test dataset
- Category filter UI works
- Manual override saves correctly
- Urgent category triggers priority view

**Technical Dependencies:**
- Epic 6 (AI Agent Framework)
- OpenAI API
- Firebase Cloud Functions

---

### Epic 8: Smart Reply Draft Agent
**Phase:** Early (Day 4)
**Priority:** P1 (Critical)

**What It Does:**
- Generates reply drafts using Supermemory context
- Matches creator's communication style
- Editable before sending
- References past conversations when relevant

**Key User Stories:**
- As a creator, I can tap "Draft Reply" to get an AI-generated response
- As a creator, the draft sounds like me, not a robot
- As a creator, the draft references previous conversations when appropriate
- As a creator, I can edit the draft before sending
- As a creator, I can discard the draft if it's not helpful

**Acceptance:**
- Draft generated in <3 seconds
- Uses Supermemory context
- 60%+ acceptance rate (sent as-is or lightly edited)
- Draft appears in message input (editable)
- References past conversations correctly

**Technical Dependencies:**
- Epic 6 (AI Agent Framework)
- Supermemory API (RAG)
- OpenAI API

---

### Epic 9: FAQ Auto-Responder Agent
**Phase:** Early (Day 4)
**Priority:** P1 (Critical)

**What It Does:**
- Detects frequently asked questions
- Suggests pre-written answers
- Creator can manage FAQ library
- Bulk FAQ responses

**Key User Stories:**
- As a creator, I can create FAQ templates for common questions
- As a creator, when a FAQ is detected, I see a suggested answer
- As a creator, I can send, edit, or dismiss FAQ suggestions
- As a creator, I can bulk-respond to multiple similar FAQs
- As a creator, I can manage my FAQ library in settings

**Acceptance:**
- FAQ detection <2 seconds
- 90%+ precision (no false positives)
- FAQ library management UI works
- Suggested answers display correctly
- Can send/edit/dismiss suggestions

**Technical Dependencies:**
- Epic 6 (AI Agent Framework)
- OpenAI API
- Firebase (FAQ storage)

---

### Epic 10: Sentiment Analysis Agent
**Phase:** Early (Day 4)
**Priority:** P1 (Critical)

**What It Does:**
- Analyzes emotional tone of messages
- Flags urgent/negative messages
- Priority inbox for important messages
- Sentiment badges on messages

**Key User Stories:**
- As a creator, urgent messages are flagged automatically
- As a creator, I have a Priority Inbox for important messages
- As a creator, I can see sentiment indicators on messages
- As a creator, negative/emotional messages don't get lost

**Acceptance:**
- Sentiment analyzed in <3 seconds
- 80%+ accuracy on test dataset
- Priority inbox shows urgent/negative messages
- Sentiment badges display correctly
- False positive rate <5%

**Technical Dependencies:**
- Epic 6 (AI Agent Framework)
- OpenAI API

---

### Epic 11: Opportunity Scoring Agent
**Phase:** Early (Day 4)
**Priority:** P2 (Important)

**What It Does:**
- Scores business messages by potential value
- Scoring criteria: monetary value, brand fit, legitimacy, urgency
- Business messages sorted by score
- Score badges on messages

**Key User Stories:**
- As a creator, business messages are ranked by potential value
- As a creator, I can see opportunity scores on business messages
- As a creator, my Business tab is sorted by score (highest first)
- As a creator, I can see the scoring breakdown

**Acceptance:**
- Scoring completes in <3 seconds
- Scores display on business messages
- Business tab sorts correctly
- Score breakdown available on tap

**Technical Dependencies:**
- Epic 7 (Categorization Agent - business category)
- Epic 6 (AI Agent Framework)
- OpenAI API

---

### Epic 12: Contextual AI Actions - Long-Press Menu
**Phase:** Early (Day 4)
**Priority:** P2 (Important)

**What It Does:**
- Long-press message to reveal AI action menu
- Actions: Translate, Summarize, Extract Action
- Results display inline or in modal
- Quick access to AI features

**Key User Stories:**
- As a creator, I can long-press a message to see AI actions
- As a creator, I can translate messages to my language
- As a creator, I can get a summary of long messages
- As a creator, I can extract action items from messages

**Acceptance:**
- Long-press menu appears on messages
- Translate works for common languages
- Summarize condenses long messages
- Extract Action finds actionable items
- Results display clearly

**Technical Dependencies:**
- Epic 6 (AI Agent Framework)
- OpenAI API

---

### Epic 13: Context-Aware Smart Replies (Advanced)
**Phase:** Final (Day 7)
**Priority:** P2 (Important)

**What It Does:**
- Advanced reply generation using full conversation history
- Personality matching across contexts
- Adapts tone for fan vs business vs urgent
- References multiple past conversations

**Key User Stories:**
- As a creator, smart replies adapt to different contexts (fan/business/urgent)
- As a creator, replies reference multiple past conversations when relevant
- As a creator, the AI maintains my personality consistently
- As a creator, replies feel natural, not robotic

**Acceptance:**
- Smart replies use full Supermemory context
- Adapts tone appropriately
- References past conversations correctly
- Maintains consistency across conversations
- Feels authentic to creator's personality

**Technical Dependencies:**
- Epic 8 (Smart Reply Draft Agent)
- Supermemory API (advanced RAG)
- OpenAI API (GPT-4)

---

### Epic 14: Onboarding & Tutorial
**Phase:** Final (Day 7)
**Priority:** P2 (Important)

**What It Does:**
- Welcome screens explaining app value
- AI feature walkthrough
- Permission requests (notifications, camera)
- Quick tutorial with examples

**Key User Stories:**
- As a new creator, I understand what Sorted does
- As a new creator, I learn about AI features before using them
- As a new creator, I grant necessary permissions
- As a new creator, I can skip the tutorial if I want

**Acceptance:**
- Welcome flow explains value proposition
- AI features clearly demonstrated
- Permissions requested at right time
- Tutorial skippable
- Never shows again after first launch

**Technical Dependencies:**
- None (UI only)

---

### Epic 15: Settings & Preferences
**Phase:** Final (Day 7)
**Priority:** P2 (Important)

**What It Does:**
- FAQ library management
- AI feature toggles
- Privacy controls (Supermemory storage)
- Notification settings
- Account management

**Key User Stories:**
- As a creator, I can manage my FAQ library
- As a creator, I can enable/disable AI features
- As a creator, I can control what gets stored in Supermemory
- As a creator, I can customize notification preferences
- As a creator, I can log out or delete my account

**Acceptance:**
- FAQ CRUD operations work
- AI toggles disable features correctly
- Privacy controls respected
- Notification settings apply
- Logout clears local data

**Technical Dependencies:**
- Epic 9 (FAQ library)
- All AI epics (toggles)
- Supermemory API (privacy controls)

---

### Epic 16: Accessibility & Polish
**Phase:** Final (Day 7)
**Priority:** P2 (Important)

**What It Does:**
- VoiceOver support
- Dynamic Type support
- Color contrast compliance
- Smooth animations
- Loading states
- Error handling

**Key User Stories:**
- As a visually impaired creator, I can use VoiceOver to navigate the app
- As a creator, text scales with my system preferences
- As a creator, the app feels polished and professional
- As a creator, loading states don't block my workflow
- As a creator, errors are clear and actionable

**Acceptance:**
- All screens support VoiceOver
- Dynamic Type works throughout
- WCAG AA contrast compliance
- 60fps animations
- Loading states for all async operations
- Error messages clear and helpful

**Technical Dependencies:**
- All UI epics

---

### 16.2 Epic Dependency Map

```
Foundation (Epic 1)
    ↓
Core Messaging (Epic 2) → Group Chat (Epic 4)
    ↓                          ↓
Media Support (Epic 3)    Push Notifications (Epic 5)
    ↓
─────────────── MVP COMPLETE ───────────────
    ↓
AI Agent Framework (Epic 6)
    ↓
    ├→ Auto-Categorization (Epic 7)
    ├→ Smart Reply Draft (Epic 8) → Context-Aware Smart Replies (Epic 13)
    ├→ FAQ Auto-Responder (Epic 9)
    ├→ Sentiment Analysis (Epic 10)
    ├→ Opportunity Scoring (Epic 11)
    └→ Contextual AI Actions (Epic 12)
    ↓
─────────────── EARLY COMPLETE ───────────────
    ↓
Onboarding (Epic 14)
Settings (Epic 15)
Accessibility & Polish (Epic 16)
    ↓
─────────────── FINAL COMPLETE ───────────────
```

---

### 16.3 Notes on Epic Structure

**Vertical Slices:**
- Each epic delivers working, testable functionality
- No "backend epic" separate from "frontend epic"
- Each epic includes: UI, business logic, data persistence, tests

**Incremental Development:**
- Later epics build on earlier ones
- Dependencies clearly defined
- Can pivot/reprioritize based on learnings

**Testing Per Epic:**
- Each epic has acceptance criteria
- Integration tests run after epic completion
- MVP, Early, and Final phases have comprehensive test scenarios

**Epic Breakdown Coming:**
- Each epic will be broken into detailed user stories
- User stories will have technical tasks
- Tasks estimated and tracked in sprint board

### Recommended Claude Code Workflow

**1. Feature Planning:**
```bash
claude-code "Create implementation plan for message categorization
following PRD specs"
```

**2. Generate File Skeletons:**
```bash
claude-code "Generate MessageCategoryViewModel skeleton with
all methods, following 500-line limit"
```

**3. Implement Incrementally:**
```bash
claude-code "Implement loadMessages() in ConversationListViewModel
using async/await patterns"
```

**4. Add Tests:**
```bash
claude-code "Create unit tests for MessageThreadViewModel.sendMessage()"
```

**5. Review and Refactor:**
```bash
claude-code "Review MessageThreadView.swift and suggest refactorings
to stay under 500 lines"
```

### Claude Code Best Practices

**✅ DO:**
- Provide context from PRD sections
- Reference specific file names
- Request refactoring before 500 lines
- Ask for documentation headers
- Request test cases alongside implementation

**❌ DON'T:**
- Generate entire features at once
- Skip Swift 6 concurrency requirements
- Ignore documentation
- Let files exceed 500 lines

---

## Document Version History

| Version | Date       | Author | Changes |
|---------|------------|--------|---------|
| 1.0     | 2025-10-20 | Original | Initial PRD |
| 2.0     | 2025-10-20 | PM Agent | AI-First rewrite with Swift 6 standards |

---

**END OF PRODUCT REQUIREMENTS DOCUMENT v2.0**

*This PRD is designed for AI-first development with Claude Code. All specifications follow maximum modularity, clear documentation, and maintainability principles.*