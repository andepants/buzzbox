# Story 2.8: User Presence & Online Status

**Epic:** Epic 2 - One-on-One Chat Infrastructure
**Priority:** P0 (MVP REQUIREMENT - Online/offline status indicators)
**Estimated Time:** 45 minutes
**Story Order:** After Story 2.7 (Basic Group Chat)

---

## Story

**As a user,**
**I want to see when my conversation partners are online or offline,**
**so that I know if they're available to respond to my messages.**

---

## Acceptance Criteria

- [ ] User's online status updates automatically when app launches
- [ ] User's online status changes to offline when app closes or crashes
- [ ] Online status visible in conversation list (green dot next to name)
- [ ] Online status visible in message thread (header subtitle)
- [ ] Last seen timestamp visible when user is offline ("Last seen 5m ago")
- [ ] **Automatic cleanup on disconnect** using RTDB `.onDisconnect()`
- [ ] **Real-time updates** when conversation partner comes online/goes offline
- [ ] **Battery efficient** - Uses RTDB ephemeral data, no polling
- [ ] Status updates when app backgrounds/foregrounds
- [ ] Works for both one-on-one and group conversations

---

## Tasks / Subtasks

- [ ] **Task 1: Create UserPresenceService with RTDB integration (AC: 1, 2, 6)**
  - [ ] Create `UserPresenceService` singleton
  - [ ] Implement `setOnline()` method with `.onDisconnect()` cleanup
  - [ ] Implement `setOffline()` method
  - [ ] Use RTDB path `/userPresence/{uid}/online` and `/userPresence/{uid}/lastSeen`
  - [ ] Add app lifecycle observers (foreground/background)

- [ ] **Task 2: Integrate presence updates in app lifecycle (AC: 1, 2, 9)**
  - [ ] Set online when app launches (SortedApp `onAppear`)
  - [ ] Set online when app enters foreground
  - [ ] Set offline when app enters background
  - [ ] Auto-cleanup on disconnect (`.onDisconnect()`)

- [ ] **Task 3: Add presence listener to ConversationRowView (AC: 3, 5)**
  - [ ] Listen to recipient's presence status in RTDB
  - [ ] Show green dot when online
  - [ ] Show "Last seen [time]" when offline
  - [ ] Update in real-time when status changes

- [ ] **Task 4: Add presence indicator to MessageThreadView header (AC: 4, 5)**
  - [ ] Show subtitle: "Online" (green) or "Last seen [time]" (gray)
  - [ ] Update in real-time when partner's status changes
  - [ ] For groups: Show "[X] online" count

- [ ] **Task 5: Update RTDB security rules for presence (AC: 6)**
  - [ ] Anyone can read presence status
  - [ ] Only user can write their own presence
  - [ ] Validate presence data structure

- [ ] **Task 6: Handle group conversation presence (AC: 10)**
  - [ ] Fetch presence for all group participants
  - [ ] Show online count: "3 of 5 online"
  - [ ] Cache presence data to avoid repeated fetches

---

## Dev Notes

### UserPresenceService Implementation

```swift
import FirebaseDatabase
import UIKit

@MainActor
final class UserPresenceService: ObservableObject {
    static let shared = UserPresenceService()

    private let database = Database.database().reference()
    private var presenceListeners: [String: DatabaseHandle] = [:]

    private init() {
        setupAppLifecycleObservers()
    }

    // MARK: - Set Presence

    func setOnline() {
        guard let userID = AuthService.shared.currentUserID else { return }

        let presenceRef = database.child("userPresence/\(userID)")

        // Set online status
        presenceRef.child("online").setValue(true)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // ✅ CRITICAL: Auto-cleanup on disconnect (app crash, force quit, network drop)
        presenceRef.child("online").onDisconnectRemoveValue()
        presenceRef.child("lastSeen").onDisconnectSetValue(ServerValue.timestamp())

        print("User presence: ONLINE")
    }

    func setOffline() {
        guard let userID = AuthService.shared.currentUserID else { return }

        let presenceRef = database.child("userPresence/\(userID)")

        // Set offline status
        presenceRef.child("online").setValue(false)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // Cancel pending onDisconnect operations
        presenceRef.child("online").cancelDisconnectOperations()
        presenceRef.child("lastSeen").cancelDisconnectOperations()

        print("User presence: OFFLINE")
    }

    // MARK: - App Lifecycle

    private func setupAppLifecycleObservers() {
        // App enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setOnline()
        }

        // App enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setOffline()
        }

        // App will terminate
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setOffline()
        }
    }

    // MARK: - Listen to Presence

    func listenToPresence(
        userID: String,
        onChange: @escaping (PresenceStatus) -> Void
    ) -> DatabaseHandle {
        let presenceRef = database.child("userPresence/\(userID)")

        let handle = presenceRef.observe(.value) { snapshot in
            let isOnline = snapshot.childSnapshot(forPath: "online").value as? Bool ?? false
            let lastSeenTimestamp = snapshot.childSnapshot(forPath: "lastSeen").value as? TimeInterval ?? 0

            let status = PresenceStatus(
                isOnline: isOnline,
                lastSeen: Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
            )

            Task { @MainActor in
                onChange(status)
            }
        }

        presenceListeners[userID] = handle
        return handle
    }

    func stopListening(userID: String) {
        guard let handle = presenceListeners[userID] else { return }

        database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        presenceListeners.removeValue(forKey: userID)
    }

    deinit {
        // Cleanup all listeners
        for (userID, handle) in presenceListeners {
            database.child("userPresence/\(userID)").removeObserver(withHandle: handle)
        }
    }
}

// MARK: - Models

struct PresenceStatus {
    let isOnline: Bool
    let lastSeen: Date

    var displayText: String {
        if isOnline {
            return "Online"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        }
    }
}
```

### Integration in SortedApp

```swift
import SwiftUI

@main
struct SortedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // ✅ Set user online when app launches
                    Task { @MainActor in
                        UserPresenceService.shared.setOnline()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { notification in
                    // Handle deep link
                    if let conversationID = notification.userInfo?["conversationID"] as? String {
                        print("Navigate to conversation: \(conversationID)")
                    }
                }
        }
    }
}
```

### Updated ConversationRowView with Presence

```swift
struct ConversationRowView: View {
    let conversation: ConversationEntity

    @State private var recipientUser: UserEntity?
    @State private var presenceStatus: PresenceStatus?
    @State private var presenceHandle: DatabaseHandle?

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture with online indicator
            ZStack(alignment: .bottomTrailing) {
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

                // ✅ Online indicator (green dot)
                if presenceStatus?.isOnline == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
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
                    // ✅ Last message or presence status
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let status = presenceStatus {
                        Text(status.displayText)
                            .font(.system(size: 14))
                            .foregroundColor(status.isOnline ? .green : .secondary)
                    }

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
            await loadRecipientAndPresence()
        }
        .onDisappear {
            stopPresenceListener()
        }
    }

    private func loadRecipientAndPresence() async {
        // Load recipient user
        let recipientID = conversation.participantIDs.first { $0 != AuthService.shared.currentUserID }
        guard let recipientID = recipientID else { return }

        recipientUser = try? await ConversationService.shared.getUser(userID: recipientID)

        // ✅ Start listening to presence
        presenceHandle = UserPresenceService.shared.listenToPresence(userID: recipientID) { status in
            presenceStatus = status
        }
    }

    private func stopPresenceListener() {
        guard let recipientID = conversation.participantIDs.first(where: { $0 != AuthService.shared.currentUserID }) else {
            return
        }

        UserPresenceService.shared.stopListening(userID: recipientID)
    }
}
```

### Updated MessageThreadView Header

```swift
struct MessageThreadView: View {
    let conversation: ConversationEntity

    @State private var presenceStatus: PresenceStatus?
    @State private var presenceHandle: DatabaseHandle?

    var body: some View {
        VStack(spacing: 0) {
            // ... messages and composer ...
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.displayName)
                        .font(.headline)

                    // ✅ Presence status subtitle
                    if let status = presenceStatus {
                        Text(status.displayText)
                            .font(.caption)
                            .foregroundColor(status.isOnline ? .green : .secondary)
                    }
                }
            }
        }
        .task {
            await startPresenceListener()
        }
        .onDisappear {
            stopPresenceListener()
        }
    }

    private func startPresenceListener() async {
        guard !conversation.isGroup else {
            // For groups, show online count instead
            return
        }

        let recipientID = conversation.participantIDs.first { $0 != AuthService.shared.currentUserID }
        guard let recipientID = recipientID else { return }

        presenceHandle = UserPresenceService.shared.listenToPresence(userID: recipientID) { status in
            presenceStatus = status
        }
    }

    private func stopPresenceListener() {
        guard let recipientID = conversation.participantIDs.first(where: { $0 != AuthService.shared.currentUserID }) else {
            return
        }

        UserPresenceService.shared.stopListening(userID: recipientID)
    }
}
```

### RTDB Presence Structure

```json
{
  "userPresence": {
    "{userID}": {
      "online": true,
      "lastSeen": 1704067200000
    }
  }
}
```

### Updated RTDB Security Rules

Add to `database.rules.json`:

```json
{
  "rules": {
    "userPresence": {
      "$uid": {
        // Anyone authenticated can read presence status
        ".read": "auth != null",

        // Only the user can update their own presence
        ".write": "auth != null && auth.uid == $uid",

        // Validate presence data structure
        "online": {
          ".validate": "newData.isBoolean()"
        },

        "lastSeen": {
          ".validate": "newData.isNumber()"
        }
      }
    }
  }
}
```

### Group Presence Support

For groups, show online count:

```swift
extension MessageThreadView {
    private func loadGroupPresence() async {
        guard conversation.isGroup else { return }

        var onlineCount = 0

        for participantID in conversation.participantIDs {
            guard participantID != AuthService.shared.currentUserID else { continue }

            let ref = Database.database().reference().child("userPresence/\(participantID)/online")
            let snapshot = try? await ref.getData()

            if let isOnline = snapshot?.value as? Bool, isOnline {
                onlineCount += 1
            }
        }

        // Update subtitle
        let total = conversation.participantIDs.count - 1 // Exclude self
        presenceStatus = PresenceStatus(
            isOnline: onlineCount > 0,
            lastSeen: Date()
        )

        // Override displayText for groups
        // Show: "3 of 5 online" or "No one online"
    }
}
```

---

## Testing

### Test Plan

1. **Basic Online/Offline Test:**
   - Launch app on Device A
   - Verify User A shows online in Device B's conversation list
   - Close app on Device A
   - Verify User A shows offline in Device B within 1-2 seconds

2. **App Lifecycle Test:**
   - Launch app, verify online
   - Background app (home button)
   - Verify status changes to offline
   - Return to app (foreground)
   - Verify status changes back to online

3. **Crash Recovery Test:**
   - Force quit app (swipe up in app switcher)
   - Verify user shows offline within 5 seconds
   - RTDB `.onDisconnect()` should trigger automatically

4. **Network Drop Test:**
   - Enable Airplane Mode
   - Verify user shows offline after RTDB connection timeout (~10s)
   - Disable Airplane Mode
   - Verify user shows online when connection restored

5. **Real-Time Updates Test:**
   - User A viewing conversation list
   - User B launches app
   - Verify User B's status changes to online in real-time (green dot appears)

6. **Last Seen Timestamp Test:**
   - User A closes app at 3:00 PM
   - User B opens conversation list at 3:05 PM
   - Verify shows "Last seen 5m ago"
   - Wait 1 minute
   - Verify updates to "Last seen 6m ago"

7. **Group Presence Test:**
   - Create group with 5 users
   - 3 users online, 2 offline
   - Verify header shows "3 of 5 online"

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-20 | 1.0 | Initial story creation - User presence for MVP | PO (Sarah) |

---

## Notes

**Why Separate `/userPresence` Path:**

We use `/userPresence/{uid}` instead of `/users/{uid}` to:
1. **Separate concerns** - Presence is ephemeral, user profile is static
2. **Security** - Different read/write rules (presence readable by all, profile writable by owner)
3. **Performance** - Presence updates are high-frequency, don't want to mix with profile data

**Battery Impact:**

RTDB presence uses **Server-Sent Events (SSE)** which is very battery efficient:
- No polling (single persistent connection)
- Auto-reconnects when network changes
- `.onDisconnect()` cleanup requires no client action

**Accuracy:**

Presence accuracy depends on:
- **Network latency:** Usually <1 second for status changes
- **RTDB disconnect timeout:** ~10 seconds for network drops
- **App lifecycle hooks:** Instant for manual background/foreground

**MVP Scope:**

This story implements **basic presence** for MVP:
- Online/offline indicator
- Last seen timestamp
- Real-time updates

**Deferred to Post-MVP:**
- Typing status in presence (currently separate in Story 2.6)
- Custom status messages ("Away", "Busy", "In a meeting")
- Do Not Disturb mode
- Detailed online time tracking
