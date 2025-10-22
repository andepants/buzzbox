//
//  ContentView.swift
//  buzzbox
//
//  Created by Andrew Heim on 10/21/25.
//

import SwiftUI

/// Main content view for Buzzbox
/// Displays a placeholder UI during scaffolding phase
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Buzzbox")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("AI-Powered Messaging")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
