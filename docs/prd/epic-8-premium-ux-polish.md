# Epic 8: Premium UX Polish & Demo-Ready Features

**Phase:** Day 6-7 (Post-AI Features, Pre-Demo)
**Priority:** P1 (High - Professional Polish for Demo)
**Estimated Time:** 28 hours (3-4 days) - Updated after edge case analysis
**Epic Owner:** Product Owner
**Dependencies:** Epic 6 (AI Features), Epic 5 (Single-Creator Platform)
**Risk Level:** Medium - Complex streaming and offline edge cases

---

## 📋 Strategic Context

### Why This Epic Exists

**Current State:** After Epic 6, BuzzBox has all core AI features working:
- ✅ AI-powered creator inbox with categorization, sentiment, scoring
- ✅ Smart reply drafts via floating FAB
- ✅ FAQ auto-responder
- ✅ Conversation-level AI analysis

**Problem:** The app is functional but lacks the premium polish expected of a production app:
- ❌ No swipe gestures for inbox management (Superhuman-standard)
- ❌ Hardcoded light mode colors break in dark mode
- ❌ Generic system launch screen
- ❌ No way to access archived conversations
- ❌ No filtering UI for AI-generated metadata
- ❌ Minimal animations (feels static)
- ❌ No streaming for AI responses (feels slow)
- ❌ Loading states show blank screens

**Solution:** Implement 10 polish features to transform BuzzBox from "functional" to "production-ready demo app."

### Competitive Benchmark: Superhuman

This epic brings BuzzBox to Superhuman-level polish:
- ✅ Swipe-to-archive gesture (Superhuman signature feature)
- ✅ Smart keyboard shortcuts
- ✅ Smooth 60fps animations
- ✅ Instant visual feedback
- ✅ Premium attention to detail

**Demo Impact:** These features make BuzzBox feel like a real product, not a prototype.

---

## 🎯 What This Epic Delivers

### User Experience

**For Andrew (The Creator):**
- ✅ **Swipe-to-Archive:** Left swipe on conversation → archive (Superhuman-style)
- ✅ **Archive Access:** Tap archive button → view all archived convos (dimmed)
- ✅ **AI Category Filter:** Filter inbox by AI category (Fan/Business/Spam/Urgent)
- ✅ **Streaming AI:** See smart replies generate in real-time (no waiting!)
- ✅ **Dark Mode:** App adapts perfectly to system dark mode
- ✅ **Dark Mode Toggle:** Control appearance preference in Profile settings
- ✅ **Haptic Feedback:** Tactile confirmation for every action
- ✅ **Smooth Animations:** 60fps animations throughout app

**For Fans:**
- ✅ **Professional Feel:** App feels polished and production-ready
- ✅ **Dark Mode Support:** Comfortable reading at night
- ✅ **Smooth Interactions:** Animations make app feel alive

**What's New:**
- 🆕 Swipe gestures for archive/unarchive
- 🆕 Archive view with dimmed conversations
- 🆕 Custom launch screen with app icon
- 🆕 AI category filter chips (horizontal scroll)
- 🆕 Streaming OpenAI responses
- 🆕 Skeleton loading states
- 🆕 Dark mode fixes for all cards
- 🆕 Dark mode toggle in Profile → Appearance
- 🆕 Enhanced haptic feedback
- 🆕 Message send/receive animations

---

## 🏗️ Architecture Overview

### SwiftUI Native Polish

**Approach:** Pure SwiftUI modifiers and native APIs (no third-party frameworks)

```swift
// Swipe Actions (Built-in)
.swipeActions(edge: .leading) {
    Button("Archive") { archiveConversation() }
        .tint(.gray)
}

// Animations (Spring Physics)
.animation(.spring(duration: 0.3, bounce: 0.2), value: state)

// Haptics (UIKit Bridge)
HapticFeedback.impact(.light)

// Dark Mode (Environment)
@Environment(\.colorScheme) var colorScheme
```

**Why Native SwiftUI:**
- ✅ Zero dependencies (stable, no breaking changes)
- ✅ Best performance (60fps guaranteed)
- ✅ iOS-native feel (matches system conventions)
- ✅ Accessibility built-in (VoiceOver, Reduce Motion)

---

## 📊 Story Breakdown

### Phase 1: Foundation Polish (Quick Wins) - 6 hours

#### Story 8.1: Swipe-to-Archive (Superhuman-style)
**Goal:** Left swipe on conversation → archive
**Effort:** 2.5 hours (updated with edge cases)

**Implementation:**
- Add `.swipeActions(edge: .leading)` to ConversationRowView in InboxView
- Superhuman-style: full swipe required (destructive style)
- Update `ConversationEntity.isArchived = true`
- Sync to Firebase via ConversationService
- Haptic feedback on archive (medium impact)
- Queue archive operation if offline (sync when online)
- Disable swipe while conversation is actively syncing
- Show toast with undo button (3-second timeout)
- Auto-unarchive conversation if new message arrives

**Acceptance Criteria:**
- ✅ Full left swipe archives conversation
- ✅ Conversation disappears from inbox immediately
- ✅ Haptic feedback triggers on archive
- ✅ Archive syncs to Firebase (persists across devices)
- ✅ VoiceOver announces "Archived"

**Edge Case Handling:**
- ✅ **Offline Archive:** Archives locally when offline, syncs when online
- ✅ **Visual Indicator:** Shows "Pending sync" badge if offline
- ✅ **Sync State:** Cannot swipe while `syncStatus == .syncing` (disabled gesture)
- ✅ **New Message:** Auto-unarchives conversation when fan sends new message
- ✅ **Undo:** Toast appears with "Undo" button (3-second timeout)
- ✅ **Rapid Swipe:** Debounces multiple rapid swipes (max 1 per 500ms)
- ✅ **Unread Count:** Preserves unread count on archive

**Files to Modify:**
- `buzzbox/Features/Inbox/Views/InboxView.swift`
- `buzzbox/Core/Services/ConversationService.swift` (auto-unarchive logic)

---

#### Story 8.2: Archived Conversations View
**Goal:** Access archived conversations via toolbar button
**Effort:** 2.5 hours (updated with edge cases)

**Implementation:**
- Add toolbar button to InboxView ("Archive" icon, SF Symbol: `archivebox`)
- Create `ArchivedInboxView.swift` (sheet presentation)
- Query archived conversations: `filter: #Predicate { $0.isArchived }`
- Show archived convos with dimmed appearance (0.6 opacity)
- Right swipe to unarchive
- Empty state: "No archived conversations"
- Add search functionality within archived conversations
- Lazy loading for >100 archived conversations
- Tap conversation → open thread in read-only mode with unarchive button
- Mute notifications for archived conversations

**Acceptance Criteria:**
- ✅ Archive button appears in top right of InboxView
- ✅ Tapping opens sheet with archived conversations
- ✅ Archived convos shown dimmed (0.6 opacity)
- ✅ Right swipe unarchives conversation
- ✅ Empty state shows when no archived convos
- ✅ Count badge shows archive count (if > 0)

**Edge Case Handling:**
- ✅ **Performance:** Lazy loading for >100 archived conversations (pagination)
- ✅ **Search:** `.searchable()` modifier works within archived view
- ✅ **Notifications:** Archived conversations don't trigger push notifications
- ✅ **Navigation:** Tapping archived conversation opens thread with "Unarchive" button in toolbar
- ✅ **Read-Only Mode:** Optional - archive thread is read-only until unarchived
- ✅ **Empty State:** Shows helpful message when filter returns no results

**Files to Create:**
- `buzzbox/Features/Inbox/Views/ArchivedInboxView.swift`

**Files to Modify:**
- `buzzbox/Features/Inbox/Views/InboxView.swift` (add toolbar button)
- `buzzbox/Core/Services/NotificationService.swift` (check `isArchived` before notifying)

---

#### Story 8.3: Custom Launch Screen
**Goal:** Show app icon on launch instead of generic screen
**Effort:** 1 hour

**Implementation:**
- Create `LaunchScreen.storyboard`:
  - Centered app icon image (1024x1024 @1x)
  - Gradient background matching app theme
  - No text/branding (clean)
  - Use Auto Layout constraints (not fixed positions)
- Update `Info.plist` to reference `LaunchScreen.storyboard`
- Disable `INFOPLIST_KEY_UILaunchScreen_Generation` in project settings

**Acceptance Criteria:**
- ✅ App icon appears centered on launch
- ✅ Gradient background matches app theme
- ✅ Launch screen dismissed after app loads
- ✅ Works in light and dark mode

**Edge Case Handling:**
- ✅ **Device Sizes:** Auto Layout handles iPhone SE to Pro Max (use constraints, not fixed frames)
- ✅ **Dynamic Island:** Icon respects safe area insets (no overlap on iPhone 14 Pro+)
- ✅ **Orientation:** Works in portrait (landscape not required for launch)

**Files to Create:**
- `buzzbox/Resources/LaunchScreen.storyboard`

**Files to Modify:**
- `buzzbox.xcodeproj/project.pbxproj` (disable auto-generation)

---

#### Story 8.4: Dark Mode Fixes & Adaptive Colors
**Goal:** All UI elements adapt to dark mode properly
**Effort:** 1.5 hours (updated with comprehensive testing)

**Implementation:**
- Fix `ConversationRowView.swift`:
  - Line 130: `.background(Color.white)` → `.background(.background)`
  - Update gradient borders to use adaptive colors
  - Update shadows: `.shadow(color: Color(.systemGray4).opacity(0.3))` (adaptive)
- Fix `ChannelCardView.swift`:
  - Line 90: `.background(Color.white)` → `.background(.background)`
  - Update shadows for dark mode
- Test all AI badges (category, sentiment) in dark mode
- Ensure text contrast meets WCAG AA standards
- Update status bar style to match color scheme
- Set keyboard appearance to match dark mode
- Test all modals/sheets (ProfileView, GroupInfoView, ArchivedInboxView)
- Add subtle border to images in dark mode (visibility)

**Acceptance Criteria:**
- ✅ ConversationRowView adapts to dark mode
- ✅ ChannelCardView adapts to dark mode
- ✅ AI badges readable in dark mode
- ✅ No hardcoded white/black colors
- ✅ Gradient borders adapt to dark mode

**Edge Case Handling:**
- ✅ **Shadows:** Shadows adapt to dark mode (no black on black, use `.systemGray4`)
- ✅ **Status Bar:** Status bar text color updates correctly with color scheme
- ✅ **Keyboard:** Keyboard appearance matches dark mode (`.keyboardAppearance(.dark)`)
- ✅ **Modals/Sheets:** All sheets adapt to dark mode (ProfileView, GroupInfoView, etc.)
- ✅ **Image Borders:** Photos in messages have subtle border in dark mode
- ✅ **WCAG Contrast:** All text meets WCAG AA contrast ratios (4.5:1 minimum)

**Testing Checklist:**
- ✅ Test every view in dark mode
- ✅ Test transitions between light/dark mode
- ✅ Test all modals, sheets, alerts
- ✅ Test images, shadows, borders
- ✅ Verify contrast ratios with accessibility inspector

**Files to Modify:**
- `buzzbox/Features/Chat/Views/ConversationRowView.swift`
- `buzzbox/Features/Channels/Views/ChannelCardView.swift`
- `buzzbox/Features/Chat/Views/MessageBubbleView.swift` (image borders)
- `buzzbox/App/buzzboxApp.swift` (status bar style)

---

### Phase 2: Interactive Polish (UX Enhancements) - 8 hours

#### Story 8.5: Dark Mode Toggle in Profile
**Goal:** User can control dark mode preference in Profile settings
**Effort:** 2 hours

**Implementation:**
- Create `AppearanceSettings.swift` service (UserDefaults-backed):
  ```swift
  enum AppearanceMode: String, Codable {
      case system, light, dark
  }

  @MainActor
  class AppearanceSettings: ObservableObject {
      @Published var mode: AppearanceMode = .system {
          didSet { savePreference() }
      }

      init() {
          loadPreference()
          observeSystemChanges()
      }

      private func savePreference() {
          // Persist to UserDefaults with error handling
      }

      private func observeSystemChanges() {
          // Listen to UITraitCollection changes
      }
  }
  ```
- Add Appearance section in ProfileView:
  - Toggle: "Dark Mode" (on/off)
  - Subtitle: "Auto-detect from system" (when off)
  - Smooth fade animation on toggle (0.2s)
- Apply `.preferredColorScheme()` modifier on root view
- Persist preference in UserDefaults with error handling

**Acceptance Criteria:**
- ✅ Toggle appears in Profile → Appearance section
- ✅ Toggle defaults to system preference
- ✅ Toggling forces light/dark mode
- ✅ Preference persists across app launches
- ✅ VoiceOver announces mode changes

**Edge Case Handling:**
- ✅ **System Change During Runtime:** App updates if user changes iOS system dark mode while app open (only if mode == .system)
- ✅ **Persistence Failure:** Gracefully fallback to system mode if UserDefaults write fails
- ✅ **Smooth Transition:** Fade animation when toggling (0.2s) to avoid jarring flash
- ✅ **UITraitCollection Listener:** Respects system changes when mode == .system

**Files to Create:**
- `buzzbox/Core/Services/AppearanceSettings.swift`

**Files to Modify:**
- `buzzbox/Features/Settings/Views/ProfileView.swift` (add toggle)
- `buzzbox/App/buzzboxApp.swift` (apply preference)

---

#### Story 8.6: Creator Inbox Smart Filter (AI Category)
**Goal:** Filter conversations by AI-detected category
**Effort:** 3.5 hours (updated with robust validation)

**Implementation:**
- Add horizontal ScrollView at top of InboxView with filter chips
- Categories enum with validation:
  ```swift
  enum AICategory: String, CaseIterable {
      case all = "all"
      case fan = "fan"
      case superFan = "super_fan"
      case business = "business"
      case spam = "spam"
      case urgent = "urgent"

      var displayName: String {
          switch self {
          case .all: return "All"
          case .fan: return "Fan"
          case .superFan: return "Super Fan"
          case .business: return "Business"
          case .spam: return "Spam"
          case .urgent: return "Urgent"
          }
      }
  }
  ```
- Use `ConversationEntity.aiCategory` for filtering with nil handling
- Update `filteredConversations` computed property with AND logic for search:
  ```swift
  var filteredConversations: [ConversationEntity] {
      // Step 1: Apply search filter
      let searchFiltered = searchText.isEmpty
          ? dmConversations
          : dmConversations.filter { /* search logic */ }

      // Step 2: Apply category filter with nil handling
      if selectedCategory == .all {
          return searchFiltered
      } else {
          return searchFiltered.filter {
              guard let category = $0.aiCategory else { return false }
              return category == selectedCategory.rawValue
          }
      }
  }
  ```
- Animate filter selection with spring animation
- Show count badge on each filter chip
- Handle empty filter states
- Real-time category updates with smooth animations

**Acceptance Criteria:**
- ✅ Filter chips appear horizontally scrollable at top of inbox
- ✅ Tapping filter animates selection (spring bounce)
- ✅ Conversations filter by selected category
- ✅ Count badges show number of conversations per category
- ✅ "All" shows total count
- ✅ Filter persists during search

**Edge Case Handling:**
- ✅ **Null Categories:** `aiCategory == nil` conversations only appear in "All" filter
- ✅ **Invalid Categories:** Validate against enum, ignore invalid values from AI
- ✅ **Filter + Search:** AND logic (search within filtered results, not OR)
- ✅ **Empty Filter State:** Shows "No [category] conversations" when filter has no results
- ✅ **Pinned Conversations:** Respect filter (don't always show pinned)
- ✅ **Real-time Updates:** New message changes category → smooth animation in/out of filter
- ✅ **Scroll Position:** Maintain scroll position when filter updates

**Files to Create:**
- `buzzbox/Core/Views/Components/FilterChipView.swift`
- `buzzbox/Core/Models/AICategory.swift` (enum)

**Files to Modify:**
- `buzzbox/Features/Inbox/Views/InboxView.swift`

---

#### Story 8.7: Enhanced UI Animations
**Goal:** Smooth 60fps animations throughout app
**Effort:** 2 hours

**Implementation:**
- **Message send:** Scale down (0.95) + fade on tap, spring back
- **Message receive:** Slide in from left with spring
- **Conversation row tap:** Subtle scale feedback (0.98)
- **Archive swipe:** Smooth slide + fade (0.3s)
- **Filter chip selection:** Spring bounce (duration: 0.3s, bounce: 0.2)
- **FAB expand/collapse:** Existing spring (already implemented)

**Respect Reduce Motion & Low Power Mode:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var shouldAnimate: Bool {
    !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
}

.animation(shouldAnimate ? .spring(duration: 0.3) : .none, value: state)
```

**Acceptance Criteria:**
- ✅ All animations run at 60fps
- ✅ Animations feel natural and responsive
- ✅ Reduce Motion disables decorative animations
- ✅ Essential animations (like transitions) remain
- ✅ No jank or dropped frames

**Edge Case Handling:**
- ✅ **Low Power Mode:** Disables decorative animations when battery low
- ✅ **Older Devices:** Test on iPhone X (minimum target) for 60fps
- ✅ **Gesture Conflicts:** Archive swipe doesn't conflict with system back gesture
- ✅ **Reduce Motion:** Respects user accessibility preference

**Performance Testing:**
- ✅ Test on iPhone X (oldest supported device)
- ✅ Monitor frame rate with Xcode Instruments
- ✅ Verify smooth scrolling with animations active

**Files to Modify:**
- `buzzbox/Features/Chat/Views/MessageThreadView.swift` (message animations)
- `buzzbox/Features/Chat/Views/MessageBubbleView.swift` (send animation)
- `buzzbox/Features/Inbox/Views/InboxView.swift` (row tap, archive)

---

#### Story 8.10: Enhanced Haptic Feedback
**Goal:** Tactile feedback for key interactions
**Effort:** 1 hour

**Implementation:**
- Archive/unarchive: medium impact
- Filter selection: light impact
- Message sent: light impact (already exists)
- FAB expand/collapse: light impact (already exists)
- Smart reply selected: selection feedback
- Device support check for older devices

**Haptic Patterns:**
```swift
enum HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard UIDevice.current.supportsHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func selection() {
        guard UIDevice.current.supportsHaptics else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

extension UIDevice {
    var supportsHaptics: Bool {
        // iPhone SE 1st gen doesn't have Taptic Engine
        return true // System handles gracefully
    }
}
```

**Acceptance Criteria:**
- ✅ Archive triggers medium impact
- ✅ Unarchive triggers medium impact
- ✅ Filter selection triggers light impact
- ✅ Smart reply tap triggers selection feedback
- ✅ Haptics feel natural, not excessive

**Edge Case Handling:**
- ✅ **Device Support:** Gracefully handles devices without Taptic Engine (iPhone SE 1st gen)
- ✅ **User Settings:** Automatically respects iOS system haptics setting (no additional check needed)

**Files to Create:**
- `buzzbox/Core/Utilities/HapticFeedback.swift` (if doesn't exist)

**Files to Modify:**
- `buzzbox/Features/Inbox/Views/InboxView.swift` (archive haptic)
- `buzzbox/Core/Views/Components/FilterChipView.swift` (filter haptic)
- `buzzbox/Core/Views/Components/FloatingFABView.swift` (smart reply haptic)

---

### Phase 3: Advanced Polish (Premium Features) - 8 hours

#### Story 8.8a: Streaming OpenAI Responses (iOS Client)
**Goal:** iOS client supports streaming AI responses in real-time
**Effort:** 2 hours
**Risk:** HIGH - Complex async state management

**Implementation:**
- Modify `AIService.swift` to support OpenAI streaming:
  ```swift
  func generateSingleSmartReplyStreaming(
      conversationId: String,
      messageText: String,
      replyType: String,
      onChunk: @escaping (String) -> Void
  ) async throws -> String {
      // Use OpenAI streaming API (SSE)
      // Yield chunks via onChunk callback
      // Handle UTF-8 validation for partial chunks
      // 30-second timeout with fallback
  }
  ```
- Update `FloatingFABView.swift`:
  - Add streaming state: `@State private var streamingText = ""`
  - Display partial response with typing indicator
  - Disable other FAB buttons while streaming (prevent concurrent streams)
  - Cancel stream on view dismissal
  - Gracefully fallback to non-streaming if error
- Integrate with existing cache system (Story 6.10)

**Acceptance Criteria:**
- ✅ Smart replies stream character-by-character
- ✅ Typing indicator shows while streaming
- ✅ User can cancel mid-stream
- ✅ Graceful fallback to non-streaming if error
- ✅ Streaming feels fast (<100ms per chunk)

**Edge Case Handling:**
- ✅ **Connection Drop:** Falls back to non-streaming API on network error
- ✅ **App Backgrounding:** Cancels stream when app goes to background
- ✅ **Concurrent Requests:** Disables FAB buttons while streaming (only 1 stream at a time)
- ✅ **Timeout:** 30-second timeout falls back to non-streaming
- ✅ **UTF-8 Validation:** Buffers chunks until valid UTF-8 (no garbled text)
- ✅ **Cache Integration:** Caches final result after streaming completes
- ✅ **User Cancellation:** Stream task cancelled when FAB dismissed

**Files to Modify:**
- `buzzbox/Core/Services/AIService.swift`
- `buzzbox/Core/Views/Components/FloatingFABView.swift`

---

#### Story 8.8b: Streaming OpenAI Responses (Cloud Functions)
**Goal:** Cloud Functions support Server-Sent Events (SSE) for streaming
**Effort:** 1 hour
**Risk:** MEDIUM - SSE implementation complexity

**Implementation:**
- Update `functions/src/index.ts`:
  - Add new Cloud Function: `generateSmartReplyStreaming`
  - Support Server-Sent Events (SSE) protocol
  - Stream OpenAI chunks back to iOS client
  - Proper error handling and timeouts

**SSE Implementation:**
```typescript
export const generateSmartReplyStreaming = functions
  .https
  .onRequest(async (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    try {
      const stream = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [...],
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        res.write(`data: ${JSON.stringify({ content })}\n\n`);
      }

      res.write('data: [DONE]\n\n');
      res.end();
    } catch (error) {
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
      res.end();
    }
  });
```

**Acceptance Criteria:**
- ✅ Cloud Function streams OpenAI responses via SSE
- ✅ iOS client receives chunks in real-time
- ✅ Error handling for OpenAI API failures
- ✅ Timeout protection (max 30 seconds)

**Edge Case Handling:**
- ✅ **OpenAI Stream Hang:** 30-second timeout terminates function
- ✅ **Client Disconnect:** Detects closed connection, stops streaming
- ✅ **OpenAI API Error:** Returns error event via SSE
- ✅ **Cost Monitoring:** Logs token usage for cost tracking

**Testing:**
- ✅ Test on Firebase emulator before deploying
- ✅ Test in production with real OpenAI API key

**Files to Modify:**
- `functions/src/index.ts` (add new function)
- `functions/package.json` (ensure OpenAI SDK supports streaming)

---

#### Story 8.9: Loading Skeleton States
**Goal:** Show shimmer loading placeholders instead of blank screens
**Effort:** 2.5 hours (updated with edge case handling)

**Implementation:**
- Create `SkeletonView.swift` component:
  ```swift
  struct SkeletonView: View {
      @State private var phase: CGFloat = 0
      @Environment(\.accessibilityReduceMotion) var reduceMotion

      let minimumDisplayTime: TimeInterval = 0.2 // Prevent flicker

      var body: some View {
          RoundedRectangle(cornerRadius: 8)
              .fill(shimmerGradient)
              .onAppear {
                  if !reduceMotion {
                      startAnimation()
                  }
              }
      }

      var shimmerGradient: LinearGradient {
          LinearGradient(
              colors: [
                  Color.gray.opacity(0.2),
                  Color.gray.opacity(0.4),
                  Color.gray.opacity(0.2)
              ],
              startPoint: .leading,
              endPoint: .trailing
          )
      }
  }
  ```
- Add to:
  - `ConversationListView` (loading conversations)
  - `MessageThreadView` (loading messages)
  - `InboxView` (initial load)
- Add minimum display time (200ms) to prevent flicker
- Timeout after 10s shows error state

**Acceptance Criteria:**
- ✅ Skeleton views show during loading
- ✅ Shimmer animation runs smoothly
- ✅ Skeleton matches actual content layout
- ✅ Transitions smoothly to real content
- ✅ Respects Reduce Motion

**Edge Case Handling:**
- ✅ **Instant Load (Flicker):** Minimum 200ms display time prevents skeleton flash
- ✅ **Timeout:** After 10s, shows error state with retry button
- ✅ **Skeleton Size Mismatch:** Skeleton height matches average content size (no layout shift)
- ✅ **Pull-to-Refresh:** Skeleton hidden during pull-to-refresh (doesn't conflict)
- ✅ **Reduce Motion:** Disables shimmer animation, shows static skeleton

**Files to Create:**
- `buzzbox/Core/Views/Components/SkeletonView.swift`

**Files to Modify:**
- `buzzbox/Features/Chat/Views/ConversationListView.swift`
- `buzzbox/Features/Chat/Views/MessageThreadView.swift`
- `buzzbox/Features/Inbox/Views/InboxView.swift`

---

#### Story 8.11: Undo Archive Toast
**Goal:** Allow users to undo accidental archives with toast notification
**Effort:** 30 minutes
**Priority:** HIGH - Critical UX feature

**Implementation:**
- Show toast notification immediately after archiving:
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
      }
  }
  ```
- Toast appears at bottom of screen for 3 seconds
- Tapping "Undo" unarchives conversation and dismisses toast
- Toast auto-dismisses after 3 seconds
- Only one toast visible at a time (replaces previous)

**Acceptance Criteria:**
- ✅ Toast appears immediately after archiving conversation
- ✅ Toast shows "Archived" with "Undo" button
- ✅ Tapping "Undo" unarchives conversation
- ✅ Toast auto-dismisses after 3 seconds
- ✅ VoiceOver announces toast message and undo button

**Edge Case Handling:**
- ✅ **Rapid Archives:** Only latest toast shown (replaces previous)
- ✅ **Undo Haptic:** Light impact when undo tapped
- ✅ **Accessibility:** Toast announced by VoiceOver
- ✅ **Safe Area:** Toast respects bottom safe area (no notch overlap)

**Files to Create:**
- `buzzbox/Core/Views/Components/UndoToast.swift`

**Files to Modify:**
- `buzzbox/Features/Inbox/Views/InboxView.swift` (show toast on archive)

---

#### Story 8.12: Archive Notification Behavior
**Goal:** Mute notifications for archived conversations
**Effort:** 30 minutes
**Priority:** MEDIUM - Expected behavior

**Implementation:**
- Update `NotificationService.swift`:
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
- Check `isArchived` before triggering notifications
- Apply to:
  - In-app notifications
  - Local notifications
  - FCM push notifications (Cloud Functions)

**Acceptance Criteria:**
- ✅ Archived conversations don't trigger in-app notifications
- ✅ Archived conversations don't trigger local notifications
- ✅ Archived conversations don't trigger push notifications
- ✅ Auto-unarchiving conversation re-enables notifications

**Edge Case Handling:**
- ✅ **Auto-Unarchive:** When conversation auto-unarchives (new message), notifications resume
- ✅ **Manual Unarchive:** Immediately re-enables notifications
- ✅ **Muted + Archived:** Respects both flags (no notification)

**Files to Modify:**
- `buzzbox/Core/Services/NotificationService.swift` (add `isArchived` check)
- `functions/src/index.ts` (Cloud Functions - check `isArchived` before sending FCM)

---

## 🧪 Testing & Quality Gates

### Story-Level Acceptance Criteria

**Every story must pass:**
1. ✅ **Functional:** Feature works as specified
2. ✅ **60fps:** No animation jank or dropped frames
3. ✅ **Dark Mode:** Works in both light and dark mode
4. ✅ **Accessibility:** VoiceOver announces all actions
5. ✅ **Reduce Motion:** Respects user preference

### Epic-Level Success Criteria

**Demo-Ready Checklist:**
- ✅ Superhuman-style swipe gestures work flawlessly
- ✅ Archive view accessible and functional
- ✅ Custom launch screen shows app icon
- ✅ All cards adapt to dark mode
- ✅ Dark mode toggle works in Profile
- ✅ AI category filter functional and smooth
- ✅ Animations run at 60fps throughout app
- ✅ Streaming AI responses feel instant
- ✅ Loading states show skeleton views
- ✅ Haptic feedback feels natural

**Quality Bar:**
- ✅ App feels polished and production-ready
- ✅ No visual glitches or bugs
- ✅ Smooth animations throughout
- ✅ Professional attention to detail

### Comprehensive Test Plan

**Network Scenarios:**
- ✅ Archive conversation while online
- ✅ Archive conversation while offline → go online → verify sync
- ✅ Swipe to archive during active sync (should be disabled)
- ✅ Receive message while archived → verify auto-unarchive
- ✅ Streaming AI with poor connection → fallback to non-streaming

**User Flows:**
- ✅ Archive → Undo → Verify restored
- ✅ Archive → Send message → Verify auto-unarchive
- ✅ Filter by category → Archive conversation → Verify removed from filter
- ✅ Search + Filter combination → Verify AND logic
- ✅ Toggle dark mode → Verify all views adapt

**Edge Cases:**
- ✅ Rapid swipe 10 conversations → Verify no crashes
- ✅ Archive 100+ conversations → Test performance
- ✅ Filter with nil categories → Verify no crashes
- ✅ Stream AI → Background app → Foreground → Verify stream cancelled
- ✅ Low power mode → Verify animations disabled

**Device Testing:**
- ✅ iPhone SE (small screen, no Taptic Engine)
- ✅ iPhone 15 Pro (Dynamic Island, always-on display)
- ✅ iPhone 15 Pro Max (large screen)
- ✅ iOS 17.0 (minimum version)

**Accessibility:**
- ✅ VoiceOver navigation through all features
- ✅ Reduce Motion disables decorative animations
- ✅ Dynamic Type support (large text sizes)
- ✅ WCAG AA contrast ratios verified

**Performance:**
- ✅ 60fps animations on iPhone X
- ✅ Smooth scrolling with 100+ conversations
- ✅ Memory usage stable (no leaks)
- ✅ Network efficiency (minimal API calls)

---

## 📋 Implementation Strategy

### Phase 1: Foundation Polish (Day 6 AM) - 7 hours
**Priority:** P0 (Critical for demo)
1. Story 8.1: Swipe-to-Archive (2.5h) - includes undo, offline, edge cases
2. Story 8.11: Undo Archive Toast (0.5h) - complements 8.1
3. Story 8.2: Archived View (2.5h) - includes search, performance
4. Story 8.12: Archive Notification Behavior (0.5h) - complements 8.2
5. Story 8.3: Custom Launch Screen (1h)
6. Story 8.4: Dark Mode Fixes (1.5h) - comprehensive testing

**Milestone:** Archive system complete, dark mode fixed, app feels more professional

---

### Phase 2: Interactive Polish (Day 6 PM + Day 7 AM) - 9 hours
**Priority:** P1 (High - UX enhancements)
7. Story 8.5: Dark Mode Toggle (2h)
8. Story 8.6: AI Category Filter (3.5h) - robust validation
9. Story 8.7: Enhanced Animations (2h)
10. Story 8.10: Enhanced Haptics (1h)
11. Story 8.9: Loading Skeletons (2.5h) - includes edge cases

**Milestone:** App feels interactive, premium, and polished

---

### Phase 3: Advanced Polish (Day 7 PM) - 4 hours (OPTIONAL)
**Priority:** P2 (Nice-to-have, but impressive)
12. Story 8.8a: Streaming OpenAI - iOS (2h)
13. Story 8.8b: Streaming OpenAI - Cloud Functions (1h)
14. Final polish and bug fixes (1h)

**Milestone:** App feels production-ready for demo

**Note:** Phase 3 is optional - app is demo-ready after Phase 2.

---

### Updated Time Breakdown

**Total Estimated Time:** 28 hours (3-4 days)
- Phase 1 (Foundation): 7 hours
- Phase 2 (Interactive): 9 hours
- Phase 3 (Advanced - Optional): 4 hours
- Buffer for edge cases: 3 hours
- Testing & QA: 2 hours
- Documentation: 1 hour

**Realistic Timeline:**
- Day 6: Phases 1 + 2 start (12-14 hours)
- Day 7: Phase 2 completion + Phase 3 (8-10 hours)
- Day 8: Buffer + Testing + Polish (4-6 hours)

---

## 📦 Dependencies & Prerequisites

### Epic Dependencies

**Must Complete Before Epic 8:**
- ✅ **Epic 5:** Single-Creator Platform (provides inbox)
- ✅ **Epic 6:** AI Features (provides category metadata)

**Why:**
- Swipe-to-archive needs inbox structure
- AI category filter needs `ConversationEntity.aiCategory`
- Streaming needs `AIService` infrastructure

### Technical Prerequisites

**iOS:**
- SwiftUI 17+ (for `.swipeActions`, `.searchable`)
- Swift Concurrency (for streaming)
- UserDefaults (for appearance preference)

**Firebase:**
- Cloud Functions (for streaming SSE)
- Realtime Database (for real-time updates)

**No New Dependencies:**
- All features use native SwiftUI/UIKit APIs
- Zero third-party frameworks

---

## 📊 Success Metrics

### Demo Impact

**Before Epic 8:**
- ⚠️ App works but feels like prototype
- ⚠️ Static interactions (no swipes, minimal animations)
- ⚠️ Broken dark mode
- ⚠️ Generic launch screen

**After Epic 8:**
- ✅ App feels like real product (Superhuman-level polish)
- ✅ Smooth interactions (swipes, animations, haptics)
- ✅ Perfect dark mode support
- ✅ Branded launch screen

### User Experience Metrics

**Perceived Performance:**
- Loading feels **faster** (skeleton states)
- AI feels **instant** (streaming responses)
- Interactions feel **responsive** (60fps animations)

**Professionalism Score:**
- Swipe gestures: +20% (matches industry standard)
- Dark mode: +15% (essential for modern apps)
- Animations: +25% (makes app feel alive)
- Overall: **60% more polished**

---

## 🚀 Launch Readiness

### Epic 8 Completion = Demo-Ready

**After Epic 8, BuzzBox is:**
- ✅ Feature-complete (all 5 AI features)
- ✅ Professionally polished (Superhuman-level UX)
- ✅ Production-ready (dark mode, animations, haptics)
- ✅ Demo-worthy (impressive to show investors/users)

**Next Steps After Epic 8:**
1. Record demo video showcasing all features
2. Write deployment documentation
3. Prepare TestFlight build
4. Conduct final QA pass

---

## 📚 References

### Related Documentation

- **Epic 5:** `docs/prd/epic-5-creator-platform-redesign.md` (inbox structure)
- **Epic 6:** `docs/prd/epic-6-ai-powered-creator-inbox.md` (AI metadata)
- **CLAUDE.md:** Project guidelines and tech stack
- **Architecture:** `docs/architecture/system-architecture.md`

### Design Inspiration

- **Superhuman:** Swipe gestures, keyboard shortcuts, speed
- **Linear:** Smooth animations, attention to detail
- **Arc Browser:** Polish, premium feel

### Apple HIG References

- [SwiftUI Animations](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Haptic Feedback](https://developer.apple.com/design/human-interface-guidelines/haptics)
- [Accessibility](https://developer.apple.com/accessibility/)

---

## ✅ Definition of Done

**Epic 8 is complete when:**
1. ✅ All 12 stories pass acceptance criteria (updated from 10)
2. ✅ Demo video showcases all polish features
3. ✅ QA pass confirms 60fps throughout app
4. ✅ Dark mode works perfectly everywhere
5. ✅ App feels production-ready
6. ✅ All edge cases handled gracefully
7. ✅ Comprehensive test plan executed successfully

**Quality Bar:**
> "If I saw this app on the App Store, I would believe it's a real product from a professional team."

---

## 📊 Epic 8 Summary

**Total Stories:** 12 (updated from 10)
**Total Estimated Time:** 28 hours (updated from 21 hours)
**Risk Level:** Medium (streaming complexity, offline edge cases)
**Priority:** P1 (High - Demo polish)

**Story Breakdown:**
- **Foundation (Phase 1):** 6 stories - 7 hours
  - 8.1: Swipe-to-Archive (2.5h)
  - 8.11: Undo Archive Toast (0.5h)
  - 8.2: Archived View (2.5h)
  - 8.12: Archive Notification (0.5h)
  - 8.3: Launch Screen (1h)
  - 8.4: Dark Mode Fixes (1.5h)

- **Interactive (Phase 2):** 5 stories - 9 hours
  - 8.5: Dark Mode Toggle (2h)
  - 8.6: AI Category Filter (3.5h)
  - 8.7: Enhanced Animations (2h)
  - 8.10: Enhanced Haptics (1h)
  - 8.9: Loading Skeletons (2.5h)

- **Advanced (Phase 3 - Optional):** 2 stories - 3 hours
  - 8.8a: Streaming iOS (2h)
  - 8.8b: Streaming Cloud Functions (1h)

- **Buffer:** 3 hours
- **Testing & QA:** 2 hours
- **Documentation:** 1 hour

**Edge Cases Addressed:** 60+ edge cases documented and handled

**Dependencies:** Epic 5 (Inbox), Epic 6 (AI Features)

**Demo Impact:** Transforms app from functional to production-ready

---

**Epic Owner Sign-off:** _Sarah (Product Owner)_
**Created:** 2025-10-25
**Updated:** 2025-10-25 (Edge case analysis complete)
**Status:** ✅ APPROVED FOR IMPLEMENTATION
**Reviewed by:** @po (Product Owner - Sarah)

---

**Changelog:**
- **v1.0** (2025-10-25): Initial draft - 10 stories, 21 hours
- **v2.0** (2025-10-25): Edge case analysis complete
  - Split Story 8.8 into 8.8a (iOS) + 8.8b (Cloud Functions)
  - Added Story 8.11 (Undo Archive Toast)
  - Added Story 8.12 (Archive Notification Behavior)
  - Added 60+ edge cases to all stories
  - Updated time estimates: 28 hours (33% increase)
  - Added comprehensive test plan
  - Status: APPROVED
