//
//  MessageFlowTracer.swift
//  PulseTests
//
//  Tracks message flow through the mesh network.
//

import Foundation
import Combine
@testable import Pulse

/// A traced message with full hop history
struct TracedMessage: Identifiable {
    let id: String
    let senderId: String
    let recipientId: String?
    let packetType: RoutablePacket.PacketType
    let sentAt: Date
    var deliveredAt: Date?
    var hops: [HopRecord] = []

    var wasDelivered: Bool { deliveredAt != nil }
    var hopCount: Int { hops.count }
    var totalLatency: TimeInterval? {
        guard let delivered = deliveredAt else { return nil }
        return delivered.timeIntervalSince(sentAt)
    }

    struct HopRecord {
        let peerId: String
        let arrivedAt: Date
        let latency: TimeInterval  // Time at this hop
        let wasRelayed: Bool       // Did this peer relay it?
    }
}

/// Statistics for a single peer's routing behavior
struct PeerRoutingStats {
    let peerId: String
    var messagesOriginated: Int = 0
    var messagesReceived: Int = 0
    var messagesRelayed: Int = 0
    var messagesDropped: Int = 0
    var totalLatencyAdded: TimeInterval = 0

    var relayRate: Double {
        guard messagesReceived > 0 else { return 0 }
        return Double(messagesRelayed) / Double(messagesReceived)
    }

    var averageLatency: TimeInterval {
        guard messagesRelayed > 0 else { return 0 }
        return totalLatencyAdded / Double(messagesRelayed)
    }
}

/// Tracks all message flows through the simulation
@MainActor
class MessageFlowTracer: ObservableObject {

    @Published private(set) var traces: [String: TracedMessage] = [:]
    @Published private(set) var peerStats: [String: PeerRoutingStats] = [:]

    // Aggregate stats
    private(set) var messagesAttempted: Int = 0
    private(set) var messagesDelivered: Int = 0
    private(set) var directDeliveries: Int = 0
    private(set) var relayedDeliveries: Int = 0
    private(set) var droppedMessages: Int = 0
    private(set) var duplicatesBlocked: Int = 0

    // Timing
    private(set) var totalLatency: TimeInterval = 0
    private(set) var maxLatency: TimeInterval = 0
    private(set) var latencies: [TimeInterval] = []

    // MARK: - Tracing

    /// Start tracing a new message
    func startTrace(packet: RoutablePacket) {
        messagesAttempted += 1

        let trace = TracedMessage(
            id: packet.id,
            senderId: packet.senderId,
            recipientId: packet.recipientId,
            packetType: packet.packetType,
            sentAt: packet.timestamp
        )
        traces[packet.id] = trace

        // Update sender stats
        ensurePeerStats(packet.senderId)
        peerStats[packet.senderId]?.messagesOriginated += 1
    }

    /// Record a hop in the message path
    func recordHop(
        messageId: String,
        peerId: String,
        latency: TimeInterval,
        wasRelayed: Bool
    ) {
        guard var trace = traces[messageId] else { return }

        let hop = TracedMessage.HopRecord(
            peerId: peerId,
            arrivedAt: Date(),
            latency: latency,
            wasRelayed: wasRelayed
        )
        trace.hops.append(hop)
        traces[messageId] = trace

        // Update peer stats
        ensurePeerStats(peerId)
        peerStats[peerId]?.messagesReceived += 1
        if wasRelayed {
            peerStats[peerId]?.messagesRelayed += 1
            peerStats[peerId]?.totalLatencyAdded += latency
        }
    }

    /// Mark a message as delivered
    func markDelivered(messageId: String) {
        guard var trace = traces[messageId] else { return }

        trace.deliveredAt = Date()
        traces[messageId] = trace

        messagesDelivered += 1

        if trace.hopCount <= 1 {
            directDeliveries += 1
        } else {
            relayedDeliveries += 1
        }

        if let latency = trace.totalLatency {
            totalLatency += latency
            maxLatency = max(maxLatency, latency)
            latencies.append(latency)
        }
    }

    /// Mark a message as dropped
    func markDropped(messageId: String, at peerId: String, reason: String) {
        droppedMessages += 1

        ensurePeerStats(peerId)
        peerStats[peerId]?.messagesDropped += 1
    }

    /// Record a duplicate being blocked
    func recordDuplicateBlocked(messageId: String) {
        duplicatesBlocked += 1
    }

    // MARK: - Analysis

    var deliveryRate: Double {
        guard messagesAttempted > 0 else { return 0 }
        return Double(messagesDelivered) / Double(messagesAttempted)
    }

    var averageHops: Double {
        let delivered = traces.values.filter { $0.wasDelivered }
        guard !delivered.isEmpty else { return 0 }
        return Double(delivered.reduce(0) { $0 + $1.hopCount }) / Double(delivered.count)
    }

    var maxHops: Int {
        traces.values.map { $0.hopCount }.max() ?? 0
    }

    var averageLatency: TimeInterval {
        guard !latencies.isEmpty else { return 0 }
        return totalLatency / Double(latencies.count)
    }

    var p50Latency: TimeInterval {
        percentileLatency(0.50)
    }

    var p95Latency: TimeInterval {
        percentileLatency(0.95)
    }

    var p99Latency: TimeInterval {
        percentileLatency(0.99)
    }

    private func percentileLatency(_ percentile: Double) -> TimeInterval {
        guard !latencies.isEmpty else { return 0 }
        let sorted = latencies.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }

    // MARK: - Bottleneck Detection

    struct Bottleneck {
        let peerId: String
        let type: BottleneckType
        let severity: Double  // 0-1
        let description: String

        enum BottleneckType: String {
            case hubOverload      // Too many messages through one peer
            case highDropRate     // Peer dropping many messages
            case highLatency      // Peer adding significant delays
            case lowRelayRate     // Peer not forwarding messages
        }
    }

    func detectBottlenecks() -> [Bottleneck] {
        var bottlenecks: [Bottleneck] = []

        let avgReceived = peerStats.values.map { $0.messagesReceived }.reduce(0, +) / max(peerStats.count, 1)

        for (peerId, stats) in peerStats {
            // Hub overload: receives 3x+ average
            if stats.messagesReceived > avgReceived * 3 {
                let severity = min(1.0, Double(stats.messagesReceived) / Double(avgReceived * 5))
                bottlenecks.append(Bottleneck(
                    peerId: peerId,
                    type: .hubOverload,
                    severity: severity,
                    description: "Peer handling \(stats.messagesReceived) messages (avg: \(avgReceived))"
                ))
            }

            // High drop rate: > 10% dropped
            let dropRate = Double(stats.messagesDropped) / max(Double(stats.messagesReceived), 1)
            if dropRate > 0.1 {
                bottlenecks.append(Bottleneck(
                    peerId: peerId,
                    type: .highDropRate,
                    severity: min(1.0, dropRate),
                    description: "Drop rate: \(Int(dropRate * 100))%"
                ))
            }

            // High latency: > 200ms average
            if stats.averageLatency > 0.2 {
                let severity = min(1.0, stats.averageLatency / 0.5)
                bottlenecks.append(Bottleneck(
                    peerId: peerId,
                    type: .highLatency,
                    severity: severity,
                    description: "Avg latency: \(Int(stats.averageLatency * 1000))ms"
                ))
            }

            // Low relay rate: < 50% when expected to relay
            if stats.messagesReceived > 5 && stats.relayRate < 0.5 {
                bottlenecks.append(Bottleneck(
                    peerId: peerId,
                    type: .lowRelayRate,
                    severity: 1.0 - stats.relayRate,
                    description: "Relay rate: \(Int(stats.relayRate * 100))%"
                ))
            }
        }

        return bottlenecks.sorted { $0.severity > $1.severity }
    }

    // MARK: - Helpers

    private func ensurePeerStats(_ peerId: String) {
        if peerStats[peerId] == nil {
            peerStats[peerId] = PeerRoutingStats(peerId: peerId)
        }
    }

    func reset() {
        traces.removeAll()
        peerStats.removeAll()
        messagesAttempted = 0
        messagesDelivered = 0
        directDeliveries = 0
        relayedDeliveries = 0
        droppedMessages = 0
        duplicatesBlocked = 0
        totalLatency = 0
        maxLatency = 0
        latencies.removeAll()
    }
}
