# Epic 2: One-on-One Chat Infrastructure

**Phase:** Day 1 MVP (Core Messaging)
**Priority:** P0 (Blocker - Core Feature)
**Estimated Time:** 4-6 hours
**Epic Owner:** Development Team Lead
**Dependencies:** Epic 0 (Project Scaffolding), Epic 1 (User Authentication)

---

## Overview

Implement the core one-on-one messaging infrastructure with SwiftData local persistence, Firestore real-time sync, optimistic UI updates, and offline queue. This epic delivers the fundamental messaging experience that serves as the foundation for all AI features.

---

## What This Epic Delivers

- ✅ Real-time one-on-one messaging with Firestore listeners
- ✅ SwiftData local persistence with offline-first strategy
- ✅ Optimistic UI updates (instant message send feedback)
- ✅ Background sync coordinator with network monitoring
- ✅ Conversation list view with unread counts
- ✅ Message thread view with real-time updates
- ✅ Message input composer with character counter
- ✅ Read receipts and delivery status indicators
- ✅ Offline queue with automatic retry

---

### iOS-Specific Mobile Messaging Patterns

**This epic implements mobile-first messaging** - follow iOS messaging app conventions:

- ✅ **Keyboard Handling:** Message composer dismisses keyboard intelligently, doesn't obscure input
- ✅ **Scroll Performance:** LazyVStack for message lists, scroll to bottom on new messages with animation
- ✅ **Haptic Feedback:** Subtle haptic on message send success
- ✅ **Pull-to-Refresh:** Native iOS pattern for manual conversation sync
- ✅ **Swipe Actions:** Swipe-to-archive conversations (iOS standard)
- ✅ **Network Awareness:** Show "Offline" badge in nav bar when no connection
- ✅ **Loading States:** Skeleton screens for empty conversation lists
- ✅ **Accessibility:** VoiceOver announces new messages, proper labels for all UI
- ✅ **Safe Areas:** Message composer respects keyboard and home indicator

---

## User Stories

### Story 2.1: Create New Conversation
**As a user, I want to start a new one-on-one conversation so I can message another user.**

**Acceptance Criteria:**
- [ ] User can tap "New Message" button from conversation list
- [ ] User can select a recipient from contacts list
- [ ] New conversation appears in conversation list immediately
- [ ] Empty conversation shows placeholder text
- [ ] Conversation persists locally and syncs to Firestore
- [ ] Duplicate conversations prevented (reuse existing if recipient match)

**Technical Tasks:**
1. Create ConversationListView with NavigationStack
2. Implement "New Message" button in toolbar
3. Create RecipientPickerView to select user
4. Implement ConversationViewModel with `createConversation()` method:
   ```swift
   @MainActor
   final class ConversationViewModel: ObservableObject {
       @Published var conversations: [ConversationEntity] = []
       @Published var isLoading = false

       private let modelContext: ModelContext
       private let conversationService: ConversationService

       func createConversation(withUserID userID: String) async throws -> ConversationEntity {
           // Check for existing conversation
           let existing = try await conversationService.findConversation(
               withParticipants: [AuthService.shared.currentUserID, userID]
           )

           if let existing = existing {
               return existing
           }

           // Create new conversation
           let conversation = ConversationEntity(
               id: UUID().uuidString,
               participantIDs: [AuthService.shared.currentUserID, userID],
               lastMessage: nil,
               lastMessageTimestamp: Date(),
               unreadCount: 0,
               createdAt: Date(),
               updatedAt: Date(),
               syncStatus: .pending
           )

           // Save locally first (optimistic)
           modelContext.insert(conversation)
           try modelContext.save()

           // Sync to Firestore in background
           Task {
               try await conversationService.syncConversation(conversation)
           }

           return conversation
       }
   }
   ```
5. Create ConversationService for Firestore operations
6. Add duplicate prevention logic (check by participantIDs set)

**iOS Mobile Considerations:**
- **Keyboard Dismissal:** When navigating to conversation, automatically dismiss keyboard from previous screen
- **Loading State:** Show subtle loading indicator during conversation creation (not full-screen)
- **Haptic Feedback:** Light impact haptic when conversation created successfully
- **Error Handling:** Use native `.alert()` if duplicate detected or creation fails
- **Accessibility:** Announce "Conversation created with [user]" to VoiceOver

**References:**
- SwiftData Implementation Guide Section 3.2 (ConversationEntity)
- Architecture Doc Section 5.3 (Conversation Management)

---

### Story 2.2: Display Conversation List
**As a user, I want to see all my conversations so I can access my message threads.**

**Acceptance Criteria:**
- [ ] Conversation list shows all conversations sorted by last message timestamp
- [ ] Each conversation row displays: recipient name, last message preview, timestamp, unread count
- [ ] Unread conversations show badge with count
- [ ] List updates in real-time when new messages arrive
- [ ] Empty state shows "No conversations yet" placeholder
- [ ] Pull-to-refresh manually syncs from Firestore
- [ ] Swipe-to-delete archives conversation

**Technical Tasks:**
1. Create ConversationListView with @Query:
   ```swift
   struct ConversationListView: View {
       @Environment(\.modelContext) private var modelContext
       @Query(
           filter: #Predicate<ConversationEntity> { conversation in
               conversation.isArchived == false
           },
           sort: [SortDescriptor(\ConversationEntity.lastMessageTimestamp, order: .reverse)]
       ) private var conversations: [ConversationEntity]

       @StateObject private var viewModel: ConversationViewModel

       var body: some View {
           NavigationStack {
               List {
                   if conversations.isEmpty {
                       ContentUnavailableView(
                           "No Conversations",
                           systemImage: "message",
                           description: Text("Tap + to start messaging")
                       )
                   } else {
                       ForEach(conversations) { conversation in
                           NavigationLink(value: conversation) {
                               ConversationRowView(conversation: conversation)
                           }
                           .swipeActions(edge: .trailing) {
                               Button(role: .destructive) {
                                   archiveConversation(conversation)
                               } label: {
                                   Label("Archive", systemImage: "archivebox")
                               }
                           }
                       }
                   }
               }
               .navigationTitle("Messages")
               .navigationDestination(for: ConversationEntity.self) { conversation in
                   MessageThreadView(conversation: conversation)
               }
               .toolbar {
                   ToolbarItem(placement: .primaryAction) {
                       Button(action: { showRecipientPicker = true }) {
                           Image(systemName: "square.and.pencil")
                       }
                   }
               }
               .refreshable {
                   await viewModel.syncConversations()
               }
               .task {
                   await viewModel.startRealtimeListener()
               }
           }
       }
   }
   ```

2. Create ConversationRowView component:
   ```swift
   struct ConversationRowView: View {
       let conversation: ConversationEntity
       @State private var recipientUser: UserEntity?

       var body: some View {
           HStack(spacing: 12) {
               // Profile picture
               AsyncImage(url: URL(string: recipientUser?.profilePictureURL ?? "")) { image in
                   image.resizable().scaledToFill()
               } placeholder: {
                   Circle().fill(Color.gray.opacity(0.3))
               }
               .frame(width: 56, height: 56)
               .clipShape(Circle())

               VStack(alignment: .leading, spacing: 4) {
                   HStack {
                       Text(recipientUser?.displayName ?? "Unknown")
                           .font(.system(size: 17, weight: .semibold))

                       Spacer()

                       Text(conversation.lastMessageTimestamp, style: .relative)
                           .font(.system(size: 14))
                           .foregroundColor(.secondary)
                   }

                   HStack {
                       Text(conversation.lastMessage ?? "No messages yet")
                           .font(.system(size: 15))
                           .foregroundColor(.secondary)
                           .lineLimit(2)

                       Spacer()

                       if conversation.unreadCount > 0 {
                           ZStack {
                               Circle()
                                   .fill(Color.blue)
                                   .frame(width: 20, height: 20)

                               Text("\(conversation.unreadCount)")
                                   .font(.system(size: 12, weight: .bold))
                                   .foregroundColor(.white)
                           }
                       }
                   }
               }
           }
           .padding(.vertical, 8)
           .task {
               await loadRecipientUser()
           }
       }
   }
   ```

3. Implement real-time Firestore listener in ConversationService
4. Add pull-to-refresh with syncConversations()
5. Implement swipe-to-archive functionality

**iOS Mobile Considerations:**
- **Pull-to-Refresh:** Use native `.refreshable { }` modifier (shows iOS spinner at top)
- **Swipe Actions:** Use `.swipeActions(edge: .trailing)` for archive (iOS standard right swipe)
- **List Performance:** Use `LazyVStack` or native `List` for smooth scrolling with large conversation lists
- **Empty State:** Use `ContentUnavailableView` (iOS 17+) for "No conversations" placeholder
- **Unread Badge:** Use native badge view or ZStack with Circle for unread count indicators
- **Accessibility:** Each conversation row should have proper accessibility labels including unread status
- **Safe Areas:** Ensure list respects top safe area (notch/Dynamic Island)

**References:**
- UX Design Doc Section 3.1 (Conversation List Screen)
- SwiftData Implementation Guide Section 6.2 (@Query usage)

---

### Story 2.3: Send and Receive Messages
**As a user, I want to send and receive messages in real-time so I can communicate with others.**

**Acceptance Criteria:**
- [ ] User can type message in text input field
- [ ] Tapping "Send" button delivers message instantly (optimistic UI)
- [ ] Sent messages appear immediately in chat thread
- [ ] Messages show delivery status (sending → sent → delivered → read)
- [ ] Incoming messages appear in real-time without refresh
- [ ] Messages persist locally and sync to Firestore
- [ ] Failed messages show retry button
- [ ] Character counter shows remaining characters (max 10,000)

**Technical Tasks:**
1. Create MessageThreadView with @Query:
   ```swift
   struct MessageThreadView: View {
       let conversation: ConversationEntity

       @Environment(\.modelContext) private var modelContext
       @Query private var messages: [MessageEntity]
       @StateObject private var viewModel: MessageThreadViewModel
       @State private var messageText = ""
       @State private var scrollProxy: ScrollViewProxy?

       init(conversation: ConversationEntity) {
           self.conversation = conversation

           // Query messages for this conversation
           let conversationID = conversation.id
           _messages = Query(
               filter: #Predicate<MessageEntity> { message in
                   message.conversationID == conversationID
               },
               sort: [SortDescriptor(\MessageEntity.createdAt, order: .forward)]
           )

           _viewModel = StateObject(wrappedValue: MessageThreadViewModel(
               conversationID: conversationID
           ))
       }

       var body: some View {
           VStack(spacing: 0) {
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
                   }
                   .onChange(of: messages.count) { _, _ in
                       scrollToBottom(proxy: proxy)
                   }
               }

               // Message input composer
               MessageComposerView(
                   text: $messageText,
                   onSend: {
                       await sendMessage()
                   }
               )
           }
           .navigationTitle(conversation.recipientDisplayName)
           .navigationBarTitleDisplayMode(.inline)
           .task {
               await viewModel.startRealtimeListener()
               await viewModel.markAsRead()
           }
       }

       private func sendMessage() async {
           guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
               return
           }

           let text = messageText
           messageText = "" // Clear input immediately

           await viewModel.sendMessage(text: text)
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

2. Create MessageThreadViewModel:
   ```swift
   @MainActor
   final class MessageThreadViewModel: ObservableObject {
       @Published var isLoading = false
       @Published var error: Error?

       private let conversationID: String
       private let messageService: MessageService
       private let modelContext: ModelContext
       private var listener: ListenerRegistration?

       init(conversationID: String) {
           self.conversationID = conversationID
           self.messageService = MessageService.shared
           self.modelContext = ModelContext(AppContainer.shared.modelContainer)
       }

       func sendMessage(text: String) async {
           let message = MessageEntity(
               id: UUID().uuidString,
               conversationID: conversationID,
               senderID: AuthService.shared.currentUserID,
               text: text,
               createdAt: Date(),
               status: .sent,
               syncStatus: .pending,
               attachments: []
           )

           // Save locally first (optimistic UI)
           modelContext.insert(message)
           try? modelContext.save()

           // Sync to Firestore in background
           Task.detached {
               do {
                   try await self.messageService.syncMessage(message)

                   await MainActor.run {
                       message.syncStatus = .synced
                       try? self.modelContext.save()
                   }
               } catch {
                   await MainActor.run {
                       message.syncStatus = .failed
                       try? self.modelContext.save()
                   }
               }
           }

           // Update conversation lastMessage
           await updateConversationLastMessage(text: text)
       }

       func startRealtimeListener() async {
           listener = messageService.listenToMessages(
               conversationID: conversationID
           ) { [weak self] messages in
               guard let self = self else { return }

               Task { @MainActor in
                   for message in messages {
                       // Check if message already exists locally
                       let descriptor = FetchDescriptor<MessageEntity>(
                           predicate: #Predicate { $0.id == message.id }
                       )

                       let existing = try? self.modelContext.fetch(descriptor).first

                       if existing == nil {
                           // New message from server
                           self.modelContext.insert(message)
                       } else {
                           // Update existing message (status change, etc.)
                           existing?.status = message.status
                       }

                       try? self.modelContext.save()
                   }
               }
           }
       }

       func markAsRead() async {
           // Mark all messages in this conversation as read
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

               // Update Firestore
               Task.detached {
                   try? await self.messageService.markMessageAsRead(messageID: message.id)
               }
           }

           try? modelContext.save()
       }
   }
   ```

3. Create MessageBubbleView component with status indicators
4. Create MessageComposerView with character counter
5. Implement MessageService for Firestore operations

**iOS Mobile Considerations:**
- **Keyboard Management:**
  - Dismiss keyboard on send with `.focused()` binding
  - Automatically show keyboard when view appears for quick messaging
  - Use `.submitLabel(.send)` on text field for "Send" keyboard button
- **Scroll Behavior:**
  - Auto-scroll to bottom when new message arrives (with animation)
  - Use `ScrollViewReader` for programmatic scrolling
  - Maintain scroll position when keyboard appears/disappears
- **Message Composer:**
  - Character counter shows remaining chars (e.g., "9,850 / 10,000")
  - Multi-line text input expands up to 5 lines, then scrolls
  - Use `.lineLimit(1...5)` for text field
- **Haptic Feedback:**
  - Light impact haptic on message send success
  - Error haptic if send fails
- **Loading States:**
  - Show inline "sending..." status in message bubble while uploading
  - Use subtle progress indicator for long network delays
- **Accessibility:**
  - VoiceOver reads messages in chronological order
  - Announce new incoming messages: "New message from [sender]"
  - Label send button as "Send message"
- **Safe Areas:**
  - Message composer respects keyboard height and home indicator
  - Use `.safeAreaInset(edge: .bottom)` for composer

**References:**
- SwiftData Implementation Guide Section 7 (Message Sync Strategy)
- Architecture Doc Section 5.4 (Real-time Message Delivery)

---

### Story 2.4: Message Delivery Status Indicators
**As a user, I want to see message delivery status so I know when my messages are received and read.**

**Acceptance Criteria:**
- [ ] Messages show status: Sending (clock icon), Sent (checkmark), Delivered (double checkmark), Read (blue double checkmark)
- [ ] Failed messages show red exclamation with retry button
- [ ] Status updates in real-time as message progresses through delivery stages
- [ ] Only user's own messages show status indicators
- [ ] Status appears below message bubble with timestamp

**Technical Tasks:**
1. Create MessageBubbleView with status rendering:
   ```swift
   struct MessageBubbleView: View {
       let message: MessageEntity
       private let currentUserID = AuthService.shared.currentUserID

       var isFromCurrentUser: Bool {
           message.senderID == currentUserID
       }

       var body: some View {
           HStack {
               if isFromCurrentUser { Spacer() }

               VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                   // Message bubble
                   Text(message.text)
                       .padding(.horizontal, 16)
                       .padding(.vertical, 10)
                       .background(
                           isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2)
                       )
                       .foregroundColor(isFromCurrentUser ? .white : .primary)
                       .cornerRadius(18)

                   // Timestamp + status
                   HStack(spacing: 4) {
                       Text(message.createdAt, style: .time)
                           .font(.system(size: 12))
                           .foregroundColor(.secondary)

                       if isFromCurrentUser {
                           statusIcon
                       }
                   }
               }

               if !isFromCurrentUser { Spacer() }
           }
       }

       @ViewBuilder
       private var statusIcon: some View {
           switch message.syncStatus {
           case .pending:
               Image(systemName: "clock")
                   .font(.system(size: 12))
                   .foregroundColor(.secondary)
           case .failed:
               Image(systemName: "exclamationmark.circle.fill")
                   .font(.system(size: 12))
                   .foregroundColor(.red)
           case .synced:
               switch message.status {
               case .sent, .delivered:
                   Image(systemName: "checkmark")
                       .font(.system(size: 12))
                       .foregroundColor(.secondary)
               case .read:
                   Image(systemName: "checkmark")
                       .font(.system(size: 12))
                       .foregroundColor(.blue)
               }
           }
       }
   }
   ```

2. Add status update logic in MessageService
3. Implement retry button for failed messages
4. Add Firestore listener for status changes

**References:**
- UX Design Doc Section 3.2 (Message Thread Screen)

---

### Story 2.5: Offline Queue and Background Sync
**As a user, I want my messages to send automatically when I regain connectivity so I don't lose messages.**

**Acceptance Criteria:**
- [ ] Messages sent while offline are queued locally
- [ ] Queue automatically processes when connection restored
- [ ] Network status indicator shows "Offline" in navigation bar
- [ ] Failed messages retry with exponential backoff (3 attempts)
- [ ] User can manually retry failed messages
- [ ] Sync progress visible for large message queues

**Technical Tasks:**
1. Create SyncCoordinator service:
   ```swift
   import Network

   @MainActor
   final class SyncCoordinator: ObservableObject {
       static let shared = SyncCoordinator()

       @Published var isOnline = true
       @Published var isSyncing = false
       @Published var pendingCount = 0

       private let monitor = NWPathMonitor()
       private let queue = DispatchQueue(label: "com.sorted.sync")
       private let modelContext: ModelContext

       init() {
           self.modelContext = ModelContext(AppContainer.shared.modelContainer)
           setupNetworkMonitoring()
       }

       private func setupNetworkMonitoring() {
           monitor.pathUpdateHandler = { [weak self] path in
               Task { @MainActor in
                   let wasOffline = !self?.isOnline ?? false
                   self?.isOnline = path.status == .satisfied

                   // Auto-sync when connection restored
                   if wasOffline && self?.isOnline == true {
                       await self?.syncPendingMessages()
                   }
               }
           }
           monitor.start(queue: queue)
       }

       func syncPendingMessages() async {
           guard !isSyncing else { return }

           isSyncing = true
           defer { isSyncing = false }

           // Fetch pending messages
           let descriptor = FetchDescriptor<MessageEntity>(
               predicate: #Predicate { $0.syncStatus == .pending },
               sortBy: [SortDescriptor(\MessageEntity.createdAt, order: .forward)]
           )

           guard let pendingMessages = try? modelContext.fetch(descriptor) else {
               return
           }

           pendingCount = pendingMessages.count

           for message in pendingMessages {
               do {
                   try await MessageService.shared.syncMessage(message)
                   message.syncStatus = .synced
                   try? modelContext.save()
                   pendingCount -= 1
               } catch {
                   message.syncStatus = .failed
                   message.retryCount += 1

                   if message.retryCount >= 3 {
                       // Max retries exceeded
                       print("Message \(message.id) failed after 3 attempts")
                   } else {
                       // Retry with exponential backoff
                       let delay = pow(2.0, Double(message.retryCount))
                       try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                       // Retry
                       message.syncStatus = .pending
                   }

                   try? modelContext.save()
               }
           }
       }

       func retryMessage(_ message: MessageEntity) async {
           message.retryCount = 0
           message.syncStatus = .pending
           try? modelContext.save()

           await syncPendingMessages()
       }
   }
   ```

2. Add network status indicator to ConversationListView navigation bar
3. Update MessageEntity with retryCount property
4. Add manual retry button to failed messages in MessageBubbleView
5. Implement exponential backoff retry logic

**References:**
- SwiftData Implementation Guide Section 7.2 (Background Sync)
- Architecture Doc Section 6.2 (Network Resilience)

---

### Story 2.6: Real-Time Typing Indicators
**As a user, I want to see when the other person is typing so I know they're responding.**

**Acceptance Criteria:**
- [ ] "Typing..." indicator appears when recipient is typing
- [ ] Indicator disappears after 3 seconds of inactivity
- [ ] Only shows for active conversation (not in conversation list)
- [ ] Typing state syncs via Firestore in real-time
- [ ] Multiple users typing shows "2 people typing..."

**Technical Tasks:**
1. Add typing state to ConversationEntity (transient, not persisted):
   ```swift
   @Model
   final class ConversationEntity {
       // ... existing properties ...

       @Transient
       var typingUserIDs: Set<String> = []
   }
   ```

2. Create TypingIndicatorService:
   ```swift
   final class TypingIndicatorService {
       static let shared = TypingIndicatorService()

       private let db = Firestore.firestore()
       private var typingTimers: [String: Timer] = [:]

       func startTyping(conversationID: String, userID: String) {
           db.collection("conversations")
               .document(conversationID)
               .collection("typing")
               .document(userID)
               .setData([
                   "isTyping": true,
                   "timestamp": FieldValue.serverTimestamp()
               ], merge: true)

           // Auto-stop after 3 seconds
           typingTimers[conversationID]?.invalidate()
           typingTimers[conversationID] = Timer.scheduledTimer(
               withTimeInterval: 3.0,
               repeats: false
           ) { [weak self] _ in
               self?.stopTyping(conversationID: conversationID, userID: userID)
           }
       }

       func stopTyping(conversationID: String, userID: String) {
           db.collection("conversations")
               .document(conversationID)
               .collection("typing")
               .document(userID)
               .setData([
                   "isTyping": false
               ], merge: true)

           typingTimers[conversationID]?.invalidate()
           typingTimers[conversationID] = nil
       }

       func listenToTypingIndicators(
           conversationID: String,
           onChange: @escaping (Set<String>) -> Void
       ) -> ListenerRegistration {
           db.collection("conversations")
               .document(conversationID)
               .collection("typing")
               .whereField("isTyping", isEqualTo: true)
               .addSnapshotListener { snapshot, error in
                   guard let documents = snapshot?.documents else { return }

                   let typingUserIDs = Set(documents.map { $0.documentID })
                   onChange(typingUserIDs)
               }
       }
   }
   ```

3. Add typing indicator to MessageThreadView:
   ```swift
   // In MessageThreadView
   @State private var typingUserIDs: Set<String> = []

   var body: some View {
       VStack {
           ScrollView {
               // ... messages ...

               if !typingUserIDs.isEmpty {
                   HStack {
                       TypingIndicatorView()
                       Spacer()
                   }
                   .padding(.horizontal)
               }
           }

           MessageComposerView(text: $messageText, onSend: sendMessage)
               .onChange(of: messageText) { _, newValue in
                   handleTypingChange(newValue)
               }
       }
       .task {
           listener = TypingIndicatorService.shared.listenToTypingIndicators(
               conversationID: conversation.id
           ) { userIDs in
               typingUserIDs = userIDs.filter { $0 != AuthService.shared.currentUserID }
           }
       }
   }

   func handleTypingChange(_ text: String) {
       if !text.isEmpty {
           TypingIndicatorService.shared.startTyping(
               conversationID: conversation.id,
               userID: AuthService.shared.currentUserID
           )
       } else {
           TypingIndicatorService.shared.stopTyping(
               conversationID: conversation.id,
               userID: AuthService.shared.currentUserID
           )
       }
   }
   ```

4. Create TypingIndicatorView with animated dots
5. Add cleanup logic to stop typing on view disappear

**References:**
- UX Design Doc Section 3.2 (Message Thread Screen)

---

## Dependencies & Prerequisites

### Required Epics:
- [x] Epic 0: Project Scaffolding (Xcode, Firebase, SwiftData)
- [x] Epic 1: User Authentication & Profiles (for currentUserID)

### Required Services:
- [ ] AuthService with currentUserID
- [ ] ModelContext available via environment
- [ ] Firestore collections: `conversations`, `messages`, `typing`

---

## Technical Implementation Notes

### SwiftData + Firestore Sync Pattern

**Optimistic UI (Write-First):**
1. User taps Send
2. Create MessageEntity locally with `syncStatus = .pending`
3. Insert into SwiftData → UI updates immediately
4. Background task syncs to Firestore
5. Update `syncStatus = .synced` on success

**Real-Time Listener (Read-First):**
1. Firestore listener detects new message
2. Check if message exists locally (by ID)
3. If not exists → insert into SwiftData
4. If exists → update status/properties
5. SwiftData @Query auto-updates UI

### Message Status Flow

```
[User taps Send]
    ↓
syncStatus: .pending (clock icon)
    ↓
[Firestore write succeeds]
    ↓
syncStatus: .synced, status: .sent (checkmark)
    ↓
[Recipient's device receives via listener]
    ↓
status: .delivered (double checkmark)
    ↓
[Recipient opens conversation]
    ↓
status: .read (blue double checkmark)
```

### Network Monitoring

Use `NWPathMonitor` from Network framework:
```swift
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        // Online
    } else {
        // Offline
    }
}
monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
```

---

## Testing & Verification

### Verification Checklist:
- [ ] Create new conversation persists locally and syncs to Firestore
- [ ] Messages send instantly (optimistic UI)
- [ ] Messages sync to Firestore within 1 second
- [ ] Incoming messages appear in real-time without refresh
- [ ] Delivery status indicators update correctly
- [ ] Offline messages queue and sync when online
- [ ] Typing indicators appear/disappear correctly
- [ ] Swipe-to-archive removes conversation from list

### Test Procedure:
1. **Happy Path:**
   - User A creates conversation with User B
   - User A sends message "Hello"
   - Message appears instantly in User A's thread
   - User B sees message appear in real-time
   - User B sends reply "Hi!"
   - Both users see typing indicators

2. **Offline Test:**
   - Disable wifi on device
   - Send 3 messages
   - Verify messages show "clock" icon (pending)
   - Re-enable wifi
   - Verify messages sync and status updates to "checkmark"

3. **Failure Recovery:**
   - Simulate Firestore error (disconnect network mid-send)
   - Verify message shows red exclamation
   - Tap retry button
   - Verify message sends successfully

---

## Success Criteria

**Epic 2 is complete when:**
- ✅ Users can create one-on-one conversations
- ✅ Users can send and receive messages in real-time
- ✅ Messages persist locally with SwiftData
- ✅ Messages sync to Firestore with optimistic UI
- ✅ Delivery status indicators work correctly
- ✅ Offline queue processes messages when online
- ✅ Typing indicators show in real-time
- ✅ No data loss during offline periods
- ✅ UI responds instantly to user actions (<100ms)

---

## Time Estimates

| Story | Estimated Time |
|-------|---------------|
| 2.1 Create New Conversation | 45 mins |
| 2.2 Display Conversation List | 60 mins |
| 2.3 Send and Receive Messages | 90 mins |
| 2.4 Message Delivery Status Indicators | 30 mins |
| 2.5 Offline Queue and Background Sync | 60 mins |
| 2.6 Real-Time Typing Indicators | 45 mins |
| **Total** | **4-6 hours** |

---

## Implementation Order

**Recommended sequence:**
1. Story 2.1 (Create Conversation) - Foundation
2. Story 2.2 (Conversation List) - Navigation
3. Story 2.3 (Send/Receive Messages) - Core functionality
4. Story 2.4 (Delivery Status) - User feedback
5. Story 2.5 (Offline Queue) - Reliability
6. Story 2.6 (Typing Indicators) - Polish

---

## References

- **SwiftData Implementation Guide**: `docs/swiftdata-implementation-guide.md` (Section 7: Message Sync)
- **Architecture Doc**: `docs/architecture.md` (Section 5: Data Flow)
- **UX Design Doc**: `docs/ux-design.md` (Section 3: Chat Screens)
- **PRD**: `docs/prd.md` (Epic 2: One-on-One Chat)

---

## Notes for Development Team

### Critical Decisions Made:
- **Optimistic UI**: Write to SwiftData first for instant feedback, sync to Firestore in background
- **Real-Time Listeners**: Firestore snapshot listeners update SwiftData, which auto-updates SwiftUI via @Query
- **Network Monitoring**: Use NWPathMonitor for offline detection and auto-sync
- **Typing Indicators**: Separate Firestore subcollection with 3-second auto-timeout

### Potential Blockers:
- **Firestore listener performance**: May need pagination for conversations with >500 messages
- **Network flakiness**: Ensure exponential backoff doesn't cause infinite loops
- **SwiftData concurrency**: Be careful with ModelContext thread safety (use @MainActor)

### Tips for Success:
- Test offline mode extensively (airplane mode, poor connectivity)
- Use Firestore emulators to avoid quota exhaustion during development
- Monitor Firestore read/write counts (optimize listeners to reduce costs)
- Add comprehensive error logging for sync failures

---

**Epic Status:** Ready for implementation
**Blockers:** None (depends on Epic 0 and Epic 1)
**Risk Level:** Medium (real-time sync complexity)
