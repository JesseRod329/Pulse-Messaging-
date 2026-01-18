//
//  NostrIdentityManager.swift
//  Pulse
//
//  Manages Nostr identity lifecycle - creation, storage, and retrieval.
//  Provides observable state for UI integration.
//

import Foundation
import Combine

/// Manages Nostr identity for protocol compliance
@MainActor
final class NostrIdentityManager: ObservableObject {
    static let shared = NostrIdentityManager()

    @Published private(set) var nostrIdentity: NostrIdentity?
    @Published private(set) var isLoaded = false

    private init() {
        loadIdentity()
    }

    // MARK: - Identity Management

    /// Load identity from Keychain
    func loadIdentity() {
        nostrIdentity = NostrIdentity.loadFromKeychain()
        isLoaded = true
    }

    /// Create a new Nostr identity
    @discardableResult
    func createIdentity() -> NostrIdentity? {
        guard let identity = NostrIdentity.create() else {
            print("❌ Failed to create Nostr identity")
            return nil
        }
        if identity.saveToKeychain() {
            nostrIdentity = identity
            print("Created new Nostr identity: \(identity.npub)")
        }
        return identity
    }

    /// Import identity from nsec
    func importIdentity(nsec: String) throws {
        let identity = try NostrIdentity.from(nsec: nsec)
        if identity.saveToKeychain() {
            nostrIdentity = identity
            print("Imported Nostr identity: \(identity.npub)")
        }
    }

    /// Import identity from hex private key
    func importIdentity(privateKeyHex: String) throws {
        let identity = try NostrIdentity.from(privateKeyHex: privateKeyHex)
        if identity.saveToKeychain() {
            nostrIdentity = identity
            print("Imported Nostr identity: \(identity.npub)")
        }
    }

    /// Delete current identity
    func deleteIdentity() {
        if NostrIdentity.deleteFromKeychain() {
            nostrIdentity = nil
            print("Deleted Nostr identity")
        }
    }

    /// Get or create identity (ensures one exists)
    func getOrCreateIdentity() -> NostrIdentity? {
        if let existing = nostrIdentity {
            return existing
        }
        return createIdentity()
    }

    // MARK: - Signing

    /// Sign a Nostr event ID
    func signEventId(_ eventIdHex: String) throws -> String {
        guard let identity = nostrIdentity else {
            throw NostrIdentityError.invalidPrivateKey
        }
        return try identity.signEventId(eventIdHex)
    }

    /// Sign arbitrary data
    func sign(_ data: Data) throws -> Data {
        guard let identity = nostrIdentity else {
            throw NostrIdentityError.invalidPrivateKey
        }
        return try identity.sign(data)
    }

    // MARK: - Public Key Access

    /// Get public key hex for use in Nostr events
    var publicKeyHex: String? {
        nostrIdentity?.publicKeyHex
    }

    /// Get npub for display
    var npub: String? {
        nostrIdentity?.npub
    }

    /// Check if identity exists
    var hasIdentity: Bool {
        nostrIdentity != nil
    }
}
