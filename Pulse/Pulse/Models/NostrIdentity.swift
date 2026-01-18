//
//  NostrIdentity.swift
//  Pulse
//
//  secp256k1 identity for Nostr protocol compliance.
//  Nostr requires BIP-340 Schnorr signatures, which use secp256k1.
//  This is separate from PulseIdentity (Ed25519) used for mesh P2P.
//

import Foundation
import P256K

/// Nostr identity using secp256k1 for protocol compliance
struct NostrIdentity: Codable {
    let privateKeyHex: String  // 32-byte private key as hex
    let publicKeyHex: String   // 32-byte x-only public key as hex
    let createdAt: Date

    // Bech32 encoded keys (NIP-19)
    var npub: String {
        Bech32.encode(hrp: "npub", data: Data(hex: publicKeyHex) ?? Data())
    }

    var nsec: String {
        Bech32.encode(hrp: "nsec", data: Data(hex: privateKeyHex) ?? Data())
    }

    // MARK: - Creation

    /// Generate a new random Nostr identity
    static func create() -> NostrIdentity? {
        guard let privateKey = try? P256K.Schnorr.PrivateKey() else {
            print("❌ Failed to generate Nostr private key")
            return nil
        }
        let privateKeyData = Data(privateKey.dataRepresentation)
        let publicKeyData = Data(privateKey.xonly.bytes)

        return NostrIdentity(
            privateKeyHex: privateKeyData.hexEncodedString(),
            publicKeyHex: publicKeyData.hexEncodedString(),
            createdAt: Date()
        )
    }

    /// Create from existing private key hex
    static func from(privateKeyHex: String) throws -> NostrIdentity {
        guard let privateKeyData = Data(hex: privateKeyHex),
              privateKeyData.count == 32 else {
            throw NostrIdentityError.invalidPrivateKey
        }

        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: [UInt8](privateKeyData))
        let publicKeyData = Data(privateKey.xonly.bytes)

        return NostrIdentity(
            privateKeyHex: privateKeyHex,
            publicKeyHex: publicKeyData.hexEncodedString(),
            createdAt: Date()
        )
    }

    /// Create from nsec (NIP-19 encoded private key)
    static func from(nsec: String) throws -> NostrIdentity {
        guard let (hrp, data) = Bech32.decode(nsec),
              hrp == "nsec",
              data.count == 32 else {
            throw NostrIdentityError.invalidNsec
        }
        return try from(privateKeyHex: data.hexEncodedString())
    }

    // MARK: - Signing

    /// Sign data using Schnorr signature (BIP-340)
    func sign(_ data: Data) throws -> Data {
        guard let privateKeyData = Data(hex: privateKeyHex) else {
            throw NostrIdentityError.invalidPrivateKey
        }

        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: [UInt8](privateKeyData))
        var messageBytes = [UInt8](data)
        // Generate random auxiliary data for BIP-340 signing
        var auxRand = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &auxRand)
        let signature = try privateKey.signature(message: &messageBytes, auxiliaryRand: &auxRand)
        return Data(signature.dataRepresentation)
    }

    /// Sign a Nostr event ID (which is already SHA256 hashed)
    func signEventId(_ eventIdHex: String) throws -> String {
        guard let eventIdData = Data(hex: eventIdHex) else {
            throw NostrIdentityError.invalidEventId
        }

        let signature = try sign(eventIdData)
        return signature.hexEncodedString()
    }

    // MARK: - Verification

    /// Verify a Schnorr signature
    static func verify(signature: Data, message: Data, publicKeyHex: String) -> Bool {
        guard let publicKeyData = Data(hex: publicKeyHex),
              publicKeyData.count == 32 else {
            return false
        }

        do {
            let xonlyKey = P256K.Schnorr.XonlyKey(
                dataRepresentation: [UInt8](publicKeyData),
                keyParity: 0
            )
            let schnorrSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: [UInt8](signature))
            let messageBytes = [UInt8](message)
            return xonlyKey.isValidSignature(schnorrSignature, for: messageBytes)
        } catch {
            return false
        }
    }

    // MARK: - Keychain Storage

    private static let keychainKey = "pulse.nostr.identity"

    func saveToKeychain() -> Bool {
        do {
            let data = try JSONEncoder().encode(self)
            return KeychainManager.shared.save(data, forKey: Self.keychainKey)
        } catch {
            print("Failed to encode Nostr identity: \(error)")
            return false
        }
    }

    static func loadFromKeychain() -> NostrIdentity? {
        guard let data = KeychainManager.shared.load(forKey: keychainKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(NostrIdentity.self, from: data)
        } catch {
            print("Failed to decode Nostr identity: \(error)")
            return nil
        }
    }

    static func deleteFromKeychain() -> Bool {
        return KeychainManager.shared.delete(forKey: keychainKey)
    }
}

// MARK: - Errors

enum NostrIdentityError: Error, LocalizedError {
    case invalidPrivateKey
    case invalidNsec
    case invalidEventId
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid secp256k1 private key"
        case .invalidNsec:
            return "Invalid nsec format"
        case .invalidEventId:
            return "Invalid event ID"
        case .signingFailed:
            return "Failed to sign with Schnorr signature"
        }
    }
}

// MARK: - Hex Encoding Extensions

extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var index = hex.startIndex

        for _ in 0..<len {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }

    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Bech32 Encoding (NIP-19)

enum Bech32 {
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    static func encode(hrp: String, data: Data) -> String {
        let values = convertTo5bit(data)
        let checksum = createChecksum(hrp: hrp, values: values)
        let combined = values + checksum

        var result = hrp + "1"
        for value in combined {
            result.append(charset[Int(value)])
        }
        return result
    }

    static func decode(_ string: String) -> (hrp: String, data: Data)? {
        let lowered = string.lowercased()
        guard let separatorIndex = lowered.lastIndex(of: "1") else {
            return nil
        }

        let hrp = String(lowered[..<separatorIndex])
        let dataString = String(lowered[lowered.index(after: separatorIndex)...])

        var values: [UInt8] = []
        for char in dataString {
            guard let index = charset.firstIndex(of: char) else {
                return nil
            }
            values.append(UInt8(charset.distance(from: charset.startIndex, to: index)))
        }

        guard verifyChecksum(hrp: hrp, values: values) else {
            return nil
        }

        // Remove checksum (last 6 values)
        let dataValues = Array(values.dropLast(6))
        guard let data = convertFrom5bit(dataValues) else {
            return nil
        }

        return (hrp, data)
    }

    static func decodeToValues(_ string: String) -> (hrp: String, values: [UInt8])? {
        let lowered = string.lowercased()
        guard let separatorIndex = lowered.lastIndex(of: "1") else {
            return nil
        }

        let hrp = String(lowered[..<separatorIndex])
        let dataString = String(lowered[lowered.index(after: separatorIndex)...])

        var values: [UInt8] = []
        for char in dataString {
            guard let index = charset.firstIndex(of: char) else {
                return nil
            }
            values.append(UInt8(charset.distance(from: charset.startIndex, to: index)))
        }

        guard verifyChecksum(hrp: hrp, values: values) else {
            return nil
        }

        let dataValues = Array(values.dropLast(6))
        return (hrp, dataValues)
    }

    private static func convertTo5bit(_ data: Data) -> [UInt8] {
        var result: [UInt8] = []
        var acc: UInt32 = 0
        var bits: UInt32 = 0

        for byte in data {
            acc = (acc << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(UInt8((acc >> bits) & 31))
            }
        }

        if bits > 0 {
            result.append(UInt8((acc << (5 - bits)) & 31))
        }

        return result
    }

    private static func convertFrom5bit(_ values: [UInt8]) -> Data? {
        var result = Data()
        var acc: UInt32 = 0
        var bits: UInt32 = 0

        for value in values {
            acc = (acc << 5) | UInt32(value)
            bits += 5
            while bits >= 8 {
                bits -= 8
                result.append(UInt8((acc >> bits) & 255))
            }
        }

        return result
    }

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var chk: UInt32 = 1

        for value in values {
            let top = chk >> 25
            chk = ((chk & 0x1ffffff) << 5) ^ UInt32(value)
            for i in 0..<5 {
                if (top >> i) & 1 == 1 {
                    chk ^= generator[i]
                }
            }
        }

        return chk
    }

    private static func hrpExpand(_ hrp: String) -> [UInt8] {
        var result: [UInt8] = []
        for char in hrp {
            result.append(UInt8(char.asciiValue! >> 5))
        }
        result.append(0)
        for char in hrp {
            result.append(UInt8(char.asciiValue! & 31))
        }
        return result
    }

    private static func createChecksum(hrp: String, values: [UInt8]) -> [UInt8] {
        let expanded = hrpExpand(hrp) + values + [0, 0, 0, 0, 0, 0]
        let mod = polymod(expanded) ^ 1
        var result: [UInt8] = []
        for i in 0..<6 {
            result.append(UInt8((mod >> (5 * (5 - i))) & 31))
        }
        return result
    }

    private static func verifyChecksum(hrp: String, values: [UInt8]) -> Bool {
        return polymod(hrpExpand(hrp) + values) == 1
    }
}
