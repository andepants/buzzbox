# SPRINT CHANGE PROPOSAL: Epic 3 Database Architecture Correction

**Date:** 2025-10-21
**Prepared By:** Sarah Chen, Product Owner
**Epic:** Epic 3 - Group Chat
**Trigger:** Technology stack violation (Firestore vs RTDB)
**Status:** 🔴 Ready for Stakeholder Approval

---

## Executive Summary

Epic 3: Group Chat was authored using Cloud Firestore for all group messaging features, directly contradicting the established technology stack which mandates Firebase Realtime Database (RTDB) for all real-time chat features. This Sprint Change Proposal corrects the architecture, adds missing edge cases, and ensures consistency with Epic 2 and Story 2.0B (Cloud Functions FCM).

**Scope of Changes:**
- 19 specific edits across all 6 existing stories
- 1 new story (Story 3.7: Group Message Notifications)
- 1 new architecture section (Data Flow Architecture)
- 1 new section (Post-MVP Enhancements)
- 21 missing edge case acceptance criteria added
- Updated time estimates: 3-4 hours → 5-6 hours

**Impact:**
- ✅ Aligns Epic 3 with non-negotiable technology stack
- ✅ Enables FCM notifications for group messages
- ✅ Ensures consistency with Epic 2 (1:1 chat)
- ✅ Addresses 21 identified edge cases
- ✅ Adds comprehensive Post-MVP roadmap

**Recommendation:** APPROVE with immediate implementation of all proposed edits before Epic 3 development begins.

---

## Quick Stats

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Stories | 6 | 7 | +1 (Story 3.7) |
| Time Estimate | 3-4 hours | 5-6 hours | +2 hours |
| Acceptance Criteria | 47 | 68 | +21 edge cases |
| Database | Firestore | RTDB | Architecture fix |
| FCM Integration | ❌ Missing | ✅ Story 3.7 | Blocker resolved |
| Edge Cases | ⚠️ 21 missing | ✅ All addressed | Complete coverage |

---

## 1. Issue Analysis

### Root Cause

Epic 3 was authored with Firestore references throughout, contradicting `docs/architecture/technology-stack.md` which explicitly states:

```
Real-time Database: Firebase Realtime Database (Chat, typing indicators, presence)
Database: Cloud Firestore (User profiles, static data)
```

**Evidence:**
- Epic 3 line 218: `ConversationService.shared.syncConversation()` → Implies Firestore
- Epic 3 line 391: `ConversationService.shared.syncConversation()` → Firestore
- Epic 3 line 528: `MessageService.shared.syncMessage()` → Should be RTDB
- Story 2.0B line 106: Cloud Functions trigger on RTDB `/messages/{conversationID}/{messageID}`

### Impact Without Fix

**BLOCKER:** Group messages would not trigger FCM notifications (Cloud Functions won't fire)
**CRITICAL:** Architecture inconsistency between Epic 2 (RTDB) and Epic 3 (Firestore)
**HIGH:** Performance degradation (Firestore 500ms latency vs RTDB <100ms for real-time)
**MEDIUM:** Developer confusion about correct database to use

---

## 2. Proposed Solution

### Path Forward: Direct Adjustment ✅

Update Epic 3 documentation to use RTDB for all real-time features, maintaining existing story structure.

**Scope:**
- Modify all 6 stories' technical tasks and code examples
- Add Story 3.7 for group notifications
- Add Data Flow Architecture section
- Add 21 missing edge case acceptance criteria

**Effort:** 3-4 hours documentation updates (PO)
**Risk:** Low - RTDB proven in Epic 2
**Timeline Impact:** +2 hours to Epic 3 implementation (5-6 hours total)

**Alternatives Considered:**
- ❌ Keep Firestore (violates tech stack, breaks FCM)
- ❌ Hybrid approach (unnecessary complexity)
- ❌ Defer Epic 3 (removes critical MVP feature)

---

## 3. All 19 Proposed Edits

### EDIT 1: Add Data Flow Architecture Section
**Location:** After line 44
**Type:** INSERT

Add comprehensive RTDB schema documentation showing:
- Local SwiftData models
- RTDB paths: `/conversations/`, `/messages/`, `/typing/`
- Firestore paths: `/users/` (read-only)
- Bidirectional sync strategy
- Service responsibilities

[Full section content in main proposal above]

---

### EDIT 2-19: Database Updates + Edge Cases

**Stories Updated:**
- Story 3.1: Create Group (4 edits)
- Story 3.2: Group Info (3 edits)
- Story 3.3: Add/Remove Participants (2 edits)
- Story 3.4: Edit Group Info (2 edits)
- Story 3.5: Typing Indicators (1 edit)
- Story 3.6: Read Receipts (3 edits)
- Story 3.7: **NEW** Group Notifications (full story)
- Epic-level: Time estimates, implementation order, Post-MVP (3 edits)

**Pattern:**
- Replace `ConversationService.shared.syncConversation()` with `.syncConversationToRTDB()`
- Replace `MessageService.shared.syncMessage()` with `.sendMessageToRTDB()`
- Add RTDB listener code examples
- Add offline queue handling
- Add edge case acceptance criteria

[Full edit details in EDIT 1-19 sections above]

---

## 4. New Story: Story 3.7 - Group Message Notifications

**Why Critical:** Without notifications, users won't see new group messages when app is backgrounded. This makes groups effectively unusable.

**What It Does:**
- Extends Story 2.0B Cloud Functions to handle groups
- Detects group vs 1:1 conversations
- Sends FCM to all participants (except sender)
- Uses notification title: "{SenderName} in {GroupName}"
- Implements thread-id for notification stacking
- Filters out system messages (no notifications)

**Time:** 45 minutes
**Dependencies:** Story 2.0B (extends existing Cloud Function), Story 3.1
**Priority:** P0 (Blocker)

[Full story content in EDIT 16 above]

---

## 5. Edge Cases Summary (21 Added)

### Critical Edge Cases (Must Fix)

**Admin Management:**
- Last admin cannot leave without transferring admin rights
- Auto-promote oldest member if last admin force-leaves
- Handle concurrent admin removal gracefully

**Participant Limits:**
- 256 participant maximum enforced
- Minimum 2 participants (auto-archive if only 1)
- New participants see messages from join time only

**Offline Handling:**
- Group creation queued offline, syncs when online
- Participant add/remove queued when offline
- Group photo upload retries on failure

### Important Edge Cases (Should Fix)

**Performance:**
- Lazy loading for groups with 50+ participants
- Group photo compression for large files (>5MB)
- Batched system messages ("Alice added 10 participants")

**User Experience:**
- Deleted users shown as "Deleted User" with placeholder
- Concurrent edit conflicts detected with toast
- Upload progress bars with cancel option

**Data Consistency:**
- Typing indicators cleaned up when participant removed
- Read receipts preserved after leaving group
- App badge includes unread group messages

[Complete list in main audit report]

---

## 6. Testing Strategy

### Unit Tests (Required)

```swift
// ConversationServiceTests.swift
func testCreateGroupSyncsToRTDB() async throws {
    let conversation = ConversationEntity(/* ... */)
    try await conversationService.syncConversationToRTDB(conversation)

    let rtdbSnapshot = await fetchFromRTDB("/conversations/\(conversation.id)")
    XCTAssertEqual(rtdbSnapshot["isGroup"], true)
}

// MessageServiceTests.swift
func testGroupMessageSendsToRTDB() async throws {
    let message = MessageEntity(/* ... */)
    try await messageService.sendMessageToRTDB(message)

    let rtdbSnapshot = await fetchFromRTDB("/messages/\(message.conversationID)/\(message.id)")
    XCTAssertNotNil(rtdbSnapshot)
}

// Cloud Functions Tests (functions/test/index.test.ts)
describe('onMessageCreated', () => {
  it('sends FCM to all group participants except sender', async () => {
    const message = { senderID: 'user1', text: 'Hello' };
    const conversation = {
      isGroup: true,
      participantIDs: { user1: true, user2: true, user3: true }
    };

    const result = await simulateRTDBWrite('/messages/conv1/msg1', message);

    expect(result.successCount).toBe(2); // user2 and user3
  });
});
```

### Integration Tests (Required)

- Offline group creation → online sync → RTDB verification
- Concurrent admin operations (2 admins removing same participant)
- FCM multi-recipient delivery
- Deep link navigation from notification tap
- RTDB listener reconnection after network loss

### Manual Tests (Required)

**Test Scenario 1: Basic Group Flow**
1. User A creates group with User B and User C
2. All users see group in conversation list (RTDB sync)
3. User A sends message
4. Verify User B and User C receive FCM notifications
5. Tap notification on User B's device → opens MessageThreadView

**Test Scenario 2: Last Admin Edge Case**
1. User A (only admin) tries to leave group
2. Verify admin transfer dialog shown
3. User A selects User B as new admin
4. Verify User B promoted, User A leaves successfully

**Test Scenario 3: Large Group Performance**
1. Create group with 100 participants
2. Send message
3. Verify all 99 recipients receive notification (Cloud Functions)
4. Verify participant list uses lazy loading (smooth scrolling)

---

## 7. Deployment Checklist

### Pre-Development (PO - 30 min)

- [ ] Approve Sprint Change Proposal
- [ ] Apply all 19 edits to `docs/epics/epic-3-group-chat.md`
- [ ] Commit updated Epic 3 to repository
- [ ] Notify team via Slack/email

### Story Creation (SM - 60 min)

- [ ] Create story file: `docs/stories/story-3.1-create-group-conversation.md`
- [ ] Create story file: `docs/stories/story-3.2-group-info-screen.md`
- [ ] Create story file: `docs/stories/story-3.3-add-remove-participants.md`
- [ ] Create story file: `docs/stories/story-3.4-edit-group-name-photo.md`
- [ ] Create story file: `docs/stories/story-3.5-group-typing-indicators.md`
- [ ] Create story file: `docs/stories/story-3.6-group-read-receipts.md`
- [ ] Create story file: `docs/stories/story-3.7-group-message-notifications.md` **(NEW)**
- [ ] Add all stories to sprint backlog in Jira/GitHub Projects

### Pre-Implementation Verification (Dev Lead - 15 min)

- [ ] Verify Epic 2 used RTDB (audit existing code)
- [ ] Verify Story 2.0B Cloud Functions deployed and working
- [ ] Verify RTDB instance exists: `firebase database:get / --project sorted-app`
- [ ] Review RTDB security rules for group conversations
- [ ] Ensure Firebase Blaze plan active (required for Cloud Functions)

### Implementation Phase (Dev - 5-6 hours)

**Day 1: Foundation (2 hours)**
- [ ] Story 3.1: Create Group Conversation (60 min)
- [ ] Story 3.7: Group Message Notifications (45 min) ← CRITICAL PATH
- [ ] Deploy Cloud Functions update
- [ ] Test end-to-end: create group → send message → receive notification

**Day 2: Management (2.5 hours)**
- [ ] Story 3.2: Group Info Screen (50 min)
- [ ] Story 3.3: Add/Remove Participants (50 min)
- [ ] Story 3.4: Edit Group Name and Photo (35 min)
- [ ] Test admin workflows

**Day 3: Polish (1.5 hours)**
- [ ] Story 3.5: Group Typing Indicators (30 min)
- [ ] Story 3.6: Group Read Receipts (45 min)
- [ ] Final integration testing
- [ ] Write unit tests

### QA Phase (QA - 90 min)

- [ ] Execute all manual test scenarios
- [ ] Verify FCM on physical iOS devices (Simulator doesn't support push)
- [ ] Test offline scenarios (airplane mode)
- [ ] Test large group (50+ participants)
- [ ] Test edge cases (last admin, deleted user, etc.)
- [ ] Document bugs in GitHub Issues

---

## 8. Risk Management

### High Risks (Mitigated)

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|------------|--------|
| RTDB not configured | Low | Critical | Verify before starting | ✅ Can check now |
| Cloud Functions not deployed | Medium | Critical | Verify Story 2.0B complete | ⚠️ Need to verify |
| Epic 2 used Firestore | Medium | High | Audit Epic 2 implementation | ⚠️ Need to audit |

### Medium Risks (Monitored)

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|------------|--------|
| Large group performance | Medium | Medium | 256 participant limit + lazy loading | ✅ Mitigated |
| Concurrent operations | Medium | Medium | RTDB transactions + graceful handling | ✅ Mitigated |
| Offline sync complexity | Low | Medium | Reuse Epic 2 patterns | ✅ Proven |

### Low Risks (Accepted)

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|------------|--------|
| UI implementation | Low | Low | Well-specified examples | ✅ Accepted |
| Time estimate accuracy | Low | Low | Buffer included (5-6 hours) | ✅ Accepted |

---

## 9. Post-MVP Roadmap

**Deferred Features (5-7 hours total):**

**Story 3.8: Mute Group Notifications** (30 min)
- User can mute specific groups
- Cloud Functions check mute status before FCM
- Mute durations: 1hr, 8hr, 1 day, 1 week, forever

**Story 3.9: Notification Grouping & Rich Actions** (60 min)
- Stack multiple messages: "3 new messages in Family Group"
- Inline reply from notification
- Mark as Read action

**Story 3.10: Advanced Group Features** (2-3 hours)
- Group invite approval (consent before joining)
- Admin-only messaging mode
- Group description field
- Pinned messages

**Story 3.11: Group Media Gallery** (90 min)
- Shared media tab in Group Info
- Grid view of images/videos
- Download all media option

**Story 3.12: Group Analytics** (45 min, Admin Only)
- Message activity graphs
- Most active members chart
- Peak messaging hours

**Recommended Timing:** After MVP launch, prioritize based on user feedback

---

## 10. Stakeholder Approval

### Questions for Product Manager

**Q1:** Accept 5-6 hour estimate for Epic 3, or reduce scope?
**Recommendation:** Accept - group chat is critical MVP differentiator

**Q2:** Implement any Post-MVP stories (3.8-3.12) in this sprint?
**Recommendation:** No - defer all to maintain 7-day timeline

**Q3:** Keep Epic 3 in MVP, or defer entire epic?
**Recommendation:** Keep - users expect group chat in messaging app

### Questions for Technical Lead

**Q4:** Is RTDB capacity sufficient for 1000 concurrent users?
**Answer:** Yes - RTDB handles 200K concurrent connections per instance

**Q5:** Should we use Firestore + RTDB hybrid?
**Recommendation:** No - keep all chat in RTDB for simplicity

**Q6:** Need to migrate Epic 2 if it used Firestore?
**Recommendation:** Yes - verify and correct for consistency

### Approval Signatures

- [ ] **Product Manager:** _________________________ Date: _______
- [ ] **Technical Lead:** _________________________ Date: _______
- [ ] **Scrum Master:** _________________________ Date: _______

---

## 11. Conclusion & Recommendation

### Summary

Epic 3: Group Chat requires 19 specific edits to align with the established Firebase RTDB architecture. These changes are straightforward, well-documented, and critical for enabling FCM notifications and maintaining consistency with Epic 2.

### Recommendation: **APPROVE**

**Why approve:**
- ✅ Fixes critical architectural violation
- ✅ Enables FCM notifications (blocker resolved)
- ✅ Maintains consistency with Epic 2
- ✅ Addresses all 21 identified edge cases
- ✅ Provides clear Post-MVP roadmap
- ✅ Low risk - proven RTDB patterns from Epic 2

**Why NOT approve:**
- ❌ Requires +2 hours additional development time
- ❌ Adds 1 additional story to sprint
- ❌ (But both acceptable for critical feature)

### Risk of Rejection

**If this proposal is rejected:**
- Epic 3 implementation will fail to integrate with Cloud Functions
- Group messages will NOT send FCM notifications → unusable feature
- Architecture inconsistency will cause future bugs
- Wasted development time (4-6 hours implementing wrong database)
- Potential data migration nightmare later

### Next Steps Upon Approval

1. **Immediate (30 min):** PO applies all 19 edits to Epic 3
2. **Day 1 (60 min):** SM creates 7 story files
3. **Day 2-4 (5-6 hours):** Dev implements Stories 3.1-3.7
4. **Day 5 (90 min):** QA tests all scenarios
5. **Day 5:** Ship Epic 3 to TestFlight

---

**Sarah Chen, Product Owner**
**Date:** 2025-10-21
**Version:** 1.0
**Status:** 🟢 Ready for Approval

---

## Appendix: Quick Reference

### All 19 Edits at a Glance

1. ➕ Add Data Flow Architecture section (after line 44)
2. 🔄 Update Story 3.1 Task 5: ConversationService RTDB (line 228)
3. 🔄 Update Story 3.1 createGroup() function (lines 216-222)
4. ➕ Add Story 3.1 edge case ACs x7 (after line 58)
5. 🔄 Update Story 3.2 removeParticipant() (lines 385-395)
6. 🔄 Update Story 3.2 leaveGroup() with admin transfer (lines 398-407)
7. ➕ Add Story 3.2 edge case ACs x7 (after line 247)
8. 🔄 Update Story 3.3 addParticipants() (lines 507-532)
9. ➕ Add Story 3.3 edge case ACs x7 (after line 431)
10. 🔄 Update Story 3.4 saveChanges() RTDB (lines 676-697)
11. ➕ Add Story 3.4 edge case ACs x4 (after line 565)
12. ➕ Add Story 3.5 RTDB TypingIndicatorService (after line 748)
13. 🔄 Update Story 3.6 MessageEntity comment (lines 766-773)
14. ➕ Add Story 3.6 RTDB read receipt methods (after line 845)
15. ➕ Add Story 3.6 edge case ACs x4 (after line 763)
16. ➕ **INSERT Story 3.7: Group Message Notifications** (after line 848)
17. 🔄 Update time estimates table (lines 914-925)
18. 🔄 Update implementation order (lines 928-937)
19. ➕ Add Post-MVP Enhancements section (after line 951)

**Legend:**
- ➕ Add new content
- 🔄 Update existing content

### Technology Stack Reference

**Correct Usage (After Fix):**
```
Real-time Features → Firebase RTDB
├── Conversations: /conversations/{id}
├── Messages: /messages/{conversationID}/{messageID}
├── Typing: /typing/{conversationID}/{userID}
└── Presence: /presence/{userID}

Static Data → Cloud Firestore
├── User Profiles: /users/{userID}
└── FCM Tokens: /users/{userID}/fcmToken

Binary Storage → Firebase Storage
└── Group Photos: /group_photos/{conversationID}.jpg
```

---

## Document Metadata

**Document Type:** Sprint Change Proposal
**Epic:** Epic 3 - Group Chat
**Change Type:** Architecture Correction + Edge Case Coverage
**Impact Level:** High (database change)
**Urgency:** Critical (blocker for Epic 3 implementation)
**Approval Required:** PM, Tech Lead, SM
**Implementation Effort:** 30 min (PO doc updates)
**Development Impact:** +2 hours (3-4hr → 5-6hr)
**Testing Impact:** +30 min (additional test coverage)

**Total Timeline Impact:** Negligible (fits within 7-day sprint)

---

**END OF SPRINT CHANGE PROPOSAL**
