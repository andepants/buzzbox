# Story 8.9: Loading Skeleton States

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 2 - Interactive Polish
**Priority:** P1 (High - Perceived performance)
**Effort:** 2.5 hours
**Status:** Ready for Development

---

## Goal

Show shimmer loading placeholders instead of blank screens while content loads, making the app feel faster and more responsive.

---

## User Story

**As** a user waiting for content to load,
**I want** to see skeleton placeholders with shimmer animation,
**So that** the app feels faster and I know content is loading.

---

## Dependencies

- ✅ No external dependencies
- ⚠️ Integrates with all views that load data (InboxView, MessageThreadView, etc.)

---

## Implementation

### SkeletonView Component

Create `buzzbox/Core/Views/Components/SkeletonView.swift`:

```swift
import SwiftUI

struct SkeletonView: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .onAppear {
                if !reduceMotion {
                    startAnimation()
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(.systemGray5).opacity(0.3), location: 0),
                .init(color: Color(.systemGray4).opacity(0.5), location: 0.5),
                .init(color: Color(.systemGray5).opacity(0.3), location: 1)
            ]),
            startPoint: .init(x: phase - 1, y: 0.5),
            endPoint: .init(x: phase, y: 0.5)
        )
    }

    private func startAnimation() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            phase = 2
        }
    }
}
```

### Conversation List Skeleton

Create `ConversationListSkeleton.swift`:

```swift
struct ConversationListSkeleton: View {
    let count: Int = 8

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    conversationRowSkeleton
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var conversationRowSkeleton: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            SkeletonView(width: 50, height: 50, cornerRadius: 25)

            VStack(alignment: .leading, spacing: 8) {
                // Name skeleton
                SkeletonView(width: 120, height: 16, cornerRadius: 4)

                // Message preview skeleton
                SkeletonView(width: 200, height: 14, cornerRadius: 4)
            }

            Spacer()

            // Timestamp skeleton
            SkeletonView(width: 40, height: 12, cornerRadius: 4)
        }
    }
}
```

### Message Thread Skeleton

Create `MessageThreadSkeleton.swift`:

```swift
struct MessageThreadSkeleton: View {
    let count: Int = 10

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<count, id: \.self) { index in
                    if index % 3 == 0 {
                        // Sender message (right-aligned)
                        HStack {
                            Spacer()
                            SkeletonView(width: 200, height: 40, cornerRadius: 16)
                        }
                    } else {
                        // Receiver message (left-aligned)
                        HStack {
                            SkeletonView(width: 180, height: 40, cornerRadius: 16)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
    }
}
```

### InboxView Integration

Update `InboxView.swift`:

```swift
struct InboxView: View {
    @State private var isLoading = true
    @State private var showSkeleton = true
    @State private var minimumDisplayTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            if showSkeleton {
                ConversationListSkeleton()
                    .transition(.opacity)
            } else {
                conversationList
                    .transition(.opacity)
            }
        }
        .task {
            await loadConversations()
        }
    }

    func loadConversations() async {
        // Ensure minimum display time (200ms)
        minimumDisplayTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Load data
        isLoading = true
        // ... actual loading logic ...

        // Wait for minimum display time
        await minimumDisplayTask?.value

        // Hide skeleton
        withAnimation(.easeInOut(duration: 0.3)) {
            showSkeleton = false
            isLoading = false
        }
    }
}
```

### MessageThreadView Integration

Update `MessageThreadView.swift`:

```swift
struct MessageThreadView: View {
    @State private var isLoading = true
    @State private var showSkeleton = true

    var body: some View {
        if showSkeleton {
            MessageThreadSkeleton()
                .transition(.opacity)
        } else {
            messageList
                .transition(.opacity)
        }
        .task {
            await loadMessages()
        }
    }

    func loadMessages() async {
        // Minimum display time
        let minimumTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Load messages
        // ... actual loading logic ...

        // Wait for minimum display
        await minimumTask.value

        // Hide skeleton
        withAnimation(.easeInOut(duration: 0.3)) {
            showSkeleton = false
        }
    }
}
```

---

## Acceptance Criteria

### Visual Requirements
- ✅ Skeleton views show during loading
- ✅ Shimmer animation runs smoothly (if not Reduce Motion)
- ✅ Skeleton matches actual content layout
- ✅ Transitions smoothly to real content (0.3s fade)

### Performance Requirements
- ✅ Minimum display time (200ms) prevents flicker
- ✅ Timeout after 10s shows error state
- ✅ Skeleton respects Reduce Motion (no shimmer)

### Layout Requirements
- ✅ Skeleton size matches average content size (no layout shift)
- ✅ Conversation list skeleton shows 8 rows
- ✅ Message thread skeleton shows 10 messages
- ✅ Avatar, text, and timestamp skeletons positioned correctly

---

## Edge Cases & Error Handling

### Instant Load (Flicker Prevention)
- ✅ **Behavior:** Minimum 200ms display time prevents skeleton flash
- ✅ **Implementation:** `Task.sleep(for: .milliseconds(200))`

### Timeout Handling
- ✅ **Behavior:** After 10s, shows error state with retry button
- ✅ **Implementation:** Task timeout with error state

### Skeleton Size Mismatch
- ✅ **Behavior:** Skeleton height matches average content size (no layout shift)
- ✅ **Implementation:** Use typical row heights (conversation: 74pt, message: 40pt)

### Pull-to-Refresh Conflict
- ✅ **Behavior:** Skeleton hidden during pull-to-refresh (doesn't conflict)
- ✅ **Implementation:** Check `isRefreshing` state before showing skeleton

### Reduce Motion Accessibility
- ✅ **Behavior:** Disables shimmer animation, shows static skeleton
- ✅ **Implementation:** `@Environment(\.accessibilityReduceMotion)`

---

## Files to Create

### New Components
- `buzzbox/Core/Views/Components/SkeletonView.swift`
  - Base skeleton view with shimmer
  - Reduce Motion support
  - Configurable size and corner radius

- `buzzbox/Core/Views/Components/ConversationListSkeleton.swift`
  - Skeleton for conversation list
  - 8 placeholder rows

- `buzzbox/Core/Views/Components/MessageThreadSkeleton.swift`
  - Skeleton for message thread
  - 10 placeholder messages (alternating alignment)

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Chat/Views/ConversationListView.swift`
  - Add skeleton state
  - Add minimum display time logic
  - Add fade transition

- `buzzbox/Features/Chat/Views/MessageThreadView.swift`
  - Add skeleton state
  - Add minimum display time logic
  - Add fade transition

- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add skeleton state
  - Add minimum display time logic
  - Add fade transition

---

## Technical Notes

### Shimmer Animation

Use linear gradient with animated offset:
```swift
LinearGradient(
    gradient: Gradient(stops: [...]),
    startPoint: .init(x: phase - 1, y: 0.5),
    endPoint: .init(x: phase, y: 0.5)
)
```

Animate phase from 0 to 2:
```swift
withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
    phase = 2
}
```

### Minimum Display Time

Prevent flicker with minimum display:
```swift
let minimumTask = Task {
    try? await Task.sleep(for: .milliseconds(200))
}
// ... load data ...
await minimumTask.value // Wait before hiding skeleton
```

### Transition Smoothness

Use opacity transition:
```swift
.transition(.opacity)
```

With animation:
```swift
withAnimation(.easeInOut(duration: 0.3)) {
    showSkeleton = false
}
```

---

## Testing Checklist

### Visual Testing
- [ ] Skeleton appears while loading
- [ ] Shimmer animation runs smoothly
- [ ] Skeleton layout matches actual content
- [ ] Smooth fade transition to real content
- [ ] No layout shift when content loads

### Performance Testing
- [ ] Instant load (< 200ms) → skeleton shows for 200ms minimum
- [ ] Slow load (> 1s) → skeleton visible until content loads
- [ ] Timeout (> 10s) → error state appears
- [ ] Reduce Motion enabled → static skeleton (no shimmer)

### Edge Case Testing
- [ ] Pull-to-refresh while skeleton showing → no conflict
- [ ] Navigation during loading → skeleton cleans up properly
- [ ] Multiple rapid navigation → no skeleton glitches

### Accessibility Testing
- [ ] Reduce Motion enabled → no shimmer animation
- [ ] VoiceOver announces loading state
- [ ] Skeleton content not focusable by VoiceOver

---

## Definition of Done

- ✅ SkeletonView component created
- ✅ ConversationListSkeleton created
- ✅ MessageThreadSkeleton created
- ✅ Skeleton integrated into InboxView
- ✅ Skeleton integrated into MessageThreadView
- ✅ Shimmer animation working (if not Reduce Motion)
- ✅ Minimum display time (200ms) implemented
- ✅ Timeout error state (10s) implemented
- ✅ Smooth fade transition to content
- ✅ No layout shift when loading
- ✅ Reduce Motion support verified
- ✅ VoiceOver accessibility verified

---

## Related Stories

- **Story 8.7:** Enhanced Animations (smooth transitions)
- **Story 8.4:** Dark Mode Fixes (skeleton adapts to dark mode)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 636-700)
