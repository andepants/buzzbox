# Epic 8: Pre-Deployment Testing Matrix

**Version:** 1.0
**Date:** 2025-10-25
**Estimated Time:** 45 minutes
**Required Devices:** iPhone SE (small) + iPhone 14/15 Pro (Dynamic Island)

---

## Critical Path Tests (Required - 20 minutes)

### Test 1: Archive Workflow End-to-End (5 minutes)

**Setup:**
- Login as creator (andrewsheim@gmail.com)
- Inbox with 3+ conversations

**Steps:**
1. ✅ Swipe conversation left → Archive
2. ✅ Toast appears at bottom with "Undo" button
3. ✅ Tap "Undo" → Conversation returns to inbox
4. ✅ Archive again → Wait 3 seconds → Toast auto-dismisses
5. ✅ Tap Archive icon in toolbar → Archived view opens
6. ✅ Verify conversation appears dimmed (0.6 opacity)
7. ✅ Swipe right to unarchive → Returns to inbox
8. ✅ Archive conversation → Send message from fan account → Auto-unarchive
9. ✅ Check notifications muted while archived

**Pass Criteria:**
- All swipe gestures work smoothly
- Toast animations smooth (no jank)
- Archive/unarchive syncs to Firebase
- Notifications properly muted/unmuted

**Known Issues:** None

---

### Test 2: Dark Mode System (5 minutes)

**Setup:**
- Start in light mode
- Navigate to Settings → Profile

**Steps:**
1. ✅ Tap "Dark Mode" toggle → App switches to dark mode
2. ✅ Navigate: Inbox → Thread → Channels → Profile
3. ✅ Verify no white cards, proper shadows, readable text
4. ✅ Toggle back to Light Mode → Smooth transition
5. ✅ Set to "System" → Change iOS setting → App follows system
6. ✅ Open archived view in dark mode → Verify proper adaptation
7. ✅ Send message in dark mode → Verify input field keyboard matches

**Pass Criteria:**
- No hardcoded white/black colors visible
- Shadows visible in both modes
- Text meets WCAG AA contrast (4.5:1 minimum)
- Keyboard appearance matches mode

**Known Issues:** None

---

### Test 3: Skeleton Loading States (5 minutes)

**Setup:**
- Kill app → Clear cache (optional)
- Cold start from home screen

**Steps:**
1. ✅ Open app → Skeleton shows in inbox
2. ✅ Wait for content load → Smooth fade transition
3. ✅ Open conversation thread → Skeleton shows for messages
4. ✅ Fast network test → Verify 500ms minimum display (no flicker)
5. ✅ Slow network test → Skeleton persists until load complete
6. ✅ Navigate back to inbox → Cached content loads instantly

**Pass Criteria:**
- Skeleton layout matches final content
- No layout shift during transition
- Minimum 500ms display prevents flicker
- Smooth animations (60fps)

**Known Issues:**
- ⚠️ No timeout error state after 10 seconds (logged as future enhancement)

---

### Test 4: AI Category Filter (5 minutes)

**Setup:**
- Inbox with conversations in multiple categories (Quick Win, Important, FAQ)
- Ensure test data has varied AI scores

**Steps:**
1. ✅ Tap "Quick Win" filter chip → Only quick win conversations shown
2. ✅ Check badge count → Matches number of conversations
3. ✅ Tap "Important" filter → Only important conversations shown
4. ✅ Tap "FAQ" filter → Only FAQ conversations shown
5. ✅ Combine filter + search → Verify AND logic (both filters applied)
6. ✅ Switch filters rapidly → Verify smooth animations
7. ✅ Return to "All" → All conversations visible

**Pass Criteria:**
- Correct conversations filtered per category
- Badge counts accurate
- Smooth chip selection animation
- Search + filter work together (AND logic)

**Known Issues:** None

---

## Accessibility Tests (Required - 10 minutes)

### Test 5: VoiceOver Support (5 minutes)

**Setup:**
- Enable VoiceOver (Settings → Accessibility → VoiceOver)

**Steps:**
1. ✅ Navigate inbox → VoiceOver announces conversation details
2. ✅ Swipe to archive → "Archive" action announced
3. ✅ Undo toast appears → Message and "Undo" button accessible
4. ✅ Navigate to archived view → "Archived conversations" announced
5. ✅ Filter chips → Each category announced correctly
6. ✅ Dark mode toggle → State announced ("On" / "Off")

**Pass Criteria:**
- All interactive elements have accessibility labels
- Swipe actions discoverable via VoiceOver menu
- Toast message read aloud
- All buttons have hints where appropriate

**Known Issues:** None

---

### Test 6: Reduce Motion + Haptics (5 minutes)

**Setup:**
- Enable Reduce Motion (Settings → Accessibility → Motion → Reduce Motion)

**Steps:**
1. ✅ Archive conversation → Verify haptic feedback DISABLED
2. ✅ Send message → Verify haptic feedback DISABLED
3. ✅ Toggle filter chip → Verify haptic feedback DISABLED
4. ✅ Disable Reduce Motion
5. ✅ Archive conversation → Verify haptic feedback ENABLED (medium impact)
6. ✅ Send message → Verify haptic feedback ENABLED (light impact)

**Pass Criteria:**
- Haptics respect Reduce Motion setting
- No haptics when Reduce Motion is ON
- Proper haptic types when Reduce Motion is OFF

**Known Issues:** None

---

## Device-Specific Tests (Required - 10 minutes)

### Test 7: Small Screen (iPhone SE) (5 minutes)

**Device:** iPhone SE (2nd gen or later)

**Steps:**
1. ✅ Inbox view → Verify no content truncation
2. ✅ Skeleton loading → Verify layout fits screen
3. ✅ Undo toast → Verify not overlapping with navigation
4. ✅ Filter chips → Verify wrap to multiple rows if needed
5. ✅ Archived view → Verify scrollable content
6. ✅ Dark mode → Verify proper rendering on small screen

**Pass Criteria:**
- All content visible (no off-screen elements)
- Toast respects safe area
- Filter chips wrap gracefully
- No horizontal scrolling

**Known Issues:** None

---

### Test 8: Dynamic Island (iPhone 14/15 Pro) (5 minutes)

**Device:** iPhone 14 Pro or iPhone 15 Pro

**Steps:**
1. ✅ Launch app → Verify no overlap with Dynamic Island
2. ✅ Dark mode → Verify status bar text readable
3. ✅ Undo toast → Verify respects top safe area
4. ✅ Skeleton loading → Verify no overlap with island
5. ✅ Full-screen modals → Verify safe area insets correct

**Pass Criteria:**
- No UI elements overlap with Dynamic Island
- Status bar text adapts to background
- Safe area insets respected throughout

**Known Issues:** None

---

## Performance Tests (Optional - 5 minutes)

### Test 9: Animation Performance (3 minutes)

**Setup:**
- Inbox with 20+ conversations

**Steps:**
1. ✅ Rapidly scroll inbox → Verify 60fps (smooth scrolling)
2. ✅ Rapidly switch filter chips → Verify smooth animations
3. ✅ Toggle dark mode → Verify transition <100ms
4. ✅ Archive/unarchive rapidly → Verify no lag or dropped frames

**Pass Criteria:**
- No visible jank or stuttering
- Animations complete smoothly
- Scrolling feels responsive

**Known Issues:** None

---

### Test 10: Memory & Battery (2 minutes)

**Setup:**
- Use Xcode Instruments (optional)

**Steps:**
1. ✅ Open app → Monitor memory usage
2. ✅ Navigate through all screens → Check for leaks
3. ✅ Archive/unarchive 10 times → Monitor memory
4. ✅ Leave app open for 5 minutes → Check battery drain

**Pass Criteria:**
- Memory stable (no continuous growth)
- No memory leaks detected
- Battery drain minimal when idle

**Known Issues:** None

---

## Regression Tests (Optional - 10 minutes)

### Test 11: Epic 5/6/7 Features (5 minutes)

**Verify no regressions:**
1. ✅ Epic 5: Inbox still loads conversations
2. ✅ Epic 6: AI scoring still works
3. ✅ Epic 7: Smart replies still generate
4. ✅ Push notifications still arrive
5. ✅ Image upload still works

**Pass Criteria:**
- All existing features still functional
- No broken UI from dark mode changes

**Known Issues:** None

---

### Test 12: Edge Cases (5 minutes)

**Rare scenarios:**
1. ✅ Archive all conversations → Verify empty state shows
2. ✅ Search with no results → Verify empty search state
3. ✅ Archive while offline → Verify syncs when online
4. ✅ Receive message while archived view open → Verify auto-unarchive
5. ✅ Rapidly toggle dark mode 10 times → Verify no crashes

**Pass Criteria:**
- Empty states display correctly
- Offline operations queue properly
- No crashes under stress

**Known Issues:** None

---

## Known Issues Summary

### Non-Blocking Issues (Safe to Ship)

**Issue #1: Skeleton Timeout (Story 8.9)**
- **Severity:** Low
- **Impact:** No error state if loading exceeds 10 seconds
- **Workaround:** Network errors are logged; app remains functional
- **Fix Timeline:** Epic 9 (future enhancement)

**Issue #2: Partial Haptic Coverage (Story 8.10)**
- **Severity:** Low
- **Impact:** Some haptics dependent on pending features
- **Status:** By design; features not yet implemented
- **Fix Timeline:** As dependency stories mature

**Issue #3: Launch Screen Manual Step (Story 8.3)**
- **Severity:** Medium
- **Impact:** Generic iOS launch screen until manual step complete
- **Workaround:** 5-minute Xcode setup (documented)
- **Fix Timeline:** Before TestFlight (required)

---

## Testing Sign-Off

### Pre-Deployment Checklist

- [ ] All Critical Path Tests passed (Tests 1-4)
- [ ] All Accessibility Tests passed (Tests 5-6)
- [ ] All Device-Specific Tests passed (Tests 7-8)
- [ ] Story 8.3 manual steps completed (launch screen)
- [ ] Tested on minimum 2 physical devices
- [ ] No critical or high-severity bugs found
- [ ] All known issues documented and accepted

### TestFlight Checklist

- [ ] Beta build uploaded to TestFlight
- [ ] 5-10 beta testers invited
- [ ] Feedback collection form sent
- [ ] 48-hour beta period started
- [ ] Monitoring beta feedback channel

### App Store Checklist

- [ ] Beta feedback addressed (if any)
- [ ] Final build validated
- [ ] App Store screenshots updated (with dark mode)
- [ ] App Store description mentions new features
- [ ] Release notes prepared

---

## Device Testing Matrix

| Device | iOS | Test 1 | Test 2 | Test 3 | Test 4 | Test 5 | Test 6 | Test 7 | Test 8 | Notes |
|--------|-----|--------|--------|--------|--------|--------|--------|--------|--------|-------|
| iPhone SE (2nd) | 17.0 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | N/A | Small screen |
| iPhone 13 | 17.0 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | N/A | N/A | Baseline |
| iPhone 14 Pro | 17.0 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | N/A | ⬜ | Dynamic Island |
| iPhone 15 Pro Max | 17.0 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | N/A | ⬜ | Large screen |

**Legend:**
- ⬜ Not started
- 🟡 In progress
- ✅ Passed
- ❌ Failed
- N/A Not applicable

---

## Tester Notes

**Environment:**
- Xcode Version: _______________
- iOS Simulator Version: _______________
- Physical Device 1: _______________
- Physical Device 2: _______________

**Build Information:**
- Build Number: _______________
- Build Date: _______________
- Git Commit: _______________

**Testing Date:** _______________
**Tester Name:** _______________
**Signature:** _______________

---

## Quick Test Script (15 Minutes)

**For rapid validation before commits:**

```bash
# Critical tests only
Test 1: Archive → Undo → Archive → Check archived view (2 min)
Test 2: Toggle dark mode → Navigate all screens (2 min)
Test 3: Cold start → Skeleton → Content load (1 min)
Test 4: Filter chips → Quick Win → Important → FAQ → All (2 min)
Test 5: VoiceOver → Archive action → Undo toast (3 min)
Test 7: iPhone SE simulator → Verify layout (2 min)
Test 8: iPhone 15 Pro simulator → Verify Dynamic Island (2 min)
Test 11: Send message → Upload image → Verify works (1 min)

Total: 15 minutes
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25T16:00:00Z
**Next Review:** Before TestFlight submission

**Maintained By:** Quinn (QA Specialist)
**Contact:** Via BMAD Agent System
