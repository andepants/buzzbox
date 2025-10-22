# Story 3.10: Read Receipts for One-on-One Conversations - QA Test Plan

**Story:** Read Receipts for 1:1 Conversations
**Priority:** P0 (MVP Blocker)
**Implementation Date:** 2025-10-22
**Test Environment:** iOS 17+ Simulator & Physical Devices

---

## Implementation Summary

### Files Modified
1. ✅ `buzzbox/Features/Chat/Views/MessageBubbleView.swift` - Removed `&& conversation.isGroup` restriction (line 46)
2. ✅ `buzzbox/Features/Chat/Views/ReadReceiptsView.swift` - Added 1:1 UI variant with "Message Info" sheet
3. ✅ Verified `MessageService.swift` - Read receipt methods work for all conversations (no changes needed)

### Changes Made
- **MessageBubbleView:** Long press now works on own messages in both 1:1 and group chats
- **ReadReceiptsView:** Conditional UI - groups show "Read By" list, 1:1 shows "Message Info" with timestamps
- **Backend:** Already supports 1:1 (writes to `/messages/{conversationID}/{messageID}/readBy/{userID}`)

---

## Test Prerequisites

### Setup Requirements
- [ ] Two iOS devices (Device A, Device B) OR two simulators
- [ ] Both devices logged into different accounts (User A, User B)
- [ ] Firebase Auth working
- [ ] RTDB connection active
- [ ] Existing 1:1 conversation between User A and User B

### Environment Checks
```bash
# Verify RTDB rules allow read receipt writes
# Check Firebase Console > Realtime Database > Rules
# Should have: /messages/{conversationID}/{messageID}/readBy/{userID}
#   allow write: if request.auth.uid == {userID}
```

---

## Test Plan

### Test 1: Basic Read Receipt Flow (1:1 Conversation)
**Objective:** Verify read receipts work end-to-end in 1:1 chats

**Steps:**
1. **Device A:** Open conversation with User B
2. **Device A:** Send message "Test read receipt"
3. **Device A:** Observe message status → Should show single gray checkmark (sent)
4. **Device B:** Open app
5. **Device B:** Navigate to conversation with User A
6. **Device B:** Scroll to view the message
7. **Device A:** Wait 1-2 seconds

**Expected Results:**
- ✅ Device A sees checkmark change: single → double gray (delivered) → double blue (read)
- ✅ Status transitions happen automatically without refresh
- ✅ Real-time update within 2 seconds

**Pass Criteria:**
- [ ] Message shows single checkmark after send
- [ ] Checkmark becomes double gray when delivered
- [ ] Checkmark turns blue when read
- [ ] Updates happen in real-time

---

### Test 2: Message Info Sheet (1:1 Conversation)
**Objective:** Verify long press opens "Message Info" sheet with read timestamp

**Steps:**
1. **Device A:** Send message to User B
2. **Device B:** Open conversation, read the message
3. **Device A:** Wait for blue checkmark
4. **Device A:** Long press on own message
5. **Device A:** Observe sheet that appears

**Expected Results:**
- ✅ Sheet opens with title "Message Info"
- ✅ Sheet shows three rows:
  - Sent: [timestamp]
  - Delivered: ✓ (green checkmark)
  - Read: [timestamp] (time + date)

**Pass Criteria:**
- [ ] Long press gesture works (sheet opens)
- [ ] Sheet title is "Message Info" (NOT "Read By")
- [ ] Sent timestamp matches message creation time
- [ ] Delivered shows green checkmark
- [ ] Read shows timestamp (not "Not yet")

---

### Test 3: Unread Message Info
**Objective:** Verify sheet shows "Not yet" for unread messages

**Steps:**
1. **Device A:** Send message to User B
2. **Device A:** DO NOT open on Device B
3. **Device A:** Wait for double gray checkmark (delivered)
4. **Device A:** Long press on message

**Expected Results:**
- ✅ Sheet shows:
  - Sent: [timestamp]
  - Delivered: ✓
  - Read: "Not yet" (gray text)

**Pass Criteria:**
- [ ] Sheet opens
- [ ] Read status shows "Not yet" instead of timestamp
- [ ] "Not yet" text is gray/secondary color

---

### Test 4: Offline Read Receipt Sync
**Objective:** Verify read receipts sync when connection restored

**Steps:**
1. **Device A:** Turn off WiFi
2. **Device B:** Send message to User A
3. **Device B:** See message delivered (Device A offline)
4. **Device A:** Turn on WiFi
5. **Device A:** Message appears, automatically marked as read
6. **Device B:** Observe checkmark status

**Expected Results:**
- ✅ Device B sees checkmark turn blue after Device A reconnects
- ✅ Sync happens automatically (no manual action needed)

**Pass Criteria:**
- [ ] Read receipt syncs when Device A comes online
- [ ] Device B sees blue checkmark update
- [ ] Sync completes within 5 seconds of reconnection

---

### Test 5: Regression - Group Read Receipts Still Work
**Objective:** Ensure group read receipts were not broken by changes

**Steps:**
1. **Device A:** Create group with User A, User B, User C
2. **Device A:** Send message to group
3. **Devices B & C:** Read the message
4. **Device A:** Long press on own message

**Expected Results:**
- ✅ Sheet opens with title "Read By" (NOT "Message Info")
- ✅ Sheet shows two sections: "Read" and "Delivered"
- ✅ Read section lists User B and User C with timestamps
- ✅ Multi-recipient list (NOT single-recipient info)

**Pass Criteria:**
- [ ] Long press works in groups
- [ ] Sheet title is "Read By" (not "Message Info")
- [ ] Shows list of participants who read
- [ ] Shows timestamps for each reader

---

### Test 6: System Messages Don't Show Read Receipts
**Objective:** Verify system messages can't be long-pressed

**Steps:**
1. **Device A:** Create group with User B
2. **Device A:** Add User C to group
3. **Device A:** System message appears: "User A added User C"
4. **Device A:** Try to long press system message

**Expected Results:**
- ✅ Long press does NOT open read receipts sheet
- ✅ System messages are not interactive

**Pass Criteria:**
- [ ] System messages cannot be long-pressed
- [ ] No read receipts sheet for system messages

---

### Test 7: Received Messages Don't Show Read Receipts
**Objective:** Verify read receipts only work on own messages

**Steps:**
1. **Device A:** Send message to User B
2. **Device B:** Receive message
3. **Device B:** Try to long press on received message (from User A)

**Expected Results:**
- ✅ Long press does NOT open read receipts sheet
- ✅ Only own messages show read receipts

**Pass Criteria:**
- [ ] Long press on received message does nothing (or shows context menu if implemented)
- [ ] Read receipts only work on own sent messages

---

### Test 8: VoiceOver Accessibility
**Objective:** Verify VoiceOver announces read status

**Steps:**
1. **Device A:** Enable VoiceOver (Settings > Accessibility > VoiceOver)
2. **Device A:** Send message to User B
3. **Device B:** Read the message
4. **Device A:** Wait for blue checkmark
5. **Device A:** Swipe to message bubble with VoiceOver

**Expected Results:**
- ✅ VoiceOver announces: "[message text], read"
- ✅ Status is audible without visual confirmation

**Pass Criteria:**
- [ ] VoiceOver reads message content
- [ ] VoiceOver announces "read" status
- [ ] Announcement updates when status changes

---

### Test 9: Cross-Device Sync
**Objective:** Verify read receipts sync across multiple devices for same user

**Setup:** User A logged in on Device 1 and Device 2

**Steps:**
1. **Device A1:** Send message to User B
2. **Device B:** Read the message
3. **Device A1:** See blue checkmark
4. **Device A2:** Open same conversation

**Expected Results:**
- ✅ Device A2 also shows blue checkmark (synced via RTDB)
- ✅ Both devices show same read status

**Pass Criteria:**
- [ ] Read status syncs to all User A devices
- [ ] Both devices show blue checkmark

---

### Test 10: Rapid Message Read/Unread
**Objective:** Verify read receipts handle rapid status changes

**Steps:**
1. **Device A:** Send 5 rapid messages to User B
2. **Device B:** Open conversation (all 5 visible)
3. **Device A:** Observe all 5 messages turn blue within seconds
4. **Device A:** Long press each message

**Expected Results:**
- ✅ All messages show blue checkmark
- ✅ All message info sheets show read timestamp
- ✅ No race conditions or inconsistent states

**Pass Criteria:**
- [ ] All messages marked as read
- [ ] All show consistent read timestamps
- [ ] No crashes or UI glitches

---

## Edge Cases

### Edge Case 1: Message Read Before Send Completes
**Scenario:** Recipient reads message before sender's device confirms send

**Steps:**
1. **Device A:** Send message on slow network
2. **Device B:** Receive and read immediately
3. **Device A:** Wait for sync to complete

**Expected:**
- Message may jump from "sending" to "read" (skip "sent/delivered")
- No crashes, final state is correct

### Edge Case 2: User Deleted Account
**Scenario:** Recipient deletes account before reading

**Expected:**
- Message stays on "delivered" (never reaches "read")
- No crashes when opening message info

### Edge Case 3: Very Old Conversation
**Scenario:** Open conversation from 6 months ago

**Expected:**
- Old read receipts still display correctly
- Timestamps format correctly (show date + time)

---

## Performance Benchmarks

| Metric | Target | Measured |
|--------|--------|----------|
| Time to show blue checkmark after read | < 2 seconds | ______ |
| Sheet open latency | < 200ms | ______ |
| Offline sync after reconnect | < 5 seconds | ______ |
| Memory usage (100 messages) | < 50MB additional | ______ |

---

## Rollback Plan

If critical issues found:

1. **Quick Fix:** Revert `MessageBubbleView.swift` line 46:
   ```swift
   // Revert to:
   isFromCurrentUser && conversation.isGroup && !message.isSystemMessage
   ```

2. **Deploy:** Push to TestFlight with reverted code

3. **Timeline:** Can revert in < 5 minutes

---

## Sign-Off

### Developer Sign-Off
- [ ] All code changes implemented
- [ ] No compiler warnings
- [ ] No SwiftLint violations
- [ ] Code reviewed

**Developer:** ________________  **Date:** ________

### QA Sign-Off
- [ ] All 10 tests passed
- [ ] Edge cases verified
- [ ] Performance benchmarks met
- [ ] Regression tests passed

**QA Engineer:** ________________  **Date:** ________

### Product Owner Sign-Off
- [ ] Acceptance criteria met
- [ ] User experience validated
- [ ] Ready for TestFlight deployment

**Product Owner:** ________________  **Date:** ________

---

## Test Execution Log

| Test ID | Tester | Date | Result | Notes |
|---------|--------|------|--------|-------|
| Test 1 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 2 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 3 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 4 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 5 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 6 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 7 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 8 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 9 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |
| Test 10 | ______ | ____ | ⬜ PASS ⬜ FAIL | ________________________ |

---

**Overall Status:** ⬜ PASS ⬜ FAIL ⬜ BLOCKED

**Blocker Issues:** _____________________________________________

**Next Steps:** __________________________________________________
