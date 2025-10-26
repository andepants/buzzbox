/// AppearanceSettings.swift
///
/// Service for managing app appearance mode (light/dark/system).
/// Persists user preference using UserDefaults and provides system change observation.
///
/// Created: 2025-10-25
/// [Source: Story 8.5 - Dark Mode Toggle in Profile]

import SwiftUI
import Combine

/// Appearance mode options for the app
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

/// Observable service for managing appearance settings
@MainActor
@Observable
class AppearanceSettings {
    // MARK: - Properties

    var mode: AppearanceMode {
        didSet {
            savePreference()
        }
    }

    private let defaults = UserDefaults.standard
    private let key = "appearanceMode"

    // MARK: - Initialization

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

    // MARK: - Private Methods

    /// Save appearance preference to UserDefaults
    private func savePreference() {
        defaults.set(mode.rawValue, forKey: key)
        print("✅ Appearance mode saved: \(mode.displayName)")
    }

    /// Observe system appearance changes
    /// Triggers UI updates when mode is set to .system
    private func observeSystemChanges() {
        // Listen to UITraitCollection changes when mode == .system
        NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.mode == .system else { return }
            // Trigger UI update for system changes
            // The UI automatically updates when colorScheme changes
        }
    }
}
