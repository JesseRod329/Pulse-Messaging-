//
//  LNURLService.swift
//  Pulse
//
//  Handles LNURL protocol for Lightning payments.
//  Resolves Lightning Addresses and requests invoices for zaps.
//

import Foundation
import UIKit

/// Service for LNURL protocol operations
@MainActor
final class LNURLService: ObservableObject {
    static let shared = LNURLService()

    @Published var isProcessing = false
    @Published var lastError: String?

    /// Secure URLSession with certificate validation
    /// Protects against MITM attacks on Lightning Address resolution
    private let session: URLSession
    private var requestLimiter = RateLimiter(maxEvents: 5, interval: 1)
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 0.4

    private init() {
        // Use secure session with certificate validation
        self.session = SecureNetworkSession.createLNURLSession()
    }

    // MARK: - Lightning Address Resolution

    /// Resolve a Lightning Address (user@domain.com) to LNURL pay endpoint
    func resolveLightningAddress(_ address: String) async throws -> LNURLPayResponse {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        guard requestLimiter.shouldAllow() else {
            throw LNURLServiceError.rateLimited
        }

        // Parse Lightning Address
        let parts = address.split(separator: "@")
        guard parts.count == 2 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        let username = String(parts[0])
        let domain = String(parts[1])

        // Construct well-known URL
        guard let url = URL(string: "https://\(domain)/.well-known/lnurlp/\(username)") else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Fetch LNURL metadata
        let (data, response) = try await fetchData(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LNURLServiceError.serverError
        }

        // Check for error response
        if let errorResponse = try? JSONDecoder().decode(LNURLError.self, from: data),
           errorResponse.status == "ERROR" {
            lastError = errorResponse.reason
            throw errorResponse
        }

        let payResponse = try JSONDecoder().decode(LNURLPayResponse.self, from: data)

        // Validate it's a pay request
        guard payResponse.tag == "payRequest" else {
            throw LNURLServiceError.invalidResponse
        }

        return payResponse
    }

    // MARK: - Invoice Request

    /// Request an invoice with embedded zap request
    func requestInvoice(
        payResponse: LNURLPayResponse,
        amount: Int,  // millisats
        zapRequest: NostrEvent?,
        comment: String?
    ) async throws -> LNURLInvoiceResponse {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        guard requestLimiter.shouldAllow() else {
            throw LNURLServiceError.rateLimited
        }

        // Validate amount
        guard amount >= payResponse.minSendable,
              amount <= payResponse.maxSendable else {
            throw LNURLServiceError.amountOutOfRange(
                min: payResponse.minSats,
                max: payResponse.maxSats
            )
        }

        // Build callback URL
        guard var urlComponents = URLComponents(string: payResponse.callback) else {
            throw LNURLServiceError.invalidCallback
        }

        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "amount", value: String(amount)))

        // Add comment if supported and provided
        if let comment = comment, !comment.isEmpty {
            queryItems.append(URLQueryItem(name: "comment", value: comment))
        }

        // Add zap request for NIP-57
        if payResponse.supportsZaps, let zapRequest = zapRequest {
            if let zapData = try? JSONEncoder().encode(zapRequest),
               let zapJson = String(data: zapData, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "nostr", value: zapJson))
            }
        }

        urlComponents.queryItems = queryItems

        guard let callbackURL = urlComponents.url else {
            throw LNURLServiceError.invalidCallback
        }

        // Request invoice
        let (data, response) = try await fetchData(from: callbackURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LNURLServiceError.serverError
        }

        // Check for error response
        if let errorResponse = try? JSONDecoder().decode(LNURLError.self, from: data),
           errorResponse.status == "ERROR" {
            lastError = errorResponse.reason
            throw errorResponse
        }

        return try JSONDecoder().decode(LNURLInvoiceResponse.self, from: data)
    }

    // MARK: - Wallet Integration

    /// Open Lightning wallet with invoice
    @discardableResult
    func openWallet(invoice: String, preferredWallet: LightningWallet = .automatic) -> Bool {
        // Try preferred wallet first
        if preferredWallet != .automatic,
           let url = WalletURISanitizer.buildPaymentURL(invoice: invoice, wallet: preferredWallet),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }

        // Try each wallet in order
        for wallet in LightningWallet.allCases where wallet != .automatic {
            if let url = WalletURISanitizer.buildPaymentURL(invoice: invoice, wallet: wallet),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
        }

        // Fall back to generic lightning: scheme
        if let url = WalletURISanitizer.buildGenericLightningURL(invoice: invoice) {
            UIApplication.shared.open(url)
            return true
        }

        return false
    }

    /// Check if any Lightning wallet is installed
    func hasLightningWallet() -> Bool {
        for wallet in LightningWallet.allCases {
            if let url = WalletURISanitizer.buildPaymentURL(invoice: "lnbc1", wallet: wallet) {
                // Use canOpenURL which requires LSApplicationQueriesSchemes in Info.plist
                if UIApplication.shared.canOpenURL(url) {
                    return true
                }
            }
        }

        // Check generic lightning: scheme
        if let url = WalletURISanitizer.buildGenericLightningURL(invoice: "lnbc1") {
            return UIApplication.shared.canOpenURL(url)
        }

        return false
    }

    // MARK: - Bech32 LNURL Encoding

    /// Encode a URL as bech32 LNURL
    func encodeAsLNURL(_ urlString: String) -> String? {
        guard let data = urlString.data(using: .utf8) else {
            return nil
        }
        return Bech32.encode(hrp: "lnurl", data: data)
    }

    /// Decode a bech32 LNURL to URL string
    func decodeLNURL(_ lnurl: String) -> String? {
        guard let (hrp, data) = Bech32.decode(lnurl.lowercased()),
              hrp == "lnurl" else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Network Defense Helpers

    private func fetchData(from url: URL) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?

        for attempt in 0...maxRetries {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LNURLServiceError.serverError
                }

                if (500...599).contains(httpResponse.statusCode), attempt < maxRetries {
                    lastError = LNURLServiceError.serverError
                } else {
                    return (data, httpResponse)
                }
            } catch {
                lastError = error
            }

            guard attempt < maxRetries else { break }
            let delay = backoffDelay(for: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        throw lastError ?? LNURLServiceError.serverError
    }

    private func backoffDelay(for attempt: Int) -> TimeInterval {
        let exponential = baseRetryDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.2)
        return exponential + jitter
    }
}

// MARK: - Errors

enum LNURLServiceError: Error, LocalizedError {
    case invalidLightningAddress
    case invalidResponse
    case invalidCallback
    case serverError
    case rateLimited
    case amountOutOfRange(min: Int, max: Int)
    case noWalletInstalled
    case zapNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidLightningAddress:
            return "Invalid Lightning Address format"
        case .invalidResponse:
            return "Invalid response from Lightning server"
        case .invalidCallback:
            return "Invalid callback URL"
        case .serverError:
            return "Lightning server error"
        case .rateLimited:
            return "Too many Lightning requests. Please try again shortly."
        case .amountOutOfRange(let min, let max):
            return "Amount must be between \(min) and \(max) sats"
        case .noWalletInstalled:
            return "No Lightning wallet installed"
        case .zapNotSupported:
            return "This recipient doesn't support zaps"
        }
    }
}
