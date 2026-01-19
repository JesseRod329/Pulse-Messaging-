//
//  MeshManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//  Enhanced with BitChat-inspired multi-hop routing and Nostr fallback.
//

import Foundation
import MultipeerConnectivity
import Combine
import CryptoKit
import UserNotifications

@MainActor
class MeshManager: NSObject, ObservableObject {
    @Published var nearbyPeers: [PulsePeer] = []
    @Published var isAdvertising = false
    @Published var receivedMessages: [MessageEnvelope] = []

    private let serviceType = "pulse-mesh"
    private nonisolated(unsafe) var myPeerID: MCPeerID
    private nonisolated(unsafe) var session: MCSession
    private nonisolated(unsafe) var advertiser: MCNearbyServiceAdvertiser?
    private nonisolated(unsafe) var browser: MCNearbyServiceBrowser?

    // Power management
    private let powerManager = PowerManager.shared
    private var discoveryTimer: Timer?
    private var distanceUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // RSSI-based distance measurement
    private let rssiManager = RSSIManager.shared
    private let bleAdvertiser = BLEAdvertiser.shared

    // BitChat-inspired networking enhancements
    private let messageRouter = MessageRouter.shared
    private let deduplicationService = MessageDeduplicationService.shared
    private let topologyTracker = MeshTopologyTracker.shared
    private let unifiedTransport = UnifiedTransportManager.shared

    // SECURITY: Rate limiting to prevent DoS attacks
    private let rateLimiter = RateLimiter(
        config: .default,  // 100 msgs per 60s
        maxViolationsBeforeBlock: 5  // Block after 5 violations
    )
    private var rateLimiterCleanupTimer: Timer?

    override init() {
        // Load or create peer ID
        let savedID = UserDefaults.standard.string(forKey: "myPeerID") ?? UUID().uuidString
        UserDefaults.standard.set(savedID, forKey: "myPeerID")

        self.myPeerID = MCPeerID(displayName: savedID)
        self.session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        super.init()

        session.delegate = self
        setupPowerAwareDiscovery()
        setupRoutingCallbacks()
        requestNotificationPermission()
        setupRateLimiterCleanup()
        
        // Listen for place updates
        NotificationCenter.default.addObserver(
            forName: .didUpdatePlace,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAdvertising()
        }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.isAdvertising == true else { return }
            self?.refreshAdvertising()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Permission result handled silently
        }
    }
    
    private func scheduleNotification(for envelope: MessageEnvelope) {
        // Only notify if app is in background (heuristic: power manager state)
        guard PowerManager.shared.appState == .background else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Message"
        
        // Try to resolve sender name
        let senderName = nearbyPeers.first(where: { $0.id == envelope.senderId })?.handle ?? "Someone"
        content.body = "\(senderName) sent you a message"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: envelope.id, content: content, trigger: nil) // Immediate
        UNUserNotificationCenter.current().add(request)
    }
    
    private func refreshAdvertising() {
        stopAdvertising()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startAdvertising()
        }
    }

    private func setupRoutingCallbacks() {
        // Listen for packet forwarding requests from UnifiedTransportManager
        NotificationCenter.default.addObserver(
            forName: .forwardPacket,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let packet = notification.userInfo?["packet"] as? RoutablePacket,
                  let peerIds = notification.userInfo?["peers"] as? [String] else { return }
            Task { @MainActor in
                self?.forwardPacketToPeers(packet, peerIds: peerIds)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .broadcastPacket,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let packet = notification.userInfo?["packet"] as? RoutablePacket else { return }
            Task { @MainActor in
                self?.broadcastPacketToAllPeers(packet)
            }
        }

        // Handle incoming routable messages
        unifiedTransport.onMessageReceived = { [weak self] envelope in
            Task { @MainActor in
                self?.receivedMessages.append(envelope.toMessageEnvelope())
                NotificationCenter.default.post(name: .didReceiveMessage, object: envelope.toMessageEnvelope())
            }
        }
    }

    /// Forward a packet to specific peers
    private func forwardPacketToPeers(_ packet: RoutablePacket, peerIds: [String]) {
        guard let packetData = try? JSONEncoder().encode(packet) else { return }

        let targetPeers = session.connectedPeers.filter { peerIds.contains($0.displayName) }
        guard !targetPeers.isEmpty else { return }

        do {
            try session.send(packetData, toPeers: targetPeers, with: .reliable)
        } catch {
            DebugLogger.error("Failed to forward packet", category: .mesh)
        }
    }

    /// Broadcast a packet to all connected peers
    private func broadcastPacketToAllPeers(_ packet: RoutablePacket) {
        guard let packetData = try? JSONEncoder().encode(packet) else { return }
        guard !session.connectedPeers.isEmpty else { return }

        do {
            try session.send(packetData, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            DebugLogger.error("Failed to broadcast packet", category: .mesh)
        }
    }

    private func setupPowerAwareDiscovery() {
        // React to power state changes
        powerManager.$appState
            .sink { [weak self] state in
                guard let self = self, self.isAdvertising else { return }

                if state == .background {
                    self.enterBackgroundMode()
                } else if state == .foreground {
                    self.enterForegroundMode()
                }
            }
            .store(in: &cancellables)

        // React to low power mode
        powerManager.$isLowPowerMode
            .sink { [weak self] isLowPower in
                guard let self = self, self.isAdvertising else { return }

                if isLowPower {
                    self.adjustDiscoveryInterval(.minimal)
                } else {
                    self.adjustDiscoveryInterval(self.powerManager.recommendedInterval)
                }
            }
            .store(in: &cancellables)

        // Stop if battery critical
        powerManager.$batteryLevel
            .sink { [weak self] level in
                guard let self = self else { return }

                if self.powerManager.shouldStopDiscovery {
                    self.pauseDiscovery()
                }
            }
            .store(in: &cancellables)
    }

    private func enterBackgroundMode() {
        adjustDiscoveryInterval(.conservative)
    }

    private func enterForegroundMode() {
        // Cancel any intermittent discovery timer
        discoveryTimer?.invalidate()
        discoveryTimer = nil

        // Resume continuous discovery
        browser?.startBrowsingForPeers()
    }

    private func adjustDiscoveryInterval(_ interval: PowerManager.DiscoveryInterval) {
        discoveryTimer?.invalidate()

        // Continuous mode for aggressive discovery
        if interval == .aggressive {
            browser?.startBrowsingForPeers()
            return
        }

        // Intermittent discovery for power saving
        browser?.stopBrowsingForPeers()

        let scanDuration = powerManager.scanDuration

        discoveryTimer = Timer.scheduledTimer(
            withTimeInterval: interval.rawValue,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.browser?.startBrowsingForPeers()

                // Stop after brief scan
                try? await Task.sleep(for: .seconds(scanDuration))
                self?.browser?.stopBrowsingForPeers()
            }
        }
    }

    private func pauseDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
    }

    func resumeDiscovery() {
        guard !powerManager.shouldStopDiscovery else { return }
        startAdvertising()
    }

    /// Explicitly request bluetooth permissions by starting/stopping a brief scan
    func requestBluetoothPermission() {
        // Triggering any Bluetooth-related activity will prompt the OS permission dialog
        // MCNearbyServiceAdvertiser/Browser already do this on start, but we can call it explicitly

        // Starting advertising/browsing triggers the system prompt
        if !isAdvertising {
            startAdvertising()
            // We can stop it shortly after if we just wanted the prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.stopAdvertising()
            }
        }
    }

    func startAdvertising() {
        var handle = UserDefaults.standard.string(forKey: "handle") ?? "anon"
        // Ensure handle has @ prefix
        if !handle.hasPrefix("@") {
            handle = "@\(handle)"
        }
        let status = UserDefaults.standard.integer(forKey: "userStatus")
        let techStack = UserDefaults.standard.stringArray(forKey: "techStack")?.joined(separator: ",") ?? "Swift"
        let publicKey = IdentityManager.shared.myPublicKey?.base64EncodedString() ?? ""
        let signingPublicKey = IdentityManager.shared.mySigningPublicKey?.base64EncodedString() ?? ""
        let avatarHash = AvatarManager.shared.getAvatarHash() ?? ""
        let place = PlaceManager.shared.currentPlace?.rawValue ?? ""

        let shareProfile = UserDefaults.standard.object(forKey: "shareProfileInDiscovery") as? Bool ?? true
        let advertisedHandle = shareProfile ? handle : "@anon"
        let advertisedTechStack = shareProfile ? techStack : ""
        let advertisedAvatarHash = shareProfile ? avatarHash : ""
        let advertisedPlace = shareProfile ? place : ""

        let discoveryInfo: [String: String] = [
            "handle": advertisedHandle,
            "status": "\(status)",
            "techStack": advertisedTechStack,
            "publicKey": publicKey,
            "signingPublicKey": signingPublicKey,
            "avatarHash": advertisedAvatarHash,
            "place": advertisedPlace
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        isAdvertising = true

        // Start RSSI scanning and BLE advertising for distance measurement
        rssiManager.startScanning()
        bleAdvertiser.startAdvertising()

        // Start distance update timer
        startDistanceUpdates()

        // Configure BitChat-inspired networking
        topologyTracker.configure(myNodeId: myPeerID.displayName, handle: handle)

        // Start unified transport (includes Nostr if enabled)
        Task {
            await unifiedTransport.start(
                myPeerId: myPeerID.displayName,
                handle: handle,
                publicKey: publicKey
            )
        }

        // Only add demo peers in simulator for UI testing
        #if targetEnvironment(simulator)
        addDemoPeers()
        #endif
    }

    private func startDistanceUpdates() {
        distanceUpdateTimer?.invalidate()

        // Update peer distances every 2 seconds
        distanceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePeerDistances()
            }
        }
    }

    private func updatePeerDistances() {
        for (index, peer) in nearbyPeers.enumerated() {
            // Look up distance from RSSI manager
            if let distance = rssiManager.peerDistances[peer.id] {
                nearbyPeers[index].distance = distance
            }
        }
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        isAdvertising = false

        // Stop RSSI scanning and BLE advertising
        rssiManager.stopScanning()
        bleAdvertiser.stopAdvertising()
        distanceUpdateTimer?.invalidate()
        distanceUpdateTimer = nil
    }

    // MARK: - Background Tasks

    /// Refresh peer discovery during background execution
    /// Called periodically by BGTaskScheduler for continuous peer detection
    func refreshPeerDiscovery() {
        // Restart discovery to find new peers
        stopAdvertising()

        // Small delay before restarting to allow system to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startAdvertising()
        }

        // Update distances for currently visible peers
        startDistanceUpdates()
    }

    func sendEncryptedMessage(_ envelope: MessageEnvelope, to peer: PulsePeer) {
        // NOTE: Don't log peer handles or IDs in production

        guard envelope.signature != nil, envelope.senderSigningPublicKey != nil else {
            DebugLogger.error("Refusing to send unsigned message envelope", category: .crypto)
            return
        }

        // In Simulator, simulate success for demo peers
        #if targetEnvironment(simulator)
        if ["1", "2", "3", "4"].contains(peer.id) {
            // If it's a message (not typing/receipt), simulate a reply after delay
            if envelope.messageType == "text" {
                let senderId = peer.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.simulateDemoReply(from: senderId, handle: peer.handle)
                }
            }
            return
        }
        #endif

        // NOTE: Don't log connected peer counts or IDs in production

        guard let peerConnection = session.connectedPeers.first(where: { $0.displayName == peer.id }) else {
            // NOTE: Don't log peer handles or IDs in production

            // Post notification about failed send
            NotificationCenter.default.post(name: .messageSendFailed, object: nil, userInfo: ["reason": "Peer not connected - please wait for connection"])
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            try session.send(data, toPeers: [peerConnection], with: .reliable)
        } catch {
            DebugLogger.error("Failed to send message", category: .mesh)
            NotificationCenter.default.post(name: .messageSendFailed, object: nil, userInfo: ["reason": error.localizedDescription])
        }
    }

    /// Check if a peer is currently connected
    func isPeerConnected(_ peerId: String) -> Bool {
        return session.connectedPeers.contains { $0.displayName == peerId }
    }

    /// Get count of connected peers
    var connectedPeerCount: Int {
        return session.connectedPeers.count
    }

    #if targetEnvironment(simulator)
    private func simulateDemoReply(from senderId: String, handle: String) {
        let responses = [
            "That's interesting!",
            "Tell me more about Pulse.",
            "I'm working on a cool Swift project too.",
            "Mesh networking is the future!",
            "Are you going to the meetup?",
            "Nice code snippet."
        ]
        
        let content = responses.randomElement() ?? "Hello!"
        
        // We need to encrypt this to make it look real, or just inject it directly into receivedMessages as if decrypted?
        // IdentityManager expects encrypted content to decrypt.
        // For simplicity in demo, we can just inject a "decrypted" message structure if we modify how received messages are processed,
        // OR we can actually encrypt it using our public key (since we are "sending" to ourselves effectively in this sim).
        
        // Actually, easiest is to construct a MessageEnvelope and pretend it came in.
        // But the `session(_:didReceive:fromPeer:)` decodes and then appends.
        // `ChatManager` does the decryption.
        
        // To make this work end-to-end with ChatManager's decryption:
        // 1. Get MY public key.
        // 2. Encrypt the content using MY public key (as if the sender used it).
        // 3. Create envelope.
        // 4. Post .didReceiveMessage or call receivedMessages.append.
        
        guard let myPublicKey = IdentityManager.shared.myPublicKey else { return }
        
        // Create a temporary identity for the sender to encrypt FROM
        let senderIdentity = PulseIdentity.create(handle: handle)
        
        guard let encryptedData = try? senderIdentity.encrypt(content, for: myPublicKey) else {
             return
        }
        
        var envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: senderId,
            recipientId: myPeerID.displayName,
            encryptedContent: encryptedData.base64EncodedString(),
            timestamp: Date(),
            messageType: "text",
            codeLanguage: nil
        )

        if let payload = envelope.signaturePayload(),
           let signature = try? senderIdentity.sign(data: payload) {
            envelope.signature = signature
            envelope.senderSigningPublicKey = senderIdentity.signingPublicKey
        }
        
        Task { @MainActor in
            receivedMessages.append(envelope)
            NotificationCenter.default.post(name: .didReceiveMessage, object: envelope)
            
            // Persist
            PersistenceManager.shared.saveReceivedMessage(envelope, peerHandle: handle)
            SoundManager.shared.messageReceived()
        }
    }
    #endif

    private func addDemoPeers() {
        // Demo data for UI testing
        let key1 = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let key2 = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let key3 = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let key4 = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let sign1 = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        let sign2 = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        let sign3 = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        let sign4 = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation

        nearbyPeers = [
            PulsePeer(id: "1", handle: "@jesse_codes", status: .active, techStack: ["Swift", "Rust"], distance: 8, publicKey: key1, signingPublicKey: sign1),
            PulsePeer(id: "2", handle: "@swift_sarah", status: .active, techStack: ["Swift", "iOS"], distance: 15, publicKey: key2, signingPublicKey: sign2),
            PulsePeer(id: "3", handle: "@rust_dev", status: .flowState, techStack: ["Rust", "WebAssembly"], distance: 45, publicKey: key3, signingPublicKey: sign3),
            PulsePeer(id: "4", handle: "@pythonista", status: .idle, techStack: ["Python", "ML"], distance: 80, publicKey: key4, signingPublicKey: sign4)
        ]
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MeshManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let autoAccept = UserDefaults.standard.object(forKey: "autoAcceptInvites") as? Bool ?? true
        if autoAccept {
            invitationHandler(true, session)
        } else {
            // NOTE: Don't log peer display names in production
            invitationHandler(false, nil)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MeshManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let peerIDCopy = peerID.displayName
        let infoCopy = info

        Task { @MainActor in
            let publicKeyString = infoCopy?["publicKey"] ?? ""
            let publicKey = Data(base64Encoded: publicKeyString)
            let signingPublicKeyString = infoCopy?["signingPublicKey"] ?? ""
            let signingPublicKey = Data(base64Encoded: signingPublicKeyString)
            let placeRawValue = infoCopy?["place"] ?? ""
            let place = Place(rawValue: placeRawValue)

            // Get distance from RSSI manager, fallback to 50m if not available yet
            let distance = rssiManager.distance(for: peerIDCopy)

            // Get handle and ensure it has @ prefix
            var peerHandle = infoCopy?["handle"] ?? "Unknown"
            if peerHandle != "Unknown" && !peerHandle.hasPrefix("@") {
                peerHandle = "@\(peerHandle)"
            }

            let peer = PulsePeer(
                id: peerIDCopy,
                handle: peerHandle,
                status: PeerStatus(rawValue: Int(infoCopy?["status"] ?? "0") ?? 0) ?? .idle,
                place: place,
                techStack: (infoCopy?["techStack"] ?? "").split(separator: ",").map(String.init),
                distance: distance,
                publicKey: publicKey,
                signingPublicKey: signingPublicKey
            )

            if let index = nearbyPeers.firstIndex(where: { $0.id == peer.id }) {
                // Peer exists, update info
                var existingPeer = nearbyPeers[index]
                
                // Check for key change (crucial for reinstall/reset scenarios)
                if existingPeer.publicKey != peer.publicKey {
                    // NOTE: Don't log peer handles in production - security sensitive
                    existingPeer.publicKey = peer.publicKey
                    
                    // Update routing info with new key if needed
                    unifiedTransport.registerDirectPeer(DiscoveredPeer(
                        id: peerIDCopy,
                        handle: peer.handle,
                        publicKey: publicKey,
                        signingPublicKey: signingPublicKey,
                        status: peer.status.rawValue,
                        techStack: peer.techStack,
                        distance: distance,
                        lastSeen: Date(),
                        hopCount: 0,
                        viaTransport: .mesh,
                        geohash: nil
                    ))
                }

                if existingPeer.signingPublicKey != peer.signingPublicKey {
                    // NOTE: Don't log peer handles in production - security sensitive
                    existingPeer.signingPublicKey = peer.signingPublicKey
                }
                
                existingPeer.status = peer.status
                existingPeer.distance = peer.distance
                // Update other fields as needed
                nearbyPeers[index] = existingPeer
                
            } else {
                nearbyPeers.append(peer)

                // Play discovery sound
                SoundManager.shared.peerDiscovered()

                // Register with routing infrastructure
                messageRouter.addDirectPeer(peerIDCopy)
                topologyTracker.addDirectPeer(peerIDCopy, handle: peer.handle, signalStrength: 1.0 - min(distance / 100.0, 1.0))

                // Notify unified transport
                let discoveredPeer = DiscoveredPeer(
                    id: peerIDCopy,
                    handle: peer.handle,
                    publicKey: publicKey,
                    signingPublicKey: signingPublicKey,
                    status: peer.status.rawValue,
                    techStack: peer.techStack,
                    distance: distance,
                    lastSeen: Date(),
                    hopCount: 0,
                    viaTransport: .mesh,
                    geohash: nil
                )
                unifiedTransport.registerDirectPeer(discoveredPeer)
            }
        }

        // Invite to session (outside Task to avoid sendability issues)
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        let peerIDCopy = peerID.displayName

        Task { @MainActor in
            nearbyPeers.removeAll { $0.id == peerIDCopy }

            // Remove from routing infrastructure
            messageRouter.removeDirectPeer(peerIDCopy)
            topologyTracker.removePeer(peerIDCopy)
            unifiedTransport.removePeer(peerIDCopy)
        }
    }
}

// MARK: - MCSessionDelegate

extension MeshManager: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        let stateString: String
        switch state {
        case .notConnected:
            stateString = "NOT CONNECTED"
        case .connecting:
            stateString = "CONNECTING"
        case .connected:
            stateString = "CONNECTED"
        @unknown default:
            stateString = "UNKNOWN"
        }
        // NOTE: Don't log peer IDs, states, or connected peer counts in production

        let peerIdCopy = peerID.displayName
        Task { @MainActor in
            // Play sound when connected
            if state == .connected {
                SoundManager.shared.connected()

                // Send handshake with current public key
                // Look up the MCPeerID from session.connectedPeers to avoid capturing non-Sendable peerID parameter
                if let targetPeerID = self.session.connectedPeers.first(where: { $0.displayName == peerIdCopy }) {
                    self.sendHandshake(to: targetPeerID)
                }
            }
            // Silently handle disconnection
        }
    }

    /// Send a handshake message with our public key to ensure the peer has the latest key
    private func sendHandshake(to peerID: MCPeerID) {
        guard let myPublicKey = IdentityManager.shared.myPublicKey,
              let mySigningPublicKey = IdentityManager.shared.mySigningPublicKey else { return }

        let payload = HandshakePayload(
            publicKey: myPublicKey.base64EncodedString(),
            signingPublicKey: mySigningPublicKey.base64EncodedString()
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        // Use MessageEnvelope with type "handshake" and payload as content
        var envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerID.displayName,
            recipientId: peerID.displayName,
            encryptedContent: payloadData.base64EncodedString(),
            timestamp: Date(),
            messageType: "handshake",
            codeLanguage: nil
        )

        guard let signedEnvelope = signEnvelope(envelope) else {
            DebugLogger.error("Failed to sign handshake envelope", category: .crypto)
            return
        }

        do {
            let data = try JSONEncoder().encode(signedEnvelope)
            try session.send(data, toPeers: [peerID], with: .reliable)
            // NOTE: Don't log peer display names in production
        } catch {
            DebugLogger.error("Failed to send handshake", category: .mesh)
        }
    }

    private func signEnvelope(_ envelope: MessageEnvelope) -> MessageEnvelope? {
        guard let payload = envelope.signaturePayload() else { return nil }
        guard let signature = try? IdentityManager.shared.signPayload(payload) else { return nil }
        guard let signingPublicKey = IdentityManager.shared.mySigningPublicKey else { return nil }

        var signedEnvelope = envelope
        signedEnvelope.signature = signature
        signedEnvelope.senderSigningPublicKey = signingPublicKey
        return signedEnvelope
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        // NOTE: Never log data size, peer IDs, or raw data in production

        // SECURITY: Check rate limit before processing message
        Task { @MainActor in
            guard rateLimiter.shouldAllowMessage(from: peerID.displayName) else {
                #if DEBUG
                DebugLogger.warning("Rate-limited message from peer: \(peerID.displayName)", category: .security)
                #endif
                return
            }

            // Try to decode as routable packet first (new format)
            if let packet = try? JSONDecoder().decode(RoutablePacket.self, from: data) {
                // Route through unified transport
                unifiedTransport.handleIncomingPacket(packet, via: .mesh)
                return
            }

            // Process legacy format below
            await processLegacyMessage(data)
        }
    }

    /// Process legacy MessageEnvelope format (backward compatibility)
    private func processLegacyMessage(_ data: Data) async {

        // Fallback to legacy MessageEnvelope for backwards compatibility
        guard let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data) else {
            // NOTE: NEVER log raw data - could contain sensitive encrypted content
            #if DEBUG
            DebugLogger.error("Failed to decode data as MessageEnvelope", category: .mesh)
            #endif
            return
        }

        // NOTE: Don't log message types or sender IDs in production

        Task { @MainActor in
            guard isEnvelopeSignatureValid(envelope) else {
                // NOTE: Don't log message IDs or sender IDs in production - security risk
                #if DEBUG
                DebugLogger.error("Invalid or missing signature for message", category: .crypto)
                #endif
                return
            }

            // Handle different message types
            switch envelope.messageType {
            case "handshake":
                // NOTE: Don't log sender IDs in production
                let payload = decodeHandshakePayload(from: envelope.encryptedContent)
                self.updatePeerKeys(
                    peerId: envelope.senderId,
                    publicKey: payload?.publicKey,
                    signingPublicKey: payload?.signingPublicKey
                )

            case "receipt":
                // Delivery/read receipt - don't log message IDs
                NotificationCenter.default.post(name: .didReceiveReceipt, object: envelope)

            case "typing":
                // Typing indicator
                let isTyping = envelope.originalMessageId == "true"
                let indicator = TypingIndicator(
                    senderId: envelope.senderId,
                    isTyping: isTyping,
                    timestamp: envelope.timestamp
                )
                NotificationCenter.default.post(name: .didReceiveTypingIndicator, object: indicator)

            default:
                // Regular message (text or code)
                // Check for duplicates
                if deduplicationService.isDuplicate(envelope) {
                    // Silently ignore duplicates
                    return
                }

                // NOTE: Don't log message receipt in production
                receivedMessages.append(envelope)
                NotificationCenter.default.post(name: .didReceiveMessage, object: envelope)

                // Persist immediately!
                // Find handle for peer
                let senderHandle = nearbyPeers.first(where: { $0.id == envelope.senderId })?.handle ?? "@unknown"
                PersistenceManager.shared.saveReceivedMessage(envelope, peerHandle: senderHandle)

                // Play receive sound
                SoundManager.shared.messageReceived()
                
                // Schedule local notification
                self.scheduleNotification(for: envelope)

                // Send delivery receipt
                sendDeliveryReceipt(for: envelope)
            }
        }
    }

    private func isEnvelopeSignatureValid(_ envelope: MessageEnvelope) -> Bool {
        guard let signature = envelope.signature,
              let payload = envelope.signaturePayload() else {
            return false
        }

        let advertisedKey = envelope.senderSigningPublicKey
        let storedKey = nearbyPeers.first(where: { $0.id == envelope.senderId })?.signingPublicKey

        if let storedKey = storedKey, let advertisedKey = advertisedKey, storedKey != advertisedKey {
            // NOTE: Don't log sender IDs in production - security sensitive
            DebugLogger.error("Signature key mismatch detected", category: .crypto)
            return false
        }

        guard let signingKey = advertisedKey ?? storedKey else { return false }

        return (try? IdentityManager.shared.verifySignature(signature: signature, for: payload, from: signingKey)) == true
    }

    private func updatePeerKeys(peerId: String, publicKey: Data?, signingPublicKey: Data?) {
        guard let index = nearbyPeers.firstIndex(where: { $0.id == peerId }) else { return }

        var updated = nearbyPeers[index]
        if let publicKey = publicKey, updated.publicKey != publicKey {
            updated.publicKey = publicKey
            // NOTE: Don't log peer IDs in production
        }

        if let signingPublicKey = signingPublicKey, updated.signingPublicKey != signingPublicKey {
            updated.signingPublicKey = signingPublicKey
            // NOTE: Don't log peer IDs in production
        }

        nearbyPeers[index] = updated

        // Update routing info
        unifiedTransport.registerDirectPeer(DiscoveredPeer(
            id: updated.id,
            handle: updated.handle,
            publicKey: updated.publicKey,
            signingPublicKey: updated.signingPublicKey,
            status: updated.status.rawValue,
            techStack: updated.techStack,
            distance: updated.distance,
            lastSeen: Date(),
            hopCount: 0,
            viaTransport: .mesh,
            geohash: nil
        ))
    }

    /// Send a delivery receipt back to the sender
    private func sendDeliveryReceipt(for envelope: MessageEnvelope) {
        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        let receipt = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,
            recipientId: envelope.senderId,
            encryptedContent: "",
            timestamp: Date(),
            messageType: "receipt",
            codeLanguage: nil,
            receiptType: "delivered",
            originalMessageId: envelope.id
        )

        // Find the peer to send to
        if let peer = nearbyPeers.first(where: { $0.id == envelope.senderId }) {
            // NOTE: Don't log peer handles in production
            if let signedReceipt = signEnvelope(receipt) {
                sendEncryptedMessage(signedReceipt, to: peer)
            }
        }
        // Silently skip if peer not found
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

private struct HandshakePayload: Codable {
    let publicKey: String
    let signingPublicKey: String
}

private struct HandshakePayloadData {
    let publicKey: Data?
    let signingPublicKey: Data?
}

private extension MeshManager {
    func decodeHandshakePayload(from content: String) -> HandshakePayloadData? {
        if let data = Data(base64Encoded: content),
           let payload = try? JSONDecoder().decode(HandshakePayload.self, from: data) {
            return HandshakePayloadData(
                publicKey: Data(base64Encoded: payload.publicKey),
                signingPublicKey: Data(base64Encoded: payload.signingPublicKey)
            )
        }

        if let keyData = Data(base64Encoded: content) {
            return HandshakePayloadData(publicKey: keyData, signingPublicKey: nil)
        }

        return nil
    }

    // MARK: - Rate Limiting

    /// Setup periodic cleanup for rate limiter
    private func setupRateLimiterCleanup() {
        // Clean up rate limiter history every 5 minutes
        rateLimiterCleanupTimer = Timer.scheduledTimer(
            withTimeInterval: 300.0,  // 5 minutes
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rateLimiter.cleanup()
            }
        }
    }
}
