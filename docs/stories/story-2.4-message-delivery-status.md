---
# Story 2.4: Message Delivery Status Indicators

id: STORY-2.4
title: "Message Delivery Status Indicators"
epic: "Epic 2: One-on-One Chat Infrastructure"
status: ready
priority: P1  # High - Important UX feedback
estimate: 3  # Story points
assigned_to: null
created_date: "2025-10-21"
sprint_day: 2  # Day 2

---

## Description

**As a** user
**I need** to see message delivery status
**So that** I know when my messages are received and read

This story implements WhatsApp-style delivery status indicators with smooth animations, retry functionality for failed messages, and accessibility support.

**Status Flow:**
- ⏱️ **Sending** (clock icon) - Message pending sync to RTDB
- ✓ **Sent** (single checkmark) - Message synced to RTDB
- ✓✓ **Delivered** (double checkmark) - Recipient device received message
- ✓✓ **Read** (blue double checkmark) - Recipient opened conversation and viewed message

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Messages show status icons: Sending (clock), Sent (single checkmark), Delivered (double checkmark), Read (blue double checkmark)
- [ ] Failed messages show red exclamation icon with retry button
- [ ] Status updates in real-time as message progresses through delivery stages
- [ ] Only user's own messages show status indicators (not received messages)
- [ ] Status appears below message bubble with timestamp
- [ ] **Status transitions animated** (smooth fade/scale animation)
- [ ] **Retry button functional** for failed messages

---

## Technical Tasks

**Implementation steps:**

1. **Create MessageBubbleView with status rendering**
   - File: `sorted/Views/Chat/MessageBubbleView.swift`
   - Display message text in colored bubble (blue for sent, gray for received)
   - Show timestamp and status icon below bubble
   - Implement `statusIcon` computed property with @ViewBuilder
   - Add accessibility labels for VoiceOver
   - See RTDB Code Examples lines 1302-1437

2. **Implement status icon rendering logic**
   - Switch on `message.syncStatus` (pending, synced, failed)
   - Switch on `message.status` (sent, delivered, read)
   - Show clock icon for `.pending`
   - Show red exclamation with retry button for `.failed`
   - Show single checkmark for `.sent`
   - Show double checkmark (gray) for `.delivered`
   - Show double checkmark (blue) for `.read`

3. **Add retry button for failed messages**
   - Button wrapping exclamation icon
   - Calls `SyncCoordinator.shared.retryMessage(message)`
   - Accessibility label: "Failed to send. Tap to retry."

4. **Add status transition animations**
   - Use `.animation(.easeInOut(duration: 0.2), value: message.status)`
   - Use `.transition(.scale.combined(with: .opacity))`
   - Smooth fade between status icons

5. **Implement accessibility descriptions**
   - Combine message text with status in single VoiceOver label
   - Example: "Hello world, sent" or "Hello world, delivered"
   - Failed messages: "Hello world, failed to send, tap to retry"

6. **Update MessageThreadViewModel for status updates**
   - Already implemented in Story 2.3 (`handleMessageUpdate()`)
   - Listens to RTDB `.childChanged` events
   - Updates local MessageEntity status

---

## Technical Specifications

### Files to Create/Modify

```
sorted/Views/Chat/MessageBubbleView.swift (create)
sorted/ViewModels/MessageThreadViewModel.swift (modify - already has status update logic)
sorted/Core/Services/SyncCoordinator.swift (use existing retryMessage method from Story 2.5)
```

### Code Examples

**MessageBubbleView.swift (from RTDB Code Examples lines 1302-1437):**

```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: MessageEntity

    private let currentUserID = AuthService.shared.currentUserID

    var isFromCurrentUser: Bool {
        message.senderID == currentUserID
    }

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

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
                    // Use server timestamp if available, fallback to local
                    Text(message.serverTimestamp ?? message.localCreatedAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: message.status)
                            .animation(.easeInOut(duration: 0.2), value: message.syncStatus)
                    }
                }
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.syncStatus {
        case .pending:
            // Sending
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .accessibilityLabel("Sending")

        case .failed:
            // Failed - show retry button
            Button {
                retryMessage()
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Failed to send. Tap to retry.")

        case .synced:
            // Successfully synced - show delivery status
            switch message.status {
            case .sent:
                // Sent to server
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Sent")

            case .delivered:
                // Delivered to recipient
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .accessibilityLabel("Delivered")

            case .read:
                // Read by recipient
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .accessibilityLabel("Read")
            }
        }
    }

    private var accessibilityDescription: String {
        var description = message.text

        if isFromCurrentUser {
            description += ", "
            switch message.syncStatus {
            case .pending:
                description += "sending"
            case .failed:
                description += "failed to send, tap to retry"
            case .synced:
                switch message.status {
                case .sent:
                    description += "sent"
                case .delivered:
                    description += "delivered"
                case .read:
                    description += "read"
                }
            }
        } else {
            description += ", received"
        }

        return description
    }

    private func retryMessage() {
        Task {
            await SyncCoordinator.shared.retryMessage(message)
        }
    }
}
```

**Status Enums (already in MessageEntity.swift from Story 2.3):**

```swift
enum MessageStatus: String, Codable {
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
}

enum SyncStatus: String, Codable {
    case pending = "pending"
    case synced = "synced"
    case failed = "failed"
}
```

### Dependencies

**Required:**
- Story 2.3 (Send and Receive Messages) - provides MessageEntity and MessageThreadViewModel
- SyncCoordinator.shared.retryMessage() method (Story 2.5)

**Blocks:**
- None (this is a UI enhancement story)

**External:**
- RTDB `.childChanged` observer updates message status in real-time

---

## Testing & Validation

### Test Procedure

1. **Send Message - Status Progression:**
   - Send message
   - Verify shows clock icon (pending)
   - Wait 1 second
   - Verify changes to single checkmark (sent)
   - On recipient device: verify changes to double checkmark gray (delivered)
   - On recipient device: open conversation
   - On sender device: verify changes to blue double checkmark (read)

2. **Failed Message - Retry:**
   - Disable network
   - Send message
   - Verify shows clock icon (pending)
   - Wait for timeout
   - Verify changes to red exclamation icon
   - Tap retry button
   - Verify message re-attempts sync
   - Enable network
   - Verify changes to checkmark (sent)

3. **Animation Testing:**
   - Send message
   - Watch status icon transitions
   - Verify smooth fade/scale animation (not abrupt)

4. **Accessibility:**
   - Enable VoiceOver
   - Tap message bubble
   - Verify VoiceOver reads: "[message text], [status]"
   - Example: "Hello world, sent"

5. **Received Messages:**
   - Receive message from other user
   - Verify NO status icon appears (only on sent messages)

### Success Criteria

- [ ] Builds without errors
- [ ] Status icons render correctly for all states
- [ ] Smooth animations between status changes
- [ ] Retry button works for failed messages
- [ ] VoiceOver reads message with status
- [ ] Only sent messages show status (not received)
- [ ] Blue checkmarks only appear for "read" status
- [ ] Timestamps display correctly with status icons

---

## References

**Architecture Docs:**
- Epic 2: One-on-One Chat Infrastructure (REVISED) - docs/epics/epic-2-one-on-one-chat-REVISED.md (lines 2202-2403)
- Epic 2: RTDB Code Examples - docs/epics/epic-2-RTDB-CODE-EXAMPLES.md (lines 1299-1438)

**PRD Sections:**
- Message Delivery Status
- User Experience Design

**Implementation Guides:**
- UX Design Doc (docs/ux-design.md) - Section 3.2 (Message Thread Screen)

**Context7 References:**
- `/mobizt/firebaseclient` (topic: "RTDB childChanged observer")

**Related Stories:**
- Story 2.3 (Send and Receive Messages) - provides message entities
- Story 2.5 (Offline Queue) - provides retry functionality

---

## Notes & Considerations

### Implementation Notes

**Status Icon Size and Color:**
- Font size: 12pt (matches timestamp)
- Gray checkmarks for sent/delivered (secondary color)
- Blue checkmarks for read (matches sender bubble color)
- Red exclamation for failed (alert color)

**Animation Duration:**
- 0.2 seconds for smooth transition
- Combined scale + opacity for visual polish
- Prevent animation on initial render

**Button vs Icon:**
- Failed status uses Button (interactive)
- Other statuses use Image (non-interactive)
- Accessibility labels for all states

### Edge Cases

- **Network Delay:** Clock icon may persist for several seconds on slow connections
- **Status Regression:** Delivered → Read should never revert (one-way progression)
- **Multiple Retries:** Retry button resets `retryCount` to 0, allows unlimited manual retries

### Performance Considerations

- StatusIcon is computed property, re-rendered on status change only
- @ViewBuilder prevents unnecessary view hierarchies
- Animation tied to specific values (status, syncStatus) for efficiency

### Security Considerations

- Status updates must come from RTDB only (no client manipulation)
- RTDB security rules validate status transitions
- Read receipts require recipient to mark as read (can't be forged)

---

## Metadata

**Created by:** @sm (Scrum Master - Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 2 of 7-day sprint
**Epic:** Epic 2: One-on-One Chat Infrastructure
**Story points:** 3
**Priority:** P1 (High)

---

## Story Lifecycle

- [ ] **Draft** - Story created, needs review
- [x] **Ready** - Story reviewed and ready for development ✅
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Ready
