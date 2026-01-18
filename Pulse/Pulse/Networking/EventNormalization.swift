//
//  EventNormalization.swift
//  Pulse
//
//  Nostr event normalization helpers for hashing and NIP-57.
//

import Foundation
import CryptoKit

extension NostrEvent {
    func normalizedEventJSONData() throws -> Data {
        try NostrNormalization.canonicalEventJSONData(
            pubkey: pubkey,
            createdAt: created_at,
            kind: kind,
            tags: tags,
            content: content
        )
    }

    func normalizedEventJSONString() throws -> String {
        try NostrNormalization.canonicalEventJSONString(
            pubkey: pubkey,
            createdAt: created_at,
            kind: kind,
            tags: tags,
            content: content
        )
    }

    /// SHA-256 hash of the normalized event JSON (hex).
    func descriptionHash() throws -> String {
        let data = try normalizedEventJSONData()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
