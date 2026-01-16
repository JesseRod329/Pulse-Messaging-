//
//  MeshSimulatorTests.swift
//  PulseTests
//
//  Tests for the mesh network simulator.
//

import XCTest
@testable import Pulse

@MainActor
final class MeshSimulatorTests: XCTestCase {

    // MARK: - Virtual Peer Tests

    func testVirtualPeerCreation() async throws {
        let peer = VirtualPeerFactory.createPeer(handle: "test_dev")

        XCTAssertFalse(peer.id.isEmpty)
        XCTAssertEqual(peer.handle, "test_dev")
        XCTAssertTrue(peer.isOnline)
        XCTAssertTrue(peer.connections.isEmpty)
        XCTAssertNotNil(peer.identity)
    }

    func testVirtualPeerConnections() async throws {
        let peer1 = VirtualPeerFactory.createPeer(handle: "peer1")
        let peer2 = VirtualPeerFactory.createPeer(handle: "peer2")

        peer1.connect(to: peer2.id)

        XCTAssertTrue(peer1.connections.contains(peer2.id))
        XCTAssertFalse(peer2.connections.contains(peer1.id))  // One-way initially

        peer1.disconnect(from: peer2.id)
        XCTAssertFalse(peer1.connections.contains(peer2.id))
    }

    func testVirtualPeerFactory() async throws {
        let peers = VirtualPeerFactory.createPeers(count: 10)

        XCTAssertEqual(peers.count, 10)

        // All should have unique IDs
        let uniqueIds = Set(peers.map { $0.id })
        XCTAssertEqual(uniqueIds.count, 10)

        // All should have handles
        for peer in peers {
            XCTAssertFalse(peer.handle.isEmpty)
        }
    }

    func testPeerBehaviorDistribution() async throws {
        let peers = VirtualPeerFactory.createWithBehaviors(
            responsive: 5,
            slow: 3,
            unreliable: 2
        )

        XCTAssertEqual(peers.count, 10)

        let responsive = peers.filter { $0.behavior == .responsive }.count
        let slow = peers.filter { $0.behavior == .slow }.count
        let unreliable = peers.filter { $0.behavior == .unreliable }.count

        XCTAssertEqual(responsive, 5)
        XCTAssertEqual(slow, 3)
        XCTAssertEqual(unreliable, 2)
    }

    // MARK: - Topology Tests

    func testTopologyMesh() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 5)
        topology.addPeers(peers)

        topology.apply(preset: .mesh)

        // Full mesh: n*(n-1)/2 edges
        XCTAssertEqual(topology.edgeCount, 10)

        // All peers should be connected to all others
        for peer in peers {
            XCTAssertEqual(peer.connections.count, 4)
        }
    }

    func testTopologyChain() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 5)
        topology.addPeers(peers)

        topology.apply(preset: .chain)

        // Chain: n-1 edges
        XCTAssertEqual(topology.edgeCount, 4)
    }

    func testTopologyStar() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 5)
        topology.addPeers(peers)

        let peerIds = topology.peerIds
        topology.createStar(hub: peerIds[0], spokes: Array(peerIds.dropFirst()))

        // Star: n-1 edges from hub
        XCTAssertEqual(topology.edgeCount, 4)

        // Hub should have 4 connections
        XCTAssertEqual(topology.getPeer(peerIds[0])?.connections.count, 4)
    }

    func testTopologyPartition() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 10)
        topology.addPeers(peers)
        topology.apply(preset: .mesh)

        // Partition into 2 clusters
        topology.partition(into: 2)

        XCTAssertTrue(topology.isPartitioned)

        // Should have 2 connected components
        let components = topology.connectedComponents()
        XCTAssertEqual(components.count, 2)
    }

    func testTopologyReconnect() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 10)
        topology.addPeers(peers)
        topology.apply(preset: .mesh)

        topology.partition(into: 2)
        XCTAssertEqual(topology.connectedComponents().count, 2)

        topology.reconnect()
        XCTAssertEqual(topology.connectedComponents().count, 1)
    }

    func testPathFinding() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 5)
        topology.addPeers(peers)

        let ids = topology.peerIds
        topology.createChain(ids)

        // Path from first to last should go through all
        let path = topology.findPath(from: ids[0], to: ids[4])
        XCTAssertNotNil(path)
        XCTAssertEqual(path?.count, 5)
    }

    // MARK: - Chaos Engine Tests

    func testChaosNone() async throws {
        let chaos = ChaosEngine(config: .none)

        // Should never drop packets
        for _ in 0..<100 {
            XCTAssertFalse(chaos.shouldDropPacket())
        }
    }

    func testChaosPacketLoss() async throws {
        let config = ChaosConfig(level: .none, packetLossRate: 1.0)
        let chaos = ChaosEngine(config: config)

        // Should always drop packets
        XCTAssertTrue(chaos.shouldDropPacket())
    }

    func testChaosLatency() async throws {
        let chaos = ChaosEngine(config: .moderate)

        let latency = chaos.injectLatency()

        XCTAssertGreaterThan(latency, 0)
        XCTAssertLessThan(latency, 1.0)
    }

    // MARK: - Message Tracing Tests

    func testMessageTracing() async throws {
        let tracer = MessageFlowTracer()

        let packet = RoutablePacket(
            senderId: "sender",
            recipientId: "recipient",
            payload: Data(),
            packetType: .message
        )

        tracer.startTrace(packet: packet)
        XCTAssertEqual(tracer.messagesAttempted, 1)

        tracer.recordHop(messageId: packet.id, peerId: "relay1", latency: 0.05, wasRelayed: true)
        tracer.recordHop(messageId: packet.id, peerId: "recipient", latency: 0.02, wasRelayed: false)

        tracer.markDelivered(messageId: packet.id)

        XCTAssertEqual(tracer.messagesDelivered, 1)
        XCTAssertEqual(tracer.deliveryRate, 1.0)
    }

    func testBottleneckDetection() async throws {
        let tracer = MessageFlowTracer()

        // Simulate one peer handling many messages (hub overload)
        for i in 0..<100 {
            let packet = RoutablePacket(
                senderId: "sender\(i % 10)",
                recipientId: "recipient",
                payload: Data(),
                packetType: .message
            )
            tracer.startTrace(packet: packet)
            tracer.recordHop(messageId: packet.id, peerId: "hub", latency: 0.1, wasRelayed: true)
            tracer.recordHop(messageId: packet.id, peerId: "recipient", latency: 0.02, wasRelayed: false)
            tracer.markDelivered(messageId: packet.id)
        }

        let bottlenecks = tracer.detectBottlenecks()
        XCTAssertFalse(bottlenecks.isEmpty)

        // Hub should be detected as overloaded
        let hubBottleneck = bottlenecks.first { $0.peerId == "hub" }
        XCTAssertNotNil(hubBottleneck)
    }

    // MARK: - Full Simulation Tests

    func testQuickSimulation() async throws {
        let simulator = MeshSimulator()
        let report = try await simulator.run(peers: 5, scenario: .coffeeShop, duration: 5)

        XCTAssertEqual(report.peerCount, 5)
        XCTAssertGreaterThan(report.messagesAttempted, 0)
        XCTAssertGreaterThanOrEqual(report.deliveryRate, 0)
        XCTAssertLessThanOrEqual(report.deliveryRate, 1.0)
    }

    func testSimulationWithChaos() async throws {
        let config = SimulatorConfig(
            peerCount: 10,
            duration: 5,
            scenario: .coffeeShop,
            chaos: .moderate,
            messageRate: 20
        )

        let simulator = MeshSimulator()
        let report = try await simulator.run(config: config)

        // With chaos, we expect some dropped messages
        XCTAssertGreaterThan(report.messagesAttempted, 0)

        // Report should include chaos stats
        XCTAssertNotNil(report.chaosStats)
    }

    func testSimulationReport() async throws {
        let simulator = MeshSimulator()
        let report = try await simulator.run(peers: 10, duration: 3)

        // Test report summary generation
        let summary = report.summary
        XCTAssertTrue(summary.contains("MESH SIMULATION REPORT"))
        XCTAssertTrue(summary.contains("VERDICT"))
    }

    func testScenarioConfigs() async throws {
        // Test that all scenarios can be built
        for scenario in SimulatorScenario.allCases {
            let config = ScenarioBuilder.build(scenario)
            XCTAssertGreaterThan(config.peerCount, 0)
            XCTAssertGreaterThan(config.duration, 0)
        }
    }

    // MARK: - Scenario Tests

    func testCoffeeShopScenario() async throws {
        let peers = VirtualPeerFactory.coffeeShopScenario()
        XCTAssertGreaterThanOrEqual(peers.count, 5)
        XCTAssertLessThanOrEqual(peers.count, 15)
    }

    func testConferenceScenario() async throws {
        let peers = VirtualPeerFactory.conferenceScenario()
        XCTAssertGreaterThan(peers.count, 30)
    }

    func testHackathonScenario() async throws {
        let peers = VirtualPeerFactory.hackathonScenario()
        XCTAssertGreaterThan(peers.count, 10)
    }

    // MARK: - Performance Tests

    func testSimulatorPerformance() async throws {
        let simulator = MeshSimulator()
        let start = Date()
        _ = try await simulator.run(peers: 20, duration: 2)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 10)
    }

    func testTopologyScaling() async throws {
        let topology = TopologyController()
        let peers = VirtualPeerFactory.createPeers(count: 100)

        measure {
            topology.addPeers(peers)
            topology.apply(preset: .mesh)
            _ = topology.networkDiameter()
            topology.clearConnections()
        }
    }
}
