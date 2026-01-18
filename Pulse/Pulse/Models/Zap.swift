//
//  Zap.swift
//  Pulse
//
//  NIP-57 Lightning Zaps data models.
//  Zaps are Bitcoin micropayments sent via Lightning Network.
//

import Foundation

// MARK: - Zap Request (Kind 9734)

/// A zap request created by the sender to initiate a zap
struct ZapRequest: Codable, Identifiable {
    let id: String                  // Event ID
    let recipientPubkey: String     // Who receives the sats
    let messageEventId: String?     // Optional: the message being zapped
    let amount: Int                 // Amount in millisats
    let relays: [String]            // Relays to publish receipt to
    let comment: String?            // Optional zap comment
    let lnurl: String               // Bech32-encoded LNURL
    let createdAt: Date

    /// Serialize to JSON for embedding in LNURL callback
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }
}

// MARK: - Zap Receipt (Kind 9735)

/// A zap receipt created by the LNURL server after payment
struct ZapReceipt: Codable, Identifiable {
    let id: String                  // Event ID (from kind 9735)
    let senderPubkey: String        // Who sent the zap
    let recipientPubkey: String     // Who received the sats
    let amount: Int                 // Amount in millisats
    let bolt11: String              // The paid BOLT11 invoice
    let preimage: String?           // Payment preimage (proof of payment)
    let zapRequestId: String        // ID of the original zap request
    let messageEventId: String?     // The message that was zapped
    let comment: String?            // Zap comment from request
    let createdAt: Date

    /// Amount in satoshis
    var sats: Int {
        amount / 1000
    }

    /// Parse a zap receipt from a Nostr event
    static func from(event: NostrEvent) -> ZapReceipt? {
        // Extract tags
        var bolt11: String?
        var preimage: String?
        var zapRequestId: String?
        var recipientPubkey: String?
        var messageEventId: String?
        var amount: Int = 0
        var comment: String?

        for tag in event.tags {
            guard tag.count >= 2 else { continue }

            switch tag[0] {
            case "bolt11":
                bolt11 = tag[1]
            case "preimage":
                preimage = tag[1]
            case "description":
                // The description tag contains the serialized zap request
                if let requestData = tag[1].data(using: .utf8),
                   let request = try? JSONDecoder().decode(ZapRequest.self, from: requestData) {
                    zapRequestId = request.id
                    amount = request.amount
                    comment = request.comment
                    messageEventId = request.messageEventId
                }
            case "p":
                recipientPubkey = tag[1]
            case "e":
                messageEventId = messageEventId ?? tag[1]
            case "amount":
                if let parsedAmount = Int(tag[1]) {
                    amount = parsedAmount
                }
            default:
                break
            }
        }

        guard let bolt11 = bolt11,
              let recipientPubkey = recipientPubkey else {
            return nil
        }

        return ZapReceipt(
            id: event.id,
            senderPubkey: event.pubkey,
            recipientPubkey: recipientPubkey,
            amount: amount,
            bolt11: bolt11,
            preimage: preimage,
            zapRequestId: zapRequestId ?? "",
            messageEventId: messageEventId,
            comment: comment,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.created_at))
        )
    }
}

// MARK: - Zap Status

/// Status of a zap in progress
enum ZapStatus: String, Codable {
    case pending      // Zap request created, waiting for invoice
    case invoiceReady // BOLT11 invoice received, ready for payment
    case paying       // User opened wallet to pay
    case paid         // Payment sent, waiting for receipt
    case confirmed    // Kind 9735 receipt received
    case failed       // Payment or receipt failed
    case expired      // Invoice expired before payment
}

// MARK: - Pending Zap

/// Tracks a zap that's in progress
struct PendingZap: Identifiable, Codable {
    let id: String              // UUID for tracking
    var zapRequestId: String    // The kind 9734 event ID
    let recipientPubkey: String
    let messageId: String?
    let amount: Int             // millisats
    let comment: String?
    var status: ZapStatus
    var bolt11: String?         // Invoice once received
    var errorMessage: String?
    let createdAt: Date

    var sats: Int {
        amount / 1000
    }
}

// MARK: - LNURL Response Types

/// Response from resolving a Lightning Address
struct LNURLPayResponse: Codable {
    let callback: String          // URL to request invoice
    let maxSendable: Int          // Max amount in millisats
    let minSendable: Int          // Min amount in millisats
    let metadata: String          // JSON-encoded metadata
    let tag: String               // Should be "payRequest"
    let allowsNostr: Bool?        // NIP-57: true if accepts zap requests
    let nostrPubkey: String?      // NIP-57: pubkey that will sign receipts

    /// Whether this endpoint supports NIP-57 zaps
    var supportsZaps: Bool {
        allowsNostr == true && nostrPubkey != nil
    }

    /// Max amount in sats
    var maxSats: Int {
        maxSendable / 1000
    }

    /// Min amount in sats
    var minSats: Int {
        minSendable / 1000
    }
}

/// Response from requesting an invoice
struct LNURLInvoiceResponse: Codable {
    let pr: String                // BOLT11 invoice (payment request)
    let routes: [[String]]?       // Optional routing hints
    let successAction: SuccessAction?

    struct SuccessAction: Codable {
        let tag: String           // "message", "url", or "aes"
        let message: String?
        let url: String?
        let description: String?
    }
}

/// Error response from LNURL
struct LNURLError: Codable, Error {
    let status: String            // "ERROR"
    let reason: String            // Human-readable error

    var localizedDescription: String {
        reason
    }
}

// MARK: - Lightning Wallet

/// Supported Lightning wallet apps
enum LightningWallet: String, CaseIterable, Codable {
    case automatic = "automatic"
    case zeus = "zeus"
    case blueWallet = "bluewallet"
    case phoenix = "phoenix"
    case muun = "muun"
    case breez = "breez"
    case wallet = "wallet"  // Generic "lightning:" scheme

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .zeus: return "Zeus"
        case .blueWallet: return "BlueWallet"
        case .phoenix: return "Phoenix"
        case .muun: return "Muun"
        case .breez: return "Breez"
        case .wallet: return "Default Wallet"
        }
    }

    var urlScheme: String {
        switch self {
        case .automatic, .wallet: return "lightning:"
        case .zeus: return "zeusln:lightning:"
        case .blueWallet: return "bluewallet:lightning:"
        case .phoenix: return "phoenix://"
        case .muun: return "muun:"
        case .breez: return "breez:"
        }
    }

    /// Create a payment URL for this wallet
    func paymentURL(invoice: String) -> URL? {
        let urlString: String
        switch self {
        case .phoenix:
            urlString = "\(urlScheme)pay?invoice=\(invoice)"
        default:
            urlString = "\(urlScheme)\(invoice)"
        }
        return URL(string: urlString)
    }
}

// MARK: - Zap Amount Presets

/// Common zap amounts in sats
enum ZapAmount: Int, CaseIterable {
    case tiny = 21
    case nice = 69
    case hundred = 100
    case blaze = 420
    case oneK = 1000
    case fiveK = 5000
    case tenK = 10000
    case twentyOneK = 21000

    var displayName: String {
        switch self {
        case .tiny: return "21"
        case .nice: return "69"
        case .hundred: return "100"
        case .blaze: return "420"
        case .oneK: return "1K"
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .twentyOneK: return "21K"
        }
    }

    /// Amount in millisats for LNURL
    var millisats: Int {
        rawValue * 1000
    }
}

// MARK: - Formatting Helpers

extension Int {
    /// Format satoshi amount for display
    var formattedSats: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1000 {
            return String(format: "%.1fK", Double(self) / 1000)
        } else {
            return "\(self)"
        }
    }
}
