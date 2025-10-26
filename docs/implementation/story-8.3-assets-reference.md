# Story 8.3 Assets Reference - Launch Screen Assets

## Asset Catalog Structure

### LaunchGradient.imageset
**Location:** `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/`

**Purpose:** Vertical gradient background for launch screen

**Files:**
- `LaunchGradient@1x.png` - 375 × 812 pixels (2.3 KB)
- `LaunchGradient@2x.png` - 750 × 1624 pixels (6.3 KB)
- `LaunchGradient@3x.png` - 1125 × 2436 pixels (11.6 KB)
- `Contents.json` - Asset catalog metadata

**Colors:**
- Top: `#667eea` (RGB: 102, 126, 234)
- Bottom: `#764ba2` (RGB: 118, 75, 162)

**Gradient Direction:** Vertical (top to bottom)

---

### LaunchIcon.imageset
**Location:** `buzzbox/Resources/Assets.xcassets/LaunchIcon.imageset/`

**Purpose:** App icon displayed on launch screen

**Files:**
- `LaunchIcon.png` - 1024 × 1024 pixels (2.2 MB)
- `Contents.json` - Asset catalog metadata

**Usage:** Displayed at 120 × 120 points, centered on screen

---

## Visual Specifications

### Launch Screen Layout

```
┌───────────────────────────────┐
│                               │  ← Top: #667eea
│                               │
│                               │
│           ┌─────┐             │
│           │     │             │  ← Center: App Icon (120×120)
│           │ 🔷  │             │
│           │     │             │
│           └─────┘             │
│                               │
│                               │
│                               │  ← Bottom: #764ba2
└───────────────────────────────┘
```

### Gradient Visualization

```
  #667eea  ████████████████████  ← Top (Light Purple-Blue)
           ████████████████████
           ████████████████████
           ████████████████████
           ████████████████████
           ████████████████████  ← Middle (Blend)
           ████████████████████
           ████████████████████
           ████████████████████
  #764ba2  ████████████████████  ← Bottom (Deep Purple)
```

---

## Asset Generation

### Automatic Generation (Recommended)

Use the provided Python script to regenerate gradient images:

```bash
cd /Users/andre/coding/buzzbox
python3 docs/implementation/generate-launch-gradient.py
```

**Requirements:**
```bash
pip3 install pillow
```

### Manual Generation

If you prefer to create gradients manually:

1. **Design Tool:** Figma, Sketch, Photoshop, etc.
2. **Canvas Sizes:**
   - 1x: 375 × 812 pixels
   - 2x: 750 × 1624 pixels
   - 3x: 1125 × 2436 pixels
3. **Gradient:**
   - Type: Linear
   - Direction: Vertical (0° / Top to Bottom)
   - Top Color: `#667eea`
   - Bottom Color: `#764ba2`
4. **Export:**
   - Format: PNG
   - Names: `LaunchGradient@1x.png`, `LaunchGradient@2x.png`, `LaunchGradient@3x.png`
   - Destination: `buzzbox/Resources/Assets.xcassets/LaunchGradient.imageset/`

---

## File Sizes

| File                      | Size    | Dimensions      |
|---------------------------|---------|-----------------|
| LaunchGradient@1x.png     | 2.3 KB  | 375 × 812       |
| LaunchGradient@2x.png     | 6.3 KB  | 750 × 1624      |
| LaunchGradient@3x.png     | 11.6 KB | 1125 × 2436     |
| **Total**                 | **20 KB**| -              |

---

## Color Palette

### Primary Launch Gradient

| Position | Hex       | RGB             | RGBA                    |
|----------|-----------|-----------------|-------------------------|
| Top      | `#667eea` | (102, 126, 234) | rgba(102, 126, 234, 1.0)|
| Bottom   | `#764ba2` | (118, 75, 162)  | rgba(118, 75, 162, 1.0) |

### Color Accessibility

- **Contrast Ratio (Top):** 3.5:1 against white text
- **Contrast Ratio (Bottom):** 4.2:1 against white text
- **WCAG Level:** AA for large text

---

## Integration Checklist

### Asset Catalog
- [x] `LaunchGradient.imageset/` directory created
- [x] `Contents.json` configured for 1x/2x/3x scales
- [x] `LaunchGradient@1x.png` generated (375×812)
- [x] `LaunchGradient@2x.png` generated (750×1624)
- [x] `LaunchGradient@3x.png` generated (1125×2436)
- [x] `LaunchIcon.imageset/` exists (already created)

### Storyboard Usage
- [ ] LaunchScreen.storyboard created
- [ ] Background UIImageView → Image: `LaunchGradient`
- [ ] Icon UIImageView → Image: `LaunchIcon`
- [ ] Constraints configured

### Project Settings
- [ ] Target → General → Launch Screen: `LaunchScreen`
- [ ] Build Settings → Launch Screen Storyboard Name: `LaunchScreen`
- [ ] Generate Launch Screen: NO

---

## Troubleshooting

### Images Not Appearing in Xcode

**Symptom:** Assets don't show up in Interface Builder image picker

**Solutions:**
1. Clean build folder (⇧⌘K)
2. Close and reopen Xcode
3. Check file permissions: `chmod 644 *.png`
4. Verify `Contents.json` is valid JSON

### Gradient Looks Banded/Pixelated

**Symptom:** Visible color bands in gradient

**Solutions:**
1. Regenerate images with higher quality
2. Use dithering in export settings
3. Verify PNG compression settings

### File Sizes Too Large

**Symptom:** Launch images increase app bundle size significantly

**Current Status:** ✅ Total 20 KB (well within acceptable range)

**Acceptable Range:** < 100 KB total

---

## Maintenance

### Updating Colors

To change gradient colors:

1. **Edit Python script:**
   ```python
   top_color = hex_to_rgb("#YOUR_COLOR")
   bottom_color = hex_to_rgb("#YOUR_COLOR")
   ```

2. **Regenerate images:**
   ```bash
   python3 docs/implementation/generate-launch-gradient.py
   ```

3. **No storyboard changes needed** - assets automatically update

### Adding New Scales (e.g., 4x for future devices)

1. Update `generate-launch-gradient.py` scales array
2. Update `Contents.json` to include 4x entry
3. Regenerate images

---

**Created:** 2025-10-25
**Last Updated:** 2025-10-25
**Story:** Story 8.3 - Custom Launch Screen
