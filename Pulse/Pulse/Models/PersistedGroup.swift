//
//  PersistedGroup.swift
//  Pulse
//
//  SwiftData model for group chat persistence.
//

import Foundation
import SwiftData

@Model
final class PersistedGroup {
    @Attribute(.unique) var id: String
    var name: String
    var creatorId: String
    var createdAt: Date
    var lastMessageTimestamp: Date
    var unreadCount: Int

    // Members stored as comma-separated peer IDs
    private var memberIds: String

    @Relationship(deleteRule: .cascade)
    var messages: [PersistedMessage] = []

    init(
        id: String,
        name: String,
        creatorId: String,
        memberIds: [String],
        createdAt: Date = Date(),
        lastMessageTimestamp: Date = Date(),
        unreadCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.memberIds = memberIds.joined(separator: ",")
        self.createdAt = createdAt
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
    }

    // MARK: - Convenience accessors

    var members: [String] {
        memberIds.split(separator: ",").map(String.init)
    }

    func setMembers(_ ids: [String]) {
        memberIds = ids.joined(separator: ",")
    }

    // MARK: - Message management

    func addMessage(_ message: PersistedMessage) {
        messages.append(message)
        message.conversation = nil // Groups don't use conversation relationship
        lastMessageTimestamp = message.timestamp

        if !message.isRead && message.senderId != "me" {
            unreadCount += 1
        }
    }

    func markAllAsRead() {
        for message in messages where !message.isRead {
            message.isRead = true
        }
        unreadCount = 0
    }

    // MARK: - Group conversion

    func toGroup() -> Group {
        Group(
            id: id,
            name: name,
            creatorId: creatorId,
            members: members,
            createdAt: createdAt,
            lastMessageTime: lastMessageTimestamp
        )
    }
}
