# Story 6.10: Floating FAB Smart Reply Buttons

```yaml
id: "6.10"
title: "Floating FAB Smart Reply Buttons"
epic: "6"
status: "Draft"
priority: "P1"
points: 5
owner: "Dev"
sprint: "TBD"
created: "2025-10-24"
updated: "2025-10-24"
```

**Epic:** Epic 6 - AI-Powered Creator Inbox
**Priority:** P1 (Enhancement to existing Smart Reply feature)
**Estimated Time:** 3 hours
**Points:** 5

---

## 📋 Dependencies

**CRITICAL: Verify these dependencies before starting implementation:**

### Required (Must be complete):
- ✅ **Story 6.4:** Smart Replies Cloud Function (`generateSmartReplies`)
  - Verify: `functions/src/smart-replies.ts` exists
  - Verify: Function deployed to production
  - Verify: Can generate 3 reply types (short/medium/detailed)

- ✅ **Story 6.7:** AI UI Components (SmartReplyPickerView)
  - Verify: `buzzbox/Core/Views/Components/SmartReplyPickerView.swift` exists
  - Verify: Sparkles button in `MessageThreadView.swift` (lines 196-215)
  - Note: These will be REPLACED by FAB workflow

### Dependency Verification Checklist:
- [ ] Run `grep -r "generateSmartReplies" functions/src/` → Should find function
- [ ] Run `grep -r "SmartReplyPickerView" buzzbox/Core/Views/` → Should find component
- [ ] Test existing sparkles button in app → Should open sheet with 3 options
- [ ] If any verification fails, STOP and complete prerequisite story first

---

## 📋 User Story

**As Andrew (the creator), I want three floating action buttons (FAB) for quick AI reply generation so I can rapidly respond to fans with short, funny, or professional replies without opening a modal sheet.**

---

## 🎯 What This Story Delivers

### Current UX (Story 6.7)
- Single sparkles button (left of message input)
- Opens modal sheet with 3 reply options
- Must tap option to populate input
- 2 taps + review required

### New UX (Story 6.10)
- **One main FAB** in center-bottom (above input)
- **Expands to 3 FABs** when tapped (Short, Funny, Professional)
- **Direct draft generation** - tap any FAB to generate that reply type
- **Populates input immediately** for creator review before sending
- **Beautiful iOS-style animations** matching Camera app expand behavior
- **Loading states** prevent input during generation
- **Contextual - uses last 20 messages** for relevant replies
- **Fully accessible** with VoiceOver support and reduced motion

### What's New
- 🆕 Expandable FAB UI pattern (iOS native feel)
- 🆕 Three distinct reply personalities (Short, Funny, Professional)
- 🆕 Instant draft-to-input workflow
- 🆕 Input locking during generation (prevents typing conflicts)
- 🆕 Smooth expand/collapse animations
- 🆕 Full accessibility support (VoiceOver, reduced motion)
- 🆕 Smart error handling with automatic FAB collapse

---

## 🎨 Visual Design

### Apple Design Language
- **Style:** iOS 17+ floating buttons (like Camera app's mode selector)
- **Animation:** Smooth spring animation (0.4s duration, dampingFraction: 0.7)
- **Position:** Horizontal row, center-aligned, just above message input
- **Elevation:** Subtle shadow for depth (iOS-appropriate)
- **Accessibility:** Respects reduced motion preference

### Button Specifications

#### Main FAB (Collapsed State)
- **Icon:** `sparkles` (SF Symbol)
- **Color:** Blue gradient (`Color.blue`)
- **Size:** 56pt diameter
- **Shape:** Circle with subtle shadow
- **Position:** Center-bottom, 12pt above input field
- **Accessibility Label:** "AI Smart Replies"
- **Accessibility Hint:** "Double-tap to expand reply options"

#### Expanded FABs (3 buttons)
- **Layout:** Horizontal row, equal spacing (16pt between)
- **Size:** 48pt diameter each
- **Animation:** Slide from center with spring bounce (or fade if reduced motion)
- **Spacing from center:** -72pt (left), 0pt (center main), +72pt (right)

#### Button 1: Short Reply
- **Icon:** `text.bubble` (compact speech bubble)
- **Color:** Blue (`Color.blue`)
- **Label:** "Short" (below icon, 10pt font)
- **Purpose:** 1-2 sentence quick acknowledgment
- **Accessibility Label:** "Generate short reply"
- **Accessibility Hint:** "Quick one to two sentence response"

#### Button 2: Funny Reply
- **Icon:** `face.smiling` (smiling face)
- **Color:** Orange (`Color.orange`)
- **Label:** "Funny" (below icon, 10pt font)
- **Purpose:** Humorous/playful tone, light-hearted
- **Accessibility Label:** "Generate funny reply"
- **Accessibility Hint:** "Playful and humorous response"

#### Button 3: Professional Reply
- **Icon:** `briefcase` (professional context)
- **Color:** Purple (`Color.purple`)
- **Label:** "Pro" (below icon, 10pt font)
- **Purpose:** Medium-length professional response
- **Accessibility Label:** "Generate professional reply"
- **Accessibility Hint:** "Detailed professional response"

### Loading State
- **Tapped Button:** Replace icon with `ProgressView()` spinner
- **Other Buttons:** Fade to 50% opacity, disabled
- **Input Field:** Show "Generating reply..." placeholder, disabled background
- **Duration:** Until AI response received (~2-3s)
- **Accessibility:** Announce "Generating AI reply" when loading starts

### Error State (NEW)
- **On Error:** All FABs collapse automatically
- **Input Field:** Re-enable immediately
- **Alert:** Show error message "Failed to generate AI reply. Please try again."
- **Accessibility:** Announce error message to VoiceOver users
- **Retry:** User can re-expand FABs and try again (no auto-retry)

---

## 🏗️ Technical Implementation

### Cloud Function Updates

**Update: `functions/src/smart-replies.ts`**

Add new request parameter for reply type:

```typescript
interface SmartReplyRequest {
  conversationId: string;
  messageText: string;
  replyType?: 'short' | 'funny' | 'professional'; // NEW
}

export const generateSmartReplies = onCall<SmartReplyRequest>({
  region: 'us-central1',
}, async (request) => {
  const { conversationId, messageText, replyType } = request.data;

  // If replyType specified, generate single targeted reply
  if (replyType) {
    const draft = await generateSingleReply(
      conversationId,
      messageText,
      replyType
    );

    return {
      drafts: {
        [replyType]: draft,
        short: replyType === 'short' ? draft : '',
        medium: replyType === 'funny' ? draft : '',
        detailed: replyType === 'professional' ? draft : '',
      }
    };
  }

  // Otherwise, generate all 3 (existing behavior for backward compatibility)
  // ... existing code
});

/**
 * Generate a single targeted reply based on type
 */
async function generateSingleReply(
  conversationId: string,
  messageText: string,
  replyType: 'short' | 'funny' | 'professional'
): Promise<string> {

  // Fetch last 20 messages for context (or all if <20 exist)
  const messagesSnapshot = await admin.database()
    .ref(`/messages/${conversationId}`)
    .orderByChild('timestamp')
    .limitToLast(20)
    .once('value');

  const messages: Message[] = [];
  messagesSnapshot.forEach((child) => {
    messages.push(child.val() as Message);
  });

  // Use all available messages if conversation has <20
  logger.info(`Using ${messages.length} messages for context`);

  // Fetch creator profile
  const profileDoc = await admin.firestore()
    .collection('creator_profiles')
    .doc('andrew')
    .get();

  if (!profileDoc.exists) {
    throw new HttpsError('not-found', 'Creator profile not found');
  }

  const profile = profileDoc.data() as CreatorProfile;

  // Build context
  const conversationContext = messages
    .map((m) => `${m.senderName}: ${m.text}`)
    .join('\n');

  // Type-specific prompts
  const typePrompts = {
    short: `Generate a SHORT reply (1 sentence max). Quick, warm acknowledgment. Be concise.`,
    funny: `Generate a FUNNY reply (2-3 sentences). Use Andrew's playful tone. Make it light-hearted and engaging. Use emojis if appropriate.`,
    professional: `Generate a PROFESSIONAL reply (3-4 sentences). Detailed, helpful, and thorough. Maintain warmth but be comprehensive.`
  };

  const systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join('\n')}

Avoid: ${profile.avoid.join(', ')}

Recent conversation context:
${conversationContext}`;

  const userPrompt = `The fan just sent: "${messageText}"

${typePrompts[replyType]}

Make it sound authentic to Andrew's voice. Use conversation context to make it relevant.

Respond with ONLY the reply text (no JSON, no formatting).`;

  // Call OpenAI GPT-4o-mini
  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    temperature: 0.7,
    max_tokens: replyType === 'short' ? 50 : (replyType === 'funny' ? 100 : 150),
  });

  const draft = completion.choices[0].message.content?.trim() || '';

  return draft;
}
```

### iOS Implementation

**Create: `buzzbox/Core/Views/Components/FloatingFABView.swift`**

```swift
/// FloatingFABView.swift
///
/// Expandable floating action button for smart reply generation.
/// Inspired by iOS Camera app's mode selector.
/// Fully accessible with VoiceOver and reduced motion support.
///
/// Created: 2025-10-24
/// [Source: Story 6.10 - Floating FAB Smart Replies]

import SwiftUI

/// Reply type for FAB buttons
enum SmartReplyType: String, CaseIterable {
    case short
    case funny
    case professional

    var icon: String {
        switch self {
        case .short: return "text.bubble"
        case .funny: return "face.smiling"
        case .professional: return "briefcase"
        }
    }

    var color: Color {
        switch self {
        case .short: return .blue
        case .funny: return .orange
        case .professional: return .purple
        }
    }

    var label: String {
        switch self {
        case .short: return "Short"
        case .funny: return "Funny"
        case .professional: return "Pro"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .short: return "Generate short reply"
        case .funny: return "Generate funny reply"
        case .professional: return "Generate professional reply"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .short: return "Quick one to two sentence response"
        case .funny: return "Playful and humorous response"
        case .professional: return "Detailed professional response"
        }
    }
}

/// Floating FAB view for smart reply generation
struct FloatingFABView: View {

    // MARK: - Properties

    /// Whether FABs are expanded
    @State private var isExpanded = false

    /// Currently loading reply type
    @State private var loadingType: SmartReplyType?

    /// Error state
    @State private var showError = false
    @State private var errorMessage = ""

    /// Callback when reply is generated
    let onReplyGenerated: (String) -> Void

    /// Callback to generate reply
    let generateReply: (SmartReplyType) async throws -> String

    // Accessibility
    @AccessibilityFocusState private var isMainFABFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Short button (appears on left)
            if isExpanded {
                fabButton(for: .short)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .trailing)),
                        removal: .scale.combined(with: .move(edge: .trailing))
                    ))
            }

            // Main FAB (center)
            mainFABButton

            // Funny button (right of center)
            if isExpanded {
                fabButton(for: .funny)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .leading)),
                        removal: .scale.combined(with: .move(edge: .leading))
                    ))
            }

            // Professional button (far right)
            if isExpanded {
                fabButton(for: .professional)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale.combined(with: .move(edge: .leading)),
                        removal: .scale.combined(with: .move(edge: .leading))
                    ))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                // Alert dismisses automatically
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Main FAB Button

    private var mainFABButton: some View {
        Button {
            withAnimation(reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.3)) {
                isExpanded.toggle()
            }
            #if os(iOS)
            HapticFeedback.impact(.medium)
            #endif

            // Accessibility announcement
            let announcement = isExpanded ? "Reply options expanded" : "Reply options collapsed"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                Image(systemName: isExpanded ? "xmark" : "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .disabled(loadingType != nil)
        .accessibilityLabel("AI Smart Replies")
        .accessibilityHint("Double-tap to expand reply options")
        .accessibilityFocused($isMainFABFocused)
    }

    // MARK: - Individual FAB Buttons

    @ViewBuilder
    private func fabButton(for type: SmartReplyType) -> some View {
        Button {
            Task {
                await handleReplyGeneration(type: type)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(type.color.gradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                    if loadingType == type {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("Generating reply")
                    } else {
                        Image(systemName: type.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                Text(type.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(type.color)
            }
        }
        .disabled(loadingType != nil)
        .opacity(loadingType != nil && loadingType != type ? 0.5 : 1.0)
        .accessibilityLabel(type.accessibilityLabel)
        .accessibilityHint(type.accessibilityHint)
        .accessibilityAddTraits(loadingType == type ? .updatesFrequently : [])
    }

    // MARK: - Private Methods

    /// Handle reply generation for a specific type
    private func handleReplyGeneration(type: SmartReplyType) async {
        loadingType = type
        defer { loadingType = nil }

        #if os(iOS)
        HapticFeedback.impact(.light)
        #endif

        // Accessibility announcement
        UIAccessibility.post(notification: .announcement, argument: "Generating AI reply")

        do {
            let reply = try await generateReply(type)

            // Collapse FABs
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.2)) {
                isExpanded = false
            }

            // Populate input
            onReplyGenerated(reply)

            #if os(iOS)
            HapticFeedback.notification(.success)
            #endif

            // Accessibility announcement
            UIAccessibility.post(notification: .announcement, argument: "Reply generated")

        } catch {
            print("Failed to generate reply: \(error)")

            // ERROR HANDLING: Collapse FABs on error
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.2)) {
                isExpanded = false
            }

            // Show error alert
            errorMessage = "Failed to generate AI reply. Please try again."
            showError = true

            #if os(iOS)
            HapticFeedback.notification(.error)
            #endif

            // Accessibility announcement
            UIAccessibility.post(notification: .announcement, argument: errorMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        FloatingFABView(
            onReplyGenerated: { reply in
                print("Generated: \(reply)")
            },
            generateReply: { type in
                // Mock delay
                try await Task.sleep(for: .seconds(1.5))

                switch type {
                case .short:
                    return "Thanks! 🙌"
                case .funny:
                    return "Haha that's awesome! You just made my day! 😄"
                case .professional:
                    return "Thank you for reaching out! I really appreciate your message and I'd love to hear more about what you're working on. Let me know how I can help!"
                }
            }
        )

        // Mock input field
        HStack {
            TextField("Message", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .background(Color(.systemGray6))
    }
}
```

**Update: `buzzbox/Core/Services/AIService.swift`**

Add single reply generation method:

```swift
/// Generate a single targeted smart reply
/// - Parameters:
///   - conversationId: ID of the conversation for context
///   - messageText: The message to generate a reply for
///   - replyType: Type of reply (short, funny, professional)
/// - Returns: Single AI-generated reply draft
nonisolated func generateSingleSmartReply(
    conversationId: String,
    messageText: String,
    replyType: String
) async throws -> String {
    do {
        let callable = functions.httpsCallable("generateSmartReplies")
        let result = try await callable.call([
            "conversationId": conversationId,
            "messageText": messageText,
            "replyType": replyType
        ])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        let decoder = JSONDecoder()
        let response = try decoder.decode(SmartReplyResponse.self, from: data)

        // Extract the specific reply type
        switch replyType {
        case "short":
            return response.drafts.short
        case "funny":
            return response.drafts.medium // Map funny to medium
        case "professional":
            return response.drafts.detailed // Map professional to detailed
        default:
            return response.drafts.medium
        }
    } catch {
        throw AIServiceError.smartReplyFailed(error)
    }
}
```

**Update: `buzzbox/Features/Chat/Views/MessageThreadView.swift`**

Replace existing sparkles button with FloatingFABView:

```swift
// REMOVE: Lines 196-215 (existing sparkles button)

// ADD: Above message input (replace HStack at line 195)
VStack(spacing: 0) {
    // FAB buttons (Story 6.10 - only for creator)
    if canPost && isCreator && !messages.isEmpty {
        FloatingFABView(
            onReplyGenerated: { draft in
                messageText = draft
                isInputFocused = true
            },
            generateReply: { type in
                return try await aiService.generateSingleSmartReply(
                    conversationId: conversation.id,
                    messageText: messages.last?.text ?? "",
                    replyType: type.rawValue
                )
            }
        )
    }

    // Message input composer
    MessageComposerView(
        text: $messageText,
        characterLimit: 10_000,
        onSend: {
            await sendMessage()
        }
    )
    .focused($isInputFocused)
    .disabled(isLoadingDrafts) // NEW: Disable during generation
    .onChange(of: messageText) { oldValue, newValue in
        handleTypingChange(newValue)
    }
}

// REMOVE: .sheet(isPresented: $showSmartReplies) { ... }
// (Sheet picker is replaced by FAB workflow)
```

---

## ✅ Acceptance Criteria

### Functional Requirements
- [ ] Main FAB appears centered above message input (only for creator)
- [ ] Tapping main FAB expands to 3 buttons (Short, Funny, Professional)
- [ ] Tapping any reply type button generates that specific reply
- [ ] Generated reply populates message input immediately
- [ ] Creator can edit reply before sending (input remains editable)
- [ ] FABs collapse after reply generation
- [ ] Input field is disabled during generation (prevents typing conflicts)
- [ ] Loading state shows on tapped button (spinner replaces icon)
- [ ] Other buttons fade to 50% opacity during loading
- [ ] Cloud Function uses last 20 messages for context
- [ ] **NEW:** If conversation has <20 messages, use all available messages
- [ ] **NEW:** On error, FABs automatically collapse
- [ ] **NEW:** On error, input field re-enables immediately
- [ ] **NEW:** Error alert shows user-friendly message

### UI/UX Requirements
- [ ] Smooth spring animation on expand/collapse (0.4s duration)
- [ ] Button colors match specification (Blue, Orange, Purple)
- [ ] Icons are clear and match reply types
- [ ] Main FAB shows sparkles icon (collapsed) and X icon (expanded)
- [ ] FABs have subtle shadows for depth
- [ ] Labels appear below each FAB ("Short", "Funny", "Pro")
- [ ] Haptic feedback on tap (medium for main, light for reply types)
- [ ] Success haptic on completion, error haptic on failure
- [ ] Works in both light and dark mode

### Accessibility Requirements (NEW)
- [ ] **VoiceOver Support:**
  - [ ] Main FAB has label "AI Smart Replies" and hint "Double-tap to expand"
  - [ ] Each reply button has descriptive label (e.g., "Generate short reply")
  - [ ] Each reply button has helpful hint explaining reply type
  - [ ] Expansion state announced ("Reply options expanded/collapsed")
  - [ ] Loading state announced ("Generating AI reply")
  - [ ] Success announced ("Reply generated")
  - [ ] Error message announced to VoiceOver users
- [ ] **Reduced Motion Support:**
  - [ ] Animations disabled when reduced motion is enabled
  - [ ] FABs fade in/out instead of sliding when reduced motion active
  - [ ] Main FAB rotation disabled when reduced motion active
- [ ] **Dynamic Type:**
  - [ ] Button labels scale with user's font size preference
  - [ ] Layout adapts to larger text sizes

### Technical Requirements
- [ ] Cloud Function accepts `replyType` parameter
- [ ] Generates targeted single reply (not all 3)
- [ ] Response time <3s for single reply
- [ ] AIService method `generateSingleSmartReply()` implemented
- [ ] FloatingFABView component created
- [ ] Sparkles button removed from MessageThreadView
- [ ] Sheet picker UI removed (replaced by FAB workflow)
- [ ] Error handling with user-friendly messages
- [ ] No memory leaks or retain cycles
- [ ] Proper async/await patterns

### Edge Cases
- [ ] FABs don't appear if no messages exist (empty conversation)
- [ ] FABs only visible to creator (not fans)
- [ ] FABs don't appear in read-only channels
- [ ] Tapping main FAB when expanded collapses them (X button)
- [ ] Network errors show alert and re-enable input
- [ ] Multiple rapid taps don't trigger multiple generations
- [ ] Generated reply respects 10K character limit
- [ ] **NEW:** FAB buttons don't overlap keyboard on smaller screens
- [ ] **NEW:** Error state properly resets after dismissing alert

---

## 🎯 Testing Procedure

### Manual Testing

#### 1. Dependency Verification (FIRST)
- [ ] Verify Story 6.4 complete:
  - [ ] File exists: `functions/src/smart-replies.ts`
  - [ ] Function deployed: Run `firebase functions:list | grep generateSmartReplies`
  - [ ] Test existing function: Use sparkles button in app
- [ ] Verify Story 6.7 complete:
  - [ ] File exists: `buzzbox/Core/Views/Components/SmartReplyPickerView.swift`
  - [ ] File exists: Sparkles button in `MessageThreadView.swift`
- [ ] If any verification fails: STOP and complete prerequisite story

#### 2. FAB Appearance
- [ ] Log in as creator (andrewsheim@gmail.com)
- [ ] Navigate to any DM with messages
- [ ] Verify main FAB appears center-bottom
- [ ] Tap main FAB → 3 buttons expand with animation
- [ ] Tap main FAB again (X icon) → buttons collapse

#### 3. Short Reply Generation
- [ ] Expand FABs
- [ ] Tap Short button (blue)
- [ ] Verify loading spinner appears
- [ ] Verify input shows "Generating reply..." and is disabled
- [ ] Wait for completion (~2s)
- [ ] Verify short 1-2 sentence reply populates input
- [ ] Verify FABs collapse
- [ ] Verify input is editable
- [ ] Edit reply → Send
- [ ] Verify message sends successfully

#### 4. Funny Reply Generation
- [ ] Repeat steps with Funny button (orange)
- [ ] Verify reply has playful/humorous tone
- [ ] Verify emojis may be included
- [ ] Verify 2-3 sentence length

#### 5. Professional Reply Generation
- [ ] Repeat steps with Professional button (purple)
- [ ] Verify reply is detailed and thorough
- [ ] Verify 3-4 sentence length
- [ ] Verify professional but warm tone

#### 6. Context Awareness
- [ ] Create conversation with exactly 5 messages
- [ ] Generate reply → Verify all 5 messages used for context
- [ ] Have conversation with 10+ back-and-forth messages
- [ ] Generate replies using FABs
- [ ] Verify replies reference conversation context (last 20 messages)
- [ ] Verify replies are relevant to last message

#### 7. Error Handling
- [ ] Turn off WiFi
- [ ] Expand FABs
- [ ] Tap any FAB button
- [ ] Verify loading starts
- [ ] Verify error alert appears after timeout
- [ ] Verify FABs automatically collapsed
- [ ] Verify input re-enabled
- [ ] Verify error message clear and user-friendly
- [ ] Turn WiFi back on
- [ ] Retry → Verify success

#### 8. Accessibility Testing (NEW)
- [ ] **VoiceOver:**
  - [ ] Enable VoiceOver (Settings → Accessibility → VoiceOver)
  - [ ] Navigate to FAB → Verify label "AI Smart Replies"
  - [ ] Verify hint "Double-tap to expand"
  - [ ] Double-tap → Verify announcement "Reply options expanded"
  - [ ] Swipe through buttons → Verify each has descriptive label
  - [ ] Generate reply → Verify "Generating AI reply" announced
  - [ ] Verify success announcement "Reply generated"
  - [ ] Test error → Verify error message announced
- [ ] **Reduced Motion:**
  - [ ] Enable Reduced Motion (Settings → Accessibility → Motion)
  - [ ] Tap main FAB → Verify no spring animation (fade only)
  - [ ] Verify FABs still functional
  - [ ] Verify no rotation on X icon
- [ ] **Dynamic Type:**
  - [ ] Change text size (Settings → Display → Text Size)
  - [ ] Verify button labels scale
  - [ ] Verify layout still works at largest size

#### 9. Edge Cases
- [ ] Log in as fan → Verify FABs don't appear
- [ ] Navigate to empty conversation → Verify FABs don't appear
- [ ] Navigate to creator-only channel → Verify FABs appear
- [ ] Generate reply → Tap outside FABs → Verify collapse
- [ ] Test on iPhone SE (small screen) → Verify no keyboard overlap
- [ ] Rapid tap same button 3 times → Verify only 1 generation

#### 10. Device-Specific Testing (NEW)
- [ ] **iPhone SE (small screen):**
  - [ ] FABs don't overlap with keyboard
  - [ ] All 3 FABs visible when expanded
  - [ ] Touch targets sufficient (48pt minimum)
- [ ] **iPhone 16 Pro Max (large screen):**
  - [ ] FAB spacing looks good (not too spread out)
  - [ ] Shadows render correctly
- [ ] **Physical Device:**
  - [ ] Haptic feedback strength appropriate
  - [ ] Performance smooth (no frame drops)
  - [ ] Network errors handled gracefully

### Automated Testing (Future)

```swift
// Unit test for FloatingFABView
func testFABExpansion() async throws {
    let fab = FloatingFABView(
        onReplyGenerated: { _ in },
        generateReply: { type in "Test reply" }
    )

    // Verify initial state
    XCTAssertFalse(fab.isExpanded)

    // Tap main button
    fab.mainFABButton.tap()

    // Verify expanded
    XCTAssertTrue(fab.isExpanded)
}

// Test error handling
func testErrorHandling() async throws {
    let fab = FloatingFABView(
        onReplyGenerated: { _ in },
        generateReply: { type in
            throw AIServiceError.smartReplyFailed(NSError(domain: "test", code: -1))
        }
    )

    // Expand FABs
    fab.isExpanded = true

    // Tap button (will error)
    await fab.fabButton(for: .short).tap()

    // Verify FABs collapsed
    XCTAssertFalse(fab.isExpanded)

    // Verify error shown
    XCTAssertTrue(fab.showError)
}
```

---

## 🚨 Known Issues & Limitations

### Limitations
- **Fan View:** FABs only visible to creator (fans don't see them)
- **Empty Chats:** FABs don't appear in conversations with zero messages
- **Context Length:** Fixed at 20 messages max (or all if <20)
- **Reply Types:** Only 3 types supported (Short, Funny, Professional)
- **No Retry Button:** User must manually re-expand FABs after error

### Future Enhancements
- [ ] Add "Detailed" reply type (5+ sentences)
- [ ] Make context length configurable (10/20/50 messages)
- [ ] Add "Regenerate" button to try different reply
- [ ] Remember last used reply type (default to it)
- [ ] Add animation when reply populates input (typewriter effect?)
- [ ] Support multi-select (generate 2-3 replies at once)
- [ ] Add feature flag for backward compatibility with sheet picker
- [ ] Auto-retry on network errors (with exponential backoff)

---

## 📊 Time Breakdown

| Task | Description | Time |
|------|-------------|------|
| Dependency Verification | Check Story 6.4 and 6.7 complete | 15 min |
| Cloud Function Update | Add `replyType` parameter, single reply generation | 45 min |
| FloatingFABView Component | Build expandable FAB UI with animations | 1 hr |
| Accessibility Implementation | VoiceOver, reduced motion, dynamic type | 30 min |
| AIService Update | Add `generateSingleSmartReply()` method | 15 min |
| MessageThreadView Integration | Replace sparkles button with FABs | 30 min |
| Error Handling | Auto-collapse, alerts, recovery | 15 min |
| Testing & Debugging | Manual testing all scenarios + accessibility | 45 min |
| **TOTAL** | | **4 hours** |

**Updated from original 3 hours to 4 hours** (added accessibility + error handling)

---

## 🎬 Implementation Order

### Pre-Implementation (15 min)
1. **Verify Dependencies**
   - Check Story 6.4 complete (Cloud Function exists)
   - Check Story 6.7 complete (Sparkles button exists)
   - If not complete, STOP and complete prerequisites

### Phase 1: Cloud Function Update (45 min)
2. **Update Cloud Function**
   - Add `replyType` parameter to `generateSmartReplies`
   - Implement `generateSingleReply()` helper
   - Handle <20 message conversations (use all available)
   - Deploy to production: `firebase deploy --only functions`
   - Test with curl/Postman

### Phase 2: iOS Service Layer (15 min)
3. **AIService Update**
   - Add `generateSingleSmartReply()` method
   - Wire up to Cloud Function
   - Test iOS → Cloud Function flow

### Phase 3: UI Component (1.5 hrs)
4. **FloatingFABView Component**
   - Create new SwiftUI component
   - Implement expand/collapse animation
   - Add loading states
   - **NEW:** Implement VoiceOver support
   - **NEW:** Implement reduced motion support
   - **NEW:** Implement error handling with auto-collapse
   - Test in preview

### Phase 4: Integration (30 min)
5. **MessageThreadView Integration**
   - Remove sparkles button code (lines 196-215)
   - Remove sheet picker (lines 277-289)
   - Add FloatingFABView
   - Wire up callbacks

### Phase 5: Testing & Polish (45 min)
6. **Comprehensive Testing**
   - Test all 3 reply types
   - Test error handling (network off)
   - Test edge cases (empty chat, fan view)
   - **NEW:** Test accessibility (VoiceOver, reduced motion)
   - **NEW:** Test on multiple device sizes
   - Verify animations smooth

---

## 📚 References

- **Epic 6:** `docs/prd/epic-6-ai-powered-creator-inbox.md`
- **Story 6.7:** AI UI Components (original sparkles button)
- **Story 6.4:** Smart Replies Cloud Function (existing backend)
- **Apple HIG:** Floating Action Buttons (iOS design patterns)
- **Apple HIG:** Accessibility (VoiceOver, Reduced Motion)
- **SF Symbols:** https://developer.apple.com/sf-symbols/
- **WCAG 2.1:** Web Content Accessibility Guidelines

---

## ✅ Definition of Done

Story 6.10 is complete when:

- [ ] **Dependencies verified** (Story 6.4 and 6.7 complete)
- [ ] All functional acceptance criteria met (14 items)
- [ ] All UI/UX acceptance criteria met (9 items)
- [ ] **All accessibility criteria met (11 items)** ← NEW
- [ ] All technical acceptance criteria met (10 items)
- [ ] All edge cases handled (9 items)
- [ ] Cloud Function deployed to production
- [ ] FloatingFABView component created and tested
- [ ] Sparkles button removed from MessageThreadView
- [ ] Sheet picker removed (replaced by FAB workflow)
- [ ] All 3 reply types generate correctly
- [ ] Animations smooth and iOS-native feel
- [ ] **Reduced motion support verified** ← NEW
- [ ] **VoiceOver fully functional** ← NEW
- [ ] Error handling tested and working
- [ ] **Error state auto-recovery working** ← NEW
- [ ] Creator can generate and edit replies before sending
- [ ] Code reviewed and documented
- [ ] No console errors or warnings
- [ ] Tested on simulator (multiple device sizes)
- [ ] **Tested on physical device with accessibility features** ← NEW

---

**Story Status:** ✅ Ready to Implement
**Blockers:** None (after dependency verification)
**Risk Level:** Low (builds on existing infrastructure)
**UX Impact:** HIGH - Significantly faster workflow for creator replies
**Accessibility Impact:** HIGH - Fully accessible to all users

**Recommendation: Implement after Epic 6 core stories (6.0-6.9) are complete. This is an enhancement that improves UX but doesn't affect scoring. Verify dependencies first before starting implementation.**

---

## 🔄 Story Review History

### Review 1: 2025-10-24 - Bob (Scrum Master)
**Score:** 85/100 → **95/100** (after updates)

**Issues Fixed:**
- ✅ Added story metadata (ID, owner, sprint, points)
- ✅ Added accessibility acceptance criteria (VoiceOver, reduced motion)
- ✅ Clarified error handling behavior (auto-collapse FABs, re-enable input)
- ✅ Added AC for <20 message conversations
- ✅ Added dependency verification checklist
- ✅ Updated time estimate (3hrs → 4hrs for accessibility)
- ✅ Added device-specific testing section

**Status:** APPROVED - Ready for Dev Agent
