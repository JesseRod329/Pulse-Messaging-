//
//  MeshSimulator.swift
//  PulseTests
//
//  Main coordinator for mesh network simulation.
//

import Foundation
import Combine
@testable import Pulse

/// Main mesh network simulator
@MainActor
class MeshSimulator: ObservableObject {

    // Components
    @Published private(set) var topology: TopologyController
    @Published private(set) var chaos: ChaosEngine
    @Published private(set) var tracer: MessageFlowTracer

    // State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var elapsedTime: TimeInterval = 0

    // Transports for each peer
    private var transports: [String: MockMeshTransport] = [:]

    // Scheduled events
    private var scheduledEvents: [(TimeInterval, () async -> Void)] = []

    // Configuration
    private var config: SimulatorConfig = .standard

    init() {
        self.topology = TopologyController()
        self.chaos = ChaosEngine()
        self.tracer = MessageFlowTracer()
    }

    // MARK: - Setup

    /// Configure the simulator
    func configure(_ config: SimulatorConfig) {
        self.config = config
        self.chaos = ChaosEngine(config: config.chaos, topology: topology)
    }

    /// Add peers from a scenario
    func setupScenario(_ scenario: SimulatorScenario) {
        let peers = ScenarioBuilder.createPeers(for: scenario)
        topology.addPeers(peers)
        ScenarioBuilder.applyTopology(topology, for: scenario)

        // Create transports for each peer
        for peer in peers {
            let transport = MockMeshTransport(peerId: peer.id, simulator: self)
            transports[peer.id] = transport

            // Add connected peers to transport
            for connectedId in peer.connections {
                transport.addPeer(connectedId)
            }
        }
    }

    /// Add custom peers
    func addPeers(_ peers: [VirtualPeer]) {
        topology.addPeers(peers)
        for peer in peers {
            transports[peer.id] = MockMeshTransport(peerId: peer.id, simulator: self)
        }
    }

    // MARK: - Running

    /// Run a quick simulation
    func run(
        peers: Int,
        scenario: SimulatorScenario = .coffeeShop,
        duration: TimeInterval = 60
    ) async throws -> SimulatorReport {
        let config = SimulatorConfig(
            peerCount: peers,
            duration: duration,
            scenario: scenario,
            chaos: scenario.suggestedChaos,
            messageRate: scenario.suggestedMessageRate
        )
        return try await run(config: config)
    }

    /// Run with full configuration
    func run(config: SimulatorConfig) async throws -> SimulatorReport {
        // Reset state
        reset()
        self.config = config
        configure(config)

        // Setup peers
        if topology.peerCount == 0 {
            setupScenario(config.scenario)
        }

        // Ensure we have enough peers
        while topology.peerCount < config.peerCount {
            let peer = VirtualPeerFactory.createPeer()
            topology.addPeer(peer)
            transports[peer.id] = MockMeshTransport(peerId: peer.id, simulator: self)
        }

        // Apply topology if not set
        if topology.edgeCount == 0 {
            topology.apply(preset: config.scenario.suggestedTopology)
        }

        // Sync transport connections with topology
        syncTransportConnections()

        // Start simulation
        isRunning = true
        let startTime = Date()
        chaos.start(duration: config.duration)

        // Run simulation loop
        let tickInterval: TimeInterval = 0.1  // 100ms ticks
        var messageAccumulator: Double = 0

        while isRunning && elapsedTime < config.duration {
            // Process scheduled events
            await processScheduledEvents()

            // Apply chaos
            chaos.tick()

            // Generate messages based on rate
            messageAccumulator += config.messageRate * tickInterval
            while messageAccumulator >= 1 {
                messageAccumulator -= 1
                await generateRandomMessage()
            }

            // Update elapsed time
            elapsedTime = Date().timeIntervalSince(startTime)

            // Small delay to prevent CPU spinning
            try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
        }

        isRunning = false

        // Generate report
        return generateReport()
    }

    /// Stop the simulation
    func stop() {
        isRunning = false
    }

    /// Reset all state
    func reset() {
        topology = TopologyController()
        chaos = ChaosEngine()
        tracer = MessageFlowTracer()
        transports.removeAll()
        scheduledEvents.removeAll()
        elapsedTime = 0
        isRunning = false
    }

    // MARK: - Event Scheduling

    /// Schedule an event to run at a specific time
    func scheduleEvent(at time: TimeInterval, action: @escaping () async -> Void) {
        scheduledEvents.append((time, action))
        scheduledEvents.sort { $0.0 < $1.0 }
    }

    private func processScheduledEvents() async {
        while let first = scheduledEvents.first, first.0 <= elapsedTime {
            scheduledEvents.removeFirst()
            await first.1()
        }
    }

    // MARK: - Message Routing

    /// Route a packet through the simulated network
    func routePacket(_ packet: RoutablePacket, from senderId: String, to recipientId: String) async -> Bool {
        // Start tracing
        if config.tracingEnabled {
            tracer.startTrace(packet: packet)
        }

        // Apply chaos
        let chaosResult = await chaos.processPacket(packet)
        guard chaosResult.wasDelivered else {
            tracer.markDropped(messageId: packet.id, at: senderId, reason: "chaos_drop")
            return false
        }

        // Find path through network
        guard let path = topology.findPath(from: senderId, to: recipientId) else {
            tracer.markDropped(messageId: packet.id, at: senderId, reason: "no_route")
            return false
        }

        // Simulate packet traversing each hop
        var currentPacket = packet
        for (index, peerId) in path.enumerated() {
            guard let peer = topology.getPeer(peerId) else { continue }

            // Record hop
            let latency = peer.responseLatency()
            let isLastHop = index == path.count - 1
            tracer.recordHop(
                messageId: packet.id,
                peerId: peerId,
                latency: latency,
                wasRelayed: !isLastHop
            )

            // Check if peer accepts the packet
            if !peer.receive(currentPacket) {
                tracer.markDropped(messageId: packet.id, at: peerId, reason: "peer_rejected")
                return false
            }

            // Decrement TTL
            if !isLastHop {
                currentPacket = currentPacket.forwarded(by: peerId)
                if currentPacket.ttl <= 0 {
                    tracer.markDropped(messageId: packet.id, at: peerId, reason: "ttl_expired")
                    return false
                }
            }
        }

        // Success!
        tracer.markDelivered(messageId: packet.id)
        return true
    }

    /// Generate a random message between two peers
    private func generateRandomMessage() async {
        let peerIds = topology.peerIds
        guard peerIds.count >= 2 else { return }

        let senderId = peerIds.randomElement()!
        var recipientId = peerIds.randomElement()!
        while recipientId == senderId {
            recipientId = peerIds.randomElement()!
        }

        let packet = RoutablePacket(
            senderId: senderId,
            recipientId: recipientId,
            payload: "test message".data(using: .utf8)!,
            packetType: .message
        )

        _ = await routePacket(packet, from: senderId, to: recipientId)
    }

    // MARK: - Helpers

    private func syncTransportConnections() {
        for (peerId, transport) in transports {
            transport.reset()
            if let peer = topology.getPeer(peerId) {
                for connectedId in peer.connections {
                    transport.addPeer(connectedId)
                }
            }
        }
    }

    private func generateReport() -> SimulatorReport {
        let onlinePeers = topology.peers.values.filter { $0.isOnline }.count
        let offlinePeers = topology.peerCount - onlinePeers

        return SimulatorReport(
            timestamp: Date(),
            duration: elapsedTime,
            config: config,
            peerCount: topology.peerCount,
            peersOnline: onlinePeers,
            peersOffline: offlinePeers,
            messagesAttempted: tracer.messagesAttempted,
            messagesDelivered: tracer.messagesDelivered,
            deliveryRate: tracer.deliveryRate,
            directDeliveries: tracer.directDeliveries,
            relayedDeliveries: tracer.relayedDeliveries,
            averageHops: tracer.averageHops,
            maxHops: tracer.maxHops,
            droppedMessages: tracer.droppedMessages,
            duplicatesBlocked: tracer.duplicatesBlocked,
            routingFailures: tracer.droppedMessages,
            averageLatency: tracer.averageLatency,
            p50Latency: tracer.p50Latency,
            p95Latency: tracer.p95Latency,
            p99Latency: tracer.p99Latency,
            maxLatency: tracer.maxLatency,
            partitionsDetected: chaos.stats.partitionsCreated,
            peersLost: chaos.stats.peersKilled,
            peersRecovered: 0,
            networkDiameter: topology.networkDiameter(),
            averageDegree: topology.averageDegree,
            chaosStats: chaos.stats,
            bottlenecks: tracer.detectBottlenecks()
        )
    }
}

// MARK: - Convenience Extensions

extension MeshSimulator {

    /// Quick test with defaults
    static func quickTest(peers: Int = 10) async throws -> SimulatorReport {
        let simulator = MeshSimulator()
        return try await simulator.run(peers: peers, duration: 30)
    }

    /// Run a specific scenario
    static func runScenario(_ scenario: SimulatorScenario) async throws -> SimulatorReport {
        let simulator = MeshSimulator()
        let config = ScenarioBuilder.build(scenario)
        return try await simulator.run(config: config)
    }
}
