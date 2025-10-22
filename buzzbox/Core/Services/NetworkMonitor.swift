/// NetworkMonitor.swift
///
/// Singleton service for monitoring network connectivity status
/// Uses NWPathMonitor to track connection state and type
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List, Epic 2 Pattern 2]

import Foundation
import Network
import Combine

/// Monitors network connectivity and publishes status changes
@MainActor
final class NetworkMonitor: ObservableObject {
    // MARK: - Properties

    static let shared = NetworkMonitor()

    /// Whether device is connected to network
    @Published var isConnected = true

    /// Whether connection is cellular (expensive)
    @Published var isCellular = false

    /// Whether connection is constrained (low data mode)
    @Published var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.buzzbox.networkmonitor")

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.isExpensive
                self?.isConstrained = path.isConstrained

                print("📡 Network status: \(path.status == .satisfied ? "Connected" : "Offline")")
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
