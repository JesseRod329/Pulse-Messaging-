//
//  MessageDeduplicationService.swift
//  Pulse
//
//  Bloom filter-based message deduplication inspired by BitChat.
//  Prevents routing loops and duplicate message processing in mesh networks.
//

import Foundation
import CryptoKit

/// Bloom filter for efficient duplicate detection
struct BloomFilter {
    private var bits: [Bool]
    private let size: Int
    private let hashCount: Int

    init(size: Int = 10000, hashCount: Int = 7) {
        self.size = size
        self.hashCount = hashCount
        self.bits = [Bool](repeating: false, count: size)
    }

    /// Generate hash indices for an item
    private func hashIndices(for item: String) -> [Int] {
        var indices: [Int] = []
        let data = Data(item.utf8)

        for i in 0..<hashCount {
            // Create unique hash by appending index
            var hashData = data
            hashData.append(contentsOf: withUnsafeBytes(of: i) { Array($0) })

            let hash = SHA256.hash(data: hashData)
            let hashBytes = Array(hash)

            // Convert first 4 bytes to index
            let index = hashBytes.prefix(4).reduce(0) { result, byte in
                (result << 8) | Int(byte)
            } % size

            indices.append(abs(index))
        }

        return indices
    }

    /// Add an item to the filter
    mutating func insert(_ item: String) {
        for index in hashIndices(for: item) {
            bits[index] = true
        }
    }

    /// Check if an item might be in the filter
    func mightContain(_ item: String) -> Bool {
        for index in hashIndices(for: item) {
            if !bits[index] {
                return false
            }
        }
        return true
    }

    /// Reset the filter
    mutating func clear() {
        bits = [Bool](repeating: false, count: size)
    }

    /// Approximate fill ratio
    var fillRatio: Double {
        Double(bits.filter { $0 }.count) / Double(size)
    }
}

/// Service for deduplicating messages across the mesh network
@MainActor
final class MessageDeduplicationService: ObservableObject {
    static let shared = MessageDeduplicationService()

    // Bloom filters for different time windows
    private var recentFilter = BloomFilter(size: 10000, hashCount: 7)
    private var olderFilter = BloomFilter(size: 10000, hashCount: 7)

    // Exact match cache for recent messages (more accurate but limited size)
    private var recentMessageIds: Set<String> = []
    private let maxRecentIds = 5000

    // Rotation timer
    private nonisolated(unsafe) var rotationTimerStorage: Timer?
    private var rotationTimer: Timer? {
        get { rotationTimerStorage }
        set { rotationTimerStorage = newValue }
    }
    private let rotationInterval: TimeInterval = 300 // 5 minutes

    @Published var duplicatesBlocked: Int = 0
    @Published var messagesProcessed: Int = 0

    private init() {
        startRotationTimer()
    }

    /// Generate a unique key for a packet
    private func packetKey(_ packet: RoutablePacket) -> String {
        "\(packet.senderId):\(packet.id):\(Int(packet.originTimestamp.timeIntervalSince1970))"
    }

    /// Generate a unique key for a message envelope
    private func envelopeKey(_ envelope: MessageEnvelope) -> String {
        "\(envelope.senderId):\(envelope.id):\(Int(envelope.timestamp.timeIntervalSince1970))"
    }

    private func envelopeKey(_ envelope: RoutableMessageEnvelope) -> String {
        "\(envelope.senderId):\(envelope.id):\(Int(envelope.timestamp.timeIntervalSince1970))"
    }

    /// Check if a packet is a duplicate and mark it as seen
    func isDuplicate(_ packet: RoutablePacket) -> Bool {
        let key = packetKey(packet)

        // Check exact match first
        if recentMessageIds.contains(key) {
            duplicatesBlocked += 1
            return true
        }

        // Check bloom filters
        if recentFilter.mightContain(key) || olderFilter.mightContain(key) {
            // Bloom filter positive - might be false positive, but treat as duplicate
            duplicatesBlocked += 1
            return true
        }

        // Not a duplicate - mark as seen
        markAsSeen(key)
        messagesProcessed += 1
        return false
    }

    /// Check if a message envelope is a duplicate
    func isDuplicate(_ envelope: MessageEnvelope) -> Bool {
        let key = envelopeKey(envelope)

        if recentMessageIds.contains(key) {
            duplicatesBlocked += 1
            return true
        }

        if recentFilter.mightContain(key) || olderFilter.mightContain(key) {
            duplicatesBlocked += 1
            return true
        }

        markAsSeen(key)
        messagesProcessed += 1
        return false
    }

    /// Check if a routable message envelope is a duplicate
    func isDuplicate(_ envelope: RoutableMessageEnvelope) -> Bool {
        let key = envelopeKey(envelope)

        if recentMessageIds.contains(key) {
            duplicatesBlocked += 1
            return true
        }

        if recentFilter.mightContain(key) || olderFilter.mightContain(key) {
            duplicatesBlocked += 1
            return true
        }

        markAsSeen(key)
        messagesProcessed += 1
        return false
    }

    /// Mark a message key as seen
    private func markAsSeen(_ key: String) {
        // Add to exact cache
        if recentMessageIds.count >= maxRecentIds {
            // Remove oldest (not truly FIFO, but good enough)
            recentMessageIds.removeFirst()
        }
        recentMessageIds.insert(key)

        // Add to bloom filter
        recentFilter.insert(key)
    }

    /// Rotate bloom filters to prevent fill-up
    private func startRotationTimer() {
        rotationTimer = Timer.scheduledTimer(
            withTimeInterval: rotationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rotateFilters()
            }
        }
    }

    private func rotateFilters() {
        // Move recent to older, clear recent
        olderFilter = recentFilter
        recentFilter = BloomFilter(size: 10000, hashCount: 7)

        // Also trim exact cache
        if recentMessageIds.count > maxRecentIds / 2 {
            let toRemove = recentMessageIds.count - (maxRecentIds / 2)
            for _ in 0..<toRemove {
                recentMessageIds.removeFirst()
            }
        }

        print("Dedup filters rotated. Processed: \(messagesProcessed), Blocked: \(duplicatesBlocked)")
    }

    /// Get deduplication statistics
    var stats: (processed: Int, blocked: Int, filterFill: Double) {
        (messagesProcessed, duplicatesBlocked, recentFilter.fillRatio)
    }

    /// Reset all filters and counters
    func reset() {
        recentFilter.clear()
        olderFilter.clear()
        recentMessageIds.removeAll()
        duplicatesBlocked = 0
        messagesProcessed = 0
    }
}
