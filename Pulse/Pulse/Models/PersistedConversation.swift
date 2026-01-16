//
//  PersistedConversation.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import SwiftData

@Model
final class PersistedConversation {
    @Attribute(.unique) var peerId: String
    var peerHandle: String
    var lastMessageTimestamp: Date
    var unreadCount: Int

    @Relationship(deleteRule: .cascade)
    var messages: [PersistedMessage] = []

    init(
        peerId: String,
        peerHandle: String,
        lastMessageTimestamp: Date = Date(),
        unreadCount: Int = 0
    ) {
        self.peerId = peerId
        self.peerHandle = peerHandle
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
    }

    /// Add a message to the conversation
    func addMessage(_ message: PersistedMessage) {
        messages.append(message)
        message.conversation = self
        lastMessageTimestamp = message.timestamp

        if !message.isRead && message.senderId != "me" {
            unreadCount += 1
        }
    }

    /// Mark all messages as read
    func markAllAsRead() {
        for message in messages where !message.isRead {
            message.isRead = true
        }
        unreadCount = 0
    }
}
