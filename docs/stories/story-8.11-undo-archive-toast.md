# Story 8.11: Undo Archive Toast

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P0 (Critical - complements Story 8.1)
**Effort:** 30 minutes
**Status:** Ready for Development

---

## Goal

Allow users to undo accidental archives with a toast notification that appears immediately after archiving a conversation.

---

## User Story

**As** Andrew (The Creator),
**I want** to see an undo option after archiving a conversation,
**So that** I can quickly recover from accidental archives without navigating to the archive view.

---

## Dependencies

- ⚠️ **Story 8.1:** Swipe-to-Archive (must be implemented first)
- ✅ Epic 5: Inbox structure

---

## Implementation

### Toast Component

Create `UndoToast.swift` with the following structure:

```swift
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .foregroundColor(.white)

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}
```

### Toast Presentation Logic

In InboxView, add toast state management:

```swift
@State private var showUndoToast = false
@State private var lastArchivedConversation: ConversationEntity?
@State private var undoTask: Task<Void, Never>?

func archiveConversation(_ conversation: ConversationEntity) {
    // Archive the conversation
    conversation.isArchived = true
    lastArchivedConversation = conversation

    // Show toast
    showUndoToast = true

    // Auto-dismiss after 3 seconds
    undoTask?.cancel()
    undoTask = Task {
        try? await Task.sleep(for: .seconds(3))
        if !Task.isCancelled {
            showUndoToast = false
            lastArchivedConversation = nil
        }
    }
}

func undoArchive() {
    guard let conversation = lastArchivedConversation else { return }
    conversation.isArchived = false
    showUndoToast = false
    undoTask?.cancel()
    HapticFeedback.impact(.light)
}
```

### Toast Display

Add to InboxView body:

```swift
.overlay(alignment: .bottom) {
    if showUndoToast {
        UndoToast(
            message: "Conversation archived",
            onUndo: undoArchive
        )
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.3, bounce: 0.2), value: showUndoToast)
    }
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Toast appears immediately after archiving conversation
- ✅ Toast shows "Conversation archived" message with "Undo" button
- ✅ Tapping "Undo" unarchives the conversation
- ✅ Toast auto-dismisses after 3 seconds
- ✅ Toast dismisses immediately when "Undo" is tapped

### Visual Requirements
- ✅ Toast appears at bottom of screen with smooth animation
- ✅ Toast respects safe area (no overlap with home indicator)
- ✅ Toast has subtle shadow for depth
- ✅ "Undo" button is clearly visible with blue tint

### Accessibility Requirements
- ✅ VoiceOver announces toast message and undo button
- ✅ Toast is accessible via VoiceOver gestures
- ✅ Undo button is large enough for easy tapping (44pt minimum)

---

## Edge Cases & Error Handling

### Rapid Archives
- ✅ **Behavior:** Only latest toast shown (replaces previous)
- ✅ **Implementation:** Cancel previous `undoTask` before showing new toast

### Undo Haptic
- ✅ **Behavior:** Light impact when undo is tapped
- ✅ **Implementation:** `HapticFeedback.impact(.light)` in `undoArchive()`

### Safe Area Respect
- ✅ **Behavior:** Toast respects bottom safe area (no notch overlap)
- ✅ **Implementation:** Use `.padding(.bottom, 16)` with safe area insets

### Task Cancellation
- ✅ **Behavior:** Auto-dismiss task is cancelled if user manually dismisses or undoes
- ✅ **Implementation:** Use `Task` with cancellation check

### Toast Stacking
- ✅ **Behavior:** Multiple rapid archives don't stack toasts
- ✅ **Implementation:** Only one toast shown at a time (state-based)

---

## Files to Create

### New Component
- `buzzbox/Core/Views/Components/UndoToast.swift`
  - Toast UI component
  - Accessible design
  - Smooth animations

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add toast state management
  - Add `undoArchive()` function
  - Add toast overlay to view hierarchy
  - Modify `archiveConversation()` to show toast

---

## Technical Notes

### Animation Approach

Use SwiftUI's native animation modifiers:
```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(duration: 0.3, bounce: 0.2), value: showUndoToast)
```

### Timer Management

Use Swift Concurrency's `Task.sleep` instead of `DispatchQueue.asyncAfter`:
```swift
Task {
    try? await Task.sleep(for: .seconds(3))
    if !Task.isCancelled {
        // Dismiss toast
    }
}
```

### Toast Positioning

Position toast above bottom safe area:
```swift
.overlay(alignment: .bottom) {
    // Toast content
}
.padding(.bottom, 16) // Space from safe area
```

---

## Testing Checklist

### Manual Testing
- [ ] Archive conversation → toast appears at bottom
- [ ] Wait 3 seconds → toast auto-dismisses
- [ ] Tap "Undo" → conversation unarchives and toast dismisses
- [ ] Archive 3 conversations rapidly → only one toast shown
- [ ] Test on iPhone with notch → verify safe area respect
- [ ] Test on iPhone SE → verify safe area respect

### Accessibility Testing
- [ ] VoiceOver announces "Conversation archived" when toast appears
- [ ] VoiceOver can focus on "Undo" button
- [ ] "Undo" button is at least 44x44 points
- [ ] Toast contrast meets WCAG AA standards

### Edge Case Testing
- [ ] Archive conversation, then quickly archive another → verify toast updates
- [ ] Archive conversation, tap undo, then archive again → verify works correctly
- [ ] Dismiss InboxView while toast is showing → verify task is cancelled

---

## Definition of Done

- ✅ Toast component created
- ✅ Toast appears immediately after archive
- ✅ Undo functionality works correctly
- ✅ Auto-dismiss after 3 seconds works
- ✅ Haptic feedback on undo
- ✅ Safe area respected on all devices
- ✅ VoiceOver accessibility verified
- ✅ Smooth animations implemented
- ✅ No toast stacking issues
- ✅ No memory leaks from task cancellation

---

## Related Stories

- **Story 8.1:** Swipe-to-Archive (triggers this toast)
- **Story 8.2:** Archived Conversations View (alternative way to unarchive)
- **Story 8.10:** Enhanced Haptics (uses same haptic feedback system)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 703-756)
