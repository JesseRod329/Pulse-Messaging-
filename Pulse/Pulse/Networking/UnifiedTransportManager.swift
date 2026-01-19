//
//  UnifiedTransportManager.swift
//  Pulse
//
//  Unified transport manager that coordinates between mesh and Nostr transports.
//  Inspired by BitChat's dual-transport architecture.
//

import Foundation
import Combine

/// Unified manager for all transports
@MainActor
final class UnifiedTransportManager: ObservableObject {
    static let shared = UnifiedTransportManager()

    // Sub-managers
    private let messageRouter = MessageRouter.shared
    private let deduplicationService = MessageDeduplicationService.shared
    private let topologyTracker = MeshTopologyTracker.shared
    private let nostrTransport = NostrTransport.shared
    private let geohashService = GeohashService.shared

    // Configuration
    @Published var config = TransportConfig()
    @Published var preferredTransport: TransportType = .hybrid

    // State
    @Published var isMeshConnected = false
    @Published var isNostrConnected = false
    @Published var activeTransports: Set<TransportType> = []

    // Statistics
    @Published var totalMessagesSent: Int = 0
    @Published var totalMessagesReceived: Int = 0
    @Published var messagesSentViaMesh: Int = 0
    @Published var messagesSentViaNostr: Int = 0

    // Callbacks
    var onMessageReceived: ((RoutableMessageEnvelope) -> Void)?
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)?
    var onPeerLost: ((String) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var currentPeerId: String?
    private var currentHandle: String?
    private var currentPublicKey: String?

    private init() {
        setupCallbacks()
        applyUserDefaultsConfig()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyUserDefaultsConfig()
                await self?.updateTransportState()
            }
        }
    }

    private func applyUserDefaultsConfig() {
        let defaults = UserDefaults.standard
        config.meshEnabled = defaults.object(forKey: "meshEnabled") as? Bool ?? config.meshEnabled
        config.nostrEnabled = defaults.object(forKey: "nostrEnabled") as? Bool ?? config.nostrEnabled
        config.maxHops = defaults.object(forKey: "maxHops") as? Int ?? config.maxHops

        messageRouter.maxHops = config.maxHops

        if config.meshEnabled && !config.nostrEnabled {
            preferredTransport = .mesh
        } else if !config.meshEnabled && config.nostrEnabled {
            preferredTransport = .nostr
        } else {
            preferredTransport = .hybrid
        }
    }

    private func updateTransportState() async {
        if config.nostrEnabled {
            if !isNostrConnected,
               let peerId = currentPeerId,
               let handle = currentHandle,
               let publicKey = currentPublicKey {
                await startNostrIfNeeded(myPeerId: peerId, handle: handle, publicKey: publicKey)
            }
        } else if isNostrConnected {
            await nostrTransport.disconnect()
            isNostrConnected = false
            activeTransports.remove(.nostr)
        }

        if !config.meshEnabled {
            isMeshConnected = false
            activeTransports.remove(.mesh)
        }
    }

    private func setupCallbacks() {
        // Route incoming mesh packets
        messageRouter.onLocalDelivery = { [weak self] packet in
            self?.handleLocalDelivery(packet)
        }

        messageRouter.onForwardPacket = { [weak self] packet, peers in
            self?.forwardPacket(packet, to: peers)
        }

        messageRouter.onBroadcastPacket = { [weak self] packet in
            self?.broadcastPacket(packet)
        }

        // Route incoming Nostr packets
        nostrTransport.onPacketReceived = { [weak self] packet in
            Task { @MainActor in
                self?.handleIncomingPacket(packet, via: .nostr)
            }
        }
    }

    // MARK: - Transport Control

    /// Start all enabled transports
    func start(myPeerId: String, handle: String, publicKey: String) async {
        currentPeerId = myPeerId
        currentHandle = handle
        currentPublicKey = publicKey

        // Configure sub-managers
        topologyTracker.configure(myNodeId: myPeerId, handle: handle)
        nostrTransport.configure(publicKey: publicKey)

        // Start mesh (handled by MeshManager)
        if config.meshEnabled {
            activeTransports.insert(.mesh)
            isMeshConnected = true
        }

        // Start Nostr if enabled
        if config.nostrEnabled {
            await startNostrIfNeeded(myPeerId: myPeerId, handle: handle, publicKey: publicKey)
        }
    }

    private func startNostrIfNeeded(myPeerId: String, handle: String, publicKey: String) async {
        guard NostrTransport.supportsSigning else {
            print("Nostr disabled: signing support not available")
            return
        }
        do {
            try await nostrTransport.connect()
            activeTransports.insert(.nostr)
            isNostrConnected = true
        } catch {
            print("Failed to connect Nostr: \(error)")
        }
    }

    /// Stop all transports
    func stop() async {
        activeTransports.removeAll()
        isMeshConnected = false

        await nostrTransport.disconnect()
        isNostrConnected = false
    }

    // MARK: - Sending Messages

    /// Send a message using the best available transport
    func sendMessage(_ envelope: MessageEnvelope, to peer: DiscoveredPeer) async throws {
        let routableEnvelope = RoutableMessageEnvelope(from: envelope, ttl: config.maxHops)

        switch preferredTransport {
        case .mesh:
            try await sendViaMesh(routableEnvelope, to: peer.id)
        case .nostr:
            try await sendViaNostr(routableEnvelope, to: peer.id)
        case .hybrid:
            // Try mesh first, fall back to Nostr
            if isMeshConnected && peer.hopCount <= config.maxHops {
                try await sendViaMesh(routableEnvelope, to: peer.id)
            } else if isNostrConnected {
                try await sendViaNostr(routableEnvelope, to: peer.id)
            } else {
                throw TransportError.noAvailableTransport
            }
        }

        totalMessagesSent += 1
        messageRouter.trackPendingMessage(routableEnvelope)
    }

    /// Broadcast a message to all nearby peers
    func broadcastMessage(_ envelope: MessageEnvelope) async throws {
        var routableEnvelope = RoutableMessageEnvelope(from: envelope, ttl: config.maxHops)
        routableEnvelope.viaTransport = preferredTransport

        // Encode to packet
        guard let payloadData = try? JSONEncoder().encode(routableEnvelope) else {
            throw TransportError.encodingFailed
        }

        let packet = RoutablePacket(
            senderId: envelope.senderId,
            recipientId: nil,  // Broadcast
            payload: payloadData,
            packetType: .message,
            ttl: config.maxHops
        )

        // Broadcast on all active transports
        if isMeshConnected {
            broadcastPacket(packet)
            messagesSentViaMesh += 1
        }

        if isNostrConnected {
            try await nostrTransport.broadcast(packet)
            messagesSentViaNostr += 1
        }

        totalMessagesSent += 1
    }

    private func sendViaMesh(_ envelope: RoutableMessageEnvelope, to recipientId: String) async throws {
        var mutableEnvelope = envelope
        mutableEnvelope.viaTransport = .mesh

        guard let payloadData = try? JSONEncoder().encode(mutableEnvelope) else {
            throw TransportError.encodingFailed
        }

        let packet = RoutablePacket(
            senderId: envelope.senderId,
            recipientId: recipientId,
            payload: payloadData,
            packetType: .message,
            ttl: config.maxHops
        )

        // Route through mesh
        let decision = messageRouter.route(packet, myPeerId: envelope.senderId)
        switch decision {
        case .forward(let peers):
            forwardPacket(packet, to: peers)
            messagesSentViaMesh += 1
        case .broadcast:
            broadcastPacket(packet)
            messagesSentViaMesh += 1
        case .deliver, .drop:
            throw TransportError.routingFailed
        }
    }

    private func sendViaNostr(_ envelope: RoutableMessageEnvelope, to recipientId: String) async throws {
        var mutableEnvelope = envelope
        mutableEnvelope.viaTransport = .nostr

        guard let payloadData = try? JSONEncoder().encode(mutableEnvelope) else {
            throw TransportError.encodingFailed
        }

        let packet = RoutablePacket(
            senderId: envelope.senderId,
            recipientId: recipientId,
            payload: payloadData,
            packetType: .message,
            ttl: 1  // Nostr doesn't need multi-hop
        )

        try await nostrTransport.send(packet, to: recipientId)
        messagesSentViaNostr += 1
    }

    // MARK: - Receiving Messages

    /// Handle incoming packet from any transport
    func handleIncomingPacket(_ packet: RoutablePacket, via transport: TransportType) {
        let myPeerId = topologyTracker.myNodeId

        // Route the packet
        let decision = messageRouter.route(packet, myPeerId: myPeerId)

        switch decision {
        case .deliver:
            deliverLocally(packet)
        case .forward(let peers):
            if config.enableDeduplication {
                let forwarded = packet.forwarded(by: myPeerId)
                forwardPacket(forwarded, to: peers)
            }
        case .broadcast:
            deliverLocally(packet)
            if config.enableDeduplication {
                let forwarded = packet.forwarded(by: myPeerId)
                broadcastPacket(forwarded)
            }
        case .drop(let reason):
            print("Dropped packet: \(reason)")
        }
    }

    private func handleLocalDelivery(_ packet: RoutablePacket) {
        deliverLocally(packet)
    }

    private func deliverLocally(_ packet: RoutablePacket) {
        if packet.packetType == .messageAck {
            if let messageId = String(data: packet.payload, encoding: .utf8) {
                messageRouter.handleAck(messageId: messageId)
            }
            return
        }

        // Decode the envelope
        guard let envelope = try? JSONDecoder().decode(RoutableMessageEnvelope.self, from: packet.payload) else {
            print("Failed to decode message envelope")
            return
        }

        guard isEnvelopeSignatureValid(envelope) else {
            print("Invalid or missing signature for message \(envelope.id)")
            return
        }

        // Check for duplicates at envelope level
        if deduplicationService.isDuplicate(envelope) {
            return
        }

        totalMessagesReceived += 1

        // Send acknowledgment if requested
        if envelope.deliveryAck {
            sendAcknowledgment(for: envelope)
        }

        // Deliver to app
        onMessageReceived?(envelope)
    }

    private func isEnvelopeSignatureValid(_ envelope: RoutableMessageEnvelope) -> Bool {
        guard let signature = envelope.signature,
              let signingKey = envelope.senderSigningPublicKey,
              let payload = envelope.toMessageEnvelope().signaturePayload() else {
            return false
        }

        return (try? IdentityManager.shared.verifySignature(signature: signature, for: payload, from: signingKey)) == true
    }

    private func sendAcknowledgment(for envelope: RoutableMessageEnvelope) {
        // Create ack packet
        let ackPacket = RoutablePacket(
            senderId: topologyTracker.myNodeId,
            recipientId: envelope.senderId,
            payload: Data(envelope.id.utf8),
            packetType: .messageAck,
            ttl: config.maxHops
        )

        // Send back via same transport
        Task {
            if envelope.viaTransport == .nostr && isNostrConnected {
                try? await nostrTransport.send(ackPacket, to: envelope.senderId)
            } else {
                broadcastPacket(ackPacket)
            }
        }
    }

    // MARK: - Packet Forwarding

    private func forwardPacket(_ packet: RoutablePacket, to peerIds: [String]) {
        // Record relay for stats
        topologyTracker.recordRelay(packetSize: packet.payload.count)

        // Forward via mesh (MeshManager handles actual sending)
        NotificationCenter.default.post(
            name: .forwardPacket,
            object: nil,
            userInfo: ["packet": packet, "peers": peerIds]
        )
    }

    private func broadcastPacket(_ packet: RoutablePacket) {
        topologyTracker.recordRelay(packetSize: packet.payload.count)

        NotificationCenter.default.post(
            name: .broadcastPacket,
            object: nil,
            userInfo: ["packet": packet]
        )
    }

    // MARK: - Peer Management

    /// Register a directly discovered peer
    func registerDirectPeer(_ peer: DiscoveredPeer) {
        messageRouter.addDirectPeer(peer.id)
        topologyTracker.addDirectPeer(peer.id, handle: peer.handle, signalStrength: peer.distance.map { 1.0 - min($0 / 100.0, 1.0) })
        onPeerDiscovered?(peer)
    }

    /// Remove a lost peer
    func removePeer(_ peerId: String) {
        messageRouter.removeDirectPeer(peerId)
        topologyTracker.removePeer(peerId)
        onPeerLost?(peerId)
    }

    /// Update peer signal strength
    func updatePeerSignal(_ peerId: String, distance: Double) {
        let strength = 1.0 - min(distance / 100.0, 1.0)
        topologyTracker.updateSignalStrength(peerId, strength: strength)
    }

    // MARK: - Location Channels

    /// Join a location-based channel
    func joinLocationChannel(precision: GeohashPrecision = .neighborhood) {
        geohashService.selectedPrecision = precision
        geohashService.joinCurrentChannel()
    }

    /// Leave all location channels
    func leaveAllLocationChannels() {
        for channel in geohashService.activeChannels {
            geohashService.leaveChannel(id: channel.id)
        }
    }

    // MARK: - Statistics

    var stats: TransportStats {
        TransportStats(
            meshConnected: isMeshConnected,
            nostrConnected: isNostrConnected,
            nostrRelays: nostrTransport.connectedRelays,
            totalSent: totalMessagesSent,
            totalReceived: totalMessagesReceived,
            sentViaMesh: messagesSentViaMesh,
            sentViaNostr: messagesSentViaNostr,
            routerStats: messageRouter.stats,
            dedupStats: deduplicationService.stats,
            networkStats: topologyTracker.stats
        )
    }

    enum TransportError: Error {
        case noAvailableTransport
        case encodingFailed
        case routingFailed
    }
}

/// Combined transport statistics
struct TransportStats {
    let meshConnected: Bool
    let nostrConnected: Bool
    let nostrRelays: Int
    let totalSent: Int
    let totalReceived: Int
    let sentViaMesh: Int
    let sentViaNostr: Int
    let routerStats: RouterStats
    let dedupStats: (processed: Int, blocked: Int, filterFill: Double)
    let networkStats: NetworkStats
}

// MARK: - Notifications

extension Notification.Name {
    static let forwardPacket = Notification.Name("forwardPacket")
    static let broadcastPacket = Notification.Name("broadcastPacket")
}
