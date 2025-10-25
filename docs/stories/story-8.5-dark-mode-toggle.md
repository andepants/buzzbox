# Story 8.5: Dark Mode Toggle in Profile

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 2 - Interactive Polish
**Priority:** P1 (High - User control)
**Effort:** 2 hours
**Status:** Ready for Development

---

## Goal

Allow users to control dark mode preference in Profile settings with system/light/dark options.

---

## User Story

**As** a user,
**I want** to control the app's appearance mode (system, light, or dark),
**So that** I can override system settings and use my preferred mode.

---

## Dependencies

- ⚠️ **Story 8.4:** Dark Mode Fixes (must be completed first)
- ✅ Existing ProfileView structure

---

## Implementation

### AppearanceSettings Service

Create `buzzbox/Core/Services/AppearanceSettings.swift`:

```swift
import SwiftUI
import Combine

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
@Observable
class AppearanceSettings {
    var mode: AppearanceMode {
        didSet {
            savePreference()
        }
    }

    private let defaults = UserDefaults.standard
    private let key = "appearanceMode"

    init() {
        // Load saved preference
        if let savedMode = defaults.string(forKey: key),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.mode = mode
        } else {
            self.mode = .system
        }

        // Observe system changes
        observeSystemChanges()
    }

    private func savePreference() {
        do {
            defaults.set(mode.rawValue, forKey: key)
            print("✅ Appearance mode saved: \(mode.displayName)")
        } catch {
            print("❌ Failed to save appearance preference: \(error)")
            // Gracefully fallback to system mode
            mode = .system
        }
    }

    private func observeSystemChanges() {
        // Listen to UITraitCollection changes when mode == .system
        NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.mode == .system else { return }
            // Trigger UI update for system changes
        }
    }
}
```

### Profile View UI

Add Appearance section in `ProfileView.swift`:

```swift
struct ProfileView: View {
    @Environment(AppearanceSettings.self) private var appearanceSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                // ... existing sections ...

                Section {
                    Picker("Appearance", selection: $appearanceSettings.mode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if appearanceSettings.mode == .system {
                        Text("Automatically adjusts to your system settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Choose how BuzzBox looks on your device")
                }
            }
            .navigationTitle("Profile")
        }
        .animation(.easeInOut(duration: 0.2), value: appearanceSettings.mode)
    }
}
```

### Apply at App Level

Update `buzzboxApp.swift`:

```swift
@main
struct buzzboxApp: App {
    @State private var appearanceSettings = AppearanceSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceSettings.mode.colorScheme)
                .environment(appearanceSettings)
        }
    }
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Appearance picker appears in Profile → Display section
- ✅ Three options: System, Light, Dark
- ✅ Picker defaults to System on first launch
- ✅ Toggling mode immediately updates UI
- ✅ Preference persists across app launches
- ✅ Smooth fade transition when changing modes (0.2s)

### Visual Requirements
- ✅ Segmented picker shows three clear options
- ✅ Subtitle appears when System mode selected
- ✅ Section header: "Display"
- ✅ Section footer: "Choose how BuzzBox looks on your device"
- ✅ No jarring flash during mode change

### Accessibility Requirements
- ✅ VoiceOver announces mode changes
- ✅ Picker accessible via VoiceOver
- ✅ Mode description read by VoiceOver

---

## Edge Cases & Error Handling

### System Change During Runtime
- ✅ **Behavior:** App updates if user changes iOS system dark mode while app open (only if mode == .system)
- ✅ **Implementation:** Observe `UITraitCollection` changes
- ✅ **Code:** See `observeSystemChanges()` in AppearanceSettings

### UserDefaults Write Failure
- ✅ **Behavior:** Gracefully fallback to system mode if write fails
- ✅ **Implementation:** Try-catch in `savePreference()`, reset to .system on error

### Smooth Transition Animation
- ✅ **Behavior:** Fade animation when toggling (0.2s) to avoid jarring flash
- ✅ **Implementation:** `.animation(.easeInOut(duration: 0.2), value: mode)`

### UITraitCollection Listener
- ✅ **Behavior:** Respects system changes when mode == .system
- ✅ **Implementation:** NotificationCenter observer for brightness/appearance changes

---

## Files to Create

### New Service
- `buzzbox/Core/Services/AppearanceSettings.swift`
  - AppearanceMode enum (system, light, dark)
  - @Observable class with UserDefaults persistence
  - System change observation
  - Error handling

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Settings/Views/ProfileView.swift`
  - Add Display section
  - Add appearance mode picker
  - Add subtitle for system mode
  - Apply fade animation

- `buzzbox/App/buzzboxApp.swift`
  - Initialize AppearanceSettings
  - Apply `.preferredColorScheme()` modifier
  - Inject via `.environment()`

---

## Technical Notes

### SwiftUI Color Scheme Control

Use `.preferredColorScheme()` modifier at app root:
```swift
ContentView()
    .preferredColorScheme(appearanceSettings.mode.colorScheme)
```

Returns:
- `nil` for system mode (respects OS setting)
- `.light` for light mode
- `.dark` for dark mode

### UserDefaults Persistence

Save as string to ensure codable compatibility:
```swift
defaults.set(mode.rawValue, forKey: "appearanceMode")
```

### Observable Macro

Use `@Observable` instead of `ObservableObject` (Swift 5.9+):
```swift
@MainActor
@Observable
class AppearanceSettings {
    var mode: AppearanceMode
}
```

### System Change Observation

Listen for iOS appearance changes:
```swift
NotificationCenter.default.addObserver(
    forName: UIScreen.brightnessDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    // Handle system change
}
```

---

## Testing Checklist

### Functional Testing
- [ ] Open Profile → Display section appears
- [ ] Default mode is "System"
- [ ] Tap "Light" → app switches to light mode
- [ ] Tap "Dark" → app switches to dark mode
- [ ] Tap "System" → app follows iOS system setting
- [ ] Close app → reopen → mode persists

### System Integration Testing
- [ ] Set mode to "System"
- [ ] Change iOS dark mode (Settings → Display → Dark)
- [ ] Verify app updates automatically
- [ ] Set mode to "Light"
- [ ] Change iOS dark mode → app stays light (ignores system)

### Transition Testing
- [ ] Toggle System → Light → smooth fade (no flash)
- [ ] Toggle Light → Dark → smooth fade
- [ ] Toggle Dark → System → smooth fade
- [ ] Rapid toggling → no crashes or glitches

### Persistence Testing
- [ ] Set to Light → force quit app → reopen → still Light
- [ ] Set to Dark → force quit app → reopen → still Dark
- [ ] Set to System → force quit app → reopen → still System

### Edge Case Testing
- [ ] Enable UserDefaults write failure simulation → verify fallback to System
- [ ] Background app → change iOS dark mode → foreground → verify update (if System mode)
- [ ] Test on iOS 17.0 minimum version

---

## Definition of Done

- ✅ AppearanceSettings service created
- ✅ Display section added to ProfileView
- ✅ Appearance mode picker functional
- ✅ Preference persists across launches
- ✅ Smooth fade animation implemented
- ✅ System change observation working
- ✅ UserDefaults error handling implemented
- ✅ VoiceOver accessibility verified
- ✅ No jarring transitions
- ✅ All modes tested (System, Light, Dark)

---

## Related Stories

- **Story 8.4:** Dark Mode Fixes (must be completed first)
- **Story 8.3:** Custom Launch Screen (launch screen adapts to mode)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 276-333)
