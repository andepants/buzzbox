/// PrivacyOverlayView.swift
/// Privacy overlay shown when app backgrounds to prevent sensitive data screenshots
/// [Source: Epic 1, Story 1.3]
///
/// This overlay covers the app content when the app is backgrounded or inactive
/// to prevent iOS from capturing screenshots of sensitive conversation data
/// for the app switcher view.

import SwiftUI

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "envelope.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

                Text("Buzzbox")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyOverlayView()
}
