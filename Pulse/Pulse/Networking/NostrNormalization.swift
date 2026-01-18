//
//  NostrNormalization.swift
//  Pulse
//
//  Canonical JSON serialization for Nostr/NIP-57.
//

import Foundation

enum NostrNormalizationError: Error, LocalizedError {
    case invalidEventSerialization

    var errorDescription: String? {
        switch self {
        case .invalidEventSerialization:
            return "Failed to serialize Nostr event deterministically"
        }
    }
}

enum NostrNormalization {
    static func canonicalEventArray(
        pubkey: String,
        createdAt: Int,
        kind: Int,
        tags: [[String]],
        content: String
    ) -> [Any] {
        [0, pubkey, createdAt, kind, tags, content]
    }

    static func canonicalEventJSONData(
        pubkey: String,
        createdAt: Int,
        kind: Int,
        tags: [[String]],
        content: String
    ) throws -> Data {
        let eventArray = canonicalEventArray(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content
        )
        guard JSONSerialization.isValidJSONObject(eventArray) else {
            throw NostrNormalizationError.invalidEventSerialization
        }
        return try JSONSerialization.data(withJSONObject: eventArray, options: [])
    }

    static func canonicalEventJSONString(
        pubkey: String,
        createdAt: Int,
        kind: Int,
        tags: [[String]],
        content: String
    ) throws -> String {
        let data = try canonicalEventJSONData(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw NostrNormalizationError.invalidEventSerialization
        }
        return string
    }
}
