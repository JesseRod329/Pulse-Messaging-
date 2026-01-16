//
//  ErrorManager.swift
//  Pulse
//
//  Centralized error handling and user notification system.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Error Types

enum PulseError: Error, LocalizedError {
    // Connection errors
    case peerDisconnected(peerName: String)
    case connectionFailed(reason: String)
    case bluetoothDisabled
    case bluetoothUnavailable

    // Message errors
    case sendFailed(reason: String)
    case encryptionFailed
    case decryptionFailed

    // Media errors
    case microphonePermissionDenied
    case recordingFailed(reason: String)
    case playbackFailed(reason: String)

    // General errors
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .peerDisconnected(let name):
            return "\(name) disconnected"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .bluetoothDisabled:
            return "Bluetooth is disabled"
        case .bluetoothUnavailable:
            return "Bluetooth is not available"
        case .sendFailed(let reason):
            return "Message failed to send: \(reason)"
        case .encryptionFailed:
            return "Encryption error"
        case .decryptionFailed:
            return "Could not decrypt message"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .peerDisconnected:
            return "They may be out of range. Try moving closer."
        case .connectionFailed:
            return "Check your Bluetooth settings and try again."
        case .bluetoothDisabled:
            return "Enable Bluetooth in Settings to discover nearby developers."
        case .bluetoothUnavailable:
            return "This device does not support Bluetooth."
        case .sendFailed:
            return "Tap to retry sending the message."
        case .encryptionFailed, .decryptionFailed:
            return "There may be a key mismatch. Try reconnecting."
        case .microphonePermissionDenied:
            return "Enable microphone access in Settings to send voice notes."
        case .recordingFailed, .playbackFailed:
            return "Try again or restart the app."
        case .unknown:
            return nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .sendFailed, .connectionFailed, .recordingFailed, .playbackFailed:
            return true
        default:
            return false
        }
    }

    var requiresSettings: Bool {
        switch self {
        case .bluetoothDisabled, .microphonePermissionDenied:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Alert Model

struct ErrorAlert: Identifiable, Equatable {
    let id = UUID()
    let error: PulseError
    let timestamp: Date
    let retryAction: (() -> Void)?

    static func == (lhs: ErrorAlert, rhs: ErrorAlert) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Error Manager

@MainActor
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published var currentAlert: ErrorAlert?
    @Published var recentErrors: [ErrorAlert] = []
    @Published var showBanner = false
    @Published var bannerMessage = ""

    private init() {}

    // MARK: - Show Error Alert (Modal)

    func showError(_ error: PulseError, retryAction: (() -> Void)? = nil) {
        let alert = ErrorAlert(error: error, timestamp: Date(), retryAction: retryAction)
        currentAlert = alert
        recentErrors.append(alert)

        // Keep only last 10 errors
        if recentErrors.count > 10 {
            recentErrors.removeFirst()
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Show Banner (Non-blocking)

    func showBanner(_ message: String, duration: TimeInterval = 3.0) {
        bannerMessage = message
        withAnimation(.spring(response: 0.3)) {
            showBanner = true
        }

        // Auto-dismiss
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    self.showBanner = false
                }
            }
        }
    }

    // MARK: - Dismiss

    func dismissAlert() {
        currentAlert = nil
    }

    func dismissBanner() {
        withAnimation(.spring(response: 0.3)) {
            showBanner = false
        }
    }

    // MARK: - Open Settings

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
