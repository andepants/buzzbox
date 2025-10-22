---
# Story 2.2: Display Conversation List

id: STORY-2.2
title: "Display Conversation List"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P0  # Critical - Core messaging UI
estimate: 5  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 1  # Day 1 MVP

---

## Description

**As a** user
**I need** to see all my conversations in a list
**So that** I can access my message threads and stay updated on new messages

This story implements the main conversation list UI with real-time RTDB updates, pull-to-refresh, swipe actions, search functionality, and network status indicators. It provides a WhatsApp-quality messaging experience with <10ms update latency.

**Key Features:**
- Real-time RTDB SSE streaming updates (<10ms latency)
- Pull-to-refresh for manual sync
- Swipe-to-archive/delete actions
- Search by participant name or message content
- Network status indicator (offline badge)
- Long-press context menu (Pin, Archive, Mark Unread, Delete)
- Unread message badges
- VoiceOver accessibility

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Conversation list shows all conversations sorted by last message timestamp (newest first)
- [ ] Each conversation row displays: recipient name, last message preview, timestamp, unread count
- [ ] Unread conversations show blue badge with count
- [ ] List updates in real-time when new messages arrive via RTDB SSE streaming
- [ ] Empty state shows "No conversations yet" placeholder with icon
- [ ] Pull-to-refresh manually syncs from RTDB
- [ ] Swipe-to-archive removes conversation from list (sets `isArchived = true`)
- [ ] **Network status indicator** shows "Offline" badge when no connection
- [ ] **Long-press menu** for Pin, Archive, Mark Unread, Delete
- [ ] **Search conversations** by participant name or message content
- [ ] **Accessibility labels** for VoiceOver (includes unread status)

---

## Technical Tasks

**Implementation steps:**

1. **Create ConversationListView with @Query**
   - File: `sorted/Views/Chat/ConversationListView.swift`
   - Use SwiftData `@Query` to fetch non-archived conversations
   - Sort by `lastMessageTimestamp` descending (newest first)
   - Filter: `conversation.isArchived == false`
   - Initialize ConversationViewModel with ModelContext
   - See RTDB Code Examples lines 423-563

2. **Create ConversationRowView component**
   - File: `sorted/Views/Chat/ConversationRowView.swift`
   - Display: profile picture, recipient name, last message, timestamp, unread badge
   - Support pinned conversations (pin icon)
   - Load recipient user asynchronously
   - Accessibility: combine elements, provide descriptive label
   - See RTDB Code Examples lines 620-723

3. **Implement real-time RTDB listener in ConversationViewModel**
   - Method: `startRealtimeListener()` and `stopRealtimeListener()`
   - Listen to `/conversations` node with `.value` observer
   - Filter conversations where current user is participant
   - Update local SwiftData when RTDB changes
   - Use `@MainActor` for thread safety
   - See RTDB Code Examples lines 1506-1584

4. **Add NetworkMonitor singleton**
   - File: `sorted/Core/Services/NetworkMonitor.swift`
   - Use `NWPathMonitor` to detect connectivity changes
   - Published properties: `isConnected`, `isCellular`, `isConstrained`
   - Initialize ONCE in SortedApp.swift, inject via `.environmentObject()`
   - See Pattern 2 in Epic 2 lines 202-280
   - See RTDB Code Examples lines 725-760

5. **Implement NetworkStatusBanner**
   - Show "Offline" banner when `!networkMonitor.isConnected`
   - Yellow background, orange text, wifi-slash icon
   - Positioned at top of List
   - See RTDB Code Examples lines 602-617

6. **Add search functionality**
   - Use `.searchable(text: $searchText)` modifier
   - Filter conversations by recipient name OR last message content
   - Case-insensitive search with `localizedCaseInsensitiveContains()`
   - See RTDB Code Examples lines 450-458

7. **Implement swipe actions and context menu**
   - Swipe-to-archive: `.swipeActions(edge: .trailing)`
   - Long-press menu: `.contextMenu` with Pin, Mark Unread, Archive, Delete
   - Update SwiftData and sync to RTDB
   - Haptic feedback for Pin action
   - See RTDB Code Examples lines 478-516

8. **Add pull-to-refresh**
   - Use `.refreshable { }` modifier
   - Call `await viewModel.syncConversations()`
   - Force refresh from RTDB
   - See RTDB Code Examples lines 534-536

9. **Implement empty state**
   - Use `ContentUnavailableView` for empty list
   - Title: "No Conversations"
   - Icon: `systemImage: "message"`
   - Description: "Tap + to start messaging"
   - See RTDB Code Examples lines 468-473

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Views/Chat/ConversationListView.swift (create)
sorted/Views/Chat/ConversationRowView.swift (create)
sorted/Views/Chat/NetworkStatusBanner.swift (create)
sorted/Core/Services/NetworkMonitor.swift (create)
sorted/ViewModels/ConversationViewModel.swift (modify - add real-time listener)
sorted/App/SortedApp.swift (modify - inject NetworkMonitor as environmentObject)
```

### Code Examples

**ConversationListView.swift (from RTDB Code Examples lines 423-600):**

```swift
import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext

    // Query non-archived conversations sorted by last message timestamp
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isArchived == false
        },
        sort: [SortDescriptor(\ConversationEntity.lastMessageTimestamp, order: .reverse)]
    ) private var conversations: [ConversationEntity]

    @StateObject private var viewModel: ConversationViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor // ✅ Injected from SortedApp

    @State private var showRecipientPicker = false
    @State private var searchText = ""

    init() {
        let context = ModelContext(AppContainer.shared.modelContainer)
        _viewModel = StateObject(wrappedValue: ConversationViewModel(modelContext: context))
    }

    var filteredConversations: [ConversationEntity] {
        if searchText.isEmpty {
            return Array(conversations)
        }
        return conversations.filter { conversation in
            conversation.recipientDisplayName.localizedCaseInsensitiveContains(searchText) ||
            (conversation.lastMessage?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Network status banner
                if !networkMonitor.isConnected {
                    NetworkStatusBanner()
                }

                if filteredConversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "message",
                        description: Text("Tap + to start messaging")
                    )
                } else {
                    ForEach(filteredConversations) { conversation in
                        NavigationLink(value: conversation) {
                            ConversationRowView(conversation: conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                archiveConversation(conversation)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        .contextMenu {
                            Button {
                                togglePin(conversation)
                            } label: {
                                Label(
                                    conversation.isPinned ? "Unpin" : "Pin",
                                    systemImage: conversation.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                toggleUnread(conversation)
                            } label: {
                                Label(
                                    conversation.unreadCount > 0 ? "Mark as Read" : "Mark as Unread",
                                    systemImage: "envelope.badge"
                                )
                            }

                            Button {
                                archiveConversation(conversation)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }

                            Button(role: .destructive) {
                                deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Messages")
            .navigationDestination(for: ConversationEntity.self) { conversation in
                MessageThreadView(conversation: conversation)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showRecipientPicker = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Message")
                    .accessibilityHint("Start a new conversation")
                }
            }
            .refreshable {
                await viewModel.syncConversations()
            }
            .task {
                await viewModel.startRealtimeListener()
            }
            .onDisappear {
                viewModel.stopRealtimeListener()
            }
            .sheet(isPresented: $showRecipientPicker) {
                RecipientPickerView { selectedUserID in
                    Task {
                        do {
                            let conversation = try await viewModel.createConversation(withUserID: selectedUserID)
                            // Navigate to conversation (NavigationStack handles this automatically)
                        } catch {
                            // Show error alert
                        }
                    }
                }
            }
            .alert(item: $viewModel.error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.errorDescription ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Private Methods

    private func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        try? modelContext.save()

        // Sync to RTDB
        Task {
            try? await ConversationService.shared.syncConversation(conversation)
        }
    }

    private func togglePin(_ conversation: ConversationEntity) {
        conversation.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleUnread(_ conversation: ConversationEntity) {
        conversation.unreadCount = conversation.unreadCount > 0 ? 0 : 1
        try? modelContext.save()
    }

    private func deleteConversation(_ conversation: ConversationEntity) {
        modelContext.delete(conversation)
        try? modelContext.save()

        // Delete from RTDB
        Task {
            let conversationRef = Database.database().reference().child("conversations/\(conversation.id)")
            try? await conversationRef.removeValue()
        }
    }
}
```

**ConversationRowView.swift (from RTDB Code Examples lines 620-723):**

```swift
import SwiftUI

struct ConversationRowView: View {
    let conversation: ConversationEntity

    @State private var recipientUser: UserEntity?

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: recipientUser?.profilePictureURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipientUser?.displayName ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))

                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open conversation")
    }

    private var accessibilityDescription: String {
        var description = "\(recipientUser?.displayName ?? "Unknown")"

        if conversation.isPinned {
            description += ", pinned"
        }

        if conversation.unreadCount > 0 {
            description += ", \(conversation.unreadCount) unread messages"
        }

        if let lastMessage = conversation.lastMessage {
            description += ", last message: \(lastMessage)"
        }

        return description
    }

    private func loadRecipientUser() async {
        let currentUserID = AuthService.shared.currentUserID
        guard let recipientID = conversation.participantIDs.first(where: { $0 != currentUserID }) else {
            return
        }

        recipientUser = try? await ConversationService.shared.getUser(userID: recipientID)
    }
}
```

**NetworkMonitor.swift (from RTDB Code Examples lines 725-760):**

```swift
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var isCellular = false
    @Published var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sorted.networkmonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.isExpensive
                self?.isConstrained = path.isConstrained
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
```

**NetworkStatusBanner.swift (from RTDB Code Examples lines 602-617):**

```swift
import SwiftUI

struct NetworkStatusBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text("Offline")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
    }
}
```

**ConversationViewModel - Real-time Listener (from RTDB Code Examples lines 1506-1584):**

```swift
extension ConversationViewModel {
    private var sseTask: Task<Void, Never>?

    func startRealtimeListener() async {
        let currentUserID = AuthService.shared.currentUserID
        let conversationsRef = Database.database().reference().child("conversations")

        sseTask = Task { @MainActor in
            conversationsRef.observe(.value) { [weak self] snapshot in
                guard let self = self else { return }

                Task { @MainActor in
                    await self.processConversationSnapshot(snapshot, currentUserID: currentUserID)
                }
            }
        }
    }

    func stopRealtimeListener() {
        sseTask?.cancel()
        sseTask = nil
        Database.database().reference().child("conversations").removeAllObservers()
    }

    func syncConversations() async {
        isLoading = true
        defer { isLoading = false }

        let currentUserID = AuthService.shared.currentUserID
        let conversationsRef = Database.database().reference().child("conversations")

        do {
            let snapshot = try await conversationsRef.getData()
            await processConversationSnapshot(snapshot, currentUserID: currentUserID)
        } catch {
            self.error = .networkError
        }
    }

    private func processConversationSnapshot(_ snapshot: DataSnapshot, currentUserID: String) async {
        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            guard let conversationData = child.value as? [String: Any] else { continue }

            // Check if current user is participant
            let participantIDs = conversationData["participantIDs"] as? [String] ?? []
            guard participantIDs.contains(currentUserID) else { continue }

            let conversationID = child.key

            // Check if exists locally
            let descriptor = FetchDescriptor<ConversationEntity>(
                predicate: #Predicate { $0.id == conversationID }
            )

            let existing = try? modelContext.fetch(descriptor).first

            if existing == nil {
                // New conversation from RTDB
                let conversation = ConversationEntity(
                    id: conversationID,
                    participantIDs: participantIDs,
                    lastMessage: conversationData["lastMessage"] as? String,
                    lastMessageTimestamp: Date(
                        timeIntervalSince1970: conversationData["lastMessageTimestamp"] as? TimeInterval ?? 0
                    ),
                    unreadCount: conversationData["unreadCount"] as? Int ?? 0,
                    createdAt: Date(
                        timeIntervalSince1970: conversationData["createdAt"] as? TimeInterval ?? 0
                    ),
                    updatedAt: Date(
                        timeIntervalSince1970: conversationData["updatedAt"] as? TimeInterval ?? 0
                    ),
                    syncStatus: .synced,
                    isArchived: false,
                    isPinned: false
                )

                modelContext.insert(conversation)
            } else {
                // Update existing conversation
                existing?.lastMessage = conversationData["lastMessage"] as? String
                existing?.lastMessageTimestamp = Date(
                    timeIntervalSince1970: conversationData["lastMessageTimestamp"] as? TimeInterval ?? 0
                )
                existing?.unreadCount = conversationData["unreadCount"] as? Int ?? 0
                existing?.updatedAt = Date(
                    timeIntervalSince1970: conversationData["updatedAt"] as? TimeInterval ?? 0
                )
            }

            try? modelContext.save()
        }
    }

    deinit {
        stopRealtimeListener()
    }
}
```

**SortedApp.swift - Inject NetworkMonitor (from Pattern 2, Epic 2 lines 248-263):**

```swift
@main
struct SortedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ✅ Initialize NetworkMonitor ONCE
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppContainer.shared.modelContainer)
                .environmentObject(networkMonitor) // ✅ Inject globally
        }
    }
}
```

### Dependencies

**Required:**
- Story 2.0 (FCM/APNs Setup) - complete
- Story 2.1 (Create New Conversation) - provides ConversationEntity and ConversationViewModel
- AppContainer.shared.modelContainer configured (Pattern 1)
- NetworkMonitor initialized in SortedApp (Pattern 2)

**Blocks:**
- Story 2.3 (Send and Receive Messages) - navigation to MessageThreadView

**External:**
- Firebase Realtime Database rules allow conversation reads
- User profiles exist in Firestore for recipient name display

---

## Testing & Validation

### Test Procedure

1. **Initial Load:**
   - Launch app
   - Verify conversation list loads
   - Verify conversations sorted by most recent
   - Check unread badges appear correctly

2. **Real-time Updates:**
   - Open conversation on Device A
   - Send message from Device B
   - Verify Device A's conversation list updates instantly
   - Verify last message preview updates
   - Verify timestamp updates to "just now"

3. **Pull-to-Refresh:**
   - Pull down on conversation list
   - Verify loading spinner appears
   - Verify list refreshes from RTDB

4. **Search:**
   - Tap search bar
   - Type recipient name
   - Verify filtered results
   - Type message content keyword
   - Verify search works for message text

5. **Swipe Actions:**
   - Swipe left on conversation
   - Tap "Archive"
   - Verify conversation disappears from list
   - Verify `isArchived = true` in SwiftData

6. **Context Menu:**
   - Long-press conversation
   - Tap "Pin"
   - Verify pin icon appears in conversation row
   - Long-press again, tap "Unpin"
   - Verify pin icon disappears

7. **Network Status:**
   - Enable Airplane Mode
   - Verify "Offline" banner appears at top
   - Disable Airplane Mode
   - Verify banner disappears

8. **Empty State:**
   - Archive all conversations
   - Verify "No Conversations" placeholder appears
   - Verify message icon and "Tap + to start messaging" text

9. **Accessibility:**
   - Enable VoiceOver
   - Tap conversation row
   - Verify announcement includes: name, pinned status, unread count, last message

### Success Criteria

- [ ] Builds without errors
- [ ] Conversation list displays all conversations
- [ ] Conversations sorted by lastMessageTimestamp (newest first)
- [ ] Real-time updates work (<10ms RTDB latency)
- [ ] Pull-to-refresh syncs from RTDB
- [ ] Search works for recipient name and message content
- [ ] Swipe-to-archive removes conversation from list
- [ ] Context menu Pin/Unpin/Archive/Delete work
- [ ] Network status banner shows/hides based on connectivity
- [ ] Empty state displays when no conversations
- [ ] VoiceOver announces conversation details correctly
- [ ] Unread badges display correctly
- [ ] Navigation to MessageThreadView works

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 1198-1659)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 421-760)
- Pattern 2: NetworkMonitor Singleton - Epic 2 lines 202-280

**PRD Sections:**
- Conversation List UI
- User Experience Design

**Implementation Guides:**
- SwiftData Implementation Guide (docs/swiftdata-implementation-guide.md) - Section 6.2 (@Query usage)
- UX Design Doc (docs/ux-design.md) - Section 3.1 (Conversation List Screen)

**Context7 References:**
- `/mobizt/firebaseclient` (topic: "RTDB SSE streaming listeners")
- `/pointfreeco/swift-concurrency-extras` (topic: "Task management cleanup")

**Related Stories:**
- Story 2.1 (Create New Conversation) - required
- Story 2.3 (Send and Receive Messages) - navigation target
- Story 2.5 (Offline Queue) - syncs pending conversations

---

## Notes & Considerations

### Implementation Notes

**NetworkMonitor Initialization (Pattern 2 - Critical!):**
- Initialize ONCE in SortedApp.swift, NOT in individual views
- Inject via `.environmentObject()` globally
- Access in views via `@EnvironmentObject var networkMonitor: NetworkMonitor`
- Prevents redundant network monitoring instances

**Real-time Listener Lifecycle:**
- Start: `.task { await viewModel.startRealtimeListener() }`
- Stop: `.onDisappear { viewModel.stopRealtimeListener() }`
- Cleanup: `deinit` in ViewModel removes RTDB observers
- Use `weak self` in closures to prevent retain cycles

**@Query SwiftData Pattern:**
- Automatically updates UI when SwiftData changes
- No manual `@Published` arrays needed
- Filter and sort directly in @Query predicate
- Provides array of ConversationEntity for ForEach

### Edge Cases

- **Empty Conversations:** Show "No messages yet" in last message preview
- **Long Last Messages:** Use `.lineLimit(2)` to prevent UI overflow
- **Deleted Conversations:** If deleted on other device, remove from local SwiftData
- **Archived Conversations:** Filter out with `isArchived == false` predicate
- **Network Switching:** WiFi ↔ Cellular handled automatically by NetworkMonitor

### Performance Considerations

- **LazyVStack vs List:** List is more efficient for large conversation lists
- **AsyncImage:** Caches images automatically, no manual caching needed
- **RTDB Listeners:** Use `.value` observer for full snapshot (efficient for <100 conversations)
- **@Query:** SwiftData caches results, queries are fast (<5ms)
- **Real-time Updates:** RTDB SSE streaming delivers changes in <10ms

### Security Considerations

- RTDB security rules must validate:
  - User is authenticated
  - User is a participant in conversation before reading
- Conversation IDs expose participant IDs (sorted) - acceptable for one-on-one chats
- Recipient profile pictures loaded via authenticated Firebase Storage URLs

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 1 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 5
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
