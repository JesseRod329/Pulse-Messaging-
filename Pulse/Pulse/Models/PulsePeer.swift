//
//  PulsePeer.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation

struct PulsePeer: Identifiable, Codable {
    let id: String
    let handle: String
    var status: PeerStatus
    var place: Place?
    let techStack: [String]
    var distance: Double
    var publicKey: Data? // For E2E encryption
    var signingPublicKey: Data? // For message authenticity
    var lastSeen: Date = Date()

    // NIP-57 Lightning/Zap support
    var lightningAddress: String?  // lud16 from Nostr kind 0 metadata (e.g., user@getalby.com)
    var nostrPubkey: String?       // 32-byte hex pubkey for Nostr protocol

    var isActive: Bool {
        status == .active
    }

    /// Whether this peer can receive zaps
    var canReceiveZaps: Bool {
        lightningAddress != nil && !lightningAddress!.isEmpty
    }
}

enum PeerStatus: Int, Codable {
    case active = 0    // Green light - open to chat
    case flowState = 1 // Yellow - in flow, visible but DND
    case idle = 2      // Gray - idle/away

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .flowState: return "Flow State"
        case .idle: return "Idle"
        }
    }

    var emoji: String {
        switch self {
        case .active: return "🟢"
        case .flowState: return "🟡"
        case .idle: return "⚪"
        }
    }
}
