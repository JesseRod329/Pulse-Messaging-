//
//  RateLimiter.swift
//  Pulse
//
//  Security: Rate limiting to prevent DoS attacks
//  Tracks message rates per peer and blocks excessive traffic
//

import Foundation

/// Rate limiter using sliding window algorithm
@MainActor
final class RateLimiter {
    /// Configuration for rate limiting
    struct Config {
        let maxMessagesPerWindow: Int
        let windowDuration: TimeInterval

        /// Default: 100 messages per 60 seconds (aggressive DoS protection)
        static let `default` = Config(maxMessagesPerWindow: 100, windowDuration: 60.0)

        /// Permissive: 200 messages per 60 seconds (for high-volume legitimate use)
        static let permissive = Config(maxMessagesPerWindow: 200, windowDuration: 60.0)

        /// Strict: 50 messages per 60 seconds (for high-security environments)
        static let strict = Config(maxMessagesPerWindow: 50, windowDuration: 60.0)
    }

    private let config: Config

    /// Tracks message timestamps per peer ID
    /// Key: Peer ID, Value: Array of message timestamps
    private var peerMessageHistory: [String: [Date]] = [:]

    /// Tracks number of times each peer has been rate-limited
    private var peerViolationCounts: [String: Int] = [:]

    /// Maximum violations before permanent block (optional)
    private let maxViolationsBeforeBlock: Int?

    /// Permanently blocked peers
    private var blockedPeers: Set<String> = []

    init(config: Config = .default, maxViolationsBeforeBlock: Int? = nil) {
        self.config = config
        self.maxViolationsBeforeBlock = maxViolationsBeforeBlock
    }

    // MARK: - Rate Limiting

    /// Check if a message from the peer should be allowed
    /// - Parameter peerID: The peer sending the message
    /// - Returns: true if message should be allowed, false if rate-limited
    func shouldAllowMessage(from peerID: String) -> Bool {
        // Check permanent block list
        if blockedPeers.contains(peerID) {
            #if DEBUG
            DebugLogger.warning("Blocked peer attempted message: \(peerID)", category: .security)
            #endif
            return false
        }

        let now = Date()

        // Get message history for this peer
        var history = peerMessageHistory[peerID] ?? []

        // Remove timestamps outside the sliding window
        let windowStart = now.addingTimeInterval(-config.windowDuration)
        history.removeAll { $0 < windowStart }

        // Check if peer has exceeded rate limit
        if history.count >= config.maxMessagesPerWindow {
            // Rate limit exceeded
            recordViolation(for: peerID)

            #if DEBUG
            DebugLogger.warning(
                "Rate limit exceeded for peer \(peerID): \(history.count) msgs in \(Int(config.windowDuration))s",
                category: .security
            )
            #endif

            return false
        }

        // Allow message and record timestamp
        history.append(now)
        peerMessageHistory[peerID] = history

        return true
    }

    /// Record a rate limit violation for a peer
    private func recordViolation(for peerID: String) {
        let count = (peerViolationCounts[peerID] ?? 0) + 1
        peerViolationCounts[peerID] = count

        // Check if peer should be permanently blocked
        if let maxViolations = maxViolationsBeforeBlock, count >= maxViolations {
            blockedPeers.insert(peerID)

            #if DEBUG
            DebugLogger.error(
                "Peer \(peerID) permanently blocked after \(count) violations",
                category: .security
            )
            #endif
        }
    }

    // MARK: - Management

    /// Manually block a peer
    func blockPeer(_ peerID: String) {
        blockedPeers.insert(peerID)
        #if DEBUG
        DebugLogger.log("Manually blocked peer: \(peerID)", category: .security)
        #endif
    }

    /// Manually unblock a peer
    func unblockPeer(_ peerID: String) {
        blockedPeers.remove(peerID)
        peerViolationCounts.removeValue(forKey: peerID)
        #if DEBUG
        DebugLogger.log("Unblocked peer: \(peerID)", category: .security)
        #endif
    }

    /// Check if a peer is blocked
    func isBlocked(_ peerID: String) -> Bool {
        return blockedPeers.contains(peerID)
    }

    /// Get current message count for a peer in the current window
    func currentMessageCount(for peerID: String) -> Int {
        guard let history = peerMessageHistory[peerID] else { return 0 }

        let now = Date()
        let windowStart = now.addingTimeInterval(-config.windowDuration)

        return history.filter { $0 >= windowStart }.count
    }

    /// Get violation count for a peer
    func violationCount(for peerID: String) -> Int {
        return peerViolationCounts[peerID] ?? 0
    }

    /// Clear history for a specific peer
    func clearHistory(for peerID: String) {
        peerMessageHistory.removeValue(forKey: peerID)
        peerViolationCounts.removeValue(forKey: peerID)
    }

    /// Clear all history and blocks (reset)
    func reset() {
        peerMessageHistory.removeAll()
        peerViolationCounts.removeAll()
        blockedPeers.removeAll()
    }

    // MARK: - Cleanup

    /// Remove old message history to prevent memory growth
    /// Call periodically (e.g., every 5 minutes)
    func cleanup() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-config.windowDuration * 2) // Keep 2x window for safety

        // Remove peers with no recent activity
        peerMessageHistory = peerMessageHistory.filter { _, history in
            !history.isEmpty && history.last! >= cutoff
        }

        #if DEBUG
        DebugLogger.log("Rate limiter cleanup: \(peerMessageHistory.count) active peers", category: .security)
        #endif
    }
}
