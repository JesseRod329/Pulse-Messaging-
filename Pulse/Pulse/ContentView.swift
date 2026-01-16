//
//  ContentView.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showMainApp = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                RadarView()
                    .transition(.opacity)
            } else {
                LaunchRadarView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: hasCompletedOnboarding)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Update state if onboarding completes
            let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            if completed != hasCompletedOnboarding {
                withAnimation {
                    hasCompletedOnboarding = completed
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
