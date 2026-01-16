//
//  PersistedMessage.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import SwiftData

@Model
final class PersistedMessage {
    @Attribute(.unique) var id: String
    var senderId: String
    var recipientId: String // For 1-to-1 messages
    var encryptedContent: Data  // Store encrypted, decrypt on read
    var timestamp: Date
    var isRead: Bool
    var messageType: String
    var codeLanguage: String?
    var audioDuration: TimeInterval? // Duration for voice messages
    var audioFilePath: String? // Path to audio file on disk (for cleanup)
    var imageWidth: Int? // Image dimensions
    var imageHeight: Int?
    var imageThumbnail: Data? // Thumbnail data for images
    var plaintext: String? // Plaintext for sent messages (stored locally)

    // Group chat support
    var groupId: String? // For group messages
    private var recipientIdsList: String? // Comma-separated list of recipient IDs for groups

    @Relationship(inverse: \PersistedConversation.messages)
    var conversation: PersistedConversation?

    init(
        id: String,
        senderId: String,
        recipientId: String,
        encryptedContent: Data,
        timestamp: Date,
        isRead: Bool = false,
        messageType: String = "text",
        codeLanguage: String? = nil,
        audioDuration: TimeInterval? = nil,
        audioFilePath: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageThumbnail: Data? = nil,
        plaintext: String? = nil,
        groupId: String? = nil,
        recipientIdsList: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.encryptedContent = encryptedContent
        self.timestamp = timestamp
        self.isRead = isRead
        self.messageType = messageType
        self.codeLanguage = codeLanguage
        self.audioDuration = audioDuration
        self.audioFilePath = audioFilePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageThumbnail = imageThumbnail
        self.plaintext = plaintext
        self.groupId = groupId
        self.recipientIdsList = recipientIdsList
    }

    /// Create from MessageEnvelope (for persisting received messages)
    convenience init(from envelope: MessageEnvelope) {
        let encryptedData = Data(base64Encoded: envelope.encryptedContent) ?? Data()
        let thumbnailData = envelope.imageThumbnail.flatMap { Data(base64Encoded: $0) }
        let recipientIdsString = envelope.recipientIds?.joined(separator: ",")
        self.init(
            id: envelope.id,
            senderId: envelope.senderId,
            recipientId: envelope.recipientId,
            encryptedContent: encryptedData,
            timestamp: envelope.timestamp,
            isRead: false,
            messageType: envelope.messageType,
            codeLanguage: envelope.codeLanguage,
            audioDuration: envelope.audioDuration,
            audioFilePath: nil,
            imageWidth: envelope.imageWidth,
            imageHeight: envelope.imageHeight,
            imageThumbnail: thumbnailData,
            groupId: envelope.groupId,
            recipientIdsList: recipientIdsString
        )
    }

    /// Convert to Message after decryption
    func toMessage(decryptedContent: String) -> Message {
        let type = Message.MessageType(rawValue: messageType) ?? .text

        // For voice messages, the decrypted content is base64-encoded audio data
        var audioData: Data? = nil
        if type == .voice {
            audioData = Data(base64Encoded: decryptedContent)
        }

        // For image messages, the decrypted content is base64-encoded image data
        // Image data is embedded in content field as base64

        return Message(
            id: id,
            senderId: senderId,
            content: (type == .voice || type == .image) ? "" : decryptedContent,
            timestamp: timestamp,
            isRead: isRead,
            type: type,
            codeLanguage: codeLanguage,
            audioDuration: audioDuration,
            audioData: audioData,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            imageThumbnail: imageThumbnail
        )
    }
}
