# Story 8.3 Quick Reference - Custom Launch Screen

## TL;DR

Create a branded launch screen with app icon on gradient background.

---

## Quick Start (3 Steps)

### Step 1: Generate Gradient Images

```bash
cd /Users/andre/coding/buzzbox
swift docs/implementation/generate-launch-gradient.swift
```

### Step 2: Create Storyboard in Xcode

1. **New File:** Resources → Launch Screen → Name: `LaunchScreen`
2. **Add Gradient Background:**
   - Drag UIImageView → Set Image: `LaunchGradient` → Content Mode: Scale to Fill
   - Constraints: Top/Leading/Trailing/Bottom = 0
3. **Add App Icon:**
   - Drag UIImageView → Set Image: `LaunchIcon` → Content Mode: Aspect Fit
   - Constraints: Width/Height = 120, Center X/Y = 0

### Step 3: Configure Project

1. **Target → General → Launch Screen File:** `LaunchScreen`
2. **Target → General → Generate Launch Screen:** OFF
3. **Clean Build:** ⇧⌘K → Delete App → Run ⌘R

---

## Gradient Colors

- **Top:** `#667eea` (RGB: 102, 126, 234)
- **Bottom:** `#764ba2` (RGB: 118, 75, 162)

---

## Constraints Reference

### Gradient Background (UIImageView)
```
Top:      0 to Superview.Top
Leading:  0 to Superview.Leading
Trailing: 0 to Superview.Trailing
Bottom:   0 to Superview.Bottom
Content Mode: Scale to Fill
```

### App Icon (UIImageView)
```
Width:    120 (constant)
Height:   120 (constant)
Center X: 0 to Superview.Center X
Center Y: 0 to Superview.Center Y
Content Mode: Aspect Fit
```

---

## Troubleshooting Quick Fixes

### Launch Screen Not Updating
```bash
# 1. Clean build folder (⇧⌘K)
# 2. Delete app from device/simulator
# 3. Restart Xcode
# 4. Rebuild (⌘R)
```

### Gradient Not Showing
```bash
# Verify images exist
ls -la buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/

# Should show:
# - LaunchGradient@1x.png
# - LaunchGradient@2x.png
# - LaunchGradient@3x.png
# - Contents.json
```

---

## Testing Checklist

- [ ] iPhone SE - Small screen
- [ ] iPhone 13 - Standard size
- [ ] iPhone 14 Pro - Dynamic Island
- [ ] iPhone 15 Pro Max - Large screen
- [ ] Dark mode toggle
- [ ] Portrait orientation

---

## Full Documentation

See: `docs/implementation/story-8.3-launch-screen-guide.md`
