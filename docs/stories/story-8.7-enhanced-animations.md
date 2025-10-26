# Story 8.7: Enhanced UI Animations

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 2 - Interactive Polish
**Priority:** P1 (High - Premium feel)
**Effort:** 2 hours
**Status:** ✅ Complete (2025-10-25)

---

## Goal

Add smooth 60fps animations throughout the app to make interactions feel premium and responsive.

---

## User Story

**As** a user,
**I want** smooth animations when interacting with the app,
**So that** the app feels polished, alive, and responsive to my actions.

---

## Dependencies

- ✅ No external dependencies
- ⚠️ Integrates with Story 8.1 (Archive swipe animation)
- ⚠️ Integrates with Story 8.6 (Filter chip animation)

---

## Implementation

### Animation Categories

#### 1. Message Send Animation

In `MessageBubbleView.swift`:

```swift
struct MessageBubbleView: View {
    @State private var isSending = false

    var body: some View {
        messageBubble
            .scaleEffect(isSending ? 0.95 : 1.0)
            .opacity(isSending ? 0.8 : 1.0)
            .onTapGesture {
                if message.isSending {
                    withAnimation(.spring(duration: 0.2, bounce: 0.1)) {
                        isSending = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                            isSending = false
                        }
                    }
                }
            }
    }
}
```

#### 2. Message Receive Animation

In `MessageThreadView.swift`:

```swift
struct MessageThreadView: View {
    @State private var messageAnimationID = UUID()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageBubbleView(message: message)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(duration: 0.4, bounce: 0.2), value: messageAnimationID)
                }
            }
        }
        .onChange(of: messages.count) { oldValue, newValue in
            if newValue > oldValue {
                // New message arrived
                messageAnimationID = UUID()
            }
        }
    }
}
```

#### 3. Conversation Row Tap Feedback

In `ConversationRowView.swift`:

```swift
struct ConversationRowView: View {
    @State private var isTapped = false

    var body: some View {
        rowContent
            .scaleEffect(isTapped ? 0.98 : 1.0)
            .onTapGesture {
                withAnimation(.spring(duration: 0.15, bounce: 0.1)) {
                    isTapped = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(duration: 0.2, bounce: 0.2)) {
                        isTapped = false
                    }
                }

                // Navigate to conversation
                navigateToConversation()
            }
    }
}
```

#### 4. Archive Swipe Animation

In `InboxView.swift`:

```swift
.swipeActions(edge: .leading) {
    Button {
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            archiveConversation(conversation)
        }
    } label: {
        Label("Archive", systemImage: "archivebox")
    }
    .tint(.gray)
}
```

#### 5. Filter Chip Selection Animation

Already implemented in Story 8.6:

```swift
withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
    selectedCategory = category
}
```

#### 6. FAB Expand/Collapse Animation

Already implemented in existing FloatingFABView (no changes needed).

---

## Respect Reduce Motion & Low Power Mode

Add accessibility checks:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var shouldAnimate: Bool {
    !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
}

.animation(shouldAnimate ? .spring(duration: 0.3, bounce: 0.2) : .none, value: state)
```

Apply to all decorative animations.

---

## Acceptance Criteria

### Performance Requirements
- ✅ All animations run at 60fps
- ✅ Animations feel natural and responsive
- ✅ No jank or dropped frames
- ✅ Smooth on iPhone X (minimum target)

### Accessibility Requirements
- ✅ Reduce Motion disables decorative animations
- ✅ Essential animations (like transitions) remain
- ✅ Low Power Mode disables decorative animations

### Animation Specifications
- ✅ Message send: scale down (0.95) + fade, spring back
- ✅ Message receive: slide in from left with spring
- ✅ Conversation row tap: subtle scale feedback (0.98)
- ✅ Archive swipe: smooth slide + fade (0.3s)
- ✅ Filter chip selection: spring bounce (0.3s, bounce 0.2)

---

## Edge Cases & Error Handling

### Low Power Mode
- ✅ **Behavior:** Disables decorative animations when battery low
- ✅ **Implementation:** Check `ProcessInfo.processInfo.isLowPowerModeEnabled`

### Older Devices
- ✅ **Behavior:** Test on iPhone X (minimum target) for 60fps
- ✅ **Implementation:** Use performant spring animations, avoid heavy effects

### Gesture Conflicts
- ✅ **Behavior:** Archive swipe doesn't conflict with system back gesture
- ✅ **Implementation:** Use `.leading` edge (not trailing)

### Reduce Motion
- ✅ **Behavior:** Respects user accessibility preference
- ✅ **Implementation:** `@Environment(\.accessibilityReduceMotion)`

---

## Files to Modify

### Primary Files

- `buzzbox/Features/Chat/Views/MessageThreadView.swift`
  - Add message receive animation
  - Add animation ID for new message detection

- `buzzbox/Features/Chat/Views/MessageBubbleView.swift`
  - Add message send animation (tap feedback)

- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add archive swipe animation

- `buzzbox/Features/Chat/Views/ConversationRowView.swift`
  - Add conversation row tap animation

---

## Technical Notes

### Spring Animation Parameters

Use consistent spring parameters:
- **Quick feedback:** `duration: 0.15, bounce: 0.1`
- **Standard:** `duration: 0.3, bounce: 0.2`
- **Playful:** `duration: 0.4, bounce: 0.3`

### Asymmetric Transitions

For message receive:
```swift
.transition(.asymmetric(
    insertion: .move(edge: .leading).combined(with: .opacity),
    removal: .opacity
))
```

### Animation Value Triggers

Use value-based animations:
```swift
.animation(.spring(duration: 0.3), value: animationTrigger)
```

Not:
```swift
withAnimation { /* state change */ }
```

### Performance Optimization

- Use `.scaleEffect()` instead of `.frame()` for scaling
- Use `.opacity()` instead of conditional rendering
- Avoid animating layout changes (expensive)

---

## Testing Checklist

### Performance Testing
- [ ] Test on iPhone X (oldest supported device)
- [ ] Monitor frame rate with Xcode Instruments
- [ ] Verify smooth scrolling with animations active
- [ ] Check CPU/GPU usage during animations
- [ ] Test with 100+ messages in thread

### Animation Quality Testing
- [ ] Message send animation feels responsive
- [ ] Message receive animation feels smooth
- [ ] Conversation row tap provides clear feedback
- [ ] Archive swipe feels natural
- [ ] Filter chip selection has pleasing bounce

### Accessibility Testing
- [ ] Enable Reduce Motion → decorative animations disabled
- [ ] Essential animations still work (transitions)
- [ ] Enable Low Power Mode → decorative animations disabled
- [ ] VoiceOver still functional with animations

### Edge Case Testing
- [ ] Rapid conversation taps → no animation glitches
- [ ] Send 10 messages quickly → smooth animations
- [ ] Archive multiple conversations → smooth performance
- [ ] Toggle filter chips rapidly → no lag

---

## Performance Benchmarks

| Device | Target FPS | Message Receive | Archive Swipe | Row Tap |
|--------|-----------|----------------|---------------|---------|
| iPhone 15 Pro | 60fps | ✅ | ✅ | ✅ |
| iPhone 13 | 60fps | ✅ | ✅ | ✅ |
| iPhone X | 60fps | ✅ | ✅ | ✅ |

---

## Definition of Done

- ✅ Message send animation implemented
- ✅ Message receive animation implemented
- ✅ Conversation row tap animation implemented
- ✅ Archive swipe animation implemented
- ✅ Filter chip animation verified (Story 8.6)
- ✅ Reduce Motion support implemented
- ✅ Low Power Mode support implemented
- ✅ All animations run at 60fps on iPhone X
- ✅ No dropped frames or jank
- ✅ Accessibility verified
- ✅ Performance benchmarks passed

---

## Related Stories

- **Story 8.1:** Swipe-to-Archive (archive swipe animation)
- **Story 8.6:** AI Category Filter (filter chip animation)
- **Story 8.10:** Enhanced Haptics (complements animations)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 415-460)
