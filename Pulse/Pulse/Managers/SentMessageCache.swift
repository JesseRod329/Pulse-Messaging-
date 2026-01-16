//
//  SentMessageCache.swift
//  Pulse
//
//  In-memory cache for sent message plaintext.
//  Messages are encrypted for recipients, so sender can't decrypt them.
//  This cache allows displaying sent messages while maintaining security.
//

import Foundation

@MainActor
final class SentMessageCache {
    static let shared = SentMessageCache()

    private struct CachedMessage {
        let plaintext: String
        let timestamp: Date
    }

    private var cache: [String: CachedMessage] = [:]
    private let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxEntries = 1000

    private init() {}

    func store(messageId: String, plaintext: String) {
        cache[messageId] = CachedMessage(plaintext: plaintext, timestamp: Date())
        cleanup()
    }

    func retrieve(messageId: String) -> String? {
        guard let cached = cache[messageId] else { return nil }

        if Date().timeIntervalSince(cached.timestamp) > maxAge {
            cache.removeValue(forKey: messageId)
            return nil
        }

        return cached.plaintext
    }

    func remove(messageId: String) {
        cache.removeValue(forKey: messageId)
    }

    func clear() {
        cache.removeAll()
    }

    private func cleanup() {
        let now = Date()
        let expired = cache.filter { now.timeIntervalSince($0.value.timestamp) > maxAge }
        for id in expired.keys {
            cache.removeValue(forKey: id)
        }

        if cache.count > maxEntries {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count - maxEntries)
            for (id, _) in toRemove {
                cache.removeValue(forKey: id)
            }
        }
    }
}
