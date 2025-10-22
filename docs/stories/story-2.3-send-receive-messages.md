---
# Story 2.3: Send and Receive Messages

id: STORY-2.3
title: "Send and Receive Messages"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P0  # Critical - Core messaging functionality
estimate: 8  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 1-2  # Day 1-2 MVP

---

## Description

**As a** user
**I need** to send and receive messages in real-time
**So that** I can communicate with others instantly

This story implements the core messaging functionality with sub-100ms optimistic UI, <10ms RTDB sync latency, real-time SSE streaming, message validation, and WhatsApp-quality user experience.

**Performance Targets:**
- Sub-100ms optimistic UI (instant send feedback)
- <10ms RTDB sync latency
- Real-time message delivery via SSE streaming
- Scroll-to-bottom with animation
- Auto-focus keyboard on appear

---

## Acceptance Criteria

**This story is complete when:**

- [ ] User can type message in text input field (multi-line, 1-5 lines)
- [ ] Tapping "Send" button delivers message **instantly** (optimistic UI <100ms)
- [ ] Sent messages appear immediately in chat thread
- [ ] Messages show delivery status (pending → sent → delivered → read)
- [ ] Incoming messages appear in real-time via RTDB SSE streaming (<10ms)
- [ ] Messages persist locally (SwiftData) and sync to RTDB
- [ ] Failed messages show retry button with red exclamation icon
- [ ] Character counter shows remaining characters (max 10,000)
- [ ] **Message validation:** Empty messages rejected, max 10,000 chars, UTF-8 encoding
- [ ] **Message ordering:** Server-assigned timestamps and sequence numbers
- [ ] **Duplicate detection:** Prevent duplicate messages from network retries
- [ ] **Scroll-to-bottom:** Auto-scroll to latest message with animation
- [ ] **Keyboard handling:** Auto-show on appear, dismiss on send, toolbar with send button
- [ ] **Haptic feedback:** Light impact on send success, notification haptic on failure
- [ ] **Accessibility:** VoiceOver announces new messages, proper labels

---

## Technical Tasks

**Implementation steps:**

1. **Create MessageThreadView with @Query and keyboard handling**
   - File: `sorted/Views/Chat/MessageThreadView.swift`
   - Use SwiftData `@Query` to fetch messages for conversation
   - Sort by `localCreatedAt` (primary), `serverTimestamp` (secondary), `sequenceNumber` (tertiary)
   - Auto-focus keyboard on appear: `isInputFocused = true`
   - ScrollViewReader for programmatic scroll-to-bottom
   - See RTDB Code Examples lines 767-900

2. **Create MessageThreadViewModel with RTDB SSE streaming**
   - File: `sorted/ViewModels/MessageThreadViewModel.swift`
   - Method: `sendMessage(text:)` with optimistic UI
   - Method: `startRealtimeListener()` - observe `.childAdded` and `.childChanged`
   - Method: `stopRealtimeListener()` - cleanup on view disappear
   - Method: `markAsRead()` - update all unread messages
   - See RTDB Code Examples lines 904-1113

3. **Create MessageComposerView with character counter**
   - File: `sorted/Views/Chat/MessageComposerView.swift`
   - Multi-line TextField: `.lineLimit(1...5)`
   - Character counter: shows when > 90% of limit (9,000 chars)
   - Send button: disabled when empty or over limit
   - Submit label: `.submitLabel(.send)` for keyboard "Send" button
   - See RTDB Code Examples lines 1117-1192

4. **Create MessageEntity (SwiftData Model)**
   - File: `sorted/Models/MessageEntity.swift`
   - Properties: id, conversationID, senderID, text, localCreatedAt, serverTimestamp, sequenceNumber, status, syncStatus, retryCount, attachments
   - Two timestamps: `localCreatedAt` (display) and `serverTimestamp` (ordering)
   - SyncStatus enum: `.pending`, `.synced`, `.failed`
   - MessageStatus enum: `.sent`, `.delivered`, `.read`
   - See RTDB Code Examples lines 1196-1251

5. **Create MessageValidator utility**
   - File: `sorted/Utilities/MessageValidator.swift`
   - Validate: empty messages, max length (10,000), UTF-8 encoding
   - Throw ValidationError with descriptive messages
   - See RTDB Code Examples lines 1254-1295

6. **Implement RTDB real-time listener**
   - Observe `.childAdded` for new messages
   - Observe `.childChanged` for status updates (delivered → read)
   - Duplicate detection: check if message exists locally before inserting
   - Handle incoming messages on @MainActor
   - See RTDB Code Examples lines 986-1099

7. **Implement optimistic UI message sending**
   - Generate Firebase server-generated ID: `messagesRef.childByAutoId()`
   - Create MessageEntity with `syncStatus = .pending`
   - Insert into SwiftData immediately (optimistic UI)
   - Sync to RTDB in background Task
   - Update `syncStatus = .synced` on success or `.failed` on error
   - See RTDB Code Examples lines 937-984

8. **Add scroll-to-bottom logic**
   - Use ScrollViewReader with `.scrollTo(id, anchor: .bottom)`
   - Trigger on view appear
   - Trigger on messages.count change
   - Animate with `withAnimation`

9. **Add VoiceOver accessibility**
   - Message arrival announcement: `UIAccessibility.post(notification: .announcement, argument: "New message: \(text)")`
   - Message bubble accessibility labels
   - TextField and Send button labels

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Views/Chat/MessageThreadView.swift (create)
sorted/Views/Chat/MessageComposerView.swift (create)
sorted/ViewModels/MessageThreadViewModel.swift (create)
sorted/Models/MessageEntity.swift (create)
sorted/Utilities/MessageValidator.swift (create)
sorted/Services/MessageService.swift (create)
sorted/Views/Chat/ConversationListView.swift (modify - navigation to MessageThreadView)
```

### Code Examples

**MessageThreadView.swift (from RTDB Code Examples lines 767-900):**

```swift
import SwiftUI
import SwiftData

struct MessageThreadView: View {
    let conversation: ConversationEntity

    @Environment(\.modelContext) private var modelContext

    // Query messages for this conversation sorted by server timestamp
    @Query private var messages: [MessageEntity]

    @StateObject private var viewModel: MessageThreadViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    init(conversation: ConversationEntity) {
        self.conversation = conversation

        // Query messages for this conversation
        let conversationID = conversation.id
        _messages = Query(
            filter: #Predicate<MessageEntity> { message in
                message.conversationID == conversationID
            },
            sort: [
                // ✅ FIXED: Sort by localCreatedAt first (never nil)
                // See Pattern 4 in Epic 2: Null-Safe Sorting
                SortDescriptor(\MessageEntity.localCreatedAt, order: .forward),
                SortDescriptor(\MessageEntity.serverTimestamp, order: .forward),
                SortDescriptor(\MessageEntity.sequenceNumber, order: .forward)
            ]
        )

        // Initialize ViewModel
        let context = ModelContext(AppContainer.shared.modelContainer)
        _viewModel = StateObject(wrappedValue: MessageThreadViewModel(
            conversationID: conversationID,
            modelContext: context
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Network status banner
            if !networkMonitor.isConnected {
                NetworkStatusBanner()
            }

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                    isInputFocused = true // Auto-focus keyboard
                }
                .onChange(of: messages.count) { oldCount, newCount in
                    scrollToBottom(proxy: proxy)

                    // VoiceOver announcement for new messages
                    if newCount > oldCount, let newMessage = messages.last {
                        if newMessage.senderID != AuthService.shared.currentUserID {
                            UIAccessibility.post(
                                notification: .announcement,
                                argument: "New message: \(newMessage.text)"
                            )
                        }
                    }
                }
            }

            // Message input composer
            MessageComposerView(
                text: $messageText,
                characterLimit: 10_000,
                onSend: {
                    await sendMessage()
                }
            )
            .focused($isInputFocused)
        }
        .navigationTitle(conversation.recipientDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startRealtimeListener()
            await viewModel.markAsRead()
        }
        .onDisappear {
            viewModel.stopRealtimeListener()
        }
    }

    // MARK: - Private Methods

    private func sendMessage() async {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate message
        do {
            try MessageValidator.validate(trimmed)
        } catch {
            // Show error: Empty or too long
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }

        let text = messageText
        messageText = "" // Clear input immediately (optimistic UI)

        // Send message
        await viewModel.sendMessage(text: text)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
```

**MessageThreadViewModel.swift (from RTDB Code Examples lines 904-1113):**

```swift
import SwiftUI
import SwiftData
import FirebaseDatabase

@MainActor
final class MessageThreadViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Private Properties

    private let conversationID: String
    private let messageService: MessageService
    private let modelContext: ModelContext

    private var sseTask: Task<Void, Never>?
    private var messagesRef: DatabaseReference

    // MARK: - Initialization

    init(conversationID: String, modelContext: ModelContext) {
        self.conversationID = conversationID
        self.messageService = MessageService.shared
        self.modelContext = modelContext
        self.messagesRef = Database.database().reference().child("messages/\(conversationID)")
    }

    // MARK: - Public Methods

    /// Sends a message with optimistic UI and RTDB sync
    func sendMessage(text: String) async {
        // Create message with client-side timestamp (for immediate display)
        let messageID = UUID().uuidString
        let message = MessageEntity(
            id: messageID,
            conversationID: conversationID,
            senderID: AuthService.shared.currentUserID,
            text: text,
            localCreatedAt: Date(), // Client timestamp for display
            serverTimestamp: nil, // Will be set by RTDB
            sequenceNumber: nil, // Will be set by RTDB
            status: .sent,
            syncStatus: .pending,
            attachments: []
        )

        // Save locally first (optimistic UI)
        modelContext.insert(message)
        try? modelContext.save()

        // Sync to RTDB in background
        Task { @MainActor in
            do {
                // Push to RTDB (generates server timestamp)
                let messageData: [String: Any] = [
                    "senderID": message.senderID,
                    "text": message.text,
                    "serverTimestamp": ServerValue.timestamp(),
                    "status": "sent"
                ]

                try await messagesRef.child(messageID).setValue(messageData)

                // Update local sync status
                message.syncStatus = .synced
                try? modelContext.save()

                // Update conversation last message
                await updateConversationLastMessage(text: text)

            } catch {
                // Mark as failed
                message.syncStatus = .failed
                self.error = error
                try? modelContext.save()
            }
        }
    }

    /// Starts real-time RTDB listener for messages
    func startRealtimeListener() async {
        sseTask = Task { @MainActor in
            // Listen for new messages via RTDB observe
            messagesRef
                .queryOrdered(byChild: "serverTimestamp")
                .queryLimited(toLast: 100) // Load recent 100 messages
                .observe(.childAdded) { [weak self] snapshot in
                    guard let self = self else { return }

                    Task { @MainActor in
                        await self.handleIncomingMessage(snapshot)
                    }
                }

            // Listen for message status updates
            messagesRef.observe(.childChanged) { [weak self] snapshot in
                guard let self = self else { return }

                Task { @MainActor in
                    await self.handleMessageUpdate(snapshot)
                }
            }
        }
    }

    /// Stops real-time listener and cleans up
    func stopRealtimeListener() {
        sseTask?.cancel()
        sseTask = nil
        messagesRef.removeAllObservers()
    }

    /// Marks all unread messages in conversation as read
    func markAsRead() async {
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.conversationID == conversationID &&
                message.senderID != AuthService.shared.currentUserID &&
                message.status != .read
            }
        )

        guard let messages = try? modelContext.fetch(descriptor) else { return }

        for message in messages {
            message.status = .read

            // Update RTDB
            Task { @MainActor in
                try? await messagesRef.child(message.id).updateChildValues([
                    "status": "read"
                ])
            }
        }

        try? modelContext.save()
    }

    // MARK: - Private Methods

    private func handleIncomingMessage(_ snapshot: DataSnapshot) async {
        guard let messageData = snapshot.value as? [String: Any] else { return }

        let messageID = snapshot.key

        // Check if message already exists locally (duplicate detection)
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        let existing = try? modelContext.fetch(descriptor).first

        if existing == nil {
            // New message from RTDB
            let message = MessageEntity(
                id: messageID,
                conversationID: conversationID,
                senderID: messageData["senderID"] as? String ?? "",
                text: messageData["text"] as? String ?? "",
                localCreatedAt: Date(), // Use current time for display
                serverTimestamp: Date(
                    timeIntervalSince1970: messageData["serverTimestamp"] as? TimeInterval ?? 0
                ),
                sequenceNumber: messageData["sequenceNumber"] as? Int64,
                status: MessageStatus(rawValue: messageData["status"] as? String ?? "sent") ?? .sent,
                syncStatus: .synced,
                attachments: []
            )

            modelContext.insert(message)
            try? modelContext.save()
        }
    }

    private func handleMessageUpdate(_ snapshot: DataSnapshot) async {
        guard let messageData = snapshot.value as? [String: Any] else { return }

        let messageID = snapshot.key

        // Find existing message
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        guard let existing = try? modelContext.fetch(descriptor).first else { return }

        // Update status (delivered → read)
        if let statusString = messageData["status"] as? String,
           let status = MessageStatus(rawValue: statusString) {
            existing.status = status
            try? modelContext.save()
        }
    }

    private func updateConversationLastMessage(text: String) async {
        let conversationRef = Database.database().reference().child("conversations/\(conversationID)")

        try? await conversationRef.updateChildValues([
            "lastMessage": text,
            "lastMessageTimestamp": ServerValue.timestamp()
        ])
    }

    deinit {
        stopRealtimeListener()
    }
}
```

**MessageComposerView.swift (from RTDB Code Examples lines 1117-1192):**

```swift
import SwiftUI

struct MessageComposerView: View {
    @Binding var text: String
    let characterLimit: Int
    let onSend: () async -> Void

    @FocusState private var isFocused: Bool
    @State private var isLoading = false

    var remainingCharacters: Int {
        characterLimit - text.count
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .focused($isFocused)
                    .onSubmit {
                        Task {
                            await send()
                        }
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message here")

                // Send button
                Button {
                    Task {
                        await send()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .accessibilityLabel("Send message")
                .accessibilityHint("Send the message you typed")
            }
            .padding(.horizontal)

            // Character counter (only show when near limit)
            if text.count > characterLimit * 9 / 10 {
                HStack {
                    Spacer()
                    Text("\(remainingCharacters) characters remaining")
                        .font(.caption)
                        .foregroundColor(remainingCharacters < 0 ? .red : .secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func send() async {
        isLoading = true
        await onSend()
        isLoading = false
        isFocused = true // Keep keyboard focused
    }
}
```

**MessageEntity.swift (from RTDB Code Examples lines 1196-1251):**

```swift
import Foundation
import SwiftData

@Model
final class MessageEntity {
    var id: String
    var conversationID: String
    var senderID: String
    var text: String

    // Timestamps
    var localCreatedAt: Date // Client timestamp for display
    var serverTimestamp: Date? // Server timestamp for ordering
    var sequenceNumber: Int64? // Server-assigned sequence number

    // Status
    var status: MessageStatus
    var syncStatus: SyncStatus
    var retryCount: Int

    // Attachments (future)
    var attachments: [String]

    init(
        id: String,
        conversationID: String,
        senderID: String,
        text: String,
        localCreatedAt: Date,
        serverTimestamp: Date? = nil,
        sequenceNumber: Int64? = nil,
        status: MessageStatus,
        syncStatus: SyncStatus,
        attachments: [String] = []
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.text = text
        self.localCreatedAt = localCreatedAt
        self.serverTimestamp = serverTimestamp
        self.sequenceNumber = sequenceNumber
        self.status = status
        self.syncStatus = syncStatus
        self.retryCount = 0
        self.attachments = attachments
    }
}

enum MessageStatus: String, Codable {
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
}
```

**MessageValidator.swift (from RTDB Code Examples lines 1254-1295):**

```swift
import Foundation

struct MessageValidator {
    static let maxLength = 10_000
    static let minLength = 1

    enum ValidationError: LocalizedError {
        case empty
        case tooLong
        case invalidCharacters

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Message cannot be empty"
            case .tooLong:
                return "Message is too long (max 10,000 characters)"
            case .invalidCharacters:
                return "Message contains invalid characters"
            }
        }
    }

    static func validate(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= minLength else {
            throw ValidationError.empty
        }

        guard trimmed.count <= maxLength else {
            throw ValidationError.tooLong
        }

        // UTF-8 encoding validation (optional)
        guard trimmed.data(using: .utf8) != nil else {
            throw ValidationError.invalidCharacters
        }
    }
}
```

### RTDB Data Structure

```json
{
  "messages": {
    "{conversationID}": {
      "{messageID}": {
        "senderID": "user123",
        "text": "Hello world!",
        "serverTimestamp": 1704067200000,
        "sequenceNumber": 42,
        "status": "sent"
      }
    }
  },
  "conversations": {
    "{conversationID}": {
      "lastMessage": "Hello world!",
      "lastMessageTimestamp": 1704067200000
    }
  }
}
```

### Dependencies

**Required:**
- Story 2.0 (FCM/APNs Setup) - complete
- Story 2.1 (Create New Conversation) - provides ConversationEntity
- Story 2.2 (Display Conversation List) - navigation from conversation list
- AppContainer.shared.modelContainer configured
- NetworkMonitor injected via environmentObject

**Blocks:**
- Story 2.4 (Message Delivery Status Indicators) - uses MessageBubbleView
- Story 2.5 (Offline Queue) - syncs pending messages
- Story 2.6 (Typing Indicators) - adds typing state to MessageThreadView

**External:**
- Firebase Realtime Database rules allow message writes
- AuthService.shared.currentUserID available

---

## Testing & Validation

### Test Procedure

1. **Send Message (Happy Path):**
   - Open conversation
   - Type "Hello world" in message composer
   - Tap Send button
   - Verify message appears instantly (<100ms)
   - Verify message shows "clock" icon (pending)
   - Wait 1 second
   - Verify icon changes to "checkmark" (synced)

2. **Receive Message (Real-time):**
   - Device A: Send message "Hello from A"
   - Device B: Verify message appears within 10ms
   - Verify message displays with correct timestamp
   - Verify scroll-to-bottom animates to new message

3. **Message Validation:**
   - Try to send empty message
   - Verify error haptic feedback (no message sent)
   - Type 10,001 characters
   - Verify character counter turns red
   - Verify send button disabled

4. **Keyboard Handling:**
   - Open conversation
   - Verify keyboard appears automatically
   - Type message and tap Send
   - Verify keyboard stays focused (doesn't dismiss)
   - Tap outside message composer
   - Verify keyboard dismisses

5. **Scroll Behavior:**
   - Load conversation with 50+ messages
   - Verify scrolled to bottom on appear
   - Send new message
   - Verify auto-scroll to new message with animation

6. **Offline Messaging:**
   - Disable network
   - Send 3 messages
   - Verify all 3 appear with "clock" icon
   - Enable network
   - Verify messages sync and status updates to "checkmark"

7. **Duplicate Detection:**
   - Simulate network retry (send same messageID twice)
   - Verify only 1 message appears in list

8. **Accessibility:**
   - Enable VoiceOver
   - Open conversation
   - Receive new message
   - Verify VoiceOver announces "New message: [text]"

### Success Criteria

- [ ] Builds without errors
- [ ] Messages send instantly (optimistic UI <100ms)
- [ ] Messages sync to RTDB within 1 second
- [ ] Real-time message delivery works (<10ms SSE latency)
- [ ] Empty messages rejected with error haptic
- [ ] Long messages (>10,000 chars) rejected
- [ ] Character counter shows correctly
- [ ] Keyboard auto-focuses on appear
- [ ] Scroll-to-bottom works with animation
- [ ] VoiceOver announces new messages
- [ ] Failed messages show retry button (Story 2.4)
- [ ] Duplicate messages prevented

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 1661-2199)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 763-1295)
- Pattern 3: Message ID Generation - Epic 2 lines 283-351
- Pattern 4: Null-Safe Sorting - Epic 2 lines 353-402

**PRD Sections:**
- Real-Time Messaging
- Message Delivery

**Implementation Guides:**
- SwiftData Implementation Guide (docs/swiftdata-implementation-guide.md) - Section 7 (Message Sync Strategy)
- Architecture Doc (docs/architecture.md) - Section 5.4 (Real-time Message Delivery)

**Context7 References:**
- `/mobizt/firebaseclient` (topic: "RTDB SSE streaming push setValue")
- `/pointfreeco/swift-concurrency-extras` (topic: "@MainActor concurrent Task")

**Related Stories:**
- Story 2.2 (Conversation List) - navigation source
- Story 2.4 (Delivery Status) - message status indicators
- Story 2.5 (Offline Queue) - retry failed messages

---

## Notes & Considerations

### Implementation Notes

**Pattern 3: Firebase Server-Generated Message IDs (CRITICAL):**
```swift
// ❌ WRONG: Client UUID can create duplicates on retry
let messageID = UUID().uuidString

// ✅ CORRECT: Firebase generates unique IDs
let newMessageRef = messagesRef.childByAutoId()
let messageID = newMessageRef.key! // Guaranteed unique
```

**Pattern 4: Null-Safe Sorting (from Epic 2):**
```swift
// ✅ Sort by localCreatedAt first (never nil)
sort: [
    SortDescriptor(\MessageEntity.localCreatedAt, order: .forward),      // Primary
    SortDescriptor(\MessageEntity.serverTimestamp, order: .forward),     // Secondary
    SortDescriptor(\MessageEntity.sequenceNumber, order: .forward)        // Tertiary
]
```

**Why Two Timestamps?**
- `localCreatedAt`: Client timestamp for immediate display (even offline)
- `serverTimestamp`: Server timestamp for authoritative ordering (prevents clock skew)

### Edge Cases

- **Empty Messages:** Reject with validation error and haptic feedback
- **Long Messages:** Character counter warns at 9,000 chars, rejects at 10,000
- **Network Retry:** Firebase-generated IDs prevent duplicates
- **Clock Skew:** Server timestamp overrides local for ordering
- **Out-of-Order Delivery:** Sequence numbers detect gaps in message stream

### Performance Considerations

- **Optimistic UI:** SwiftData insert is <1ms, UI updates instantly
- **RTDB Sync:** Background Task doesn't block UI
- **LazyVStack:** Only renders visible messages (efficient for 100+ messages)
- **ScrollViewReader:** Programmatic scrolling is smooth with animation

### Security Considerations

- RTDB security rules must validate:
  - User is authenticated
  - User is a participant in conversation
  - Message senderID matches auth.uid (prevent impersonation)
  - Message text length ≤ 10,000 characters

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 1-2 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 8
**Priority:** P0 (Critical)

---

## Story Lifecycle

- [ ] **Draft** - Story created, needs review
- [x] **Ready** - Story reviewed and ready for development ✅
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Ready
