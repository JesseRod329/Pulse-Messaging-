//
//  AmountGuard.swift
//  Pulse
//
//  Consistency checks for zap amounts across UI, request, and invoice.
//

import Foundation

enum AmountGuardError: Error, LocalizedError {
    case missingInvoiceAmount
    case uiMismatch
    case requestMismatch

    var errorDescription: String? {
        switch self {
        case .missingInvoiceAmount:
            return "Invoice is missing an explicit amount"
        case .uiMismatch:
            return "UI amount does not match zap request amount"
        case .requestMismatch:
            return "Invoice amount does not match zap request amount"
        }
    }
}

struct AmountGuard {
    static func validate(
        uiAmountMsat: Int,
        zapRequestAmountMsat: Int,
        invoiceAmountMsat: Int?
    ) throws {
        guard let invoiceAmountMsat else {
            throw AmountGuardError.missingInvoiceAmount
        }

        guard uiAmountMsat == zapRequestAmountMsat else {
            throw AmountGuardError.uiMismatch
        }

        guard invoiceAmountMsat == zapRequestAmountMsat else {
            throw AmountGuardError.requestMismatch
        }
    }
}
