//
//  Bolt11Validator.swift
//  Pulse
//
//  Validation rules for BOLT11 invoices.
//

import Foundation

enum Bolt11ValidationError: Error, LocalizedError {
    case missingPaymentHash
    case missingDescription
    case unsafeDescription

    var errorDescription: String? {
        switch self {
        case .missingPaymentHash:
            return "BOLT11 invoice missing payment hash"
        case .missingDescription:
            return "BOLT11 invoice missing description or description hash"
        case .unsafeDescription:
            return "BOLT11 invoice contains unsafe description content"
        }
    }
}

struct Bolt11Validator {
    static func validate(_ invoice: String) throws -> Bolt11Invoice {
        let parsed = try Bolt11Parser().parse(invoice)

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
