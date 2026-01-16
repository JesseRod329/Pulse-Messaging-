//
//  MessageRouter.swift
//  Pulse
//
//  Multi-hop message routing inspired by BitChat's mesh networking.
//  Enables messages to relay through intermediate peers, extending range beyond direct connections.
//

import Foundation
import Combine

/// Routing decision for a packet
enum RoutingDecision {
    case deliver              // Deliver to local app (we're the recipient)
    case forward([String])    // Forward to these peer IDs
    case broadcast            // Send to all connected peers
    case drop(String)         // Drop packet with reason
}

/// Message router for multi-hop mesh networking
@MainActor
final class MessageRouter: ObservableObject {
    static let shared = MessageRouter()

    private let deduplicationService = MessageDeduplicationService.shared

    // Routing table: maps peer IDs to known routes
    @Published var routingTable: [String: RouteEntry] = [:]

    // Connected peers (direct connections)
    @Published var directPeers: Set<String> = []

    // Pending acknowledgments
    private var pendingAcks: [String: PendingMessage] = [:]

    // Callbacks
    var onLocalDelivery: ((RoutablePacket) -> Void)?
    var onForwardPacket: ((RoutablePacket, [String]) -> Void)?
    var onBroadcastPacket: ((RoutablePacket) -> Void)?

    // Configuration
    var maxHops: Int = 7
    var enableRelaying: Bool = true

    // Statistics
    @Published var packetsRouted: Int = 0
    @Published var packetsForwarded: Int = 0
    @Published var packetsDelivered: Int = 0
    @Published var packetsDropped: Int = 0

    private nonisolated(unsafe) var ackTimerStorage: Timer?

    private var ackTimer: Timer? {
        get { ackTimerStorage }
        set { ackTimerStorage = newValue }
    }

    private init() {
        startAckTimer()
    }

    /// Route an incoming packet
    func route(_ packet: RoutablePacket, myPeerId: String) -> RoutingDecision {
        packetsRouted += 1

        // Check for duplicates
        if deduplicationService.isDuplicate(packet) {
            packetsDropped += 1
            return .drop("Duplicate packet")
        }

        // Check if TTL exhausted
        if packet.ttl <= 0 {
            packetsDropped += 1
            return .drop("TTL exhausted")
        }

        // Check for routing loops
        if packet.hasVisited(myPeerId) {
            packetsDropped += 1
            return .drop("Routing loop detected")
        }

        // Handle based on recipient
        if let recipientId = packet.recipientId {
            // Unicast message
            if recipientId == myPeerId {
                // We're the recipient - deliver locally
                packetsDelivered += 1
                return .deliver
            } else {
                // Need to forward
                return routeToRecipient(packet, recipientId: recipientId)
            }
        } else {
            // Broadcast message - deliver locally AND forward
            packetsDelivered += 1
            packetsForwarded += 1
            return .broadcast
        }
    }

    /// Determine best route to a recipient
    private func routeToRecipient(_ packet: RoutablePacket, recipientId: String) -> RoutingDecision {
        // Check if recipient is directly connected
        if directPeers.contains(recipientId) {
            packetsForwarded += 1
            return .forward([recipientId])
        }

        // Check routing table for known route
        if let route = routingTable[recipientId], route.isValid {
            packetsForwarded += 1
            return .forward([route.nextHop])
        }

        // No known route - if relaying enabled, flood to all peers
        if enableRelaying && !directPeers.isEmpty {
            packetsForwarded += 1
            // Exclude peers already in the hop path
            let validPeers = directPeers.filter { !packet.hasVisited($0) }
            if validPeers.isEmpty {
                packetsDropped += 1
                return .drop("No valid forward peers")
            }
            return .forward(Array(validPeers))
        }

        packetsDropped += 1
        return .drop("No route to recipient")
    }

    /// Process a routable message envelope
    func routeMessage(_ envelope: RoutableMessageEnvelope, myPeerId: String) -> RoutingDecision {
        // Convert to packet for routing
        guard let payloadData = try? JSONEncoder().encode(envelope) else {
            return .drop("Failed to encode envelope")
        }

        let packet = RoutablePacket(
            senderId: envelope.senderId,
            recipientId: envelope.recipientId,
            payload: payloadData,
            packetType: .message,
            ttl: envelope.ttl
        )

        return route(packet, myPeerId: myPeerId)
    }

    /// Update routing table when we learn about a peer
    func updateRoute(to peerId: String, via nextHop: String, hopCount: Int) {
        let existingRoute = routingTable[peerId]

        // Only update if new route is better (fewer hops)
        if existingRoute == nil || existingRoute!.hopCount > hopCount {
            routingTable[peerId] = RouteEntry(
                destination: peerId,
                nextHop: nextHop,
                hopCount: hopCount,
                lastUpdated: Date()
            )
        }
    }

    /// Mark a peer as directly connected
    func addDirectPeer(_ peerId: String) {
        directPeers.insert(peerId)
        updateRoute(to: peerId, via: peerId, hopCount: 0)
    }

    /// Remove a disconnected peer
    func removeDirectPeer(_ peerId: String) {
        directPeers.remove(peerId)

        // Invalidate routes through this peer
        for (destination, route) in routingTable {
            if route.nextHop == peerId {
                routingTable.removeValue(forKey: destination)
            }
        }
    }

    /// Track a pending message awaiting acknowledgment
    func trackPendingMessage(_ envelope: RoutableMessageEnvelope) {
        pendingAcks[envelope.id] = PendingMessage(
            envelope: envelope,
            sentAt: Date(),
            retryCount: 0
        )
    }

    /// Handle delivery acknowledgment
    func handleAck(messageId: String) {
        if var pending = pendingAcks.removeValue(forKey: messageId) {
            pending.envelope.deliveryAck = true
            print("Message \(messageId) acknowledged")
        }
    }

    /// Retry unacknowledged messages
    private func startAckTimer() {
        ackTimer = Timer.scheduledTimer(
            withTimeInterval: 10.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.retryPendingMessages()
            }
        }
    }

    private func retryPendingMessages() {
        let now = Date()
        let retryThreshold: TimeInterval = 30.0
        let maxRetries = 3

        for (messageId, pending) in pendingAcks {
            if now.timeIntervalSince(pending.sentAt) > retryThreshold {
                if pending.retryCount < maxRetries {
                    // Retry
                    var updated = pending
                    updated.retryCount += 1
                    updated.envelope.retryCount = updated.retryCount
                    pendingAcks[messageId] = updated

                    print("Retrying message \(messageId), attempt \(updated.retryCount)")
                    // Trigger resend via callback
                    if let payloadData = try? JSONEncoder().encode(updated.envelope) {
                        let packet = RoutablePacket(
                            senderId: updated.envelope.senderId,
                            recipientId: updated.envelope.recipientId,
                            payload: payloadData,
                            packetType: .message,
                            ttl: updated.envelope.ttl
                        )
                        onBroadcastPacket?(packet)
                    }
                } else {
                    // Max retries exceeded - give up
                    pendingAcks.removeValue(forKey: messageId)
                    print("Message \(messageId) delivery failed after \(maxRetries) retries")
                }
            }
        }
    }

    /// Clean up stale routes
    func pruneStaleRoutes(olderThan age: TimeInterval = 300) {
        let cutoff = Date().addingTimeInterval(-age)
        routingTable = routingTable.filter { $0.value.lastUpdated > cutoff }
    }

    /// Get statistics
    var stats: RouterStats {
        RouterStats(
            packetsRouted: packetsRouted,
            packetsForwarded: packetsForwarded,
            packetsDelivered: packetsDelivered,
            packetsDropped: packetsDropped,
            directPeers: directPeers.count,
            knownRoutes: routingTable.count,
            pendingAcks: pendingAcks.count
        )
    }
}

/// Routing table entry
struct RouteEntry: Codable {
    let destination: String
    let nextHop: String
    let hopCount: Int
    let lastUpdated: Date

    var isValid: Bool {
        // Routes older than 5 minutes are considered stale
        Date().timeIntervalSince(lastUpdated) < 300
    }
}

/// Pending message awaiting acknowledgment
struct PendingMessage {
    var envelope: RoutableMessageEnvelope
    let sentAt: Date
    var retryCount: Int
}

/// Router statistics
struct RouterStats {
    let packetsRouted: Int
    let packetsForwarded: Int
    let packetsDelivered: Int
    let packetsDropped: Int
    let directPeers: Int
    let knownRoutes: Int
    let pendingAcks: Int
}
