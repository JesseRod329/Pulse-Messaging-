//
//  NostrTransport.swift
//  Pulse
//
//  Nostr protocol transport for internet-based messaging.
//  Inspired by BitChat's dual-transport architecture - provides global reach
//  when local mesh is unavailable.
//

import Foundation
import CryptoKit

/// Nostr event kinds used by Pulse
enum NostrEventKind: Int, Codable {
    case setMetadata = 0
    case textNote = 1
    case recommendServer = 2
    case contactList = 3
    case encryptedDM = 4          // NIP-04 (deprecated but widely supported)
    case deletion = 5
    case repost = 6
    case reaction = 7
    case giftWrap = 1059          // NIP-17 gift-wrapped private messages
    case zapRequest = 9734        // NIP-57 zap request
    case zapReceipt = 9735        // NIP-57 zap receipt
    case auth = 22242             // NIP-42 auth challenge response
    case pulseMessage = 30078     // Custom kind for Pulse mesh messages
    case pulseChannel = 30079     // Custom kind for Pulse location channels
}

/// A Nostr event
struct NostrEvent: Codable, Identifiable {
    let id: String
    let pubkey: String
    let created_at: Int
    let kind: Int
    let tags: [[String]]
    let content: String
    let sig: String

    /// Create a new event (unsigned)
    static func create(
        pubkey: String,
        kind: NostrEventKind,
        content: String,
        tags: [[String]] = []
    ) -> NostrEvent {
        let createdAt = Int(Date().timeIntervalSince1970)
        let id = computeEventId(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind.rawValue,
            tags: tags,
            content: content
        )

        return NostrEvent(
            id: id,
            pubkey: pubkey,
            created_at: createdAt,
            kind: kind.rawValue,
            tags: tags,
            content: content,
            sig: "" // Needs to be signed
        )
    }

    /// Create a new signed event using NostrIdentity
    static func createSigned(
        identity: NostrIdentity,
        kind: NostrEventKind,
        content: String,
        tags: [[String]] = []
    ) throws -> NostrEvent {
        let pubkey = identity.publicKeyHex
        let createdAt = Int(Date().timeIntervalSince1970)
        let id = computeEventId(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind.rawValue,
            tags: tags,
            content: content
        )

        // Sign the event ID with Schnorr signature
        let signature = try identity.signEventId(id)

        return NostrEvent(
            id: id,
            pubkey: pubkey,
            created_at: createdAt,
            kind: kind.rawValue,
            tags: tags,
            content: content,
            sig: signature
        )
    }

    /// Compute event ID as SHA256 of serialized event
    private static func computeEventId(
        pubkey: String,
        createdAt: Int,
        kind: Int,
        tags: [[String]],
        content: String
    ) -> String {
        guard let data = try? NostrNormalization.canonicalEventJSONData(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content
        ) else {
            return ""
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Nostr relay message types
enum NostrRelayMessage {
    case event(subscriptionId: String, event: NostrEvent)
    case ok(eventId: String, success: Bool, message: String)
    case eose(subscriptionId: String) // End of stored events
    case notice(message: String)
    case auth(challenge: String)

    static func parse(_ json: String) -> NostrRelayMessage? {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let type = array.first as? String else {
            return nil
        }

        switch type {
        case "EVENT":
            guard array.count >= 3,
                  let subId = array[1] as? String,
                  let eventDict = array[2] as? [String: Any],
                  let eventData = try? JSONSerialization.data(withJSONObject: eventDict),
                  let event = try? JSONDecoder().decode(NostrEvent.self, from: eventData) else {
                return nil
            }
            return .event(subscriptionId: subId, event: event)
        case "OK":
            guard array.count >= 4,
                  let eventId = array[1] as? String,
                  let success = array[2] as? Bool,
                  let message = array[3] as? String else {
                return nil
            }
            return .ok(eventId: eventId, success: success, message: message)
        case "EOSE":
            guard array.count >= 2, let subId = array[1] as? String else {
                return nil
            }
            return .eose(subscriptionId: subId)
        case "NOTICE":
            guard array.count >= 2, let message = array[1] as? String else {
                return nil
            }
            return .notice(message: message)
        case "AUTH":
            guard array.count >= 2, let challenge = array[1] as? String else {
                return nil
            }
            return .auth(challenge: challenge)
        default:
            return nil
        }
    }
}

/// Nostr relay connection
@MainActor
final class NostrRelay: ObservableObject {
    let url: URL
    private var webSocket: URLSessionWebSocketTask?

    /// Secure URLSession with certificate validation for WebSocket connections
    /// Protects against MITM attacks on relay connections
    private let session: URLSession

    @Published var isConnected = false
    @Published var lastError: String?

    var onEvent: ((NostrEvent, String) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?

    private var subscriptions: [String: NostrFilter] = [:]

    init(url: URL) {
        self.url = url
        // Use secure session with certificate validation
        self.session = SecureNetworkSession.createWebSocketSession()
    }

    func connect() {
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        isConnected = true
        onConnect?()
        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        onDisconnect?()
    }

    func subscribe(filter: NostrFilter, subscriptionId: String) {
        subscriptions[subscriptionId] = filter

        let request = "[\"REQ\",\"\(subscriptionId)\",\(filter.toJson())]"
        send(request)
    }

    func unsubscribe(_ subscriptionId: String) {
        subscriptions.removeValue(forKey: subscriptionId)
        let request = "[\"CLOSE\",\"\(subscriptionId)\"]"
        send(request)
    }

    func publish(_ event: NostrEvent) {
        guard let eventData = try? JSONEncoder().encode(event),
              let eventJson = String(data: eventData, encoding: .utf8) else {
            return
        }
        let request = "[\"EVENT\",\(eventJson)]"
        send(request)
    }

    private func send(_ message: String) {
        webSocket?.send(.string(message)) { error in
            if let error = error {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                var textToProcess: String?
                switch message {
                case .string(let text):
                    textToProcess = text
                case .data(let data):
                    textToProcess = String(data: data, encoding: .utf8)
                @unknown default:
                    break
                }

                if let text = textToProcess {
                    Task { @MainActor [weak self] in
                        self?.handleMessage(text)
                        self?.receiveMessage()
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.receiveMessage()
                    }
                }
            case .failure(let error):
                let errorMessage = error.localizedDescription
                Task { @MainActor [weak self] in
                    self?.lastError = errorMessage
                    self?.isConnected = false
                    self?.onDisconnect?()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let message = NostrRelayMessage.parse(text) else { return }

        switch message {
        case .event(let subscriptionId, let event):
            onEvent?(event, subscriptionId)
        case .ok(let eventId, let success, let message):
            print("Nostr OK: \(eventId) - \(success ? "success" : "failed"): \(message)")
        case .eose(let subscriptionId):
            print("Nostr EOSE: \(subscriptionId)")
        case .notice(let message):
            print("Nostr notice: \(message)")
        case .auth(let challenge):
            print("Nostr auth challenge: \(challenge)")
            guard let identity = NostrIdentityManager.shared.nostrIdentity else {
                print("Nostr auth skipped: missing identity")
                return
            }
            let tags = [
                ["relay", url.absoluteString],
                ["challenge", challenge]
            ]
            do {
                let event = try NostrEvent.createSigned(
                    identity: identity,
                    kind: .auth,
                    content: "",
                    tags: tags
                )
                publish(event)
            } catch {
                print("Nostr auth failed: \(error)")
            }
        }
    }
}

/// Nostr subscription filter
struct NostrFilter: Codable {
    var ids: [String]?
    var authors: [String]?
    var kinds: [Int]?
    var since: Int?
    var until: Int?
    var limit: Int?

    // Tag filters (e.g., #e, #p, #g for geohash)
    var tagFilters: [String: [String]] = [:]

    func toJson() -> String {
        var dict: [String: Any] = [:]
        if let ids = ids { dict["ids"] = ids }
        if let authors = authors { dict["authors"] = authors }
        if let kinds = kinds { dict["kinds"] = kinds }
        if let since = since { dict["since"] = since }
        if let until = until { dict["until"] = until }
        if let limit = limit { dict["limit"] = limit }

        for (tag, values) in tagFilters {
            dict["#\(tag)"] = values
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

/// Nostr transport manager
@MainActor
final class NostrTransport: ObservableObject, TransportProtocol {
    static let shared = NostrTransport()
    static let supportsSigning = true  // Now enabled with secp256k1

    let transportType: TransportType = .nostr

    @Published var isConnected = false
    @Published var connectedRelays: Int = 0

    var onPacketReceived: ((RoutablePacket) -> Void)?
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)?
    var onPeerLost: ((String) -> Void)?
    var onZapReceived: ((NostrEvent) -> Void)?  // NIP-57 zap receipt handler

    // Default Pulse-friendly relays
    private let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.nostr.band",
        "wss://nostr.wine"
    ]

    private var relays: [NostrRelay] = []
    private var myPublicKey: String?
    private var currentGeohash: String?

    // Active subscriptions
    private var channelSubscriptions: [String: String] = [:] // geohash -> subscriptionId
    private var zapReceiptSubscriptionId: String?

    private init() {}

    func configure(publicKey: String) {
        self.myPublicKey = publicKey
    }

    func connect() async throws {
        // Ensure we have a Nostr identity for signing
        let nostrIdentityManager = NostrIdentityManager.shared
        if !nostrIdentityManager.hasIdentity {
            if nostrIdentityManager.createIdentity() == nil {
                throw NostrError.notConfigured
            }
        }

        // Configure with Nostr public key
        guard let pubkey = nostrIdentityManager.publicKeyHex else {
            throw NostrError.notConfigured
        }
        self.myPublicKey = pubkey

        for urlString in defaultRelays {
            guard let url = URL(string: urlString) else { continue }
            let relay = NostrRelay(url: url)

            relay.onConnect = { [weak self] in
                Task { @MainActor in
                    self?.connectedRelays += 1
                    self?.isConnected = (self?.connectedRelays ?? 0) > 0
                }
            }

            relay.onDisconnect = { [weak self] in
                Task { @MainActor in
                    self?.connectedRelays -= 1
                    self?.isConnected = (self?.connectedRelays ?? 0) > 0
                }
            }

            relay.onEvent = { [weak self] event, subscriptionId in
                self?.handleEvent(event, subscriptionId: subscriptionId)
            }

            relay.connect()
            relays.append(relay)
        }
    }

    func disconnect() async {
        for relay in relays {
            relay.disconnect()
        }
        relays.removeAll()
        connectedRelays = 0
        isConnected = false
    }

    func send(_ packet: RoutablePacket, to recipient: String) async throws {
        guard let identity = NostrIdentityManager.shared.nostrIdentity else {
            throw NostrError.notConfigured
        }

        // Encode packet as content
        let packetData = try JSONEncoder().encode(packet)
        let content = packetData.base64EncodedString()

        // Create signed event with recipient tag
        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .pulseMessage,
            content: content,
            tags: [["p", recipient]]
        )

        // Publish to all connected relays
        for relay in relays where relay.isConnected {
            relay.publish(event)
        }
    }

    func broadcast(_ packet: RoutablePacket) async throws {
        guard let identity = NostrIdentityManager.shared.nostrIdentity,
              let geohash = currentGeohash else {
            throw NostrError.notConfigured
        }

        let packetData = try JSONEncoder().encode(packet)
        let content = packetData.base64EncodedString()

        // Broadcast to location channel with signed event
        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .pulseChannel,
            content: content,
            tags: [["g", geohash]] // Geohash tag
        )

        for relay in relays where relay.isConnected {
            relay.publish(event)
        }
    }

    // MARK: - NIP-57 Zap Support

    /// Publish a zap request (kind 9734)
    func publishZapRequest(
        recipientPubkey: String,
        lightningAddress: String,
        amount: Int,  // millisats
        messageEventId: String?,
        comment: String?
    ) async throws -> NostrEvent {
        guard let identity = NostrIdentityManager.shared.nostrIdentity else {
            throw NostrError.notConfigured
        }

        // Build tags per NIP-57
        var tags: [[String]] = [
            ["p", recipientPubkey],
            ["amount", String(amount)],
            ["relays"] + defaultRelays,
            ["lnurl", lightningAddress]  // Will be encoded by caller
        ]

        // Optional: reference the message being zapped
        if let eventId = messageEventId {
            tags.append(["e", eventId])
        }

        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .zapRequest,
            content: comment ?? "",
            tags: tags
        )

        // Publish to relays
        for relay in relays where relay.isConnected {
            relay.publish(event)
        }

        return event
    }

    /// Subscribe to zap receipts (kind 9735) for a pubkey
    func subscribeToZapReceipts(for pubkey: String) {
        let subscriptionId = "zap-\(pubkey.prefix(8))"
        zapReceiptSubscriptionId = subscriptionId

        var filter = NostrFilter()
        filter.kinds = [NostrEventKind.zapReceipt.rawValue]
        filter.tagFilters["p"] = [pubkey]
        filter.since = Int(Date().addingTimeInterval(-86400).timeIntervalSince1970)  // Last 24 hours

        for relay in relays where relay.isConnected {
            relay.subscribe(filter: filter, subscriptionId: subscriptionId)
        }
    }

    /// Unsubscribe from zap receipts
    func unsubscribeFromZapReceipts() {
        guard let subscriptionId = zapReceiptSubscriptionId else { return }

        for relay in relays where relay.isConnected {
            relay.unsubscribe(subscriptionId)
        }
        zapReceiptSubscriptionId = nil
    }

    /// Fetch peer metadata (kind 0) to get lightning address
    func fetchPeerMetadata(pubkey: String) async throws -> [String: Any]? {
        // Create a one-time subscription for kind 0
        let subscriptionId = "meta-\(pubkey.prefix(8))"

        var filter = NostrFilter()
        filter.kinds = [NostrEventKind.setMetadata.rawValue]
        filter.authors = [pubkey]
        filter.limit = 1

        // Subscribe on first connected relay
        guard let relay = relays.first(where: { $0.isConnected }) else {
            throw NostrError.connectionFailed
        }

        relay.subscribe(filter: filter, subscriptionId: subscriptionId)

        // Note: In a real implementation, you'd use async/await with a continuation
        // to wait for the response. For now, return nil and let the caller retry.
        return nil
    }

    /// Publish profile metadata (kind 0) with lightning address
    func publishMetadata(
        name: String,
        lightningAddress: String?,
        about: String? = nil,
        picture: String? = nil
    ) async throws {
        guard let identity = NostrIdentityManager.shared.nostrIdentity else {
            throw NostrError.notConfigured
        }

        var metadata: [String: Any] = ["name": name]
        if let lud16 = lightningAddress {
            metadata["lud16"] = lud16
        }
        if let about = about {
            metadata["about"] = about
        }
        if let picture = picture {
            metadata["picture"] = picture
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
              let content = String(data: jsonData, encoding: .utf8) else {
            throw NostrError.notConfigured
        }

        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .setMetadata,
            content: content,
            tags: []
        )

        for relay in relays where relay.isConnected {
            relay.publish(event)
        }
    }

    /// Subscribe to a location-based channel
    func subscribeToChannel(geohash: String) {
        let subscriptionId = "pulse-\(geohash)"
        channelSubscriptions[geohash] = subscriptionId

        var filter = NostrFilter()
        filter.kinds = [NostrEventKind.pulseChannel.rawValue]
        filter.tagFilters["g"] = [geohash]
        filter.since = Int(Date().addingTimeInterval(-3600).timeIntervalSince1970) // Last hour

        for relay in relays where relay.isConnected {
            relay.subscribe(filter: filter, subscriptionId: subscriptionId)
        }

        currentGeohash = geohash
    }

    /// Unsubscribe from a channel
    func unsubscribeFromChannel(geohash: String) {
        guard let subscriptionId = channelSubscriptions.removeValue(forKey: geohash) else {
            return
        }

        for relay in relays where relay.isConnected {
            relay.unsubscribe(subscriptionId)
        }
    }

    private func handleEvent(_ event: NostrEvent, subscriptionId: String) {
        // Handle zap receipts (kind 9735)
        if event.kind == NostrEventKind.zapReceipt.rawValue {
            onZapReceived?(event)
            return
        }

        // Handle metadata events (kind 0)
        if event.kind == NostrEventKind.setMetadata.rawValue {
            // Metadata events are handled by their specific callbacks
            return
        }

        // Decode Pulse packet from content
        guard let packetData = Data(base64Encoded: event.content),
              let packet = try? JSONDecoder().decode(RoutablePacket.self, from: packetData) else {
            return
        }

        onPacketReceived?(packet)
    }

    enum NostrError: Error {
        case notConfigured
        case connectionFailed
        case signatureFailed
    }
}
