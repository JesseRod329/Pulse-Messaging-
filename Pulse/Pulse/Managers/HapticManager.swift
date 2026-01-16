//
//  HapticManager.swift
//  Pulse
//
//  Created by Jesse on 2026
//

import SwiftUI
import UIKit

/// A centralized manager for providing haptic feedback.
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let feedbackEnabledKey = "hapticFeedback"
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: feedbackEnabledKey)
    }
    
    private init() {
        // Ensure default is true if not set
        if UserDefaults.standard.object(forKey: feedbackEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: feedbackEnabledKey)
        }
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
