//
//  Bolt11Validator.swift
//  Pulse
//
//  Validation rules for BOLT11 invoices.
//

import Foundation

enum Bolt11ValidationError: Error, LocalizedError {
    case invoiceTooLong
    case missingPaymentHash
    case missingDescription
    case unsafeDescription
    case missingAmount
    case unsupportedNetwork

    var errorDescription: String? {
        switch self {
        case .invoiceTooLong:
            return "BOLT11 invoice exceeds maximum length"
        case .missingPaymentHash:
            return "BOLT11 invoice missing payment hash"
        case .missingDescription:
            return "BOLT11 invoice missing description or description hash"
        case .unsafeDescription:
            return "BOLT11 invoice contains unsafe description content"
        case .missingAmount:
            return "BOLT11 invoice missing explicit amount"
        case .unsupportedNetwork:
            return "BOLT11 invoice network not supported"
        }
    }
}

struct Bolt11Validator {
    private static let maxInvoiceLength = 4096
    private static let supportedNetworks: Set<Bolt11Network> = [.bitcoin, .testnet]

    static func validate(_ invoice: String) throws -> Bolt11Invoice {
        guard invoice.count <= maxInvoiceLength else {
            throw Bolt11ValidationError.invoiceTooLong
        }

        let parsed = try Bolt11Parser().parse(invoice)

        guard supportedNetworks.contains(parsed.network) else {
            throw Bolt11ValidationError.unsupportedNetwork
        }

        guard let amount = parsed.amountMillisats, amount > 0 else {
            throw Bolt11ValidationError.missingAmount
        }

        guard parsed.paymentHash != nil else {
            throw Bolt11ValidationError.missingPaymentHash
        }

        guard parsed.description != nil || parsed.descriptionHash != nil else {
            throw Bolt11ValidationError.missingDescription
        }

        if let description = parsed.description, !description.isEmpty {
            guard isSafeDescription(description) else {
                throw Bolt11ValidationError.unsafeDescription
            }
        }

        return parsed
    }

    static func isSafeDescription(_ description: String) -> Bool {
        if description.rangeOfCharacter(from: unsafeControlCharacters) != nil {
            return false
        }

        let lowered = description.lowercased()
        let blockedSubstrings = [
            "<script",
            "</script",
            "javascript:",
            "onerror=",
            "onload=",
            "union select",
            "drop table",
            "insert into",
            "' or 1=1",
            "--",
            "/*",
            "*/"
        ]

        for token in blockedSubstrings where lowered.contains(token) {
            return false
        }

        return true
    }

    private static let unsafeControlCharacters: CharacterSet = {
        var set = CharacterSet.controlCharacters
        set.remove("\n")
        set.remove("\t")
        return set
    }()
}
