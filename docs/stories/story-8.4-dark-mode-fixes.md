# Story 8.4: Dark Mode Fixes & Adaptive Colors

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P0 (Critical - broken UI in dark mode)
**Effort:** 1.5 hours
**Status:** Ready for Development

---

## Goal

Fix all hardcoded colors throughout the app to properly adapt to dark mode using SwiftUI semantic colors.

---

## User Story

**As** a user who prefers dark mode,
**I want** all UI elements to adapt properly to dark mode,
**So that** the app is comfortable to use at night and matches my system preference.

---

## Dependencies

- ✅ No external dependencies
- ⚠️ Related to Story 8.5 (Dark Mode Toggle)
- ⚠️ Related to Story 8.3 (Launch Screen dark mode support)

---

## Implementation

### Priority 1: Fix Hardcoded White Backgrounds

#### ConversationRowView.swift (Line 130)
```swift
// Before
.background(Color.white)

// After
.background(.background)
```

#### ChannelCardView.swift (Line 90)
```swift
// Before
.background(Color.white)

// After
.background(.background)
```

### Priority 2: Adaptive Shadows

Update all shadows to use adaptive colors:

```swift
// Before
.shadow(color: .black.opacity(0.1), radius: 4, y: 2)

// After
.shadow(color: Color(.systemGray4).opacity(0.3), radius: 4, y: 2)
```

Apply to:
- ConversationRowView
- ChannelCardView
- MessageBubbleView
- FloatingFABView

### Priority 3: Gradient Borders

Update gradient borders to adapt:

```swift
// Before
LinearGradient(
    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
    startPoint: .leading,
    endPoint: .trailing
)

// After (adaptive)
LinearGradient(
    colors: [
        Color(hex: "667eea").opacity(colorScheme == .dark ? 0.8 : 1.0),
        Color(hex: "764ba2").opacity(colorScheme == .dark ? 0.8 : 1.0)
    ],
    startPoint: .leading,
    endPoint: .trailing
)
```

### Priority 4: Status Bar & Keyboard

#### Status Bar (buzzboxApp.swift)
```swift
@main
struct buzzboxApp: App {
    init() {
        // Set status bar style based on color scheme
        UIApplication.shared.statusBarStyle = .default
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceSettings.mode.colorScheme)
        }
    }
}
```

#### Keyboard Appearance
```swift
TextField("Type a message...", text: $messageText)
    .keyboardAppearance(colorScheme == .dark ? .dark : .light)
```

### Priority 5: Image Borders in Dark Mode

Add subtle borders to photos in MessageBubbleView:

```swift
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
    )
```

### Priority 6: Modal/Sheet Backgrounds

Verify all sheets adapt:
- ProfileView
- GroupInfoView
- ArchivedInboxView (Story 8.2)

```swift
.sheet(isPresented: $showProfile) {
    ProfileView()
        .background(.background) // Ensures proper dark mode
}
```

---

## Acceptance Criteria

### Visual Requirements
- ✅ ConversationRowView adapts to dark mode
- ✅ ChannelCardView adapts to dark mode
- ✅ AI badges readable in dark mode
- ✅ No hardcoded white/black colors remain
- ✅ Gradient borders adapt to dark mode
- ✅ Shadows visible in both light and dark mode

### Accessibility Requirements
- ✅ Text contrast meets WCAG AA standards (4.5:1 minimum)
- ✅ All text readable in dark mode
- ✅ Icons visible in dark mode
- ✅ Separators visible in dark mode

### Technical Requirements
- ✅ Status bar text color updates with color scheme
- ✅ Keyboard appearance matches dark mode
- ✅ All modals/sheets adapt to dark mode
- ✅ Image borders visible in dark mode

---

## Edge Cases & Error Handling

### Shadow Visibility
- ✅ **Problem:** Black shadows invisible on dark backgrounds
- ✅ **Solution:** Use `.systemGray4` adaptive color
- ✅ **Implementation:** `Color(.systemGray4).opacity(0.3)`

### Status Bar Text Color
- ✅ **Problem:** White text on light background (or vice versa)
- ✅ **Solution:** Use `.default` style (auto-adapts)
- ✅ **Implementation:** Set in app initialization

### Keyboard Appearance
- ✅ **Problem:** Light keyboard in dark mode app
- ✅ **Solution:** Match keyboard to color scheme
- ✅ **Implementation:** `.keyboardAppearance()` modifier

### Modal Sheet Backgrounds
- ✅ **Problem:** Sheets may not inherit dark mode
- ✅ **Solution:** Explicitly set `.background(.background)`
- ✅ **Implementation:** Add to all sheet presentations

### Image Visibility
- ✅ **Problem:** Photos blend into dark backgrounds
- ✅ **Solution:** Add subtle border using `.separator` color
- ✅ **Implementation:** Overlay with stroke

### WCAG Contrast Compliance
- ✅ **Problem:** Some text may not meet 4.5:1 ratio
- ✅ **Solution:** Use semantic colors (.primary, .secondary)
- ✅ **Implementation:** Test with Accessibility Inspector

---

## Files to Modify

### Primary Files (Critical Fixes)
- `buzzbox/Features/Chat/Views/ConversationRowView.swift`
  - Fix background color (line 130)
  - Update shadows
  - Update gradient borders

- `buzzbox/Features/Channels/Views/ChannelCardView.swift`
  - Fix background color (line 90)
  - Update shadows

- `buzzbox/Features/Chat/Views/MessageBubbleView.swift`
  - Add image borders for dark mode
  - Update shadows

### Secondary Files (Polish)
- `buzzbox/App/buzzboxApp.swift`
  - Set status bar style
  - Ensure proper color scheme propagation

- `buzzbox/Features/Settings/Views/ProfileView.swift`
  - Verify dark mode adaptation
  - Test all UI elements

- `buzzbox/Features/Chat/Views/MessageThreadView.swift`
  - Set keyboard appearance
  - Verify input field adapts

---

## Testing Checklist

### Visual Testing (Light Mode)
- [ ] Open app in light mode
- [ ] Verify all views look correct
- [ ] Check conversation list
- [ ] Check channel list
- [ ] Check message thread
- [ ] Check profile view

### Visual Testing (Dark Mode)
- [ ] Toggle to dark mode (Settings → Display → Dark)
- [ ] Verify all views adapt
- [ ] Check conversation list (no white cards)
- [ ] Check channel list (no white cards)
- [ ] Check message thread (readable bubbles)
- [ ] Check profile view (adapts correctly)

### Transition Testing
- [ ] Toggle light → dark → light
- [ ] Verify smooth transition (no flashing)
- [ ] Check all sheets/modals
- [ ] Verify status bar updates

### Shadow Testing
- [ ] Verify shadows visible in light mode
- [ ] Verify shadows visible in dark mode
- [ ] Check conversation cards
- [ ] Check channel cards
- [ ] Check floating FAB

### Accessibility Testing
- [ ] Open Accessibility Inspector
- [ ] Verify text contrast ratios (WCAG AA)
- [ ] Check in light mode
- [ ] Check in dark mode
- [ ] Test with system text sizes (Large, Extra Large)

### Edge Case Testing
- [ ] Test on iPhone with OLED (true blacks in dark mode)
- [ ] Test status bar on notched devices
- [ ] Test keyboard appearance in message input
- [ ] Test all modals (Profile, GroupInfo, etc.)

---

## Comprehensive Testing Matrix

| View | Light Mode | Dark Mode | Shadows | Images | Text Contrast |
|------|-----------|-----------|---------|---------|--------------|
| ConversationRowView | ✅ | ✅ | ✅ | N/A | ✅ |
| ChannelCardView | ✅ | ✅ | ✅ | ✅ | ✅ |
| MessageBubbleView | ✅ | ✅ | ✅ | ✅ | ✅ |
| ProfileView | ✅ | ✅ | N/A | ✅ | ✅ |
| InboxView | ✅ | ✅ | N/A | N/A | ✅ |
| MessageThreadView | ✅ | ✅ | N/A | ✅ | ✅ |

---

## Definition of Done

- ✅ All hardcoded `.white` and `.black` colors replaced
- ✅ All shadows use adaptive colors
- ✅ Gradient borders adapt to dark mode
- ✅ Status bar adapts correctly
- ✅ Keyboard appearance matches color scheme
- ✅ All modals/sheets adapt to dark mode
- ✅ Image borders visible in dark mode
- ✅ WCAG AA contrast ratios verified
- ✅ Smooth transitions between modes
- ✅ No visual glitches or flashing
- ✅ Tested on all major views
- ✅ Accessibility Inspector passed

---

## Related Stories

- **Story 8.3:** Custom Launch Screen (must work in dark mode)
- **Story 8.5:** Dark Mode Toggle (allows user control)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 225-271)
