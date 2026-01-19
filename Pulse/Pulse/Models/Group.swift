//
//  Group.swift
//  Pulse
//
//  Group chat model for multi-recipient conversations.
//

import Foundation

struct Group: Identifiable, Codable {
    let id: String
    let name: String
    let creatorId: String
    let createdAt: Date
    var members: [String] // Array of peer IDs
    var lastMessageTime: Date

    var memberCount: Int {
        members.count
    }

    var displayName: String {
        name.isEmpty ? "Group Chat" : name
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        creatorId: String,
        members: [String],
        createdAt: Date = Date(),
        lastMessageTime: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.members = members
        self.createdAt = createdAt
        self.lastMessageTime = lastMessageTime
    }

    mutating func addMember(_ peerId: String) {
        if !members.contains(peerId) {
            members.append(peerId)
        }
    }

    mutating func removeMember(_ peerId: String) {
        members.removeAll { $0 == peerId }
    }

    func isMember(_ peerId: String) -> Bool {
        members.contains(peerId)
    }
}

/// Payload for inviting peers to a group over the mesh
struct GroupInvitePayload: Codable {
    let id: String
    let name: String
    let creatorId: String
    let members: [String]
    let createdAt: Date
}
