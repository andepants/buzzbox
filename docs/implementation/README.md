# Implementation Guides

This directory contains detailed implementation guides for stories that require manual steps in Xcode or other tools.

---

## Story 8.3: Custom Launch Screen

**Files:**
- **`story-8.3-launch-screen-guide.md`** - Complete step-by-step implementation guide
- **`story-8.3-quick-reference.md`** - Quick reference for experienced developers
- **`story-8.3-assets-reference.md`** - Asset specifications and visual reference
- **`generate-launch-gradient.py`** - Python script to generate gradient images
- **`generate-launch-gradient.swift`** - Swift script (requires Xcode playground)

**Quick Start:**
```bash
# Generate gradient images
python3 docs/implementation/generate-launch-gradient.py

# Then follow the guide to create LaunchScreen.storyboard in Xcode
open docs/implementation/story-8.3-launch-screen-guide.md
```

**Status:** Assets Generated, Storyboard Creation Required

---

## Why Implementation Guides?

Some iOS features cannot be created programmatically and require Xcode GUI interaction:
- Launch Screen storyboards (iOS requirement)
- Interface Builder files (.xib, .storyboard)
- Asset catalog configurations
- Project settings not exposed via .pbxproj

These guides provide:
1. Complete instructions for manual steps
2. Automation where possible (scripts for assets)
3. Troubleshooting for common issues
4. Verification checklists

---

## Contributing

When adding new implementation guides:

1. **Use consistent naming:** `story-X.Y-feature-name-guide.md`
2. **Include quick reference:** `story-X.Y-quick-reference.md`
3. **Automate what you can:** Provide scripts for asset generation
4. **Document all manual steps:** Assume the reader is unfamiliar with Xcode
5. **Add troubleshooting:** Include common issues and solutions
6. **Update this README:** Add a new section for the story

---

**Last Updated:** 2025-10-25
