//
//  ErrorAlertView.swift
//  Pulse
//
//  Error alert and banner UI components.
//

import SwiftUI

// MARK: - Error Alert View (Modal)

struct ErrorAlertView: View {
    let alert: ErrorAlert
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let onOpenSettings: () -> Void

    @State private var themeManager = ThemeManager.shared
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background dimmer
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Alert card
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(themeManager.colors.error.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(themeManager.colors.error)
                }

                // Title
                Text(alert.error.localizedDescription)
                    .font(.headline)
                    .foregroundStyle(themeManager.colors.text)
                    .multilineTextAlignment(.center)

                // Recovery suggestion
                if let suggestion = alert.error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Buttons
                HStack(spacing: 12) {
                    // Dismiss button
                    Button(action: dismissWithAnimation) {
                        Text(alert.error.requiresSettings || alert.error.isRetryable ? "Cancel" : "OK")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Dismiss")

                    // Action button
                    if alert.error.requiresSettings {
                        Button(action: {
                            onOpenSettings()
                            dismissWithAnimation()
                        }) {
                            Text("Open Settings")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeManager.colors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(themeManager.colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Open Settings")
                        .accessibilityHint("Opens system settings")
                    } else if alert.error.isRetryable, let retry = onRetry {
                        Button(action: {
                            retry()
                            dismissWithAnimation()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Retry")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeManager.colors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Retry")
                        .accessibilityHint("Tries the action again")
                    }
                }
            }
            .padding(24)
            .background(themeManager.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private var iconName: String {
        switch alert.error {
        case .bluetoothDisabled, .bluetoothUnavailable:
            return "antenna.radiowaves.left.and.right.slash"
        case .peerDisconnected, .connectionFailed:
            return "wifi.slash"
        case .sendFailed:
            return "exclamationmark.bubble"
        case .encryptionFailed, .decryptionFailed:
            return "lock.slash"
        case .microphonePermissionDenied:
            return "mic.slash"
        case .recordingFailed, .playbackFailed:
            return "waveform.slash"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Error Banner View (Non-blocking toast)

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    @State private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(themeManager.colors.error)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.colors.text)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Status Banner (for connection status)

struct StatusBannerView: View {
    let message: String
    let type: StatusType

    @State private var themeManager = ThemeManager.shared

    enum StatusType {
        case info
        case warning
        case error
        case success

        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundStyle(type.color)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(themeManager.colors.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(type.color.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type == .error ? "Error" : type == .warning ? "Warning" : "Status"): \(message)")
    }
}

// MARK: - View Modifier for Error Handling

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager: ErrorManager

    func body(content: Content) -> some View {
        ZStack {
            content

            // Banner (top)
            if errorManager.showBanner {
                VStack {
                    ErrorBannerView(
                        message: errorManager.bannerMessage,
                        onDismiss: { errorManager.dismissBanner() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)

                    Spacer()
                }
                .animation(.spring(response: 0.3), value: errorManager.showBanner)
            }

            // Modal alert
            if let alert = errorManager.currentAlert {
                ErrorAlertView(
                    alert: alert,
                    onDismiss: { errorManager.dismissAlert() },
                    onRetry: alert.retryAction,
                    onOpenSettings: { errorManager.openSettings() }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3), value: errorManager.currentAlert != nil)
    }
}

extension View {
    func errorAlert(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorAlertModifier(errorManager: errorManager))
    }
}

// MARK: - Previews

#Preview("Error Alert") {
    ErrorAlertView(
        alert: ErrorAlert(
            error: .sendFailed(reason: "Peer is out of range"),
            timestamp: Date(),
            retryAction: { print("Retry") }
        ),
        onDismiss: {},
        onRetry: { print("Retry") },
        onOpenSettings: {}
    )
}

#Preview("Error Banner") {
    VStack {
        ErrorBannerView(
            message: "Failed to connect to peer",
            onDismiss: {}
        )
        Spacer()
    }
    .background(Color.black)
}

#Preview("Status Banners") {
    VStack(spacing: 12) {
        StatusBannerView(message: "Connected", type: .success)
        StatusBannerView(message: "Reconnecting...", type: .warning)
        StatusBannerView(message: "Offline", type: .error)
        StatusBannerView(message: "3 peers nearby", type: .info)
    }
    .padding()
    .background(Color.black)
}
