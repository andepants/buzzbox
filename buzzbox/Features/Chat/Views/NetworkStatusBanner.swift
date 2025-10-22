/// NetworkStatusBanner.swift
///
/// Banner view shown when device is offline
/// Displays at top of conversation list
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI

/// Banner indicating offline network status
struct NetworkStatusBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
                .font(.system(size: 16, weight: .semibold))

            Text("Offline")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.yellow.opacity(0.2))
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
}

// MARK: - Preview

#Preview {
    List {
        NetworkStatusBanner()
    }
}
