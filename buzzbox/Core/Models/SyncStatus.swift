/// SyncStatus.swift
///
/// Sync status enum shared across SwiftData models for offline-first architecture
///
/// Created: 2025-10-21

import Foundation

/// Sync status for offline-first architecture
enum SyncStatus: String, Codable {
    case pending  // Not yet synced to Firebase
    case synced   // Successfully synced to Firebase
    case failed   // Sync failed, will retry
}
