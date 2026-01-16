//
//  IdentityManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import CryptoKit

@MainActor
class IdentityManager: ObservableObject {
    static let shared = IdentityManager()

    @Published var currentIdentity: PulseIdentity?

    private init() {
        loadIdentity()
    }

    // MARK: - Identity Management

    func createIdentity(handle: String) -> Bool {
        let identity = PulseIdentity.create(handle: handle)

        guard identity.saveToKeychain() else {
            print("Failed to save identity to Keychain")
            return false
        }

        currentIdentity = identity

        // Also save handle to UserDefaults for quick access
        UserDefaults.standard.set(handle, forKey: "handle")

        return true
    }

    func loadIdentity() {
        currentIdentity = PulseIdentity.loadFromKeychain()
    }

    func deleteIdentity() -> Bool {
        currentIdentity = nil
        UserDefaults.standard.removeObject(forKey: "handle")
        return PulseIdentity.deleteFromKeychain()
    }

    func hasIdentity() -> Bool {
        return currentIdentity != nil
    }

    // MARK: - Encryption Helpers

    func encryptMessage(_ message: String, for recipientPublicKey: Data) -> Data? {
        guard let identity = currentIdentity else {
            print("No identity available for encryption")
            return nil
        }

        do {
            return try identity.encrypt(message, for: recipientPublicKey)
        } catch {
            print("Encryption failed: \(error)")
            return nil
        }
    }

    func decryptMessage(_ ciphertext: Data) -> String? {
        guard let identity = currentIdentity else {
            print("No identity available for decryption")
            return nil
        }

        do {
            return try identity.decrypt(ciphertext)
        } catch {
            print("Decryption failed: \(error)")
            return nil
        }
    }

    // MARK: - Public Key Access

    var myPublicKey: Data? {
        return currentIdentity?.publicKey
    }

    var mySigningPublicKey: Data? {
        return currentIdentity?.signingPublicKey
    }

    var myDID: String? {
        return currentIdentity?.did
    }

    var myHandle: String? {
        return currentIdentity?.handle
    }

    // MARK: - Signing Helpers

    func signMessage(_ message: String) throws -> Data {
        guard let identity = currentIdentity else {
            print("No identity available for signing")
            throw CryptoError.invalidCiphertext
        }
        return try identity.sign(message: message)
    }

    func signPayload(_ payload: Data) throws -> Data {
        guard let identity = currentIdentity else {
            print("No identity available for signing")
            throw CryptoError.invalidCiphertext
        }
        return try identity.sign(data: payload)
    }

    func verifySignature(signature: Data, for message: String, from publicKey: Data) throws -> Bool {
        guard let identity = currentIdentity else {
            print("No identity available for verification")
            throw CryptoError.invalidSignature
        }
        return try identity.verify(message: message, signature: signature, from: publicKey)
    }

    func verifySignature(signature: Data, for payload: Data, from publicKey: Data) throws -> Bool {
        let signingKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        return signingKey.isValidSignature(signature, for: Array(payload))
    }
}
