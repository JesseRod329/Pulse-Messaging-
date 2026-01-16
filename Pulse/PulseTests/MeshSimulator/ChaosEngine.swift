//
//  ChaosEngine.swift
//  PulseTests
//
//  Injects failures and chaos into mesh simulations.
//

import Foundation
import Combine
@testable import Pulse

/// Chaos intensity levels
enum ChaosLevel: String, CaseIterable {
    case none       // No chaos
    case low        // Minimal disruption
    case moderate   // Noticeable issues
    case high       // Severe disruption
    case extreme    // Near-total failure

    var packetLossRate: Double {
        switch self {
        case .none: return 0
        case .low: return 0.02
        case .moderate: return 0.08
        case .high: return 0.20
        case .extreme: return 0.50
        }
    }

    var latencyRange: ClosedRange<TimeInterval> {
        switch self {
        case .none: return 0.001...0.01
        case .low: return 0.01...0.05
        case .moderate: return 0.05...0.2
        case .high: return 0.1...0.5
        case .extreme: return 0.3...2.0
        }
    }

    var churnRate: Double {  // Disconnects per minute per peer
        switch self {
        case .none: return 0
        case .low: return 0.01
        case .moderate: return 0.05
        case .high: return 0.15
        case .extreme: return 0.40
        }
    }
}

/// Configuration for chaos behavior
struct ChaosConfig {
    var level: ChaosLevel = .moderate
    var packetLossRate: Double?       // Override level default
    var latencyRange: ClosedRange<TimeInterval>?
    var churnRate: Double?
    var batteryDeaths: Int = 0        // Number of sudden peer deaths
    var partitionEvents: Int = 0      // Number of network partitions
    var signalDegradation: Bool = false  // Gradual signal fade

    static let none = ChaosConfig(level: .none)
    static let low = ChaosConfig(level: .low)
    static let moderate = ChaosConfig(level: .moderate)
    static let high = ChaosConfig(level: .high, batteryDeaths: 2, partitionEvents: 1)
    static let extreme = ChaosConfig(level: .extreme, batteryDeaths: 5, partitionEvents: 3, signalDegradation: true)

    var effectivePacketLoss: Double {
        packetLossRate ?? level.packetLossRate
    }

    var effectiveLatency: ClosedRange<TimeInterval> {
        latencyRange ?? level.latencyRange
    }

    var effectiveChurnRate: Double {
        churnRate ?? level.churnRate
    }
}

/// Injects chaos into the mesh network
@MainActor
class ChaosEngine: ObservableObject {

    let config: ChaosConfig
    weak var topology: TopologyController?

    // Stats
    @Published private(set) var packetsDropped: Int = 0
    @Published private(set) var latencyInjected: Int = 0
    @Published private(set) var disconnectsTriggered: Int = 0
    @Published private(set) var peersKilled: Int = 0
    @Published private(set) var partitionsCreated: Int = 0

    // Scheduled events
    private var scheduledBatteryDeaths: [TimeInterval] = []
    private var scheduledPartitions: [TimeInterval] = []
    private var startTime: Date?

    init(config: ChaosConfig = .moderate, topology: TopologyController? = nil) {
        self.config = config
        self.topology = topology
    }

    // MARK: - Initialization

    func start(duration: TimeInterval) {
        startTime = Date()

        // Schedule battery deaths
        for _ in 0..<config.batteryDeaths {
            let time = TimeInterval.random(in: 0.1...0.9) * duration
            scheduledBatteryDeaths.append(time)
        }
        scheduledBatteryDeaths.sort()

        // Schedule partitions
        for _ in 0..<config.partitionEvents {
            let time = TimeInterval.random(in: 0.2...0.8) * duration
            scheduledPartitions.append(time)
        }
        scheduledPartitions.sort()
    }

    func reset() {
        packetsDropped = 0
        latencyInjected = 0
        disconnectsTriggered = 0
        peersKilled = 0
        partitionsCreated = 0
        scheduledBatteryDeaths.removeAll()
        scheduledPartitions.removeAll()
        startTime = nil
    }

    // MARK: - Packet Chaos

    /// Decide if a packet should be dropped
    func shouldDropPacket() -> Bool {
        let lossRate = config.effectivePacketLoss
        guard lossRate > 0 else { return false }

        if Double.random(in: 0...1) < lossRate {
            packetsDropped += 1
            return true
        }
        return false
    }

    /// Get latency to inject for a packet
    func injectLatency() -> TimeInterval {
        guard config.level != .none else { return 0 }

        latencyInjected += 1
        return TimeInterval.random(in: config.effectiveLatency)
    }

    /// Apply chaos to a packet delivery
    func processPacket(_ packet: RoutablePacket) async -> ChaosResult {
        // Check for packet loss
        if shouldDropPacket() {
            return .dropped
        }

        // Apply latency
        let delay = injectLatency()
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return .delivered(latency: delay)
    }

    // MARK: - Connection Chaos

    /// Check if random churn should disconnect a peer
    func shouldDisconnectPeer() -> Bool {
        guard config.effectiveChurnRate > 0 else { return false }

        // Convert per-minute rate to per-check probability
        // Assuming checks happen ~10 times per second
        let probability = config.effectiveChurnRate / 600

        if Double.random(in: 0...1) < probability {
            disconnectsTriggered += 1
            return true
        }
        return false
    }

    /// Trigger random peer disconnection
    func applyChurn() {
        guard let topology = topology else { return }

        for peer in topology.peers.values {
            if shouldDisconnectPeer() && peer.connections.count > 1 {
                // Disconnect from a random peer
                if let victim = peer.connections.randomElement() {
                    topology.disconnect(peer.id, from: victim)
                }
            }
        }
    }

    // MARK: - Scheduled Events

    /// Process scheduled events based on elapsed time
    func tick() {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)

        // Battery deaths
        while let nextDeath = scheduledBatteryDeaths.first, nextDeath <= elapsed {
            scheduledBatteryDeaths.removeFirst()
            killRandomPeer()
        }

        // Partitions
        while let nextPartition = scheduledPartitions.first, nextPartition <= elapsed {
            scheduledPartitions.removeFirst()
            createPartition()
        }

        // Apply random churn
        applyChurn()

        // Signal degradation
        if config.signalDegradation {
            degradeSignals(elapsed: elapsed)
        }
    }

    private func killRandomPeer() {
        guard let topology = topology else { return }

        if let victim = topology.peers.values.randomElement() {
            victim.isOnline = false
            topology.disconnectAll(victim.id)
            peersKilled += 1
        }
    }

    private func createPartition() {
        guard let topology = topology, !topology.isPartitioned else { return }

        topology.partition(into: 2)
        partitionsCreated += 1

        // Schedule reconnection after random delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000_000...5_000_000_000))
            await topology.reconnect()
        }
    }

    private func degradeSignals(elapsed: TimeInterval) {
        guard let topology = topology else { return }

        // Gradually move peers further apart (simulating signal fade)
        for peer in topology.peers.values {
            let drift = SimulatedPosition(
                x: Double.random(in: -0.5...0.5),
                y: Double.random(in: -0.5...0.5)
            )
            peer.position = SimulatedPosition(
                x: peer.position.x + drift.x,
                y: peer.position.y + drift.y
            )
        }
    }

    // MARK: - Statistics

    var stats: ChaosStats {
        ChaosStats(
            packetsDropped: packetsDropped,
            latencyInjected: latencyInjected,
            disconnectsTriggered: disconnectsTriggered,
            peersKilled: peersKilled,
            partitionsCreated: partitionsCreated,
            config: config
        )
    }
}

// MARK: - Types

enum ChaosResult {
    case delivered(latency: TimeInterval)
    case dropped
    case corrupted

    var wasDelivered: Bool {
        if case .delivered = self { return true }
        return false
    }
}

struct ChaosStats {
    let packetsDropped: Int
    let latencyInjected: Int
    let disconnectsTriggered: Int
    let peersKilled: Int
    let partitionsCreated: Int
    let config: ChaosConfig
}
