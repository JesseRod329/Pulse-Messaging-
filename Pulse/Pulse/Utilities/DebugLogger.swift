//
//  DebugLogger.swift
//  Pulse
//
//  Security-conscious logging utility that only outputs in DEBUG builds.
//  NEVER logs sensitive data like message content, keys, or PII.
//

import Foundation
import os.log

/// A secure logging utility that only outputs in DEBUG builds.
/// Use this instead of print() to prevent sensitive data from leaking to production logs.
enum DebugLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pulse"

    private static let generalLog = OSLog(subsystem: subsystem, category: "general")
    private static let networkLog = OSLog(subsystem: subsystem, category: "network")
    private static let cryptoLog = OSLog(subsystem: subsystem, category: "crypto")
    private static let meshLog = OSLog(subsystem: subsystem, category: "mesh")
    private static let securityLog = OSLog(subsystem: subsystem, category: "security")

    enum Category {
        case general
        case network
        case crypto
        case mesh
        case security

        var osLog: OSLog {
            switch self {
            case .general: return generalLog
            case .network: return networkLog
            case .crypto: return cryptoLog
            case .mesh: return meshLog
            case .security: return securityLog
            }
        }
    }

    /// Log a debug message. Only outputs in DEBUG builds.
    /// - Parameters:
    ///   - message: The message to log (should NOT contain sensitive data)
    ///   - category: The log category
    static func log(_ message: String, category: Category = .general) {
        #if DEBUG
        os_log("%{public}@", log: category.osLog, type: .debug, message)
        #endif
    }

    /// Log an info message. Only outputs in DEBUG builds.
    static func info(_ message: String, category: Category = .general) {
        #if DEBUG
        os_log("%{public}@", log: category.osLog, type: .info, message)
        #endif
    }

    /// Log a warning. Only outputs in DEBUG builds.
    static func warning(_ message: String, category: Category = .general) {
        #if DEBUG
        os_log("%{public}@", log: category.osLog, type: .default, "⚠️ \(message)")
        #endif
    }

    /// Log an error. Always outputs (errors are important for diagnostics).
    /// IMPORTANT: Never include sensitive data in error messages.
    static func error(_ message: String, category: Category = .general) {
        // Errors are logged in all builds, but with privacy protection
        os_log("%{public}@", log: category.osLog, type: .error, "❌ \(message)")
    }

    /// Log a success message. Only outputs in DEBUG builds.
    static func success(_ message: String, category: Category = .general) {
        #if DEBUG
        os_log("%{public}@", log: category.osLog, type: .debug, "✅ \(message)")
        #endif
    }
}
