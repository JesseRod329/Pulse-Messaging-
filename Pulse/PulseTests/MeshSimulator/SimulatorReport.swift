//
//  SimulatorReport.swift
//  PulseTests
//
//  Generates human-readable simulation reports.
//

import Foundation

/// Complete simulation report
struct SimulatorReport {
    let timestamp: Date
    let duration: TimeInterval
    let config: SimulatorConfig

    // Peer metrics
    let peerCount: Int
    let peersOnline: Int
    let peersOffline: Int

    // Delivery metrics
    let messagesAttempted: Int
    let messagesDelivered: Int
    let deliveryRate: Double

    // Routing metrics
    let directDeliveries: Int
    let relayedDeliveries: Int
    let averageHops: Double
    let maxHops: Int

    // Failure analysis
    let droppedMessages: Int
    let duplicatesBlocked: Int
    let routingFailures: Int

    // Performance
    let averageLatency: TimeInterval
    let p50Latency: TimeInterval
    let p95Latency: TimeInterval
    let p99Latency: TimeInterval
    let maxLatency: TimeInterval

    // Network health
    let partitionsDetected: Int
    let peersLost: Int
    let peersRecovered: Int
    let networkDiameter: Int
    let averageDegree: Double

    // Chaos stats
    let chaosStats: ChaosStats?

    // Bottlenecks
    let bottlenecks: [MessageFlowTracer.Bottleneck]

    // MARK: - Summary Generation

    var summary: String {
        var lines: [String] = []

        lines.append("═══════════════════════════════════════════════════════")
        lines.append("                  MESH SIMULATION REPORT                ")
        lines.append("═══════════════════════════════════════════════════════")
        lines.append("")

        // Overview
        lines.append("OVERVIEW")
        lines.append("────────────────────────────────────────────────────────")
        lines.append("Duration:        \(formatDuration(duration))")
        lines.append("Peers:           \(peerCount) (\(peersOnline) online, \(peersOffline) offline)")
        lines.append("Scenario:        \(config.scenario.rawValue)")
        lines.append("Chaos Level:     \(config.chaos.level.rawValue)")
        lines.append("")

        // Delivery
        lines.append("MESSAGE DELIVERY")
        lines.append("────────────────────────────────────────────────────────")
        lines.append("Attempted:       \(messagesAttempted)")
        lines.append("Delivered:       \(messagesDelivered)")
        lines.append("Delivery Rate:   \(formatPercent(deliveryRate)) \(deliveryRateIndicator)")
        lines.append("  Direct (1-hop):\(directDeliveries)")
        lines.append("  Relayed (2+):  \(relayedDeliveries)")
        lines.append("")

        // Routing
        lines.append("ROUTING")
        lines.append("────────────────────────────────────────────────────────")
        lines.append("Avg Hops:        \(String(format: "%.1f", averageHops)) \(hopsIndicator)")
        lines.append("Max Hops:        \(maxHops)")
        lines.append("Dropped:         \(droppedMessages)")
        lines.append("Duplicates:      \(duplicatesBlocked)")
        lines.append("")

        // Latency
        lines.append("LATENCY")
        lines.append("────────────────────────────────────────────────────────")
        lines.append("Average:         \(formatLatency(averageLatency)) \(latencyIndicator)")
        lines.append("P50:             \(formatLatency(p50Latency))")
        lines.append("P95:             \(formatLatency(p95Latency))")
        lines.append("P99:             \(formatLatency(p99Latency))")
        lines.append("Max:             \(formatLatency(maxLatency))")
        lines.append("")

        // Network
        lines.append("NETWORK HEALTH")
        lines.append("────────────────────────────────────────────────────────")
        lines.append("Diameter:        \(networkDiameter)")
        lines.append("Avg Connections: \(String(format: "%.1f", averageDegree))")
        lines.append("Partitions:      \(partitionsDetected)")
        lines.append("Peers Lost:      \(peersLost)")
        lines.append("Recovered:       \(peersRecovered)")
        lines.append("")

        // Chaos
        if let chaos = chaosStats, chaos.config.level != .none {
            lines.append("CHAOS EFFECTS")
            lines.append("────────────────────────────────────────────────────────")
            lines.append("Packets Dropped: \(chaos.packetsDropped)")
            lines.append("Disconnects:     \(chaos.disconnectsTriggered)")
            lines.append("Peers Killed:    \(chaos.peersKilled)")
            lines.append("Partitions:      \(chaos.partitionsCreated)")
            lines.append("")
        }

        // Bottlenecks
        if !bottlenecks.isEmpty {
            lines.append("BOTTLENECKS DETECTED")
            lines.append("────────────────────────────────────────────────────────")
            for (i, bottleneck) in bottlenecks.prefix(5).enumerated() {
                let severity = bottleneck.severity > 0.7 ? "🔴" : bottleneck.severity > 0.4 ? "🟡" : "🟢"
                lines.append("\(i + 1). \(severity) [\(bottleneck.type.rawValue)]")
                lines.append("   Peer: \(bottleneck.peerId.prefix(8))...")
                lines.append("   \(bottleneck.description)")
            }
            lines.append("")
        }

        // Verdict
        lines.append("═══════════════════════════════════════════════════════")
        lines.append("VERDICT: \(verdict)")
        lines.append("═══════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }

    // MARK: - Indicators

    private var deliveryRateIndicator: String {
        if deliveryRate >= 0.99 { return "✅ Excellent" }
        if deliveryRate >= 0.95 { return "✅ Good" }
        if deliveryRate >= 0.90 { return "⚠️ Warning" }
        return "❌ Critical"
    }

    private var hopsIndicator: String {
        if averageHops < 2 { return "✅" }
        if averageHops < 4 { return "⚠️" }
        return "❌"
    }

    private var latencyIndicator: String {
        if averageLatency < 0.1 { return "✅" }
        if averageLatency < 0.3 { return "⚠️" }
        return "❌"
    }

    private var verdict: String {
        var score = 0

        if deliveryRate >= 0.99 { score += 3 }
        else if deliveryRate >= 0.95 { score += 2 }
        else if deliveryRate >= 0.90 { score += 1 }

        if averageHops < 2 { score += 2 }
        else if averageHops < 4 { score += 1 }

        if averageLatency < 0.1 { score += 2 }
        else if averageLatency < 0.3 { score += 1 }

        if bottlenecks.isEmpty { score += 1 }

        if score >= 7 { return "🎉 EXCELLENT - Network performing optimally" }
        if score >= 5 { return "✅ GOOD - Network healthy with minor issues" }
        if score >= 3 { return "⚠️ WARNING - Network degraded, review bottlenecks" }
        return "❌ CRITICAL - Network failing, immediate action needed"
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func formatLatency(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.2fms", seconds * 1000)
        }
        return String(format: "%.0fms", seconds * 1000)
    }
}

/// Configuration for a simulation run
struct SimulatorConfig {
    var peerCount: Int = 20
    var duration: TimeInterval = 60
    var scenario: SimulatorScenario = .coffeeShop
    var chaos: ChaosConfig = .moderate
    var messageRate: Double = 10  // Messages per second
    var tracingEnabled: Bool = true

    static let quick = SimulatorConfig(peerCount: 10, duration: 30, chaos: .low)
    static let standard = SimulatorConfig(peerCount: 20, duration: 60, chaos: .moderate)
    static let stress = SimulatorConfig(peerCount: 100, duration: 300, chaos: .high)
}
