//
//  VirtualPeer.swift
//  PulseTests
//
//  Synthetic peer for mesh network simulation.
//

import Foundation
import Combine
@testable import Pulse

/// Behavior pattern for a virtual peer
enum PeerBehavior: String, CaseIterable {
    case responsive      // Replies quickly, reliable
    case slow            // High latency responses
    case unreliable      // Drops packets randomly
    case intermittent    // Goes offline periodically
    case malicious       // Sends invalid/duplicate packets
}

/// Simulated position for distance calculation
struct SimulatedPosition {
    var x: Double  // meters from origin
    var y: Double

    static let origin = SimulatedPosition(x: 0, y: 0)

    func distance(to other: SimulatedPosition) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Generate random position within radius
    static func random(maxRadius: Double) -> SimulatedPosition {
        let angle = Double.random(in: 0..<(2 * .pi))
        let radius = Double.random(in: 0..<maxRadius)
        return SimulatedPosition(
            x: radius * cos(angle),
            y: radius * sin(angle)
        )
    }
}

/// A synthetic peer in the mesh simulation
@MainActor
class VirtualPeer: Identifiable, ObservableObject {
    let id: String
    let identity: PulseIdentity

    @Published var status: PeerStatus
    @Published var connections: Set<String>  // Connected peer IDs
    @Published var position: SimulatedPosition
    @Published var isOnline: Bool

    let behavior: PeerBehavior
    let techStack: [String]

    // Simulation state
    var messagesSent: Int = 0
    var messagesReceived: Int = 0
    var messagesDropped: Int = 0
    var lastSeen: Date = Date()

    // Inbox for received packets
    private(set) var inbox: [RoutablePacket] = []

    var handle: String { identity.handle }
    var publicKey: Data { identity.publicKey }
    var signingPublicKey: Data { identity.signingPublicKey }

    init(
        id: String = UUID().uuidString,
        handle: String,
        status: PeerStatus = .active,
        position: SimulatedPosition = .origin,
        behavior: PeerBehavior = .responsive,
        techStack: [String] = []
    ) {
        self.id = id
        self.identity = PulseIdentity.create(handle: handle)
        self.status = status
        self.connections = []
        self.position = position
        self.isOnline = true
        self.behavior = behavior
        self.techStack = techStack
    }

    // MARK: - Connection Management

    func connect(to peerId: String) {
        connections.insert(peerId)
    }

    func disconnect(from peerId: String) {
        connections.remove(peerId)
    }

    func disconnectAll() {
        connections.removeAll()
    }

    var isConnected: Bool {
        !connections.isEmpty && isOnline
    }

    // MARK: - Message Handling

    /// Receive a packet (subject to behavior rules)
    func receive(_ packet: RoutablePacket) -> Bool {
        guard isOnline else {
            messagesDropped += 1
            return false
        }

        // Apply behavior-based packet loss
        switch behavior {
        case .unreliable:
            if Double.random(in: 0...1) < 0.2 {
                messagesDropped += 1
                return false
            }
        case .intermittent:
            if Double.random(in: 0...1) < 0.1 {
                messagesDropped += 1
                return false
            }
        case .malicious:
            // Malicious peers accept but may cause issues later
            break
        default:
            break
        }

        inbox.append(packet)
        messagesReceived += 1
        lastSeen = Date()
        return true
    }

    /// Get latency for this peer based on behavior
    func responseLatency() -> TimeInterval {
        switch behavior {
        case .responsive:
            return Double.random(in: 0.01...0.05)
        case .slow:
            return Double.random(in: 0.2...0.8)
        case .unreliable:
            return Double.random(in: 0.05...0.3)
        case .intermittent:
            return Double.random(in: 0.02...0.1)
        case .malicious:
            return Double.random(in: 0.001...0.01)
        }
    }

    /// Clear inbox
    func clearInbox() {
        inbox.removeAll()
    }

    // MARK: - Conversion

    func toPulsePeer(relativeTo observer: SimulatedPosition = .origin) -> PulsePeer {
        PulsePeer(
            id: id,
            handle: handle,
            status: status,
            place: nil,
            techStack: techStack,
            distance: position.distance(to: observer),
            publicKey: publicKey,
            signingPublicKey: signingPublicKey,
            lastSeen: lastSeen
        )
    }

    func toDiscoveredPeer(hopCount: Int = 0, transport: TransportType = .mesh) -> DiscoveredPeer {
        DiscoveredPeer(
            id: id,
            handle: handle,
            publicKey: publicKey,
            signingPublicKey: signingPublicKey,
            status: status.rawValue,
            techStack: techStack,
            distance: nil,
            lastSeen: lastSeen,
            hopCount: hopCount,
            viaTransport: transport,
            geohash: nil
        )
    }
}

// MARK: - Equatable & Hashable

extension VirtualPeer: Equatable {
    static func == (lhs: VirtualPeer, rhs: VirtualPeer) -> Bool {
        lhs.id == rhs.id
    }
}

extension VirtualPeer: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
