//
//  PowerManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import UIKit
import Combine

@MainActor
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published var isLowPowerMode: Bool = false
    @Published var batteryLevel: Float = 1.0
    @Published var appState: AppState = .foreground

    enum AppState {
        case foreground
        case background
        case inactive
    }

    enum DiscoveryInterval: TimeInterval {
        case aggressive = 1.0    // Foreground, good battery
        case normal = 5.0        // Foreground, moderate battery
        case conservative = 15.0 // Background
        case minimal = 60.0      // Low power mode
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = max(UIDevice.current.batteryLevel, 0)
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        setupObservers()
    }

    private func setupObservers() {
        // Monitor battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.batteryLevel = max(UIDevice.current.batteryLevel, 0)
            }
            .store(in: &cancellables)

        // Monitor low power mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .store(in: &cancellables)

        // Monitor app state - entering background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.appState = .background
            }
            .store(in: &cancellables)

        // Monitor app state - entering foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.appState = .foreground
            }
            .store(in: &cancellables)

        // Monitor app state - becoming inactive
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.appState = .inactive
            }
            .store(in: &cancellables)

        // Monitor app state - becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.appState = .foreground
            }
            .store(in: &cancellables)
    }

    /// Get recommended discovery interval based on current power state
    var recommendedInterval: DiscoveryInterval {
        // Critical battery - minimal activity
        if isLowPowerMode || batteryLevel < 0.1 {
            return .minimal
        }

        switch appState {
        case .foreground:
            // In foreground, adjust based on battery level
            return batteryLevel > 0.3 ? .aggressive : .normal
        case .background, .inactive:
            // Background - always conservative
            return .conservative
        }
    }

    /// Whether discovery should be completely stopped
    var shouldStopDiscovery: Bool {
        // Stop if critical battery AND in background
        return batteryLevel < 0.05 && appState == .background
    }

    /// Whether we're in a power-constrained state
    var isPowerConstrained: Bool {
        return isLowPowerMode || batteryLevel < 0.2 || appState != .foreground
    }

    /// Get scan duration for intermittent discovery
    var scanDuration: TimeInterval {
        switch recommendedInterval {
        case .aggressive:
            return 0 // Continuous
        case .normal:
            return 10 // 10 seconds per interval
        case .conservative:
            return 5 // 5 seconds per interval
        case .minimal:
            return 3 // 3 seconds per interval
        }
    }
}
