//
//  PulseIdentity.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import CryptoKit

struct PulseIdentity: Codable {
    let did: String // Decentralized ID
    let handle: String
    let publicKey: Data // KeyAgreement public key for encryption
    private let privateKey: Data // KeyAgreement private key for decryption
    let signingPublicKey: Data // Signing public key for verification
    private let signingPrivateKey: Data // Signing private key for signatures
    let createdAt: Date

    // MARK: - Creation

    static func create(handle: String) -> PulseIdentity {
        // Use KeyAgreement keys for encryption/decryption
        let keyAgreementKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyRaw = keyAgreementKey.publicKey.rawRepresentation

        // Use Signing keys for signatures/verification
        let signingKey = Curve25519.Signing.PrivateKey()
        let signingPublicKeyRaw = signingKey.publicKey.rawRepresentation

        // Create DID (did:key:z...)
        let publicKeyBase58 = publicKeyRaw.base58EncodedString()
        let did = "did:key:z\(publicKeyBase58)"

        let identity = PulseIdentity(
            did: did,
            handle: handle,
            publicKey: publicKeyRaw,
            privateKey: keyAgreementKey.rawRepresentation,
            signingPublicKey: signingPublicKeyRaw,
            signingPrivateKey: signingKey.rawRepresentation,
            createdAt: Date()
        )

        return identity
    }

    // MARK: - Keychain Storage

    func saveToKeychain() -> Bool {
        do {
            let data = try JSONEncoder().encode(self)
            return KeychainManager.shared.save(data, forKey: "pulse.identity")
        } catch {
            print("Failed to encode identity: \(error)")
            return false
        }
    }

    static func loadFromKeychain() -> PulseIdentity? {
        guard let data = KeychainManager.shared.load(forKey: "pulse.identity") else {
            return nil
        }

        do {
            return try JSONDecoder().decode(PulseIdentity.self, from: data)
        } catch {
            print("Failed to decode identity: \(error)")
            // Corrupt or incompatible identity. Delete it and force re-onboarding.
            _ = KeychainManager.shared.delete(forKey: "pulse.identity")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            return nil
        }
    }

    static func deleteFromKeychain() -> Bool {
        return KeychainManager.shared.delete(forKey: "pulse.identity")
    }

    // MARK: - Encryption

    func encrypt(_ plaintext: String, for recipientPublicKey: Data) throws -> Data {
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        let recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPublicKey)

        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "pulse-e2e-v1".data(using: .utf8)!,
            outputByteCount: 32
        )

        let plainData = plaintext.data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(plainData, using: symmetricKey)

        // Combine: ephemeralPublicKey + nonce + ciphertext + tag
        var combined = Data()
        combined.append(ephemeralKey.publicKey.rawRepresentation) // 32 bytes
        combined.append(contentsOf: sealedBox.nonce) // 12 bytes
        combined.append(sealedBox.ciphertext)
        combined.append(sealedBox.tag) // 16 bytes

        return combined
    }

    func decrypt(_ ciphertext: Data) throws -> String {
        guard ciphertext.count >= 60 else {
            throw CryptoError.invalidCiphertext
        }

        // Extract components
        let ephemeralPublicKeyData = ciphertext.prefix(32)
        let nonceData = ciphertext.dropFirst(32).prefix(12)
        let tagData = ciphertext.suffix(16)
        let ciphertextData = ciphertext.dropFirst(44).dropLast(16)

        let ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicKeyData)
        let myPrivateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)

        let sharedSecret = try myPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "pulse-e2e-v1".data(using: .utf8)!,
            outputByteCount: 32
        )

        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonceData),
            ciphertext: ciphertextData,
            tag: tagData
        )

        let plainData = try AES.GCM.open(sealedBox, using: symmetricKey)

        guard let plaintext = String(data: plainData, encoding: .utf8) else {
            throw CryptoError.invalidPlaintext
        }

        return plaintext
    }

    // MARK: - Signing and Verification

    func sign(data: Data) throws -> Data {
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingPrivateKey)
        return try signingKey.signature(for: Array(data))
    }

    func verify(data: Data, signature: Data, from signerPublicKey: Data) throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: signerPublicKey)
        return publicKey.isValidSignature(signature, for: Array(data))
    }

    func sign(message: String) throws -> Data {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.invalidPlaintext
        }
        return try sign(data: messageData)
    }

    func verify(message: String, signature: Data, from signerPublicKey: Data) throws -> Bool {
        guard let messageData = message.data(using: .utf8) else {
            throw CryptoError.invalidPlaintext
        }
        return try verify(data: messageData, signature: signature, from: signerPublicKey)
    }
}

// MARK: - SignedMessageEnvelope

struct SignedMessageEnvelope: Codable {
    let id: String
    let senderId: String
    let recipientId: String
    let encryptedContent: String
    let timestamp: Date
    let messageType: String
    let codeLanguage: String?
    let signature: Data // Signature of the encrypted content
    let senderSigningPublicKey: Data // Sender's signing public key for verification

    var encodedSignature: String {
        signature.base64EncodedString()
    }

    var encodedPublicKey: String {
        senderSigningPublicKey.base64EncodedString()
    }
}

extension MessageEnvelope {
    func signed(with signature: Data, senderSigningKey: Data) -> SignedMessageEnvelope {
        return SignedMessageEnvelope(
            id: id,
            senderId: senderId,
            recipientId: recipientId,
            encryptedContent: encryptedContent,
            timestamp: timestamp,
            messageType: messageType,
            codeLanguage: codeLanguage,
            signature: signature,
            senderSigningPublicKey: senderSigningKey
        )
    }
}

enum CryptoError: Error {
    case invalidCiphertext
    case invalidPlaintext
    case invalidSignature
}

// MARK: - Base58 Encoding (for DID)

extension Data {
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    func base58EncodedString() -> String {
        guard !isEmpty else { return "" }

        // Convert bytes to a big integer (manual implementation)
        var bytes = [UInt8](self)

        // Count leading zeros
        var leadingZeros = 0
        for byte in bytes {
            if byte == 0 {
                leadingZeros += 1
            } else {
                break
            }
        }

        // Base58 encoding
        var result = [Character]()

        while !bytes.allSatisfy({ $0 == 0 }) {
            var carry = 0
            for i in 0..<bytes.count {
                let value = carry * 256 + Int(bytes[i])
                bytes[i] = UInt8(value / 58)
                carry = value % 58
            }
            result.append(Self.base58Alphabet[carry])
        }

        // Add leading '1's for each leading zero byte
        for _ in 0..<leadingZeros {
            result.append("1")
        }

        return String(result.reversed())
    }

    static func base58Decoded(_ string: String) -> Data? {
        guard !string.isEmpty else { return Data() }

        // Count leading '1's (zeros in Base58)
        var leadingZeros = 0
        for char in string {
            if char == "1" {
                leadingZeros += 1
            } else {
                break
            }
        }

        // Convert from Base58
        var result = [UInt8]()

        for char in string {
            guard let index = base58Alphabet.firstIndex(of: char) else {
                return nil // Invalid character
            }

            var carry = index
            for i in (0..<result.count).reversed() {
                let value = Int(result[i]) * 58 + carry
                result[i] = UInt8(value & 0xFF)
                carry = value >> 8
            }

            while carry > 0 {
                result.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }

        // Add leading zeros
        let zeros = [UInt8](repeating: 0, count: leadingZeros)
        return Data(zeros + result)
    }
}
