# Story 8.12: Archive Notification Behavior

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P1 (Medium - Expected behavior)
**Effort:** 30 minutes
**Status:** Ready for Development

---

## Goal

Mute notifications for archived conversations to prevent interruptions from conversations the user has intentionally archived.

---

## User Story

**As** Andrew (The Creator),
**I want** archived conversations to stop sending me notifications,
**So that** I'm only notified about active conversations I care about.

---

## Dependencies

- ⚠️ **Story 8.1:** Swipe-to-Archive (creates archived conversations)
- ⚠️ **Story 8.2:** Archived Conversations View (provides unarchive functionality)
- ✅ Existing NotificationService

---

## Implementation

### NotificationService Update

Update `NotificationService.swift` to check `isArchived` before triggering notifications:

```swift
func shouldShowNotification(for conversation: ConversationEntity) -> Bool {
    // Don't notify for archived conversations
    guard !conversation.isArchived else {
        print("🔕 Notification muted: conversation archived")
        return false
    }

    // Don't notify for muted conversations
    guard !conversation.isMuted else {
        print("🔕 Notification muted: conversation muted")
        return false
    }

    return true
}
```

### Apply to All Notification Types

1. **In-app notifications:** Check before showing banner
2. **Local notifications:** Check before scheduling
3. **FCM push notifications:** Check in Cloud Functions before sending

### Cloud Functions Update

Update `functions/src/index.ts` to check `isArchived` before sending FCM:

```typescript
export const sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = context.params.conversationId;

    // Get conversation
    const conversationRef = admin.firestore()
      .collection('conversations')
      .doc(conversationId);
    const conversation = await conversationRef.get();

    // Don't send notification if archived
    if (conversation.data()?.isArchived) {
      console.log('🔕 Notification skipped: conversation archived');
      return null;
    }

    // Don't send notification if muted
    if (conversation.data()?.isMuted) {
      console.log('🔕 Notification skipped: conversation muted');
      return null;
    }

    // Send FCM notification
    // ... existing FCM logic
  });
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Archived conversations don't trigger in-app notifications
- ✅ Archived conversations don't trigger local notifications
- ✅ Archived conversations don't trigger push notifications (FCM)
- ✅ Auto-unarchiving conversation re-enables notifications
- ✅ Manual unarchiving conversation re-enables notifications

### Logging Requirements
- ✅ Log when notification is muted due to archive
- ✅ Include conversation ID in log for debugging
- ✅ Use consistent log format across platforms

---

## Edge Cases & Error Handling

### Auto-Unarchive Notification Resume
- ✅ **Behavior:** When conversation auto-unarchives (new message), notifications resume immediately
- ✅ **Implementation:** No caching - real-time check of `isArchived` status

### Manual Unarchive Notification Resume
- ✅ **Behavior:** Immediately re-enables notifications when user unarchives
- ✅ **Implementation:** Real-time property check, no delayed state

### Muted + Archived
- ✅ **Behavior:** Respects both flags (no notification if either is true)
- ✅ **Implementation:** Check both `isArchived` and `isMuted` in `shouldShowNotification()`

### Race Condition
- ✅ **Behavior:** Handle case where message arrives while archive is syncing
- ✅ **Implementation:** Check latest `isArchived` value from database, not cached state

---

## Files to Modify

### iOS Files
- `buzzbox/Core/Services/NotificationService.swift`
  - Add `shouldShowNotification()` helper function
  - Check `isArchived` before showing in-app notifications
  - Check `isArchived` before scheduling local notifications
  - Add logging for muted notifications

### Cloud Functions Files
- `functions/src/index.ts`
  - Add `isArchived` check in `sendMessageNotification` function
  - Add logging for muted notifications
  - Respect both `isArchived` and `isMuted` flags

---

## Technical Notes

### Notification Decision Logic

Follow this priority:
1. Check if conversation is archived → mute
2. Check if conversation is muted → mute
3. Check if user has notifications disabled → mute
4. Otherwise → send notification

### Real-Time Property Checks

Always check current `isArchived` value from the conversation entity, not cached state:
```swift
// Good - real-time check
if conversation.isArchived { return false }

// Bad - could use stale cached value
if cachedIsArchivedStatus { return false }
```

### Cloud Functions Database Query

Query Firestore for latest conversation state:
```typescript
const conversation = await conversationRef.get();
const isArchived = conversation.data()?.isArchived ?? false;
```

---

## Testing Checklist

### iOS Notification Testing
- [ ] Archive conversation → send message → verify no in-app notification
- [ ] Archive conversation → send message → verify no local notification
- [ ] Archive conversation → unarchive → send message → verify notification appears
- [ ] Muted + archived conversation → verify no notification
- [ ] Check logs → verify "conversation archived" log appears

### Cloud Functions Testing
- [ ] Archive conversation → send message → verify no FCM push
- [ ] Archive conversation → unarchive → send message → verify FCM push sent
- [ ] Check Cloud Functions logs → verify "conversation archived" log appears
- [ ] Test on physical device (push notifications require real device)

### Edge Case Testing
- [ ] Send message while archiving (race condition) → verify correct behavior
- [ ] Auto-unarchive (new message arrives) → verify notifications resume
- [ ] Manual unarchive → send message → verify notification appears

---

## Definition of Done

- ✅ `shouldShowNotification()` function implemented in NotificationService
- ✅ `isArchived` check added to all notification paths (in-app, local, FCM)
- ✅ Cloud Functions updated with `isArchived` check
- ✅ Logging added for muted notifications
- ✅ Auto-unarchive re-enables notifications verified
- ✅ Manual unarchive re-enables notifications verified
- ✅ Muted + archived case handled correctly
- ✅ No regression in existing notification functionality
- ✅ Tested on physical device (FCM)

---

## Related Stories

- **Story 8.1:** Swipe-to-Archive (sets isArchived property)
- **Story 8.2:** Archived Conversations View (provides unarchive)
- **Story 8.11:** Undo Archive Toast (alternative unarchive method)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 759-803)
