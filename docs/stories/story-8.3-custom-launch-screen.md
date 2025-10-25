# Story 8.3: Custom Launch Screen

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P1 (High - Professional polish for demo)
**Effort:** 1 hour
**Status:** Ready for Development

---

## Goal

Replace the generic system launch screen with a branded launch screen showing the BuzzBox app icon on a gradient background.

---

## User Story

**As** a user launching the BuzzBox app,
**I want** to see the app icon and branding on launch,
**So that** the app feels professional and polished from the first moment.

---

## Dependencies

- ✅ App icon assets (already exists in Assets.xcassets)
- ✅ No external dependencies

---

## Implementation

### Create LaunchScreen.storyboard

Create `buzzbox/Resources/LaunchScreen.storyboard` with:

1. **Centered App Icon:**
   - UIImageView with app icon (1024x1024 @1x)
   - Centered horizontally and vertically
   - Fixed size (120x120 points)
   - Corner radius to match app icon style

2. **Gradient Background:**
   - UIView covering entire screen
   - Gradient layer matching app theme
   - Colors: Top (#667eea) → Bottom (#764ba2)

3. **Auto Layout Constraints:**
   ```
   Icon:
   - centerX = superview.centerX
   - centerY = superview.centerY
   - width = 120
   - height = 120

   Background:
   - top = superview.top
   - leading = superview.leading
   - trailing = superview.trailing
   - bottom = superview.bottom
   ```

### Update Info.plist

Add launch screen reference:

```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

### Disable Auto-Generation

Update `buzzbox.xcodeproj/project.pbxproj`:

Set `INFOPLIST_KEY_UILaunchScreen_Generation` to `NO`

---

## Acceptance Criteria

### Visual Requirements
- ✅ App icon appears centered on launch
- ✅ Gradient background matches app theme
- ✅ Launch screen dismissed after app loads
- ✅ Works in light and dark mode
- ✅ No text or branding (clean design)

### Technical Requirements
- ✅ Uses UIKit storyboard (not SwiftUI)
- ✅ Auto Layout constraints (not fixed positions)
- ✅ Respects safe area insets
- ✅ Works on all device sizes (iPhone SE to Pro Max)

---

## Edge Cases & Error Handling

### Device Size Compatibility
- ✅ **iPhone SE:** Icon remains centered and properly sized
- ✅ **iPhone Pro Max:** Icon remains centered and properly sized
- ✅ **Implementation:** Use Auto Layout constraints, not fixed frames

### Dynamic Island
- ✅ **Behavior:** Icon respects safe area insets (no overlap on iPhone 14 Pro+)
- ✅ **Implementation:** Use safe area layout guides

### Orientation
- ✅ **Behavior:** Works in portrait (landscape not required for launch)
- ✅ **Implementation:** Portrait-only constraint

### Dark Mode
- ✅ **Behavior:** Gradient adapts to dark mode (slightly darker tones)
- ✅ **Implementation:** Use dynamic colors or adaptive gradient

---

## Files to Create

### New Storyboard
- `buzzbox/Resources/LaunchScreen.storyboard`
  - Centered app icon (120x120)
  - Gradient background (#667eea → #764ba2)
  - Auto Layout constraints
  - Safe area respect

---

## Files to Modify

### Project Configuration
- `buzzbox.xcodeproj/project.pbxproj`
  - Set `INFOPLIST_KEY_UILaunchScreen_Generation = NO`
  - Add LaunchScreen.storyboard to build phase

- `buzzbox/Info.plist` (if exists separately)
  - Add `UILaunchStoryboardName = LaunchScreen`

---

## Technical Notes

### Storyboard vs SwiftUI

**Why Storyboard:**
- Launch screens MUST use UIKit storyboard (iOS requirement)
- SwiftUI launch screens are not supported
- Storyboard ensures instant display (no SwiftUI initialization delay)

### Gradient Implementation

Use CAGradientLayer in storyboard:
1. Add UIView to storyboard
2. Set background color as fallback
3. Runtime: Apply gradient layer in AppDelegate/SceneDelegate

Or use static image with gradient:
1. Create gradient PNG in Assets
2. Set as background image in storyboard

**Recommendation:** Use static gradient image for simplicity.

### App Icon Reference

Reference app icon from Assets.xcassets:
- Use "AppIcon" image set
- Extract 1024x1024 version
- Add as separate image asset for launch screen

---

## Implementation Steps

### 1. Create Gradient Asset
- Open Assets.xcassets
- Create new Image Set: "LaunchGradient"
- Add 1x, 2x, 3x gradient images
- Gradient: #667eea (top) → #764ba2 (bottom)

### 2. Create Launch Icon Asset
- Extract 1024x1024 app icon
- Create new Image Set: "LaunchIcon"
- Add as 1x image (iOS will scale)

### 3. Create Storyboard
- File → New → Storyboard
- Name: LaunchScreen.storyboard
- Add UIImageView (background gradient)
- Add UIImageView (app icon, centered)
- Set constraints

### 4. Update Project Settings
- Target → General → App Icons and Launch Screen
- Set Launch Screen to "LaunchScreen"
- Disable "Generate Launch Screen"

---

## Testing Checklist

### Device Testing
- [ ] iPhone SE (1st gen) - small screen
- [ ] iPhone 13 - standard size
- [ ] iPhone 14 Pro - Dynamic Island
- [ ] iPhone 15 Pro Max - large screen

### Orientation Testing
- [ ] Portrait (primary)
- [ ] Landscape (verify graceful handling)

### Mode Testing
- [ ] Light mode - gradient visible
- [ ] Dark mode - gradient adapts
- [ ] System appearance changes while app backgrounded

### Build Testing
- [ ] Clean build → launch screen appears
- [ ] Delete app → reinstall → launch screen appears
- [ ] TestFlight build → launch screen appears

---

## Definition of Done

- ✅ LaunchScreen.storyboard created
- ✅ App icon centered and sized correctly
- ✅ Gradient background applied
- ✅ Auto Layout constraints set
- ✅ Safe area insets respected
- ✅ Works on all device sizes tested
- ✅ Works in light and dark mode
- ✅ No overlap with Dynamic Island
- ✅ Project settings updated
- ✅ Generic system launch screen removed

---

## Related Stories

- **Story 8.4:** Dark Mode Fixes (ensures launch screen works in dark mode)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 193-222)
