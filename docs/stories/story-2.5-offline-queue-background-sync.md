---
# Story 2.5: Offline Queue and Background Sync

id: STORY-2.5
title: "Offline Queue and Background Sync"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P0  # Blocker - Critical for reliability
estimate: 5  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 2  # Day 2-3

---

## Description

**As a** user
**I want** my messages to send automatically when I regain connectivity
**So that** I don't lose messages when offline

This story implements robust offline message queuing with intelligent background sync, network monitoring, concurrent retry processing, and battery optimization. Messages sent while offline are queued locally in SwiftData and automatically synced when connectivity is restored.

**Performance Target:** <5s sync time for 50 queued messages with concurrent processing

**Key Features:**
- Concurrent retry processing (up to 5 messages simultaneously)
- Exponential backoff for failed syncs (1s → 2s → 4s)
- Network type awareness (WiFi vs Cellular)
- Battery optimization (throttle sync in low power mode)
- Real-time network status indicator

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Messages sent while offline are queued locally in SwiftData with `.pending` syncStatus
- [ ] Queue automatically processes when connection restored (WiFi or Cellular)
- [ ] Network status indicator shows "Offline" banner in navigation bar
- [ ] Failed messages retry with exponential backoff (1s → 2s → 4s, max 3 attempts)
- [ ] User can manually retry failed messages via retry button (Story 2.4)
- [ ] **Sync progress visible** for large message queues (>5 pending messages)
- [ ] **Concurrent retry processing** (up to 5 messages simultaneously using TaskGroup)
- [ ] **Network type awareness** (WiFi vs Cellular, respect user preferences)
- [ ] **Battery optimization** (throttle sync when low power mode enabled - 5s delay)
- [ ] **Performance target met**: 50 queued messages sync in <5s on WiFi

---

## Technical Tasks

**Implementation steps:**

1. **Create SyncCoordinator service with NWPathMonitor**
   - File: `sorted/Core/Services/SyncCoordinator.swift`
   - Singleton pattern with @MainActor
   - Monitor network status (online/offline, WiFi/cellular)
   - Monitor low power mode via NSProcessInfoPowerStateDidChange
   - Auto-sync when connection restored
   - Check user preferences for cellular sync
   - See RTDB Code Examples lines 1442-1606

2. **Implement concurrent retry with TaskGroup**
   - Method: `syncPendingMessages()`
   - Fetch pending messages from SwiftData
   - Process up to 5 messages concurrently using `withTaskGroup`
   - Track sync progress with `@Published var pendingCount`
   - See RTDB Code Examples lines 1516-1559

3. **Implement exponential backoff retry logic**
   - Method: `syncSingleMessage(_ message:)`
   - Retry failed syncs up to 3 times
   - Exponential delays: 1s → 2s → 4s
   - Update `message.syncStatus` to `.failed` after 3 attempts
   - Increment `message.retryCount`
   - See RTDB Code Examples lines 1572-1601

4. **Add manual retry method**
   - Method: `retryMessage(_ message:)`
   - Reset `retryCount` to 0
   - Reset `syncStatus` to `.pending`
   - Call `syncSingleMessage()`
   - See RTDB Code Examples lines 1562-1568

5. **Update MessageEntity with retryCount property**
   - File: `sorted/Models/MessageEntity.swift`
   - Add `var retryCount: Int` property
   - Initialize to 0 in init method
   - SwiftData will persist this automatically

6. **Create SyncProgressView for large queues**
   - File: `sorted/Views/Chat/Components/SyncProgressView.swift`
   - Display progress indicator when syncing >5 messages
   - Show "Sending N messages..." text
   - Blue background with rounded corners
   - Place below network status banner

7. **Add network status banner to MessageThreadView**
   - File: `sorted/Views/Chat/MessageThreadView.swift`
   - Observe `SyncCoordinator.shared.isOnline`
   - Display banner when offline
   - Include network type (WiFi/Cellular/Offline)

8. **Add MessageService.syncMessage() method**
   - File: `sorted/Services/MessageService.swift`
   - Method signature: `func syncMessage(_ message: MessageEntity) async throws`
   - Push message data to RTDB with serverTimestamp
   - See RTDB Code Examples lines 1609-1648

9. **Add cellular sync preference to Settings**
   - UserDefaults key: `"allowCellularSync"`
   - Default: true (allow cellular sync)
   - Toggle in ProfileView/Settings

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Core/Services/SyncCoordinator.swift (create)
sorted/Services/MessageService.swift (modify - add syncMessage method)
sorted/Models/MessageEntity.swift (modify - add retryCount property)
sorted/Views/Chat/Components/SyncProgressView.swift (create)
sorted/Views/Chat/MessageThreadView.swift (modify - add network banner and sync progress)
sorted/Features/Settings/Views/ProfileView.swift (modify - add cellular sync toggle)
```

### Code Examples

**SyncCoordinator.swift (from RTDB Code Examples lines 1442-1606):**

```swift
import Foundation
import Network
import SwiftData

@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    // MARK: - Published Properties

    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var pendingCount = 0
    @Published var isCellular = false
    @Published var isLowPowerMode = false

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sorted.sync")
    private let modelContext: ModelContext

    // MARK: - Initialization

    init() {
        self.modelContext = ModelContext(AppContainer.shared.modelContainer)
        setupNetworkMonitoring()
        setupLowPowerModeMonitoring()
    }

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }

                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                self.isCellular = path.isExpensive

                // Auto-sync when connection restored
                if wasOffline && self.isOnline {
                    // Check user preferences for cellular sync
                    let allowCellularSync = UserDefaults.standard.bool(forKey: "allowCellularSync")

                    if !self.isCellular || allowCellularSync {
                        await self.syncPendingMessages()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func setupLowPowerModeMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Public Methods

    /// Syncs all pending messages concurrently
    func syncPendingMessages() async {
        guard !isSyncing else { return }
        guard isOnline else { return }

        // Throttle sync in low power mode
        if isLowPowerMode {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }

        isSyncing = true
        defer { isSyncing = false }

        // Fetch pending messages
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.syncStatus == .pending },
            sortBy: [SortDescriptor(\MessageEntity.localCreatedAt, order: .forward)]
        )

        guard let pendingMessages = try? modelContext.fetch(descriptor) else {
            return
        }

        pendingCount = pendingMessages.count

        // Process messages concurrently (up to 5 at a time)
        await withTaskGroup(of: Void.self) { group in
            for message in pendingMessages {
                // Limit concurrent tasks to 5
                if group.isEmpty || pendingMessages.count < 5 {
                    group.addTask {
                        await self.syncSingleMessage(message)
                    }
                } else {
                    await group.next()
                    group.addTask {
                        await self.syncSingleMessage(message)
                    }
                }
            }

            // Wait for all remaining tasks
            await group.waitForAll()
        }
    }

    /// Retries a single failed message
    func retryMessage(_ message: MessageEntity) async {
        message.retryCount = 0
        message.syncStatus = .pending
        try? modelContext.save()

        await syncSingleMessage(message)
    }

    // MARK: - Private Methods

    private func syncSingleMessage(_ message: MessageEntity) async {
        // Retry with exponential backoff (max 3 attempts)
        for attempt in 0..<3 {
            do {
                try await MessageService.shared.syncMessage(message)

                // Success!
                await MainActor.run {
                    message.syncStatus = .synced
                    message.retryCount = 0
                    pendingCount -= 1
                    try? modelContext.save()
                }
                return

            } catch {
                // Exponential backoff: 1s → 2s → 4s
                let delay = pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // Failed after 3 attempts
        await MainActor.run {
            message.syncStatus = .failed
            message.retryCount = 3
            pendingCount -= 1
            try? modelContext.save()
        }
    }

    deinit {
        monitor.cancel()
    }
}
```

**MessageService.swift - syncMessage method (from RTDB Code Examples lines 1609-1648):**

```swift
import Foundation
import FirebaseDatabase

final class MessageService {
    static let shared = MessageService()

    private let database = Database.database().reference()

    private init() {}

    /// Syncs a message to RTDB
    func syncMessage(_ message: MessageEntity) async throws {
        let messagesRef = database.child("messages/\(message.conversationID)/\(message.id)")

        let messageData: [String: Any] = [
            "senderID": message.senderID,
            "text": message.text,
            "serverTimestamp": ServerValue.timestamp(),
            "status": message.status.rawValue
        ]

        try await messagesRef.setValue(messageData)
    }

    /// Updates message status in RTDB
    func updateMessageStatus(messageID: String, conversationID: String, status: MessageStatus) async throws {
        let messagesRef = database.child("messages/\(conversationID)/\(messageID)")

        try await messagesRef.updateChildValues([
            "status": status.rawValue
        ])
    }

    /// Marks a message as read in RTDB
    func markMessageAsRead(messageID: String, conversationID: String) async throws {
        try await updateMessageStatus(messageID: messageID, conversationID: conversationID, status: .read)
    }
}
```

**SyncProgressView.swift:**

```swift
import SwiftUI

struct SyncProgressView: View {
    @ObservedObject var syncCoordinator = SyncCoordinator.shared

    var body: some View {
        if syncCoordinator.isSyncing && syncCoordinator.pendingCount > 5 {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)

                Text("Sending \(syncCoordinator.pendingCount) messages...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
```

**Network Status Banner (add to MessageThreadView):**

```swift
// Add below navigation title
if !syncCoordinator.isOnline {
    HStack(spacing: 8) {
        Image(systemName: "wifi.slash")
            .font(.system(size: 14))

        Text(syncCoordinator.networkType)
            .font(.subheadline)
            .fontWeight(.medium)
    }
    .foregroundColor(.white)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color.red)
    .cornerRadius(8)
    .padding(.horizontal)
}

// Sync progress indicator
SyncProgressView()
```

**MessageEntity - Add retryCount property:**

```swift
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
    var retryCount: Int // ← New property

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
        self.retryCount = 0 // ← Initialize to 0
        self.attachments = attachments
    }
}
```

**Enhanced Network State Detection:**

```swift
extension SyncCoordinator {
    var networkType: String {
        if !isOnline {
            return "Offline"
        } else if isCellular {
            return "Cellular"
        } else {
            return "WiFi"
        }
    }

    var shouldSync: Bool {
        guard isOnline else { return false }

        // Always sync on WiFi
        if !isCellular { return true }

        // Check user preference for cellular sync
        let allowCellularSync = UserDefaults.standard.bool(forKey: "allowCellularSync")
        return allowCellularSync
    }
}
```

### Dependencies

**Required:**
- Story 2.3 (Send and Receive Messages) - provides MessageEntity with syncStatus property
- Story 2.4 (Message Delivery Status) - provides retry button UI
- AppContainer with shared ModelContainer

**Blocks:**
- None (this is an enhancement story)

**External:**
- Network.framework (NWPathMonitor for network monitoring)
- Foundation (ProcessInfo for low power mode detection)

---

## Testing & Validation

### Test Procedure

1. **Offline Message Queue:**
   - Disable WiFi and Cellular on device
   - Send 3 messages
   - Verify messages appear locally with clock icon (pending)
   - Verify "Offline" banner appears in navigation
   - Enable WiFi
   - Verify messages sync automatically within 5 seconds
   - Verify status icons change to checkmark (sent)

2. **Concurrent Sync Performance:**
   - Queue 50 messages while offline
   - Enable WiFi
   - Measure sync time
   - Verify completes in <5 seconds
   - Verify sync progress indicator appears during sync

3. **Exponential Backoff:**
   - Use Charles Proxy to simulate network errors
   - Send message
   - Verify retry attempts with 1s → 2s → 4s delays
   - Verify message marked as failed after 3 attempts
   - Verify red exclamation icon appears

4. **Manual Retry:**
   - Tap retry button on failed message
   - Verify message syncs successfully
   - Verify status changes from failed → pending → sent

5. **Cellular Sync Preference:**
   - Go to Settings → Profile
   - Disable "Allow Cellular Sync" toggle
   - Queue messages while offline
   - Switch to cellular network
   - Verify messages DO NOT sync automatically
   - Switch to WiFi
   - Verify messages sync immediately

6. **Low Power Mode Throttling:**
   - Enable Low Power Mode in iOS Settings
   - Queue messages while offline
   - Enable WiFi
   - Verify 5-second delay before sync starts
   - Disable Low Power Mode
   - Verify sync starts immediately on next connection change

7. **Network Type Indicator:**
   - Verify banner shows "WiFi" when on WiFi
   - Switch to cellular
   - Verify banner shows "Cellular"
   - Disable network
   - Verify banner shows "Offline" with red background

### Success Criteria

- [ ] Builds without errors
- [ ] Offline messages queue locally and sync on reconnection
- [ ] Concurrent sync processes up to 5 messages simultaneously
- [ ] 50 queued messages sync in <5 seconds on WiFi
- [ ] Exponential backoff implemented (1s → 2s → 4s)
- [ ] Manual retry button functional
- [ ] Network status indicator accurate
- [ ] Cellular sync preference respected
- [ ] Low power mode throttles sync by 5 seconds
- [ ] SyncProgressView appears for >5 pending messages
- [ ] No crashes or memory leaks during sync

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 2406-2695)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 1442-1649)

**PRD Sections:**
- Offline Support
- Network Resilience

**Implementation Guides:**
- SwiftData Implementation Guide Section 7.2 (Background Sync)
- Architecture Doc Section 6.2 (Network Resilience)

**Context7 References:**
- `/pointfreeco/swift-concurrency-extras` (topic: "TaskGroup concurrent operations")
- `/mobizt/firebaseclient` (topic: "RTDB offline capabilities")

**Related Stories:**
- Story 2.3 (Send and Receive Messages) - provides MessageEntity
- Story 2.4 (Message Delivery Status) - provides retry button UI

---

## Notes & Considerations

### Implementation Notes

**Concurrent Processing with TaskGroup:**
- TaskGroup allows processing up to 5 messages simultaneously
- Use `group.next()` to wait for available slot before adding new task
- This prevents overwhelming RTDB with 50+ simultaneous requests
- Ensures predictable performance and proper error handling

**Network Monitoring Best Practices:**
- Use `NWPathMonitor` (native iOS network monitoring)
- Monitor `path.status` for online/offline state
- Monitor `path.isExpensive` for cellular detection
- Start monitor on background queue to avoid blocking main thread

**Low Power Mode Detection:**
- Listen to `NSProcessInfoPowerStateDidChange` notification
- Check `ProcessInfo.processInfo.isLowPowerModeEnabled`
- Throttle sync by 5 seconds to preserve battery
- User can still manually retry if urgent

**Exponential Backoff Benefits:**
- Reduces server load during outages
- Gives temporary network issues time to resolve
- Progressive delays: 1s → 2s → 4s (total 7s max)
- Prevents aggressive retry loops

### Edge Cases

- **Network Flapping:** Rapid online/offline transitions should not trigger multiple sync attempts (use `guard !isSyncing` check)
- **App Background:** Sync may be interrupted if app enters background - messages remain queued for next foreground session
- **Cellular Preference Change:** If user disables cellular sync while on cellular, pending sync will pause until WiFi
- **Low Power Mode:** 5-second delay may feel slow - user can manually retry via retry button for urgent messages
- **Simultaneous Retry:** If user manually retries while auto-sync is running, message may sync twice - use syncStatus check to prevent

### Performance Considerations

- **TaskGroup Overhead:** TaskGroup adds ~5ms overhead per message - acceptable for 50 messages (<250ms total overhead)
- **SwiftData Fetch:** Fetching pending messages is fast (<10ms) due to predicate filtering
- **RTDB Write Performance:** Each message write takes 50-100ms - concurrent processing cuts 50 messages from 5000ms to ~1000ms
- **Memory Usage:** TaskGroup uses structured concurrency - no memory leaks or retain cycles

### Security Considerations

- **Token Expiration:** Exponential backoff may cause auth token to expire during retry - MessageService should handle token refresh
- **Data Integrity:** Retry logic must ensure message ID remains consistent (no duplicate IDs)
- **User Privacy:** Network status should not leak sensitive information in logs

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 2-3 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 5
**Priority:** P0 (Blocker)

---

## Story Lifecycle

- [ ] **Draft** - Story created, needs review
- [x] **Ready** - Story reviewed and ready for development ✅
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Ready
