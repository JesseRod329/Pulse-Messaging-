//
//  Message.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation

// MARK: - Reaction Model

struct Reaction: Identifiable, Codable, Hashable {
    let id: String // UUID for uniqueness
    let emoji: String // The emoji character(s)
    let userId: String // Who reacted
    let timestamp: Date

    init(emoji: String, userId: String, timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.emoji = emoji
        self.userId = userId
        self.timestamp = timestamp
    }
}

struct Message: Identifiable, Codable {
    let id: String
    let senderId: String
    let content: String
    let timestamp: Date
    var isRead: Bool
    var isDelivered: Bool
    let type: MessageType
    let codeLanguage: String?

    // Voice note properties
    let audioDuration: TimeInterval?
    let audioData: Data?

    // Image properties
    let imageWidth: Int?
    let imageHeight: Int?
    let imageThumbnail: Data? // Small base64 thumbnail

    // Reaction properties
    var reactions: [Reaction] = [] // Emoji reactions on this message

    init(id: String, senderId: String, content: String, timestamp: Date, isRead: Bool = false, isDelivered: Bool = false, type: MessageType = .text, codeLanguage: String? = nil, audioDuration: TimeInterval? = nil, audioData: Data? = nil, imageWidth: Int? = nil, imageHeight: Int? = nil, imageThumbnail: Data? = nil, reactions: [Reaction] = []) {
        self.id = id
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
        self.isDelivered = isDelivered
        self.type = type
        self.codeLanguage = codeLanguage
        self.audioDuration = audioDuration
        self.audioData = audioData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageThumbnail = imageThumbnail
        self.reactions = reactions
    }

    enum MessageType: String, Codable {
        case text
        case code
        case voice
        case image
    }

    /// Status for display
    var status: MessageStatus {
        if isRead { return .read }
        if isDelivered { return .delivered }
        return .sent
    }
}

enum MessageStatus {
    case sending
    case sent
    case delivered
    case read

    var icon: String {
        switch self {
        case .sending: return "circle"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        }
    }
}

struct MessageEnvelope: Codable {
    let id: String
    let senderId: String
    let recipientId: String // For 1-to-1 messages
    let encryptedContent: String // Base64-encoded encrypted data
    let timestamp: Date
    let messageType: String // "text", "code", "voice", "image", "receipt", "typing"
    let codeLanguage: String?
    var signature: Data? // Signature of the payload
    var senderSigningPublicKey: Data? // Sender signing public key
    var receiptType: String? // "delivered" or "read"
    var originalMessageId: String? // For receipts, the message being acknowledged
    var audioDuration: TimeInterval? // Duration for voice messages
    var imageWidth: Int? // Image width
    var imageHeight: Int? // Image height
    var imageThumbnail: String? // Base64-encoded thumbnail

    // Group chat support
    var groupId: String? // For group messages
    var recipientIds: [String]? // For group messages (list of peer IDs)
}

extension MessageEnvelope {
    func signaturePayload() -> Data? {
        let timestampValue = String(Int(timestamp.timeIntervalSince1970 * 1000))
        let language = codeLanguage ?? ""
        let receipt = receiptType ?? ""
        let originalId = originalMessageId ?? ""
        let audioDurationValue = audioDuration.map { String(format: "%.3f", $0) } ?? ""
        let imageWidthValue = imageWidth.map { String($0) } ?? ""
        let imageHeightValue = imageHeight.map { String($0) } ?? ""
        let thumbnailValue = imageThumbnail ?? ""
        let groupValue = groupId ?? ""
        let recipientsValue = recipientIds?.joined(separator: ",") ?? ""
        let payload = [
            id,
            senderId,
            recipientId,
            timestampValue,
            messageType,
            language,
            encryptedContent,
            receipt,
            originalId,
            audioDurationValue,
            imageWidthValue,
            imageHeightValue,
            thumbnailValue,
            groupValue,
            recipientsValue
        ].joined(separator: "|")
        return payload.data(using: .utf8)
    }
}

/// Receipt sent when message is delivered or read
struct MessageReceipt: Codable {
    let messageId: String
    let type: ReceiptType
    let timestamp: Date

    enum ReceiptType: String, Codable {
        case delivered
        case read
    }
}

/// Typing indicator
struct TypingIndicator: Codable {
    let senderId: String
    let isTyping: Bool
    let timestamp: Date
}

extension Notification.Name {
    static let didReceiveMessage = Notification.Name("didReceiveMessage")
    static let messageSendFailed = Notification.Name("messageSendFailed")
    static let didReceiveReceipt = Notification.Name("didReceiveReceipt")
    static let didReceiveTypingIndicator = Notification.Name("didReceiveTypingIndicator")
}
