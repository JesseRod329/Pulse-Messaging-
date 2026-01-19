//
//  WalletURISanitizer.swift
//  Pulse
//
//  Sanitizes Lightning payment URIs before opening external wallets.
//

import Foundation

enum WalletURISanitizer {
    private static let maxInvoiceLength = 4096
    private static let maxURLLength = 8192
    private static let allowedSchemes: Set<String> = [
        "lightning",
        "zeusln",
        "bluewallet",
        "phoenix",
        "muun",
        "breez"
    ]
    private static let allowedInvoiceCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")

    static func sanitizeInvoice(_ invoice: String) -> String? {
        let trimmed = invoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let stripped = trimmed.lowercased().replacingOccurrences(of: "lightning:", with: "")
        guard stripped.count >= 10, stripped.count <= maxInvoiceLength else { return nil }
        guard stripped.hasPrefix("ln") else { return nil }
        guard stripped.unicodeScalars.allSatisfy({ allowedInvoiceCharacters.contains($0) }) else {
            return nil
        }
        return stripped
    }

    static func buildPaymentURL(invoice: String, wallet: LightningWallet) -> URL? {
        guard let sanitized = sanitizeInvoice(invoice) else { return nil }

        let urlString: String
        switch wallet {
        case .phoenix:
            guard let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            urlString = "phoenix://pay?invoice=\(encoded)"
        default:
            urlString = "\(wallet.urlScheme)\(sanitized)"
        }

        guard urlString.count <= maxURLLength, let url = URL(string: urlString) else {
            return nil
        }
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
            return nil
        }
        return url
    }

    static func buildGenericLightningURL(invoice: String) -> URL? {
        guard let sanitized = sanitizeInvoice(invoice) else { return nil }
        let urlString = "lightning:\(sanitized)"
        guard urlString.count <= maxURLLength else { return nil }
        return URL(string: urlString)
    }
}
