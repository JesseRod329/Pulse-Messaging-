//
//  PersistenceManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import SwiftData
import CryptoKit

@MainActor
final class PersistenceManager {
    static let shared = PersistenceManager()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    // MARK: - Sent Message Cache

    private struct CachedMessage {
        let plaintext: String
        let timestamp: Date
    }

    private var sentMessageCache: [String: CachedMessage] = [:]
    private let cacheMaxAge: TimeInterval = 7 * 24 * 60 * 60
    private let cacheMaxEntries = 1000
    private let plaintextKeychainKey = "pulse.local.plaintext.key"
    private let plaintextPrefix = "enc:"

    private func storeSentMessage(_ messageId: String, plaintext: String) {
        sentMessageCache[messageId] = CachedMessage(plaintext: plaintext, timestamp: Date())
        cleanupSentMessageCache()
    }

    private func loadOrCreatePlaintextKey() -> SymmetricKey? {
        if let keyData = KeychainManager.shared.load(forKey: plaintextKeychainKey) {
            return SymmetricKey(data: keyData)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        if KeychainManager.shared.save(keyData, forKey: plaintextKeychainKey) {
            return key
        }
        return nil
    }

    private func encryptPlaintext(_ plaintext: String) -> String? {
        guard let key = loadOrCreatePlaintextKey() else { return nil }
        let data = Data(plaintext.utf8)
        guard let sealedBox = try? AES.GCM.seal(data, using: key),
              let combined = sealedBox.combined else {
            return nil
        }
        return plaintextPrefix + combined.base64EncodedString()
    }

    private func decryptPlaintextIfNeeded(_ stored: String) -> String? {
        guard stored.hasPrefix(plaintextPrefix) else { return stored }
        let base64 = String(stored.dropFirst(plaintextPrefix.count))
        guard let combined = Data(base64Encoded: base64),
              let key = loadOrCreatePlaintextKey(),
              let sealedBox = try? AES.GCM.SealedBox(combined: combined),
              let decrypted = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }
        return String(data: decrypted, encoding: .utf8)
    }

    private func retrieveSentMessage(_ messageId: String) -> String? {
        guard let cached = sentMessageCache[messageId] else { return nil }

        if Date().timeIntervalSince(cached.timestamp) > cacheMaxAge {
            sentMessageCache.removeValue(forKey: messageId)
            return nil
        }

        return cached.plaintext
    }

    private func cleanupSentMessageCache() {
        let now = Date()
        let expired = sentMessageCache.filter { now.timeIntervalSince($0.value.timestamp) > cacheMaxAge }
        for id in expired.keys {
            sentMessageCache.removeValue(forKey: id)
        }

        if sentMessageCache.count > cacheMaxEntries {
            let sorted = sentMessageCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(sentMessageCache.count - cacheMaxEntries)
            for (id, _) in toRemove {
                sentMessageCache.removeValue(forKey: id)
            }
        }
    }

    private init() {
        let schema = Schema([
            PersistedMessage.self,
            PersistedConversation.self,
            PersistedGroup.self
        ])

        // Use default container (App Groups can be added later for widget support)
        // Ensure Application Support directory exists to avoid CoreData path errors
        if let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            do {
                try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("⚠️ Failed to create Application Support directory: \(error)")
            }
        }

        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false
        )

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Conversation Operations

    /// Get or create a conversation for a peer
    func getOrCreateConversation(peerId: String, peerHandle: String) -> PersistedConversation {
        let descriptor = FetchDescriptor<PersistedConversation>(
            predicate: #Predicate { $0.peerId == peerId }
        )

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let conversation = PersistedConversation(peerId: peerId, peerHandle: peerHandle)
        context.insert(conversation)
        try? context.save()
        return conversation
    }

    /// Get all conversations sorted by last message
    func getAllConversations() -> [PersistedConversation] {
        let descriptor = FetchDescriptor<PersistedConversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Message Operations

    /// Save a sent message (already have plaintext, need to store encrypted)
    func saveSentMessage(
        id: String,
        recipientId: String,
        recipientHandle: String,
        encryptedContent: Data,
        plaintext: String,
        timestamp: Date,
        messageType: String,
        codeLanguage: String?,
        audioFilePath: String? = nil
    ) {
        let conversation = getOrCreateConversation(peerId: recipientId, peerHandle: recipientHandle)

        let encryptedPlaintext = encryptPlaintext(plaintext)
        let message = PersistedMessage(
            id: id,
            senderId: "me",
            recipientId: recipientId,
            encryptedContent: encryptedContent,
            timestamp: timestamp,
            isRead: true, // Our own messages are always "read"
            messageType: messageType,
            codeLanguage: codeLanguage,
            audioFilePath: audioFilePath,
            plaintext: encryptedPlaintext
        )

        conversation.addMessage(message)
        try? context.save()

        // Store plaintext in memory cache for immediate display
        storeSentMessage(id, plaintext: plaintext)
    }

    /// Save a received message from envelope
    func saveReceivedMessage(_ envelope: MessageEnvelope, peerHandle: String) {
        let conversation = getOrCreateConversation(peerId: envelope.senderId, peerHandle: peerHandle)

        // Check if message already exists
        let existingDescriptor = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.id == envelope.id }
        )
        if (try? context.fetch(existingDescriptor).first) != nil {
            return // Already saved
        }

        let message = PersistedMessage(from: envelope)
        conversation.addMessage(message)
        try? context.save()
    }

    /// Load messages for a peer, decrypting on read
    func loadMessages(for peerId: String) -> [Message] {
        let descriptor = FetchDescriptor<PersistedConversation>(
            predicate: #Predicate { $0.peerId == peerId }
        )

        guard let conversation = try? context.fetch(descriptor).first else {
            return []
        }

        // Sort messages by timestamp
        let sortedMessages = conversation.messages.sorted { $0.timestamp < $1.timestamp }

        // Decrypt and convert to Message objects
        return sortedMessages.compactMap { persistedMessage in
            // For sent messages ("me"), check stored plaintext or cache
            if persistedMessage.senderId == "me" {
                if let storedPlaintext = persistedMessage.plaintext,
                   let plaintext = decryptPlaintextIfNeeded(storedPlaintext) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                } else if let plaintext = retrieveSentMessage(persistedMessage.id) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                } else {
                    // Cache expired or not found - placeholder
                    return persistedMessage.toMessage(decryptedContent: "[Message content not available]")
                }
            } else {
                // Received messages - decrypt
                guard let decrypted = IdentityManager.shared.decryptMessage(persistedMessage.encryptedContent) else {
                    return nil
                }
                return persistedMessage.toMessage(decryptedContent: decrypted)
            }
        }
    }

    /// Mark conversation as read
    func markConversationAsRead(peerId: String) {
        let descriptor = FetchDescriptor<PersistedConversation>(
            predicate: #Predicate { $0.peerId == peerId }
        )

        if let conversation = try? context.fetch(descriptor).first {
            conversation.markAllAsRead()
            try? context.save()
        }
    }

    /// Delete a conversation and all its messages
    func deleteConversation(peerId: String) {
        let descriptor = FetchDescriptor<PersistedConversation>(
            predicate: #Predicate { $0.peerId == peerId }
        )

        if let conversation = try? context.fetch(descriptor).first {
            context.delete(conversation)
            try? context.save()
        }
    }

    /// Delete a single message by ID
    func deleteMessage(id: String) -> String? {
        let descriptor = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.id == id }
        )

        if let message = try? context.fetch(descriptor).first {
            let audioFilePath = message.audioFilePath
            context.delete(message)
            try? context.save()
            return audioFilePath
        }
        return nil
    }

    /// Get all audio file paths referenced by messages
    func getAllAudioFilePaths() -> [String] {
        let descriptor = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.audioFilePath != nil }
        )

        let messages = (try? context.fetch(descriptor)) ?? []
        return messages.compactMap { $0.audioFilePath }
    }

    /// Get unread message count across all conversations
    func totalUnreadCount() -> Int {
        let conversations = getAllConversations()
        return conversations.reduce(0) { $0 + $1.unreadCount }
    }

    /// Delete all persisted messages, conversations, and groups
    func deleteAllData() {
        let messageDescriptor = FetchDescriptor<PersistedMessage>()
        let conversationDescriptor = FetchDescriptor<PersistedConversation>()
        let groupDescriptor = FetchDescriptor<PersistedGroup>()

        let messages = (try? context.fetch(messageDescriptor)) ?? []
        let conversations = (try? context.fetch(conversationDescriptor)) ?? []
        let groups = (try? context.fetch(groupDescriptor)) ?? []

        for message in messages { context.delete(message) }
        for conversation in conversations { context.delete(conversation) }
        for group in groups { context.delete(group) }

        try? context.save()
    }

    // MARK: - Search Operations

    /// Search messages across all conversations
    func searchMessages(
        query: String,
        peerId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [PersistedMessage] {
        var descriptor = FetchDescriptor<PersistedMessage>()

        // Build predicates (without case-insensitive functions)
        var predicates: [Predicate<PersistedMessage>] = []

        // Filter by peer if specified
        if let peerId = peerId {
            predicates.append(#Predicate { $0.recipientId == peerId || $0.senderId == peerId })
        }

        // Filter by date range
        if let startDate = startDate {
            predicates.append(#Predicate { $0.timestamp >= startDate })
        }
        if let endDate = endDate {
            predicates.append(#Predicate { $0.timestamp <= endDate })
        }

        // Combine predicates with AND logic
        if !predicates.isEmpty {
            var combined = predicates[0]
            for predicate in predicates.dropFirst() {
                let current = combined
                let next = predicate
                combined = #Predicate { message in
                    current.evaluate(message) && next.evaluate(message)
                }
            }
            descriptor.predicate = combined
        }

        // Sort by timestamp descending (newest first)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]

        var results = (try? context.fetch(descriptor)) ?? []

        // Apply text search client-side (case-insensitive)
        // For sent messages, check cache. For received messages, decrypt to search.
        if !query.isEmpty {
            let searchTerm = query.lowercased()
            results = results.filter { message in
                if message.senderId == "me" {
                    if let plaintext = retrieveSentMessage(message.id) {
                        return plaintext.lowercased().contains(searchTerm)
                    }
                    if let storedPlaintext = message.plaintext,
                       let plaintext = decryptPlaintextIfNeeded(storedPlaintext) {
                        return plaintext.lowercased().contains(searchTerm)
                    }
                    return false
                } else {
                    if let decrypted = IdentityManager.shared.decryptMessage(message.encryptedContent) {
                        return decrypted.lowercased().contains(searchTerm) ||
                        message.messageType.lowercased().contains(searchTerm)
                    }
                    return false
                }
            }
        }

        return results
    }

    /// Search messages for a specific conversation
    func searchMessages(
        in peerId: String,
        query: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [Message] {
        let persistedMessages = searchMessages(
            query: query,
            peerId: peerId,
            startDate: startDate,
            endDate: endDate
        )

        // Decrypt and convert to Message objects
        return persistedMessages.compactMap { persistedMessage in
            if persistedMessage.senderId == "me" {
                if let plaintext = retrieveSentMessage(persistedMessage.id) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
                if let storedPlaintext = persistedMessage.plaintext,
                   let plaintext = decryptPlaintextIfNeeded(storedPlaintext) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
            } else {
                guard let decrypted = IdentityManager.shared.decryptMessage(persistedMessage.encryptedContent) else {
                    return nil
                }
                return persistedMessage.toMessage(decryptedContent: decrypted)
            }
            return nil
        }
    }

    /// Get all messages across all conversations (for global search)
    func allMessages() -> [Message] {
        let descriptor = FetchDescriptor<PersistedMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        guard let persistedMessages = try? context.fetch(descriptor) else {
            return []
        }

        return persistedMessages.compactMap { persistedMessage in
            if persistedMessage.senderId == "me" {
                if let plaintext = retrieveSentMessage(persistedMessage.id) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
                if let storedPlaintext = persistedMessage.plaintext,
                   let plaintext = decryptPlaintextIfNeeded(storedPlaintext) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
            } else {
                guard let decrypted = IdentityManager.shared.decryptMessage(persistedMessage.encryptedContent) else {
                    return nil
                }
                return persistedMessage.toMessage(decryptedContent: decrypted)
            }
            return nil
        }
    }

    // MARK: - Group Operations

    /// Save a new group
    func saveGroup(_ group: Group) {
        // Check if group already exists
        let descriptor = FetchDescriptor<PersistedGroup>(
            predicate: #Predicate { $0.id == group.id }
        )

        if (try? context.fetch(descriptor).first) != nil {
            return // Already exists
        }

        let persistedGroup = PersistedGroup(
            id: group.id,
            name: group.name,
            creatorId: group.creatorId,
            memberIds: group.members,
            createdAt: group.createdAt,
            lastMessageTimestamp: group.lastMessageTime
        )

        context.insert(persistedGroup)
        try? context.save()
    }

    /// Get all groups sorted by last message
    func getAllGroups() -> [Group] {
        let descriptor = FetchDescriptor<PersistedGroup>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )

        let persistedGroups = (try? context.fetch(descriptor)) ?? []
        return persistedGroups.map { $0.toGroup() }
    }

    /// Get a specific group by ID
    func getGroup(id: String) -> Group? {
        let descriptor = FetchDescriptor<PersistedGroup>(
            predicate: #Predicate { $0.id == id }
        )

        return try? context.fetch(descriptor).first?.toGroup()
    }

    /// Get persisted group by ID (for message operations)
    func getPersistedGroup(id: String) -> PersistedGroup? {
        let descriptor = FetchDescriptor<PersistedGroup>(
            predicate: #Predicate { $0.id == id }
        )

        return try? context.fetch(descriptor).first
    }

    /// Update group's last message timestamp
    func updateGroupLastMessage(groupId: String, timestamp: Date) {
        if let group = getPersistedGroup(id: groupId) {
            group.lastMessageTimestamp = timestamp
            try? context.save()
        }
    }

    /// Delete a group and all its messages
    func deleteGroup(id: String) {
        let descriptor = FetchDescriptor<PersistedGroup>(
            predicate: #Predicate { $0.id == id }
        )

        if let group = try? context.fetch(descriptor).first {
            context.delete(group)
            try? context.save()
        }
    }

    /// Add a message to a group
    func saveGroupMessage(
        groupId: String,
        messageId: String,
        senderId: String,
        content: String,
        timestamp: Date,
        messageType: String = "text"
    ) {
        guard let group = getPersistedGroup(id: groupId) else { return }

        // For group messages, store plaintext in cache for sender
        if senderId == "me" {
            storeSentMessage(messageId, plaintext: content)
        }

        let encryptedPlaintext = senderId == "me" ? encryptPlaintext(content) : nil
        let message = PersistedMessage(
            id: messageId,
            senderId: senderId,
            recipientId: groupId,
            encryptedContent: Data(),
            timestamp: timestamp,
            isRead: senderId == "me",
            messageType: messageType,
            codeLanguage: nil,
            audioFilePath: nil,
            plaintext: encryptedPlaintext
        )

        group.addMessage(message)
        try? context.save()
    }

    /// Load messages for a group
    func loadGroupMessages(groupId: String) -> [Message] {
        guard let group = getPersistedGroup(id: groupId) else { return [] }

        let sortedMessages = group.messages.sorted { $0.timestamp < $1.timestamp }

        return sortedMessages.compactMap { persistedMessage in
            // Group messages from sender are stored encrypted but sender can retrieve from cache
            if persistedMessage.senderId == "me" {
                if let plaintext = retrieveSentMessage(persistedMessage.id) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
                if let storedPlaintext = persistedMessage.plaintext,
                   let plaintext = decryptPlaintextIfNeeded(storedPlaintext) {
                    return persistedMessage.toMessage(decryptedContent: plaintext)
                }
            } else {
                // Received messages from others in group
                if let decrypted = IdentityManager.shared.decryptMessage(persistedMessage.encryptedContent) {
                    return persistedMessage.toMessage(decryptedContent: decrypted)
                }
            }
            return nil
        }
    }
}
