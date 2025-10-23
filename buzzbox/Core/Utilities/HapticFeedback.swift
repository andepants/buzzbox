/// HapticFeedback.swift
/// Utility for providing haptic feedback without console warnings
///
/// Properly prepares feedback generators to avoid iOS runtime warnings
/// in the console logs.

import UIKit

/// Provides haptic feedback with proper preparation to avoid console warnings
enum HapticFeedback {
    /// Trigger notification haptic feedback
    /// - Parameter type: The type of notification (success, warning, error)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Trigger impact haptic feedback
    /// - Parameter style: The style of impact (light, medium, heavy, rigid, soft)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Trigger selection haptic feedback
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
