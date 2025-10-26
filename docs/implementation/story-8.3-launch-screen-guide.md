# Story 8.3: Custom Launch Screen - Implementation Guide

**Status:** Manual Implementation Required
**Reason:** Launch screens must use UIKit storyboard files (.storyboard), which cannot be created programmatically

---

## Overview

This guide provides step-by-step instructions for implementing a custom launch screen with:
- Centered app icon (120x120 points)
- Gradient background (#667eea → #764ba2)
- Auto Layout constraints
- Safe area respect

---

## Prerequisites

### Assets Already Created
- ✅ **LaunchIcon.imageset** - Located at `buzzbox/Resources/Assets.xcassets/LaunchIcon.imageset/`
  - Contains: `LaunchIcon.png` (1024x1024 app icon)
- ✅ **LaunchGradient.imageset** - Located at `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/`
  - Placeholder created, needs gradient images (see Step 1)

---

## Step 1: Create Gradient Images

### Option A: Using Design Tool (Recommended)

1. **Open your preferred design tool** (Figma, Sketch, Photoshop, etc.)

2. **Create gradient backgrounds** with these specifications:
   - **Colors:**
     - Top: `#667eea` (RGB: 102, 126, 234)
     - Bottom: `#764ba2` (RGB: 118, 75, 162)
   - **Direction:** Vertical (top to bottom)
   - **Gradient Type:** Linear

3. **Export three versions:**
   - `LaunchGradient@1x.png` - 375 × 812 pixels (iPhone X/11 Pro/12/13/14 Pro base size)
   - `LaunchGradient@2x.png` - 750 × 1624 pixels (2x scale)
   - `LaunchGradient@3x.png` - 1125 × 2436 pixels (3x scale)

4. **Save images to:**
   ```
   /Users/andre/coding/buzzbox/buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/
   ```

### Option B: Using Swift Script (Alternative)

Create gradient images programmatically:

```swift
import UIKit

func createGradientImage(size: CGSize, scale: CGFloat) -> UIImage? {
    let bounds = CGRect(origin: .zero, size: size)
    let renderer = UIGraphicsImageRenderer(bounds: bounds)

    return renderer.image { context in
        let colors = [
            UIColor(red: 102/255, green: 126/255, blue: 234/255, alpha: 1.0).cgColor,
            UIColor(red: 118/255, green: 75/255, blue: 162/255, alpha: 1.0).cgColor
        ]

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0.0, 1.0]
        )!

        context.cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width / 2, y: 0),
            end: CGPoint(x: size.width / 2, y: size.height),
            options: []
        )
    }
}

// Generate and save images
let baseSize = CGSize(width: 375, height: 812)

// 1x
if let image1x = createGradientImage(size: baseSize, scale: 1.0),
   let data = image1x.pngData() {
    try? data.write(to: URL(fileURLWithPath: "LaunchGradient@1x.png"))
}

// 2x
if let image2x = createGradientImage(size: CGSize(width: 750, height: 1624), scale: 2.0),
   let data = image2x.pngData() {
    try? data.write(to: URL(fileURLWithPath: "LaunchGradient@2x.png"))
}

// 3x
if let image3x = createGradientImage(size: CGSize(width: 1125, height: 2436), scale: 3.0),
   let data = image3x.pngData() {
    try? data.write(to: URL(fileURLWithPath: "LaunchGradient@3x.png"))
}
```

---

## Step 2: Create LaunchScreen.storyboard

### 2.1 Create New Storyboard

1. **Open Xcode** with the buzzbox project
2. **Navigate to:** `buzzbox/Resources/` in Project Navigator
3. **Right-click** on `Resources` folder → **New File...**
4. **Select:** iOS → User Interface → **Launch Screen**
5. **Name:** `LaunchScreen` (without .storyboard extension)
6. **Click:** Create

### 2.2 Design Launch Screen Layout

1. **Select the View Controller** in the storyboard
2. **Delete any existing UI elements** (if present)

#### Add Gradient Background

1. **Drag UIImageView** from Object Library onto the view
2. **Set Image:** `LaunchGradient` (from Assets.xcassets)
3. **Set Content Mode:** Scale to Fill
4. **Add Constraints:**
   - Top: 0 to Superview.Top
   - Leading: 0 to Superview.Leading
   - Trailing: 0 to Superview.Trailing
   - Bottom: 0 to Superview.Bottom
5. **Send to Back:** Editor → Arrange → Send to Back (or right-click → Arrange → Send to Back)

#### Add App Icon

1. **Drag UIImageView** from Object Library onto the view (on top of gradient)
2. **Set Image:** `LaunchIcon` (from Assets.xcassets)
3. **Set Content Mode:** Aspect Fit
4. **Add Constraints:**
   - Width: 120 (constant)
   - Height: 120 (constant)
   - Center X: 0 to Superview.Center X
   - Center Y: 0 to Superview.Center Y

### 2.3 Configure View Controller

1. **Select View Controller** in Document Outline
2. **Open Attributes Inspector** (⌥⌘4)
3. **Verify Settings:**
   - Simulated Metrics → Size: Freeform (or iPhone)
   - Is Initial View Controller: ✓ (checkmark)

---

## Step 3: Update Project Configuration

### 3.1 Set Launch Screen in Project Settings

1. **Select buzzbox project** in Project Navigator (top-level blue icon)
2. **Select buzzbox target** under TARGETS
3. **Go to General tab**
4. **Scroll to App Icons and Launch Screen**
5. **Launch Screen File:** Select `LaunchScreen` from dropdown
6. **Generate Launch Screen:** Ensure this is **UNCHECKED/OFF**

### 3.2 Verify Build Phase

1. **Select buzzbox target** → **Build Phases tab**
2. **Expand "Copy Bundle Resources"**
3. **Verify `LaunchScreen.storyboard` is present**
   - If not, click `+` and add it from Resources folder

### 3.3 Update Info.plist (If Using Separate Info.plist)

**Note:** Modern Xcode projects often don't have a separate Info.plist file - settings are in project build settings. Only do this step if you have a separate Info.plist file.

If `buzzbox/Info.plist` exists:

```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

If using build settings (more common):
1. **Select buzzbox target** → **Build Settings tab**
2. **Search for:** "Launch"
3. **Find:** `Info.plist Key - Launch Screen Storyboard Name`
4. **Set value to:** `LaunchScreen`
5. **Find:** `Generate Info.plist File - Launch Screen`
6. **Set value to:** `NO`

---

## Step 4: Clean and Rebuild

### 4.1 Clean Build Folder

1. **Product menu** → **Clean Build Folder** (⇧⌘K)
2. **Wait for cleaning to complete**

### 4.2 Delete App from Simulator/Device

1. **Delete buzzbox app** from all test devices and simulators
2. **This ensures cached launch screens are cleared**

### 4.3 Rebuild and Run

1. **Product menu** → **Run** (⌘R)
2. **Watch for launch screen** when app starts

---

## Step 5: Verification

### 5.1 Visual Verification

Launch the app and verify:
- ✅ Gradient background appears (purple-blue gradient)
- ✅ App icon is centered horizontally and vertically
- ✅ App icon is 120x120 points in size
- ✅ No white bars or safe area issues
- ✅ Smooth transition to main app screen

### 5.2 Device Testing

Test on multiple device sizes:
- ✅ **iPhone SE (1st gen)** - Small screen (4")
- ✅ **iPhone 13/14** - Standard size (6.1")
- ✅ **iPhone 14 Pro** - Dynamic Island
- ✅ **iPhone 15 Pro Max** - Large screen (6.7")

### 5.3 Orientation Testing

Test app launch:
- ✅ **Portrait** - Primary orientation (should work perfectly)
- ✅ **Landscape** - Verify graceful handling if supported

### 5.4 Dark Mode Testing

1. **Toggle Dark Mode:**
   - Simulator: Features → Toggle Appearance
   - Device: Settings → Display & Brightness
2. **Verify gradient adapts** (should work with current gradient)

---

## Troubleshooting

### Launch Screen Not Appearing

**Problem:** Old launch screen still shows or white screen appears

**Solutions:**
1. **Delete app completely** from device/simulator
2. **Clean build folder** (⇧⌘K)
3. **Restart Xcode**
4. **Restart Simulator**
5. **Rebuild app** (⌘R)

### Gradient Not Showing

**Problem:** Gradient background is blank or white

**Solutions:**
1. **Verify gradient images exist:**
   ```
   ls -la buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/
   ```
2. **Check image names match Contents.json:**
   - `LaunchGradient@1x.png`
   - `LaunchGradient@2x.png`
   - `LaunchGradient@3x.png`
3. **Verify UIImageView is set to "Scale to Fill" content mode**
4. **Verify UIImageView constraints are set to 0 on all sides**

### App Icon Not Centered

**Problem:** App icon appears off-center

**Solutions:**
1. **Verify constraints:**
   - Center X = 0 to Superview.Center X
   - Center Y = 0 to Superview.Center Y
2. **Check icon size constraints:**
   - Width = 120
   - Height = 120
3. **Update constraints:** Editor → Update Frames

### White Bars on Some Devices

**Problem:** White bars appear on top/bottom on some devices

**Solutions:**
1. **Verify gradient background constraints:**
   - Top, Leading, Trailing, Bottom = 0 to Superview
2. **Ensure "Respect Safe Area Layout Guides" is appropriate:**
   - For gradient background: UNCHECKED (fill entire screen)
   - For app icon: CHECKED (respect safe area)

---

## File Locations Summary

### Files Created
- ✅ `buzzbox/Resources/LaunchScreen.storyboard` - **Manual creation required**
- ✅ `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/Contents.json` - Created
- ⚠️ `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/LaunchGradient@1x.png` - **Needs creation**
- ⚠️ `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/LaunchGradient@2x.png` - **Needs creation**
- ⚠️ `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/LaunchGradient@3x.png` - **Needs creation**

### Files Already Exist
- ✅ `buzzbox/Resources/Assets.xcassets/LaunchIcon.imageset/` - App icon for launch screen
- ✅ `buzzbox/Resources/Assets.xcassets/AppIcon.appiconset/` - App icon set

### Project Settings Modified
- ✅ **Target Settings → General → Launch Screen File:** `LaunchScreen`
- ✅ **Target Settings → General → Generate Launch Screen:** `NO`
- ✅ **Build Settings → Launch Screen Storyboard Name:** `LaunchScreen`
- ✅ **Build Phases → Copy Bundle Resources:** Includes `LaunchScreen.storyboard`

---

## Acceptance Criteria Checklist

### Visual Requirements
- [ ] App icon appears centered on launch
- [ ] Gradient background matches app theme (#667eea → #764ba2)
- [ ] Launch screen dismissed after app loads
- [ ] Works in light and dark mode
- [ ] No text or branding (clean design)

### Technical Requirements
- [ ] Uses UIKit storyboard (not SwiftUI)
- [ ] Auto Layout constraints (not fixed positions)
- [ ] Respects safe area insets
- [ ] Works on all device sizes (iPhone SE to Pro Max)

### Edge Cases
- [ ] iPhone SE - Icon remains centered and properly sized
- [ ] iPhone Pro Max - Icon remains centered and properly sized
- [ ] Dynamic Island - Icon respects safe area insets (no overlap)
- [ ] Portrait orientation - Works correctly
- [ ] Dark mode - Gradient adapts appropriately

---

## Next Steps

After completing this implementation:

1. **Run full device test suite** (Story 8.3 acceptance criteria)
2. **Document any issues** in this guide
3. **Create QA gate** (`docs/qa/gates/8.3-custom-launch-screen.yml`)
4. **Move to Story 8.4** (Dark Mode Fixes)

---

## Technical Notes

### Why Storyboard?

Launch screens **must** use UIKit storyboard files because:
- iOS requires launch screens to be static resources
- SwiftUI views require runtime initialization (too slow for launch)
- Storyboards are compiled into binary format for instant display
- Apple explicitly requires `.storyboard` files for launch screens

### Gradient Implementation Choice

We chose **static gradient images** over CAGradientLayer because:
- **Simpler:** No runtime code required
- **Faster:** Images load instantly from asset catalog
- **Reliable:** No risk of gradient rendering issues
- **Compatible:** Works on all iOS versions consistently

### Image Sizes

Gradient image sizes (375×812 base) chosen because:
- Covers most common iPhone sizes (X/11 Pro/12/13/14 Pro)
- Scales well with 1x/2x/3x multipliers
- Small enough to keep app binary size minimal
- Large enough to avoid pixelation on Pro Max devices

---

**Created:** 2025-10-25
**Story:** Story 8.3 - Custom Launch Screen
**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
