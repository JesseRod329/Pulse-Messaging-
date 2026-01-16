//
//  TransportProtocol.swift
//  Pulse
//
//  Unified transport abstraction inspired by BitChat's dual-transport architecture.
//  Enables seamless switching between Mesh (BLE/MultipeerConnectivity) and Nostr (Internet).
//

import Foundation

/// Transport types available in Pulse
enum TransportType: String, Codable, CaseIterable {
    case mesh       // Local BLE/MultipeerConnectivity - offline capable
    case nostr      // Internet via Nostr relays - global reach
    case hybrid     // Prefer mesh, fallback to nostr
}

/// Configuration for transport behavior
struct TransportConfig {
    var preferredTransport: TransportType = .hybrid
    var meshEnabled: Bool = true
    var nostrEnabled: Bool = true
    var maxHops: Int = 7
    var messageRetryCount: Int = 3
    var messageRetryDelay: TimeInterval = 5.0
    var enableDeduplication: Bool = true
}

/// Protocol that all transports must implement
@MainActor
protocol TransportProtocol: AnyObject {
    var transportType: TransportType { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect() async
    func send(_ packet: RoutablePacket, to recipient: String) async throws
    func broadcast(_ packet: RoutablePacket) async throws

    var onPacketReceived: ((RoutablePacket) -> Void)? { get set }
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)? { get set }
    var onPeerLost: ((String) -> Void)? { get set }
}

/// A packet that can be routed through the mesh network
struct RoutablePacket: Codable, Identifiable {
    let id: String
    let senderId: String
    let recipientId: String?  // nil = broadcast
    let payload: Data
    let packetType: PacketType
    var ttl: Int              // Time-to-live (hop count remaining)
    let timestamp: Date
    let signature: Data?      // Ed25519 signature for verification

    // Routing metadata
    var hopPath: [String]     // IDs of nodes that relayed this packet
    let originTimestamp: Date // Original send time (for dedup)

    enum PacketType: String, Codable {
        case message          // Chat message
        case messageAck       // Delivery acknowledgment
        case readReceipt      // Read confirmation
        case peerAnnounce     // Peer discovery announcement
        case peerQuery        // Request for peer info
        case routeRequest     // Request optimal route
        case routeReply       // Route information
    }

    init(
        senderId: String,
        recipientId: String?,
        payload: Data,
        packetType: PacketType,
        ttl: Int = 7,
        signature: Data? = nil
    ) {
        self.id = UUID().uuidString
        self.senderId = senderId
        self.recipientId = recipientId
        self.payload = payload
        self.packetType = packetType
        self.ttl = ttl
        self.timestamp = Date()
        self.signature = signature
        self.hopPath = [senderId]
        self.originTimestamp = Date()
    }

    /// Check if this packet should be forwarded (TTL > 0 and not at destination)
    var shouldForward: Bool {
        ttl > 0 && recipientId != nil
    }

    /// Create a forwarded copy with decremented TTL
    func forwarded(by relayerId: String) -> RoutablePacket {
        var copy = self
        copy.ttl -= 1
        copy.hopPath.append(relayerId)
        return copy
    }

    /// Check if we've already seen this node in the path (loop detection)
    func hasVisited(_ nodeId: String) -> Bool {
        hopPath.contains(nodeId)
    }
}

/// Discovered peer information
struct DiscoveredPeer: Codable, Identifiable {
    let id: String
    let handle: String
    let publicKey: Data?
    let signingPublicKey: Data?
    let status: Int
    let techStack: [String]
    var distance: Double?
    var lastSeen: Date
    var hopCount: Int         // 0 = direct connection, 1+ = relayed
    var viaTransport: TransportType

    /// Geohash for location-based features
    var geohash: String?
}

/// Extended message envelope with routing support
struct RoutableMessageEnvelope: Codable {
    // Original message fields
    let id: String
    let senderId: String
    let recipientId: String
    let encryptedContent: String
    let timestamp: Date
    let messageType: String
    let codeLanguage: String?
    var signature: Data?
    var senderSigningPublicKey: Data?

    // Routing extensions (BitChat-inspired)
    var ttl: Int
    var hopPath: [String]
    var deliveryAck: Bool
    var readReceipt: Bool

    // Transport metadata
    var viaTransport: TransportType
    var retryCount: Int

    init(from envelope: MessageEnvelope, ttl: Int = 7) {
        self.id = envelope.id
        self.senderId = envelope.senderId
        self.recipientId = envelope.recipientId
        self.encryptedContent = envelope.encryptedContent
        self.timestamp = envelope.timestamp
        self.messageType = envelope.messageType
        self.codeLanguage = envelope.codeLanguage
        self.signature = envelope.signature
        self.senderSigningPublicKey = envelope.senderSigningPublicKey
        self.ttl = ttl
        self.hopPath = [envelope.senderId]
        self.deliveryAck = false
        self.readReceipt = false
        self.viaTransport = .mesh
        self.retryCount = 0
    }

    /// Convert back to simple envelope
    func toMessageEnvelope() -> MessageEnvelope {
        MessageEnvelope(
            id: id,
            senderId: senderId,
            recipientId: recipientId,
            encryptedContent: encryptedContent,
            timestamp: timestamp,
            messageType: messageType,
            codeLanguage: codeLanguage,
            signature: signature,
            senderSigningPublicKey: senderSigningPublicKey
        )
    }
}
