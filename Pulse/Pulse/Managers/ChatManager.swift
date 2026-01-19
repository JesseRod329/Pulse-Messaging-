//
//  ChatManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Link Preview Data Structures

/// A struct to hold the fetched metadata for a URL link preview.
struct LinkPreviewData: Identifiable, Codable, Hashable {
    /// The unique ID, which is the URL string itself.
    var id: String { url }
    
    let url: String
    let title: String?
    let description: String?
    let imageURL: String?
}

/// A service to fetch metadata for URL link previews.
@MainActor
final class LinkPreviewService {
    static let shared = LinkPreviewService()

    // A simple in-memory cache for preview data.
    private let cache = NSCache<NSString, NSData>()

    /// Secure URLSession with certificate validation for link preview fetching
    /// Protects against MITM attacks when fetching external metadata
    private let session: URLSession

    private init() {
        // Use secure session with certificate validation
        self.session = SecureNetworkSession.createSession()
    }

    /// Fetches preview data for a given URL.
    /// It first checks the cache, and if not available, fetches the data from the network.
    func fetchPreview(for url: URL) async -> LinkPreviewData? {
        let urlString = url.absoluteString

        // Check cache first
        if let cachedData = cache.object(forKey: urlString as NSString) {
            if let previewData = try? JSONDecoder().decode(LinkPreviewData.self, from: cachedData as Data) {
                return previewData
            }
        }

        // Fetch from network using secure session
        guard let (data, response) = try? await session.data(for: .init(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let htmlString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let metadata = parseHTMLForMetadata(htmlString: htmlString, url: url)
        
        let previewData = LinkPreviewData(
            url: urlString,
            title: metadata["og:title"] ?? metadata["title"],
            description: metadata["og:description"] ?? metadata["description"],
            imageURL: metadata["og:image"]
        )

        // Don't cache incomplete previews
        guard previewData.title != nil || previewData.description != nil || previewData.imageURL != nil else {
            return nil
        }
        
        // Save to cache
        if let dataToCache = try? JSONEncoder().encode(previewData) {
            cache.setObject(dataToCache as NSData, forKey: urlString as NSString)
        }

        return previewData
    }

    /// A simple parser to extract Open Graph and standard metadata tags from HTML.
    private func parseHTMLForMetadata(htmlString: String, url: URL) -> [String: String] {
        var metadata = [String: String]()

        // Regex to find <meta> tags
        // NOTE: Use try? instead of try! to prevent crashes on malformed HTML
        guard let metaTagRegex = try? NSRegularExpression(pattern: "<meta[^>]+>", options: .caseInsensitive) else {
            DebugLogger.error("Failed to create meta tag regex", category: .general)
            return metadata
        }
        let matches = metaTagRegex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))

        for match in matches {
            // Safely convert NSRange to Range to prevent crashes on malformed HTML
            guard let range = Range(match.range, in: htmlString) else {
                continue
            }
            let tag = String(htmlString[range])
            
            // Extract property/name and content
            if let property = extractAttribute(from: tag, attribute: "property"),
               let content = extractAttribute(from: tag, attribute: "content") {
                metadata[property] = content
            } else if let name = extractAttribute(from: tag, attribute: "name"),
                      let content = extractAttribute(from: tag, attribute: "content") {
                // For standard tags like <meta name="description" ...>
                 if name == "description" {
                    metadata[name] = content
                }
            }
        }
        
        // Extract title
        if let titleRange = htmlString.range(of: "<title>(.*?)</title>", options: .regularExpression) {
            metadata["title"] = String(htmlString[titleRange].dropFirst(7).dropLast(8))
        }

        // Ensure image URL is absolute
        if let imageURL = metadata["og:image"] {
            if imageURL.starts(with: "/") {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.path = imageURL
                components?.query = nil
                components?.fragment = nil
                if let absoluteURL = components?.url?.absoluteString {
                    metadata["og:image"] = absoluteURL
                }
            }
        }
        
        return metadata
    }

    private func extractAttribute(from tag: String, attribute: String) -> String? {
        let pattern = "\(attribute)=[\"']([^\"']+)[\"']"

        // NOTE: Use try? instead of try! to prevent crashes on malformed patterns
        // If attribute contains regex special chars, pattern creation could fail
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            DebugLogger.error("Failed to create attribute extraction regex", category: .general)
            return nil
        }

        if let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
           let range = Range(match.range(at: 1), in: tag) {
            return String(tag[range])
        }
        return nil
    }
}


@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping: Bool = false
    @Published var peerIsTyping: Bool = false
    @Published var isInitialized: Bool = false
    @Published var linkPreviews: [String: LinkPreviewData] = [:]

    private var peer: PulsePeer?
    private var meshManager: MeshManager?
    private let persistenceManager = PersistenceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private var lastTypingSent: Date?
    @AppStorage("linkPreviewsEnabled") private var linkPreviewsEnabled = true

    /// Placeholder initializer for deferred initialization
    static func placeholder() -> ChatManager {
        return ChatManager()
    }

    private init() {
        // Placeholder - will be initialized later
    }

    /// Full initializer with peer and meshManager
    init(peer: PulsePeer, meshManager: MeshManager) {
        self.peer = peer
        self.meshManager = meshManager
        self.isInitialized = true
        setupAll()
    }

    /// Deferred initialization for use with @StateObject placeholder pattern
    func initialize(peer: PulsePeer, meshManager: MeshManager) {
        guard !isInitialized else {
            return
        }

        #if DEBUG
        DebugLogger.log("ChatManager initializing", category: .general)
        #endif
        self.peer = peer
        self.meshManager = meshManager
        self.isInitialized = true
        setupAll()
    }

    private func setupAll() {
        guard let peer = peer else { return }

        // Load persisted messages first
        loadPersistedMessages()

        // Listen for incoming messages
        setupMessageListener()

        // Listen for receipts
        setupReceiptListener()

        // Listen for typing indicators
        setupTypingListener()

        // Mark conversation as read when opened
        persistenceManager.markConversationAsRead(peerId: peer.id)

        // Send read receipts for unread messages
        sendReadReceiptsForUnreadMessages()

        #if DEBUG
        DebugLogger.success("ChatManager fully initialized", category: .general)
        #endif
    }

    private func loadPersistedMessages() {
        guard let peer = peer else { return }
        let persistedMessages = persistenceManager.loadMessages(for: peer.id)
        if !persistedMessages.isEmpty {
            messages = persistedMessages
        }
    }

    private func setupMessageListener() {
        guard let meshManager = meshManager, peer != nil else { return }

        meshManager.$receivedMessages
            .receive(on: DispatchQueue.main)  // Ensure main thread
            .sink { [weak self] envelopes in
                guard let self = self, let peer = self.peer else {
                    return
                }

                let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? ""

                // NOTE: Don't log peer IDs or envelope counts in production

                // Filter messages for this chat (from this peer to me, or from me to this peer)
                for envelope in envelopes {
                    // Skip internal system messages (receipts, typing, handshakes which are handled by MeshManager)
                    // But ALLOW text, code, image, and voice
                    let allowedTypes = ["text", "code", "image", "voice"]
                    guard allowedTypes.contains(envelope.messageType) else {
                        continue
                    }

                    // NOTE: Don't log sender/recipient IDs in production

                    let isFromThisPeer = envelope.senderId == peer.id && envelope.recipientId == myPeerId
                    let isToThisPeer = envelope.senderId == myPeerId && envelope.recipientId == peer.id

                    if isFromThisPeer {
                        self.processReceivedMessage(envelope)
                    }
                    // Skip own sent messages
                }
            }
            .store(in: &cancellables)
    }

    func sendMessage(_ content: String, type: Message.MessageType = .text, language: String? = nil) {
        guard let peer = peer, let meshManager = meshManager else {
            DebugLogger.error("ChatManager not initialized, cannot send message", category: .general)
            return
        }

        // Play send sound
        SoundManager.shared.messageSent()

        guard let recipientPublicKey = peer.publicKey else {
            DebugLogger.warning("Cannot send: peer has no public key", category: .crypto)
            SoundManager.shared.playErrorSound()

            // Add a system message to indicate the issue
            let errorMessage = Message(
                id: UUID().uuidString,
                senderId: "system",
                content: "Waiting for secure connection... Message will send when peer's key is received.",
                timestamp: Date(),
                type: .text
            )
            messages.append(errorMessage)
            return
        }

        // Encrypt the message
        guard let encryptedData = IdentityManager.shared.encryptMessage(content, for: recipientPublicKey) else {
            DebugLogger.error("Failed to encrypt message", category: .crypto)
            return
        }

        // Use the MCPeerID (stored in UserDefaults) as senderId for consistency
        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        // Create envelope
        let envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,  // Use MCPeerID, not DID
            recipientId: peer.id,
            encryptedContent: encryptedData.base64EncodedString(),
            timestamp: Date(),
            messageType: type.rawValue,
            codeLanguage: language
        )

        guard let signedEnvelope = signEnvelope(envelope) else {
            DebugLogger.error("Failed to sign message", category: .crypto)
            return
        }

        // NOTE: Don't log sender/recipient IDs in production

        // Send via mesh
        meshManager.sendEncryptedMessage(signedEnvelope, to: peer)

        // Add to local messages
        let message = Message(
            id: envelope.id,
            senderId: "me",
            content: content,
            timestamp: envelope.timestamp,
            type: type,
            codeLanguage: language
        )
        // Explicitly notify before change to ensure SwiftUI updates
        objectWillChange.send()
        messages.append(message)

        // Fetch link previews if any
        fetchPreviews(for: message)

        // Persist the sent message
        persistenceManager.saveSentMessage(
            id: envelope.id,
            recipientId: peer.id,
            recipientHandle: peer.handle,
            encryptedContent: encryptedData,
            plaintext: content,
            timestamp: envelope.timestamp,
            messageType: type.rawValue,
            codeLanguage: language
        )
    }

    /// Send a voice note message
    func sendVoiceNote(audioURL: URL, audioData: Data, duration: TimeInterval) {
        guard let peer = peer, let meshManager = meshManager else {
            DebugLogger.error("ChatManager not initialized, cannot send voice note", category: .general)
            return
        }

        // Play send sound
        SoundManager.shared.messageSent()

        guard let recipientPublicKey = peer.publicKey else {
            DebugLogger.warning("Cannot send: peer has no public key", category: .crypto)
            SoundManager.shared.playErrorSound()
            
            let errorMessage = Message(
                id: UUID().uuidString,
                senderId: "system",
                content: "⚠️ Failed to send media: Secure connection not established. (Missing Public Key)",
                timestamp: Date(),
                type: .text
            )
            objectWillChange.send()
            messages.append(errorMessage)
            return
        }

        // Encode audio as base64 for encryption
        let audioBase64 = audioData.base64EncodedString()

        // Encrypt the audio data
        guard let encryptedData = IdentityManager.shared.encryptMessage(audioBase64, for: recipientPublicKey) else {
            DebugLogger.error("Failed to encrypt voice note", category: .crypto)
            return
        }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        // Create envelope with voice type
        let envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,
            recipientId: peer.id,
            encryptedContent: encryptedData.base64EncodedString(),
            timestamp: Date(),
            messageType: "voice",
            codeLanguage: nil,
            receiptType: nil,
            originalMessageId: nil,
            audioDuration: duration
        )

        guard let signedEnvelope = signEnvelope(envelope) else {
            DebugLogger.error("Failed to sign voice note", category: .crypto)
            return
        }

        // NOTE: Don't log recipient IDs in production

        // Send via mesh
        meshManager.sendEncryptedMessage(signedEnvelope, to: peer)

        // Add to local messages
        let message = Message(
            id: envelope.id,
            senderId: "me",
            content: "",
            timestamp: envelope.timestamp,
            type: .voice,
            audioDuration: duration,
            audioData: audioData
        )

        objectWillChange.send()
        messages.append(message)

        // Persist the sent message
        persistenceManager.saveSentMessage(
            id: envelope.id,
            recipientId: peer.id,
            recipientHandle: peer.handle,
            encryptedContent: encryptedData,
            plaintext: audioBase64,
            timestamp: envelope.timestamp,
            messageType: "voice",
            codeLanguage: nil,
            audioFilePath: audioURL.path
        )
    }

    func sendImageMessage(imageData: Data, width: Int, height: Int, thumbnail: Data?) async {
        guard let peer = peer, let meshManager = meshManager else {
            DebugLogger.error("ChatManager not initialized, cannot send image", category: .general)
            return
        }

        // Play send sound
        SoundManager.shared.messageSent()

        guard let recipientPublicKey = peer.publicKey else {
            DebugLogger.warning("Cannot send: peer has no public key", category: .crypto)
            SoundManager.shared.playErrorSound()
            
            let errorMessage = Message(
                id: UUID().uuidString,
                senderId: "system",
                content: "⚠️ Failed to send media: Secure connection not established. (Missing Public Key)",
                timestamp: Date(),
                type: .text
            )
            objectWillChange.send()
            messages.append(errorMessage)
            return
        }

        // Encode image as base64 for encryption
        let imageBase64 = imageData.base64EncodedString()

        // Encrypt the image data
        guard let encryptedData = IdentityManager.shared.encryptMessage(imageBase64, for: recipientPublicKey) else {
            DebugLogger.error("Failed to encrypt image", category: .crypto)
            return
        }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"
        let thumbnailBase64 = thumbnail?.base64EncodedString()

        // Create envelope with image type
        let envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,
            recipientId: peer.id,
            encryptedContent: encryptedData.base64EncodedString(),
            timestamp: Date(),
            messageType: "image",
            codeLanguage: nil,
            receiptType: nil,
            originalMessageId: nil,
            audioDuration: nil,
            imageWidth: width,
            imageHeight: height,
            imageThumbnail: thumbnailBase64
        )

        guard let signedEnvelope = signEnvelope(envelope) else {
            DebugLogger.error("Failed to sign image message", category: .crypto)
            return
        }

        // NOTE: Don't log recipient IDs or image dimensions in production

        // Send via mesh
        meshManager.sendEncryptedMessage(signedEnvelope, to: peer)

        // Add to local messages
        let message = Message(
            id: envelope.id,
            senderId: "me",
            content: "",
            timestamp: envelope.timestamp,
            type: .image,
            imageWidth: width,
            imageHeight: height,
            imageThumbnail: thumbnail
        )

        objectWillChange.send()
        messages.append(message)

        // Persist the sent message
        persistenceManager.saveSentMessage(
            id: envelope.id,
            recipientId: peer.id,
            recipientHandle: peer.handle,
            encryptedContent: encryptedData,
            plaintext: imageBase64,
            timestamp: envelope.timestamp,
            messageType: "image",
            codeLanguage: nil
        )
    }

    private func processReceivedMessage(_ envelope: MessageEnvelope) {
        // NOTE: Don't log message IDs in production - can be used for traffic analysis
        #if DEBUG
        DebugLogger.log("Processing received message", category: .crypto)
        #endif

        // Decrypt the message
        guard let encryptedData = Data(base64Encoded: envelope.encryptedContent) else {
            DebugLogger.error("Failed to decode base64 content", category: .crypto)
            return
        }

        #if DEBUG
        DebugLogger.log("Encrypted data size: \(encryptedData.count) bytes", category: .crypto)
        #endif

        guard let decryptedContent = IdentityManager.shared.decryptMessage(encryptedData) else {
            DebugLogger.error("Failed to decrypt message", category: .crypto)
            return
        }

        // NOTE: Never log decrypted content - security risk
        #if DEBUG
        DebugLogger.success("Decryption successful", category: .crypto)
        #endif

        // Create message
        let messageType = Message.MessageType(rawValue: envelope.messageType) ?? .text

        // Handle voice messages - decrypted content is base64 audio data
        var audioData: Data? = nil
        var content = decryptedContent
        if messageType == .voice {
            audioData = Data(base64Encoded: decryptedContent)
            content = "" // Voice messages don't have text content
            // NOTE: Don't log audio duration in production
        }

        let message = Message(
            id: envelope.id,
            senderId: envelope.senderId,
            content: content,
            timestamp: envelope.timestamp,
            type: messageType,
            codeLanguage: envelope.codeLanguage,
            audioDuration: envelope.audioDuration,
            audioData: audioData
        )

        // Add if not already exists
        if !messages.contains(where: { $0.id == message.id }) {
            // Explicitly notify before change to ensure SwiftUI updates
            objectWillChange.send()
            messages.append(message)
            
            // Fetch link previews if any
            fetchPreviews(for: message)

            // Play receive sound
            SoundManager.shared.messageReceived()

            // Persist the received message
            if let peer = peer {
                persistenceManager.saveReceivedMessage(envelope, peerHandle: peer.handle)
            }

            // Send read receipt since chat is open
            sendReceipt(for: message.id, type: .read)
        }
        // Silently skip duplicates
    }

    // MARK: - Link Preview Handling

    private func fetchPreviews(for message: Message) {
        guard linkPreviewsEnabled else { return }
        let urls = detectURLs(in: message.content)
        guard !urls.isEmpty else { return }

        Task {
            for url in urls {
                // Don't re-fetch if a preview already exists
                if linkPreviews[url.absoluteString] == nil {
                    if let previewData = await LinkPreviewService.shared.fetchPreview(for: url) {
                        // Update the dictionary on the main thread
                        linkPreviews[url.absoluteString] = previewData
                    }
                }
            }
        }
    }

    private func detectURLs(in text: String) -> [URL] {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            return matches.compactMap { $0.url }
        } catch {
            DebugLogger.error("Failed to create URL detector", category: .general)
            return []
        }
    }

    // MARK: - Receipt Handling

    private func setupReceiptListener() {
        guard let peer = peer else { return }
        let peerId = peer.id


        NotificationCenter.default.publisher(for: .didReceiveReceipt)
            .compactMap { $0.object as? MessageEnvelope }
            .filter { $0.senderId == peerId }
            .sink { [weak self] envelope in
                self?.handleReceipt(envelope)
            }
            .store(in: &cancellables)
    }

    private func handleReceipt(_ envelope: MessageEnvelope) {
        guard let originalId = envelope.originalMessageId,
              let receiptType = envelope.receiptType else {
            return
        }

        if let index = messages.firstIndex(where: { $0.id == originalId }) {
            if receiptType == "read" {
                messages[index].isRead = true
                messages[index].isDelivered = true
            } else if receiptType == "delivered" {
                messages[index].isDelivered = true
            }
        }
        // NOTE: Don't log message IDs in production
    }

    // MARK: - Group Chat Support

    /// Send a message to multiple recipients (group chat)
    func sendGroupMessage(_ content: String, groupId: String, recipientPeers: [PulsePeer], type: Message.MessageType = .text, language: String? = nil) {
        guard !recipientPeers.isEmpty else {
            DebugLogger.error("No recipients for group message", category: .general)
            return
        }

        // Play send sound
        SoundManager.shared.messageSent()

        // Get sender ID
        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        // Encrypt message for each recipient and send
        for recipientPeer in recipientPeers {
            guard let recipientPublicKey = recipientPeer.publicKey else {
                // Skip peers without public keys
                continue
            }

            // Encrypt for this specific recipient
            guard let encryptedData = IdentityManager.shared.encryptMessage(content, for: recipientPublicKey) else {
                DebugLogger.error("Failed to encrypt group message for recipient", category: .crypto)
                continue
            }

            // Create group message envelope
            let envelope = MessageEnvelope(
                id: UUID().uuidString,
                senderId: myPeerId,
                recipientId: recipientPeer.id,
                encryptedContent: encryptedData.base64EncodedString(),
                timestamp: Date(),
                messageType: type.rawValue,
                codeLanguage: language,
                groupId: groupId,
                recipientIds: recipientPeers.map { $0.id }
            )

            // NOTE: Don't log recipient handles in production

            // Send via mesh
            if let meshManager = meshManager {
                if let signedEnvelope = signEnvelope(envelope) {
                    meshManager.sendEncryptedMessage(signedEnvelope, to: recipientPeer)
                }
            }
        }

        // Add to local messages once (shared across all recipients in group)
        let messageId = UUID().uuidString
        let message = Message(
            id: messageId,
            senderId: "me",
            content: content,
            timestamp: Date(),
            type: type,
            codeLanguage: language
        )

        objectWillChange.send()
        messages.append(message)

        // Fetch link previews if any
        fetchPreviews(for: message)
    }

    private func sendReadReceiptsForUnreadMessages() {
        guard let peer = peer else { return }
        let unreadFromPeer = messages.filter { $0.senderId == peer.id && !$0.isRead }
        for message in unreadFromPeer {
            sendReceipt(for: message.id, type: .read)
        }
    }

    func sendReceipt(for messageId: String, type: MessageReceipt.ReceiptType) {
        guard let peer = peer, let meshManager = meshManager else { return }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        let envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,
            recipientId: peer.id,
            encryptedContent: "",
            timestamp: Date(),
            messageType: "receipt",
            codeLanguage: nil,
            receiptType: type.rawValue,
            originalMessageId: messageId
        )

        if let signedEnvelope = signEnvelope(envelope) {
            meshManager.sendEncryptedMessage(signedEnvelope, to: peer)
        }
    }

    // MARK: - Typing Indicator

    private func setupTypingListener() {
        guard let peer = peer else { return }

        NotificationCenter.default.publisher(for: .didReceiveTypingIndicator)
            .compactMap { $0.object as? TypingIndicator }
            .filter { $0.senderId == peer.id }
            .sink { [weak self] indicator in
                self?.peerIsTyping = indicator.isTyping

                // Auto-hide after 3 seconds if no update
                if indicator.isTyping {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.peerIsTyping = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    func userStartedTyping() {
        // Throttle typing indicator sends to once per 2 seconds
        if let lastSent = lastTypingSent, Date().timeIntervalSince(lastSent) < 2 {
            return
        }

        lastTypingSent = Date()
        sendTypingIndicator(isTyping: true)

        // Reset typing timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sendTypingIndicator(isTyping: false)
            }
        }
    }

    func userStoppedTyping() {
        typingTimer?.invalidate()
        typingTimer = nil
        sendTypingIndicator(isTyping: false)
    }

    private func sendTypingIndicator(isTyping: Bool) {
        guard let peer = peer, let meshManager = meshManager else { return }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        // Send as a lightweight envelope
        let envelope = MessageEnvelope(
            id: UUID().uuidString,
            senderId: myPeerId,
            recipientId: peer.id,
            encryptedContent: "",
            timestamp: Date(),
            messageType: "typing",
            codeLanguage: nil,
            receiptType: nil,
            originalMessageId: isTyping ? "true" : "false"
        )

        if let signedEnvelope = signEnvelope(envelope) {
            meshManager.sendEncryptedMessage(signedEnvelope, to: peer)
        }
    }

    // MARK: - Reactions

    func addReaction(_ emoji: String, toMessageId messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"
        let reaction = Reaction(emoji: emoji, userId: myPeerId)

        objectWillChange.send()
        messages[index].reactions.append(reaction)
    }

    func removeReaction(_ emoji: String, fromMessageId messageId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        let myPeerId = UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"

        objectWillChange.send()
        messages[index].reactions.removeAll { $0.emoji == emoji && $0.userId == myPeerId }
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
}
