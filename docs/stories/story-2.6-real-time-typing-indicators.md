---
# Story 2.6: Real-Time Typing Indicators

id: STORY-2.6
title: "Real-Time Typing Indicators"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P2  # Medium - UX enhancement
estimate: 2  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 3  # Day 3

---

## Description

**As a** user
**I want** to see when the other person is typing
**So that** I know they're responding in real-time

This story implements real-time typing indicators using RTDB's ephemeral storage capabilities. Typing state is synced in real-time (<50ms) with automatic cleanup on disconnect, throttled events to save bandwidth, and smooth animated UI.

**Performance Target:** <50ms typing state update, auto-cleanup on disconnect

**Key Features:**
- Ephemeral RTDB storage with `.onDisconnect()` auto-cleanup
- Throttled typing events (max 1 update per 3 seconds)
- Auto-stop typing after 3 seconds of inactivity
- Animated "Typing..." indicator with bouncing dots
- Cleanup on view disappear

---

## Acceptance Criteria

**This story is complete when:**

- [ ] "Typing..." indicator appears when recipient is typing
- [ ] Indicator disappears after 3 seconds of inactivity
- [ ] Only shows for active conversation (not in conversation list)
- [ ] Typing state syncs via RTDB in real-time (<50ms latency)
- [ ] **Automatic cleanup on disconnect** (RTDB `.onDisconnect()` feature)
- [ ] **Throttled typing events** (max 1 update per 3 seconds to save bandwidth)
- [ ] **Cleanup on view disappear** (stop typing when leaving conversation)
- [ ] **Animated dots** (sequential fade animation, 0.4s interval)
- [ ] **Filter own typing** (don't show typing indicator for current user)

---

## Technical Tasks

**Implementation steps:**

1. **Create TypingIndicatorService with RTDB ephemeral storage**
   - File: `sorted/Services/TypingIndicatorService.swift`
   - Singleton pattern
   - Throttle typing events (max 1 per 3 seconds)
   - Auto-stop typing after 3 seconds via Timer
   - Use `.onDisconnectRemoveValue()` for auto-cleanup
   - See RTDB Code Examples lines 1655-1735

2. **Implement startTyping method**
   - Set typing state to true in RTDB
   - Path: `conversations/{conversationID}/typing/{userID}`
   - Configure `.onDisconnectRemoveValue()`
   - Schedule auto-stop timer (3 seconds)
   - Throttle duplicate events
   - See RTDB Code Examples lines 1669-1693

3. **Implement stopTyping method**
   - Invalidate throttle timer
   - Remove typing state from RTDB
   - See RTDB Code Examples lines 1696-1705

4. **Implement listenToTypingIndicators method**
   - Observe `.value` events on typing path
   - Return Set<String> of typing user IDs
   - Return DatabaseHandle for cleanup
   - See RTDB Code Examples lines 1708-1726

5. **Implement stopListening method**
   - Remove observer with DatabaseHandle
   - See RTDB Code Examples lines 1729-1733

6. **Create TypingIndicatorView with animated dots**
   - File: `sorted/Views/Chat/Components/TypingIndicatorView.swift`
   - Display "Typing" text with 3 animated dots
   - Sequential fade animation (0.4s interval)
   - Gray rounded background
   - Timer-based animation cycle
   - See RTDB Code Examples lines 1737-1774

7. **Update MessageThreadView with typing logic**
   - File: `sorted/Views/Chat/MessageThreadView.swift`
   - Add `@State var typingUserIDs: Set<String>`
   - Add `@State var typingListenerHandle: DatabaseHandle?`
   - Start typing listener in `.task` modifier
   - Display TypingIndicatorView when !typingUserIDs.isEmpty
   - Handle text changes with `handleTypingChange()`
   - Cleanup on `.onDisappear`
   - See RTDB Code Examples lines 1776-1849

8. **Implement handleTypingChange method**
   - Called on messageText change
   - Trim whitespace
   - Start typing if text is not empty
   - Stop typing if text is empty
   - See RTDB Code Examples lines 1834-1849

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Services/TypingIndicatorService.swift (create)
sorted/Views/Chat/Components/TypingIndicatorView.swift (create)
sorted/Views/Chat/MessageThreadView.swift (modify - add typing logic)
```

### Code Examples

**TypingIndicatorService.swift (from RTDB Code Examples lines 1655-1735):**

```swift
import Foundation
import FirebaseDatabase

final class TypingIndicatorService {
    static let shared = TypingIndicatorService()

    private let database = Database.database().reference()
    private var throttleTimers: [String: Timer] = [:]

    private init() {}

    /// Starts typing indicator for a user in a conversation
    func startTyping(conversationID: String, userID: String) {
        // Throttle typing events (max 1 per 3 seconds)
        let key = "\(conversationID)_\(userID)"

        if throttleTimers[key] != nil {
            return // Already typing, don't send duplicate event
        }

        let typingRef = database
            .child("conversations/\(conversationID)/typing/\(userID)")

        // Set typing state
        typingRef.setValue(true)

        // Auto-cleanup on disconnect (RTDB feature!)
        typingRef.onDisconnectRemoveValue()

        // Throttle for 3 seconds
        throttleTimers[key] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.throttleTimers[key] = nil

            // Auto-stop typing after 3 seconds
            self?.stopTyping(conversationID: conversationID, userID: userID)
        }
    }

    /// Stops typing indicator for a user in a conversation
    func stopTyping(conversationID: String, userID: String) {
        let key = "\(conversationID)_\(userID)"
        throttleTimers[key]?.invalidate()
        throttleTimers[key] = nil

        let typingRef = database
            .child("conversations/\(conversationID)/typing/\(userID)")

        typingRef.removeValue()
    }

    /// Listens to typing indicators in a conversation
    func listenToTypingIndicators(
        conversationID: String,
        onChange: @escaping (Set<String>) -> Void
    ) -> DatabaseHandle {
        let typingRef = database
            .child("conversations/\(conversationID)/typing")

        return typingRef.observe(.value) { snapshot in
            var typingUserIDs = Set<String>()

            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let isTyping = child.value as? Bool, isTyping {
                    typingUserIDs.insert(child.key)
                }
            }

            onChange(typingUserIDs)
        }
    }

    /// Stops listening to typing indicators
    func stopListening(conversationID: String, handle: DatabaseHandle) {
        database
            .child("conversations/\(conversationID)/typing")
            .removeObserver(withHandle: handle)
    }
}
```

**TypingIndicatorView.swift (from RTDB Code Examples lines 1737-1774):**

```swift
import SwiftUI

struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text("Typing")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.4),
                            value: animationPhase
                        )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(18)
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}
```

**MessageThreadView.swift Updates (from RTDB Code Examples lines 1776-1849):**

```swift
// Add state variables to MessageThreadView
@State private var typingUserIDs: Set<String> = []
@State private var typingListenerHandle: DatabaseHandle?

var body: some View {
    VStack(spacing: 0) {
        // ... network banner ...

        // Message list
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // Typing indicator at bottom
                    if !typingUserIDs.isEmpty {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                }
                .padding()
            }
            // ... scroll handling ...
        }

        // Message composer
        MessageComposerView(
            text: $messageText,
            characterLimit: 10_000,
            onSend: { await sendMessage() }
        )
        .focused($isInputFocused)
        .onChange(of: messageText) { oldValue, newValue in
            handleTypingChange(newValue)
        }
    }
    .task {
        // Start typing listener
        typingListenerHandle = TypingIndicatorService.shared.listenToTypingIndicators(
            conversationID: conversation.id
        ) { userIDs in
            withAnimation {
                typingUserIDs = userIDs.filter { $0 != AuthService.shared.currentUserID }
            }
        }

        await viewModel.startRealtimeListener()
        await viewModel.markAsRead()
    }
    .onDisappear {
        // Cleanup: Stop typing
        TypingIndicatorService.shared.stopTyping(
            conversationID: conversation.id,
            userID: AuthService.shared.currentUserID
        )

        // Remove typing listener
        if let handle = typingListenerHandle {
            TypingIndicatorService.shared.stopListening(
                conversationID: conversation.id,
                handle: handle
            )
        }

        viewModel.stopRealtimeListener()
    }
}

// Add typing change handler
private func handleTypingChange(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if !trimmed.isEmpty {
        // User is typing
        TypingIndicatorService.shared.startTyping(
            conversationID: conversation.id,
            userID: AuthService.shared.currentUserID
        )
    } else {
        // User cleared input
        TypingIndicatorService.shared.stopTyping(
            conversationID: conversation.id,
            userID: AuthService.shared.currentUserID
        )
    }
}
```

### RTDB Data Structure

```json
{
  "conversations": {
    "{conversationID}": {
      "typing": {
        "{userID}": true
      }
    }
  }
}
```

**Key Characteristics:**
- Ephemeral storage (auto-removed on disconnect)
- Boolean value (true when typing)
- No persistence (not synced to SwiftData)
- Real-time updates only

### Dependencies

**Required:**
- Story 2.3 (Send and Receive Messages) - provides MessageThreadView and conversation context
- AuthService.shared.currentUserID

**Blocks:**
- None (this is a UX enhancement story)

**External:**
- Firebase Realtime Database with `.onDisconnect()` support

---

## Testing & Validation

### Test Procedure

1. **Basic Typing Indicator:**
   - Open conversation on Device A
   - Start typing on Device B
   - Verify "Typing..." indicator appears on Device A within 50ms
   - Stop typing on Device B
   - Verify indicator disappears within 3 seconds on Device A

2. **Auto-Stop After 3 Seconds:**
   - Start typing on Device A
   - Wait 3 seconds without typing
   - Verify indicator disappears on Device B
   - Continue typing on Device A
   - Verify indicator does NOT reappear (throttled)
   - Wait 3 more seconds
   - Type again on Device A
   - Verify indicator reappears on Device B

3. **Disconnect Cleanup:**
   - Start typing on Device A
   - Force-quit app on Device A
   - Verify indicator disappears immediately on Device B
   - (Tests RTDB `.onDisconnectRemoveValue()`)

4. **View Disappear Cleanup:**
   - Start typing on Device A
   - Navigate away from conversation on Device A
   - Verify indicator disappears immediately on Device B

5. **Filter Own Typing:**
   - Type in conversation on Device A
   - Verify "Typing..." indicator does NOT appear on Device A
   - (Only recipient should see typing indicator)

6. **Animation Quality:**
   - Observe typing indicator animation
   - Verify dots animate sequentially (left to right)
   - Verify smooth fade transition (0.4s interval)
   - Verify no animation jank or stuttering

7. **Throttle Behavior:**
   - Type continuously for 10 seconds
   - Monitor RTDB network traffic (Firebase Console)
   - Verify only 1 typing event sent per 3 seconds
   - (Prevents excessive bandwidth usage)

### Success Criteria

- [ ] Builds without errors
- [ ] Typing indicator appears within 50ms of recipient typing
- [ ] Auto-stops after 3 seconds of inactivity
- [ ] Auto-cleanup on app termination (disconnect)
- [ ] Cleanup on view disappear
- [ ] Own typing indicator not visible to self
- [ ] Smooth dot animation (no jank)
- [ ] Throttling prevents excessive RTDB writes
- [ ] No memory leaks or timer leaks

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 2698-2941)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 1653-1849)

**PRD Sections:**
- Real-Time Messaging Features
- User Experience Design

**Implementation Guides:**
- UX Design Doc Section 3.2 (Message Thread Screen)
- Firebase RTDB onDisconnect Documentation

**Context7 References:**
- `/mobizt/firebaseclient` (topic: "RTDB onDisconnect ephemeral data")

**Related Stories:**
- Story 2.3 (Send and Receive Messages) - provides MessageThreadView

---

## Notes & Considerations

### Implementation Notes

**RTDB .onDisconnect() Feature:**
- `.onDisconnectRemoveValue()` is a server-side feature
- Automatically removes data when client disconnects
- Triggered on: app crash, force-quit, network loss, device sleep
- No client-side cleanup needed - server handles it
- Perfect for ephemeral data like typing indicators and presence

**Throttling Strategy:**
- Max 1 typing event per 3 seconds
- Prevents RTDB bandwidth abuse
- Smooth UX - recipient doesn't need sub-second updates
- Auto-stop after 3 seconds prevents "stuck" typing indicators

**Timer Management:**
- Use weak self in Timer closure to prevent retain cycles
- Invalidate timer on stopTyping to prevent memory leaks
- Store timers in dictionary keyed by "conversationID_userID"
- Clean up on deinit (if service is ever released)

**Animation Performance:**
- Timer.publish with 0.4s interval
- Sequential dot animation (0 → 1 → 2 → 0)
- Opacity animation only (no position/scale changes)
- Minimal CPU/GPU usage

### Edge Cases

- **Rapid Typing:** Throttling prevents excessive RTDB writes - typing state "sticks" for 3 seconds
- **Multiple Conversations:** Throttle timers are keyed per conversation - typing in multiple chats works independently
- **Network Flapping:** If connection lost, `.onDisconnect()` triggers - indicator removed on recipient's device
- **App Background:** iOS may suspend timers - typing indicator may persist longer than 3 seconds
- **Simultaneous Typing:** Both users can type at same time - both indicators show simultaneously (UI should handle gracefully)

### Performance Considerations

- **RTDB Latency:** Typing updates sync in <50ms on good connection
- **Timer Overhead:** Negligible - single timer per conversation
- **Animation Overhead:** Minimal - only 3 small circles with opacity animation
- **Bandwidth Usage:** Throttling limits to 20 RTDB writes per minute per conversation

### Security Considerations

- **RTDB Security Rules:** Typing path should allow read/write for conversation participants only
- **Privacy:** Typing indicators reveal user activity - ensure only visible to conversation participants
- **Spam Prevention:** Throttling prevents malicious typing spam attacks

### UX Considerations

- **Indicator Placement:** Bottom of message list, left-aligned (like incoming message)
- **Transition Animation:** Use `.transition(.opacity)` for smooth appear/disappear
- **Multiple Typers:** If needed in future, show "Alice and Bob are typing..." (currently only supports 1-on-1)
- **Accessibility:** TypingIndicatorView should have accessibility label for VoiceOver

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 3 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 2
**Priority:** P2 (Medium)

---

## Story Lifecycle

- [ ] **Draft** - Story created, needs review
- [x] **Ready** - Story reviewed and ready for development ✅
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Ready
