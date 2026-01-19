//
//  ClipboardManager.swift
//  Pulse
//
//  Security: Auto-clears clipboard after copying sensitive data
//  Prevents clipboard-sniffing attacks and data leakage
//

import UIKit

/// Secure clipboard manager with auto-clear functionality
@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()

    /// Auto-clear timeout in seconds (default: 30 seconds)
    private let autoClearTimeout: TimeInterval

    /// Active timer for clipboard clearing
    private var clearTimer: Timer?

    /// Last copied content for verification
    private var lastCopiedContent: String?

    private init(autoClearTimeout: TimeInterval = 30.0) {
        self.autoClearTimeout = autoClearTimeout
    }

    // MARK: - Public API

    /// Copy text to clipboard with auto-clear after timeout
    /// - Parameters:
    ///   - text: The text to copy
    ///   - sensitive: If true, clipboard will be cleared after timeout (default: true)
    func copy(_ text: String, sensitive: Bool = true) {
        // Copy to clipboard
        UIPasteboard.general.string = text
        lastCopiedContent = text

        #if DEBUG
        DebugLogger.log("Copied to clipboard (sensitive: \(sensitive))", category: .security)
        #endif

        // Schedule auto-clear for sensitive content
        if sensitive {
            scheduleAutoClear()
        } else {
            cancelAutoClear()
        }
    }

    /// Immediately clear the clipboard if it contains our content
    func clearNow() {
        // Only clear if we were the last ones to write
        if let lastContent = lastCopiedContent,
           UIPasteboard.general.string == lastContent {
            UIPasteboard.general.string = ""
            #if DEBUG
            DebugLogger.log("Clipboard cleared immediately", category: .security)
            #endif
        }

        cancelAutoClear()
        lastCopiedContent = nil
    }

    // MARK: - Private Methods

    /// Schedule automatic clipboard clearing
    private func scheduleAutoClear() {
        // Cancel any existing timer
        cancelAutoClear()

        // Schedule new timer
        clearTimer = Timer.scheduledTimer(
            withTimeInterval: autoClearTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.autoClearClipboard()
        }

        #if DEBUG
        DebugLogger.log("Clipboard will auto-clear in \(Int(autoClearTimeout)) seconds", category: .security)
        #endif
    }

    /// Cancel scheduled auto-clear
    private func cancelAutoClear() {
        clearTimer?.invalidate()
        clearTimer = nil
    }

    /// Auto-clear clipboard content if it matches our last copied content
    private func autoClearClipboard() {
        // Only clear if the clipboard still contains our content
        // This prevents clearing if user copied something else
        if let lastContent = lastCopiedContent,
           UIPasteboard.general.string == lastContent {
            UIPasteboard.general.string = ""

            #if DEBUG
            DebugLogger.log("Clipboard auto-cleared after \(Int(autoClearTimeout))s timeout", category: .security)
            #endif
        } else {
            #if DEBUG
            DebugLogger.log("Clipboard content changed, skipping auto-clear", category: .security)
            #endif
        }

        lastCopiedContent = nil
        clearTimer = nil
    }

    // MARK: - Lifecycle

    /// Clean up when app enters background
    func handleAppDidEnterBackground() {
        // Optionally clear immediately when app backgrounds
        // This prevents clipboard snooping by other apps
        clearNow()
    }
}

// MARK: - App Lifecycle Integration

extension ClipboardManager {
    /// Register for app lifecycle notifications
    func registerForAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
    }
}
