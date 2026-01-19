//
//  NostrEventValidator.swift
//  Pulse
//
//  Validation for Nostr events and zap-specific checks.
//

import Foundation
import CryptoKit

enum NostrEventValidationError: Error, LocalizedError {
    case invalidPubkey
    case invalidSignatureFormat
    case invalidEventId
    case signatureMismatch
    case invalidKind
    case missingAmount

    var errorDescription: String? {
        switch self {
        case .invalidPubkey:
            return "Invalid Nostr pubkey format"
        case .invalidSignatureFormat:
            return "Invalid Nostr signature format"
        case .invalidEventId:
            return "Invalid Nostr event id"
        case .signatureMismatch:
            return "Nostr signature verification failed"
        case .invalidKind:
            return "Unexpected Nostr event kind"
        case .missingAmount:
            return "Zap request missing amount"
        }
    }
}

struct NostrEventValidator {
    static func validateZapRequest(_ event: NostrEvent) throws {
        guard event.kind == NostrEventKind.zapRequest.rawValue else {
            throw NostrEventValidationError.invalidKind
        }
        try validateEventSignature(event)
        guard extractZapAmount(event) != nil else {
            throw NostrEventValidationError.missingAmount
        }
    }

    static func validateZapReceipt(_ event: NostrEvent) throws {
        guard event.kind == NostrEventKind.zapReceipt.rawValue else {
            throw NostrEventValidationError.invalidKind
        }
        try validateEventSignature(event)
    }

    static func validateEventSignature(_ event: NostrEvent) throws {
        guard isValidHex(event.pubkey, length: 64) else {
            throw NostrEventValidationError.invalidPubkey
        }
        guard isValidHex(event.sig, length: 128) else {
            throw NostrEventValidationError.invalidSignatureFormat
        }
        guard isValidHex(event.id, length: 64) else {
            throw NostrEventValidationError.invalidEventId
        }

        let canonicalData = try NostrNormalization.canonicalEventJSONData(
            pubkey: event.pubkey,
            createdAt: event.created_at,
            kind: event.kind,
            tags: event.tags,
            content: event.content
        )
        let computedId = canonicalData.sha256Hex
        guard computedId == event.id else {
            throw NostrEventValidationError.invalidEventId
        }

        guard let signatureData = Data(hex: event.sig),
              let messageData = Data(hex: event.id) else {
            throw NostrEventValidationError.invalidSignatureFormat
        }

        let verified = NostrIdentity.verify(
            signature: signatureData,
            message: messageData,
            publicKeyHex: event.pubkey
        )
        guard verified else {
            throw NostrEventValidationError.signatureMismatch
        }
    }

    private static func extractZapAmount(_ event: NostrEvent) -> Int? {
        for tag in event.tags where tag.count >= 2 {
            if tag[0] == "amount", let amount = Int(tag[1]) {
                return amount
            }
        }
        return nil
    }

    private static func isValidHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.allSatisfy { $0.isHexDigit }
    }
}

private extension Data {
    var sha256Hex: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
