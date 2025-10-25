# Story 8.1: Swipe-to-Archive (Superhuman-style)

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P0 (Critical for demo)
**Effort:** 2.5 hours
**Status:** Ready for Development

---

## Goal

Enable left swipe gesture on conversations in the inbox to archive them, following Superhuman's signature interaction pattern.

---

## User Story

**As** Andrew (The Creator),
**I want** to archive conversations with a left swipe gesture,
**So that** I can quickly manage my inbox without tapping through menus.

---

## Dependencies

- ✅ Epic 5: Single-Creator Platform (provides inbox structure)
- ✅ Epic 6: AI Features (provides ConversationEntity with isArchived property)
- ⚠️ Pairs with Story 8.11 (Undo Archive Toast)

---

## Implementation

### SwiftUI Swipe Actions

Add `.swipeActions(edge: .leading)` to ConversationRowView in InboxView:

```swift
.swipeActions(edge: .leading) {
    Button {
        archiveConversation()
        HapticFeedback.impact(.medium)
    } label: {
        Label("Archive", systemImage: "archivebox")
    }
    .tint(.gray)
}
```

### Archive Logic

1. Update `ConversationEntity.isArchived = true`
2. Sync to Firebase via ConversationService
3. Remove from inbox view immediately
4. Queue archive operation if offline (sync when online)
5. Disable swipe while conversation is actively syncing
6. Show toast with undo button (3-second timeout) - Story 8.11
7. Auto-unarchive conversation if new message arrives

### Haptic Feedback

Trigger medium impact haptic when archive completes:
```swift
HapticFeedback.impact(.medium)
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Full left swipe archives conversation
- ✅ Conversation disappears from inbox immediately
- ✅ Haptic feedback triggers on archive
- ✅ Archive syncs to Firebase (persists across devices)
- ✅ VoiceOver announces "Archived"

### Integration Requirements
- ✅ Follows Superhuman-style: full swipe required (destructive style)
- ✅ Works with existing ConversationEntity model
- ✅ Integrates with ConversationService for Firebase sync

---

## Edge Cases & Error Handling

### Offline Archive
- ✅ **Behavior:** Archives locally when offline, syncs when online
- ✅ **Visual Indicator:** Shows "Pending sync" badge if offline
- ✅ **Implementation:** Queue operation in ConversationService

### Sync State
- ✅ **Behavior:** Cannot swipe while `syncStatus == .syncing` (disabled gesture)
- ✅ **Implementation:** Use `.disabled()` modifier when syncing

### New Message Auto-Unarchive
- ✅ **Behavior:** Auto-unarchives conversation when fan sends new message
- ✅ **Implementation:** Add logic to ConversationService message handler

### Undo Functionality
- ✅ **Behavior:** Toast appears with "Undo" button (3-second timeout)
- ✅ **Implementation:** See Story 8.11 for toast component

### Rapid Swipe Protection
- ✅ **Behavior:** Debounces multiple rapid swipes (max 1 per 500ms)
- ✅ **Implementation:** Track last archive timestamp

### Unread Count Preservation
- ✅ **Behavior:** Preserves unread count on archive
- ✅ **Implementation:** Don't reset `unreadCount` when archiving

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add `.swipeActions()` modifier to conversation list
  - Add archive handler function
  - Add offline queue support

### Secondary Files
- `buzzbox/Core/Services/ConversationService.swift`
  - Add auto-unarchive logic for new messages
  - Add offline sync queue
  - Add debounce logic for rapid swipes

---

## Technical Notes

### SwiftUI Swipe Actions API
- Uses built-in `.swipeActions(edge:)` modifier (iOS 15+)
- No third-party dependencies required
- Native accessibility support included

### Archive Property
The `ConversationEntity.isArchived` property already exists from Epic 6:
```swift
@Model
class ConversationEntity {
    var isArchived: Bool = false
    // ... other properties
}
```

### Superhuman-Style Implementation
- Full swipe required (not partial)
- Destructive style (.tint(.gray))
- Haptic feedback confirmation
- Instant visual feedback

---

## Testing Checklist

### Manual Testing
- [ ] Archive conversation while online → verify syncs to Firebase
- [ ] Archive conversation while offline → verify local archive + sync on reconnect
- [ ] Attempt to swipe while syncing → verify gesture disabled
- [ ] Receive message while archived → verify auto-unarchive
- [ ] Rapid swipe 5 conversations → verify debounce works
- [ ] Archive conversation with unread count → verify count preserved

### Accessibility Testing
- [ ] VoiceOver announces "Archived" on swipe
- [ ] Swipe action discoverable via VoiceOver actions menu
- [ ] Haptic feedback respects iOS system settings

### Edge Case Testing
- [ ] Archive last conversation in inbox → verify empty state
- [ ] Archive conversation with pending outgoing message
- [ ] Archive during active network request

---

## Definition of Done

- ✅ Functional requirements met
- ✅ Edge cases handled
- ✅ Haptic feedback implemented
- ✅ Offline sync queue working
- ✅ Auto-unarchive logic implemented
- ✅ VoiceOver accessibility verified
- ✅ Code follows existing patterns
- ✅ No regression in existing inbox functionality

---

## Related Stories

- **Story 8.11:** Undo Archive Toast (complements this story)
- **Story 8.2:** Archived Conversations View (viewing archived conversations)
- **Story 8.12:** Archive Notification Behavior (muting archived convos)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 115-149)
