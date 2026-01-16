//
//  TopologyController.swift
//  PulseTests
//
//  Controls network topology for mesh simulation.
//

import Foundation
import Combine
@testable import Pulse

/// Network topology presets
enum TopologyPreset: String, CaseIterable {
    case star       // All peers connect to central hub
    case mesh       // Fully connected graph
    case chain      // Linear A -> B -> C -> D
    case ring       // Circular chain
    case partition  // Two disconnected clusters
    case tree       // Hierarchical tree structure
    case random     // Random connections
}

/// Manages peer connections and network shape
@MainActor
class TopologyController: ObservableObject {

    @Published private(set) var peers: [String: VirtualPeer] = [:]
    @Published private(set) var edges: Set<Edge> = []

    struct Edge: Hashable {
        let from: String
        let to: String

        // Edges are undirected
        func hash(into hasher: inout Hasher) {
            let sorted = [from, to].sorted()
            hasher.combine(sorted[0])
            hasher.combine(sorted[1])
        }

        static func == (lhs: Edge, rhs: Edge) -> Bool {
            let lhsSorted = [lhs.from, lhs.to].sorted()
            let rhsSorted = [rhs.from, rhs.to].sorted()
            return lhsSorted == rhsSorted
        }
    }

    // Partition tracking
    private var partitions: [[String]] = []
    var isPartitioned: Bool { partitions.count > 1 }

    // MARK: - Peer Management

    func addPeer(_ peer: VirtualPeer) {
        peers[peer.id] = peer
    }

    func addPeers(_ newPeers: [VirtualPeer]) {
        for peer in newPeers {
            addPeer(peer)
        }
    }

    func removePeer(_ peerId: String) {
        peers.removeValue(forKey: peerId)
        // Remove all edges involving this peer
        edges = edges.filter { $0.from != peerId && $0.to != peerId }
        // Update other peers' connections
        for (id, peer) in peers {
            peer.disconnect(from: peerId)
        }
    }

    func getPeer(_ id: String) -> VirtualPeer? {
        peers[id]
    }

    var peerIds: [String] {
        Array(peers.keys)
    }

    var peerCount: Int {
        peers.count
    }

    // MARK: - Connection Management

    func connect(_ peer1: String, to peer2: String) {
        guard let p1 = peers[peer1], let p2 = peers[peer2] else { return }

        edges.insert(Edge(from: peer1, to: peer2))
        p1.connect(to: peer2)
        p2.connect(to: peer1)
    }

    func disconnect(_ peer1: String, from peer2: String) {
        edges.remove(Edge(from: peer1, to: peer2))
        peers[peer1]?.disconnect(from: peer2)
        peers[peer2]?.disconnect(from: peer1)
    }

    func disconnectAll(_ peerId: String) {
        guard let peer = peers[peerId] else { return }
        for connectedId in peer.connections {
            disconnect(peerId, from: connectedId)
        }
    }

    func areConnected(_ peer1: String, _ peer2: String) -> Bool {
        edges.contains(Edge(from: peer1, to: peer2))
    }

    func neighbors(of peerId: String) -> [String] {
        peers[peerId]?.connections.map { $0 } ?? []
    }

    // MARK: - Topology Presets

    func apply(preset: TopologyPreset) {
        // Clear existing connections
        clearConnections()

        let ids = Array(peers.keys)
        guard ids.count >= 2 else { return }

        switch preset {
        case .star:
            createStar(hub: ids[0], spokes: Array(ids.dropFirst()))

        case .mesh:
            createFullMesh(ids)

        case .chain:
            createChain(ids)

        case .ring:
            createRing(ids)

        case .partition:
            let mid = ids.count / 2
            let cluster1 = Array(ids.prefix(mid))
            let cluster2 = Array(ids.suffix(from: mid))
            createFullMesh(cluster1)
            createFullMesh(cluster2)
            partitions = [cluster1, cluster2]

        case .tree:
            createTree(ids)

        case .random:
            createRandom(ids, density: 0.3)
        }
    }

    // MARK: - Topology Builders

    func createStar(hub: String, spokes: [String]) {
        for spoke in spokes {
            connect(hub, to: spoke)
        }
    }

    func createFullMesh(_ ids: [String]) {
        for i in 0..<ids.count {
            for j in (i+1)..<ids.count {
                connect(ids[i], to: ids[j])
            }
        }
    }

    func createChain(_ ids: [String]) {
        for i in 0..<(ids.count - 1) {
            connect(ids[i], to: ids[i + 1])
        }
    }

    func createRing(_ ids: [String]) {
        createChain(ids)
        if ids.count > 2 {
            connect(ids.last!, to: ids.first!)
        }
    }

    func createTree(_ ids: [String], branchFactor: Int = 2) {
        for i in 0..<ids.count {
            for j in 1...branchFactor {
                let childIndex = i * branchFactor + j
                if childIndex < ids.count {
                    connect(ids[i], to: ids[childIndex])
                }
            }
        }
    }

    func createRandom(_ ids: [String], density: Double) {
        for i in 0..<ids.count {
            for j in (i+1)..<ids.count {
                if Double.random(in: 0...1) < density {
                    connect(ids[i], to: ids[j])
                }
            }
        }
    }

    // MARK: - Network Manipulation

    func partition(into count: Int) {
        let ids = Array(peers.keys)
        let chunkSize = ids.count / count

        partitions = stride(from: 0, to: ids.count, by: chunkSize).map {
            Array(ids[$0..<min($0 + chunkSize, ids.count)])
        }

        // Disconnect edges between partitions
        var newEdges = Set<Edge>()
        for edge in edges {
            let fromPartition = partitions.firstIndex { $0.contains(edge.from) }
            let toPartition = partitions.firstIndex { $0.contains(edge.to) }

            if fromPartition == toPartition {
                newEdges.insert(edge)
            } else {
                // Remove connection from peers
                peers[edge.from]?.disconnect(from: edge.to)
                peers[edge.to]?.disconnect(from: edge.from)
            }
        }
        edges = newEdges
    }

    func reconnect() {
        guard partitions.count > 1 else { return }

        // Connect one peer from each partition to create bridges
        for i in 0..<(partitions.count - 1) {
            if let p1 = partitions[i].first, let p2 = partitions[i + 1].first {
                connect(p1, to: p2)
            }
        }

        partitions = [Array(peers.keys)]
    }

    func clearConnections() {
        edges.removeAll()
        for peer in peers.values {
            peer.disconnectAll()
        }
        partitions = [Array(peers.keys)]
    }

    // MARK: - Analysis

    /// Find shortest path between two peers using BFS
    func findPath(from source: String, to destination: String) -> [String]? {
        guard peers[source] != nil, peers[destination] != nil else { return nil }

        var visited = Set<String>()
        var queue: [(String, [String])] = [(source, [source])]

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()

            if current == destination {
                return path
            }

            if visited.contains(current) { continue }
            visited.insert(current)

            for neighbor in neighbors(of: current) {
                if !visited.contains(neighbor) {
                    queue.append((neighbor, path + [neighbor]))
                }
            }
        }

        return nil
    }

    /// Calculate network diameter (longest shortest path)
    func networkDiameter() -> Int {
        var maxDistance = 0
        let ids = Array(peers.keys)

        for i in 0..<ids.count {
            for j in (i+1)..<ids.count {
                if let path = findPath(from: ids[i], to: ids[j]) {
                    maxDistance = max(maxDistance, path.count - 1)
                }
            }
        }

        return maxDistance
    }

    /// Count connected components
    func connectedComponents() -> [[String]] {
        var visited = Set<String>()
        var components: [[String]] = []

        for peerId in peers.keys {
            if visited.contains(peerId) { continue }

            var component: [String] = []
            var stack = [peerId]

            while !stack.isEmpty {
                let current = stack.removeLast()
                if visited.contains(current) { continue }

                visited.insert(current)
                component.append(current)

                for neighbor in neighbors(of: current) {
                    if !visited.contains(neighbor) {
                        stack.append(neighbor)
                    }
                }
            }

            components.append(component)
        }

        return components
    }

    /// Check if network is fully connected
    var isFullyConnected: Bool {
        connectedComponents().count == 1
    }

    /// Average degree (connections per peer)
    var averageDegree: Double {
        guard peerCount > 0 else { return 0 }
        let totalConnections = peers.values.reduce(0) { $0 + $1.connections.count }
        return Double(totalConnections) / Double(peerCount)
    }

    /// Edge count
    var edgeCount: Int {
        edges.count
    }
}
