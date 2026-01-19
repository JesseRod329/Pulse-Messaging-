//
//  ZapSecurityGuard.swift
//  Pulse
//
//  Defense-in-depth checks for NIP-57 zap invoices.
//

import Foundation

enum ZapSecurityGuardError: Error, LocalizedError {
    case missingZapAmount
    case missingDescriptionHash
    case descriptionHashMismatch
    case invoiceExpired

    var errorDescription: String? {
        switch self {
        case .missingZapAmount:
            return "Zap request missing amount"
        case .missingDescriptionHash:
            return "Invoice missing description hash"
        case .descriptionHashMismatch:
            return "Invoice description hash does not match zap request"
        case .invoiceExpired:
            return "Invoice is expired"
        }
    }
}

struct ZapSecurityGuard {
    private static let defaultExpirySeconds: TimeInterval = 3600

    static func validate(
        invoice: String,
        zapRequest: NostrEvent,
        expectedAmountMsat: Int,
        now: Date = Date()
    ) throws -> Bolt11Invoice {
        let parsed = try Bolt11Parser().parse(invoice)
        try validate(
            invoice: parsed,
            zapRequest: zapRequest,
            expectedAmountMsat: expectedAmountMsat,
            now: now
        )
        return parsed
    }

    static func validate(
        invoice: Bolt11Invoice,
        zapRequest: NostrEvent,
        expectedAmountMsat: Int,
        now: Date = Date()
    ) throws {
        try NostrEventValidator.validateZapRequest(zapRequest)
        guard let zapAmountMsat = zapRequestAmountMsat(zapRequest) else {
            throw ZapSecurityGuardError.missingZapAmount
        }

        try AmountGuard.validate(
            uiAmountMsat: expectedAmountMsat,
            zapRequestAmountMsat: zapAmountMsat,
            invoiceAmountMsat: invoice.amountMillisats
        )

        guard let invoiceDescriptionHash = invoice.descriptionHash else {
            throw ZapSecurityGuardError.missingDescriptionHash
        }

        let requestHashHex = try zapRequest.descriptionHash()
        guard let requestHashData = Data(hex: requestHashHex) else {
            throw ZapSecurityGuardError.descriptionHashMismatch
        }

        guard requestHashData == invoiceDescriptionHash else {
            throw ZapSecurityGuardError.descriptionHashMismatch
        }

        let expirySeconds = expiryInterval(from: invoice)
        let expiryDate = invoice.timestamp.addingTimeInterval(expirySeconds)
        guard now <= expiryDate else {
            throw ZapSecurityGuardError.invoiceExpired
        }
    }

    private static func zapRequestAmountMsat(_ event: NostrEvent) -> Int? {
        for tag in event.tags where tag.count >= 2 {
            guard tag[0] == "amount" else { continue }
            if let amount = Int(tag[1]) {
                return amount
            }
        }
        return nil
    }

    private static func expiryInterval(from invoice: Bolt11Invoice) -> TimeInterval {
        for tag in invoice.tags {
            if case let .expiry(seconds) = tag {
                return TimeInterval(seconds)
            }
        }
        return defaultExpirySeconds
    }
}
