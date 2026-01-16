//
//  MeshTopologyTracker.swift
//  Pulse
//
//  Tracks mesh network topology for visualization and routing optimization.
//  Inspired by BitChat's mesh topology tracking.
//

import Foundation
import Combine

/// A node in the mesh network
struct MeshNode: Identifiable, Codable, Equatable {
    let id: String
    var handle: String
    var isDirectConnection: Bool
    var hopCount: Int
    var lastSeen: Date
    var signalStrength: Double?  // RSSI-derived, 0-1
    var connectedPeers: [String] // IDs of peers this node is connected to

    static func == (lhs: MeshNode, rhs: MeshNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// An edge (connection) in the mesh network
struct MeshEdge: Identifiable, Codable, Equatable {
    let id: String
    let sourceId: String
    let targetId: String
    var strength: Double  // Connection quality 0-1
    var latency: TimeInterval?
    var lastActive: Date

    init(sourceId: String, targetId: String, strength: Double = 1.0) {
        self.id = "\(sourceId)-\(targetId)"
        self.sourceId = sourceId
        self.targetId = targetId
        self.strength = strength
        self.latency = nil
        self.lastActive = Date()
    }

    static func == (lhs: MeshEdge, rhs: MeshEdge) -> Bool {
        lhs.id == rhs.id
    }
}

/// Network statistics
struct NetworkStats: Codable {
    var totalNodes: Int
    var directConnections: Int
    var relayedConnections: Int
    var averageHopCount: Double
    var networkDiameter: Int  // Max hops between any two nodes
    var packetsRelayed: Int
    var bytesTransferred: Int64
}

/// Mesh topology tracker for network visualization
@MainActor
final class MeshTopologyTracker: ObservableObject {
    static let shared = MeshTopologyTracker()

    @Published var nodes: [String: MeshNode] = [:]
    @Published var edges: [String: MeshEdge] = [:]
    @Published var myNodeId: String = ""

    // Network health indicators
    @Published var networkHealth: Double = 1.0  // 0-1
    @Published var isPartitioned: Bool = false

    // Statistics
    @Published var stats = NetworkStats(
        totalNodes: 0,
        directConnections: 0,
        relayedConnections: 0,
        averageHopCount: 0,
        networkDiameter: 0,
        packetsRelayed: 0,
        bytesTransferred: 0
    )

    private nonisolated(unsafe) var cleanupTimerStorage: Timer?
    private var cleanupTimer: Timer? {
        get { cleanupTimerStorage }
        set { cleanupTimerStorage = newValue }
    }

    private init() {
        startCleanupTimer()
    }

    /// Set our node ID
    func configure(myNodeId: String, handle: String) {
        self.myNodeId = myNodeId

        // Add ourselves to the topology
        nodes[myNodeId] = MeshNode(
            id: myNodeId,
            handle: handle,
            isDirectConnection: true,
            hopCount: 0,
            lastSeen: Date(),
            signalStrength: 1.0,
            connectedPeers: []
        )

        updateStats()
    }

    /// Add or update a directly connected peer
    func addDirectPeer(_ peerId: String, handle: String, signalStrength: Double?) {
        let node = MeshNode(
            id: peerId,
            handle: handle,
            isDirectConnection: true,
            hopCount: 1,
            lastSeen: Date(),
            signalStrength: signalStrength,
            connectedPeers: [myNodeId]
        )

        nodes[peerId] = node

        // Add edge from us to peer
        let edge = MeshEdge(
            sourceId: myNodeId,
            targetId: peerId,
            strength: signalStrength ?? 0.5
        )
        edges[edge.id] = edge

        // Update our connected peers
        if var myNode = nodes[myNodeId] {
            if !myNode.connectedPeers.contains(peerId) {
                myNode.connectedPeers.append(peerId)
                nodes[myNodeId] = myNode
            }
        }

        updateStats()
    }

    /// Remove a disconnected peer
    func removePeer(_ peerId: String) {
        nodes.removeValue(forKey: peerId)

        // Remove edges involving this peer
        edges = edges.filter { !($0.key.contains(peerId)) }

        // Update our connected peers
        if var myNode = nodes[myNodeId] {
            myNode.connectedPeers.removeAll { $0 == peerId }
            nodes[myNodeId] = myNode
        }

        updateStats()
    }

    /// Update a peer from a relayed packet (learned about indirectly)
    func addRelayedPeer(_ peerId: String, handle: String, hopCount: Int, viaNode: String) {
        // Only add if we don't have a better route
        if let existing = nodes[peerId], existing.hopCount <= hopCount {
            // Just update last seen
            nodes[peerId]?.lastSeen = Date()
            return
        }

        let node = MeshNode(
            id: peerId,
            handle: handle,
            isDirectConnection: false,
            hopCount: hopCount,
            lastSeen: Date(),
            signalStrength: nil,
            connectedPeers: []
        )

        nodes[peerId] = node

        // Add edge from relay node to this peer
        let edge = MeshEdge(
            sourceId: viaNode,
            targetId: peerId,
            strength: 0.5  // Unknown strength for relayed connections
        )
        edges[edge.id] = edge

        updateStats()
    }

    /// Record a relayed packet (for stats)
    func recordRelay(packetSize: Int) {
        stats.packetsRelayed += 1
        stats.bytesTransferred += Int64(packetSize)
    }

    /// Update signal strength for a peer
    func updateSignalStrength(_ peerId: String, strength: Double) {
        nodes[peerId]?.signalStrength = strength

        // Update edge strength
        let edgeId = "\(myNodeId)-\(peerId)"
        edges[edgeId]?.strength = strength
    }

    /// Get all nodes sorted by hop count
    var sortedNodes: [MeshNode] {
        Array(nodes.values).sorted { $0.hopCount < $1.hopCount }
    }

    /// Get all edges as array
    var allEdges: [MeshEdge] {
        Array(edges.values)
    }

    /// Find shortest path to a peer
    func findPath(to targetId: String) -> [String]? {
        guard nodes[targetId] != nil else { return nil }

        // BFS to find shortest path
        var visited: Set<String> = [myNodeId]
        var queue: [(String, [String])] = [(myNodeId, [myNodeId])]

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()

            if current == targetId {
                return path
            }

            if let node = nodes[current] {
                for peerId in node.connectedPeers {
                    if !visited.contains(peerId) {
                        visited.insert(peerId)
                        queue.append((peerId, path + [peerId]))
                    }
                }
            }
        }

        return nil
    }

    /// Calculate network diameter (max shortest path)
    private func calculateDiameter() -> Int {
        var maxDiameter = 0

        for node in nodes.values {
            maxDiameter = max(maxDiameter, node.hopCount)
        }

        return maxDiameter
    }

    /// Update statistics
    private func updateStats() {
        let allNodes = Array(nodes.values)
        let directNodes = allNodes.filter { $0.isDirectConnection && $0.id != myNodeId }
        let relayedNodes = allNodes.filter { !$0.isDirectConnection }

        let avgHops = allNodes.isEmpty ? 0 :
            Double(allNodes.reduce(0) { $0 + $1.hopCount }) / Double(allNodes.count)

        stats = NetworkStats(
            totalNodes: allNodes.count,
            directConnections: directNodes.count,
            relayedConnections: relayedNodes.count,
            averageHopCount: avgHops,
            networkDiameter: calculateDiameter(),
            packetsRelayed: stats.packetsRelayed,
            bytesTransferred: stats.bytesTransferred
        )

        // Update network health based on connectivity
        if stats.totalNodes <= 1 {
            networkHealth = 0
        } else {
            // Health based on average connection strength
            let avgStrength = edges.values.isEmpty ? 0 :
                edges.values.reduce(0) { $0 + $1.strength } / Double(edges.count)
            networkHealth = avgStrength
        }
    }

    /// Clean up stale nodes
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupStaleNodes()
            }
        }
    }

    private func cleanupStaleNodes() {
        let staleThreshold = Date().addingTimeInterval(-300) // 5 minutes

        for (nodeId, node) in nodes {
            if nodeId != myNodeId && node.lastSeen < staleThreshold {
                removePeer(nodeId)
            }
        }
    }

    /// Export topology for debugging
    func exportTopology() -> Data? {
        let topology = TopologyExport(
            nodes: Array(nodes.values),
            edges: Array(edges.values),
            stats: stats,
            exportedAt: Date()
        )
        return try? JSONEncoder().encode(topology)
    }
}

/// Exportable topology structure
struct TopologyExport: Codable {
    let nodes: [MeshNode]
    let edges: [MeshEdge]
    let stats: NetworkStats
    let exportedAt: Date
}
