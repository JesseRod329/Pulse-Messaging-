//
//  MockMeshTransport.swift
//  PulseTests
//
//  Mock transport implementing TransportProtocol for simulation.
//

import Foundation
@testable import Pulse

/// Mock mesh transport for simulation - replaces real MultipeerConnectivity
@MainActor
class MockMeshTransport: TransportProtocol {
    let transportType: TransportType = .mesh

    private(set) var isConnected: Bool = false

    // Callbacks
    var onPacketReceived: ((RoutablePacket) -> Void)?
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)?
    var onPeerLost: ((String) -> Void)?

    // Simulation components
    weak var simulator: MeshSimulator?
    private let peerId: String
    private var connectedPeers: Set<String> = []

    // Stats
    private(set) var packetsSent: Int = 0
    private(set) var packetsReceived: Int = 0
    private(set) var packetsFailed: Int = 0

    init(peerId: String, simulator: MeshSimulator? = nil) {
        self.peerId = peerId
        self.simulator = simulator
    }

    // MARK: - TransportProtocol

    func connect() async throws {
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        connectedPeers.removeAll()
    }

    func send(_ packet: RoutablePacket, to recipient: String) async throws {
        guard isConnected else {
            packetsFailed += 1
            throw MockTransportError.notConnected
        }

        guard connectedPeers.contains(recipient) else {
            packetsFailed += 1
            throw MockTransportError.peerNotConnected(recipient)
        }

        // Route through simulator
        if let sim = simulator {
            let success = await sim.routePacket(packet, from: peerId, to: recipient)
            if success {
                packetsSent += 1
            } else {
                packetsFailed += 1
                throw MockTransportError.deliveryFailed
            }
        } else {
            packetsSent += 1
        }
    }

    func broadcast(_ packet: RoutablePacket) async throws {
        guard isConnected else {
            throw MockTransportError.notConnected
        }

        for peer in connectedPeers {
            try? await send(packet, to: peer)
        }
    }

    // MARK: - Simulation Interface

    func addPeer(_ peerId: String) {
        connectedPeers.insert(peerId)
    }

    func removePeer(_ peerId: String) {
        connectedPeers.remove(peerId)
    }

    func simulatePacketReceived(_ packet: RoutablePacket) {
        packetsReceived += 1
        onPacketReceived?(packet)
    }

    func simulatePeerDiscovered(_ peer: DiscoveredPeer) {
        connectedPeers.insert(peer.id)
        onPeerDiscovered?(peer)
    }

    func simulatePeerLost(_ peerId: String) {
        connectedPeers.remove(peerId)
        onPeerLost?(peerId)
    }

    var connectedPeerIds: Set<String> {
        connectedPeers
    }

    func reset() {
        packetsSent = 0
        packetsReceived = 0
        packetsFailed = 0
        connectedPeers.removeAll()
    }
}

// MARK: - Errors

enum MockTransportError: Error, LocalizedError {
    case notConnected
    case peerNotConnected(String)
    case deliveryFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Transport not connected"
        case .peerNotConnected(let id):
            return "Peer \(id) not connected"
        case .deliveryFailed:
            return "Packet delivery failed"
        case .timeout:
            return "Operation timed out"
        }
    }
}
