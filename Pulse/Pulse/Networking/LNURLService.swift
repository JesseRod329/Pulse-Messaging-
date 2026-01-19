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

        // SECURITY: Validate and sanitize Lightning Address
        let validatedAddress = try validateLightningAddress(address)

        // Parse Lightning Address
        let parts = validatedAddress.split(separator: "@")
        guard parts.count == 2 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        let username = String(parts[0])
        let domain = String(parts[1])

        // SECURITY: URL-encode username to prevent injection attacks
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Construct well-known URL
        guard let url = URL(string: "https://\(domain)/.well-known/lnurlp/\(encodedUsername)") else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // SECURITY: Validate URL doesn't target internal networks
        try validateLNURLEndpoint(url)

        // Fetch LNURL metadata
        let (data, response) = try await session.data(from: url)

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
        let (data, response) = try await session.data(from: callbackURL)

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
           let url = preferredWallet.paymentURL(invoice: invoice),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }

        // Try each wallet in order
        for wallet in LightningWallet.allCases where wallet != .automatic {
            if let url = wallet.paymentURL(invoice: invoice),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
        }

        // Fall back to generic lightning: scheme
        if let url = URL(string: "lightning:\(invoice)") {
            UIApplication.shared.open(url)
            return true
        }

        return false
    }

    /// Check if any Lightning wallet is installed
    func hasLightningWallet() -> Bool {
        for wallet in LightningWallet.allCases {
            if let url = wallet.paymentURL(invoice: "lnbc1") {
                // Use canOpenURL which requires LSApplicationQueriesSchemes in Info.plist
                if UIApplication.shared.canOpenURL(url) {
                    return true
                }
            }
        }

        // Check generic lightning: scheme
        if let url = URL(string: "lightning:lnbc1") {
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

    // MARK: - Input Validation

    /// Validate and sanitize Lightning Address
    /// Format: username@domain.com
    private func validateLightningAddress(_ address: String) throws -> String {
        // 1. Trim whitespace
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Check length limits
        guard trimmed.count >= 3, trimmed.count <= 255 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // 3. Check format (must contain exactly one @)
        let atCount = trimmed.filter { $0 == "@" }.count
        guard atCount == 1 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // 4. Parse components
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        let username = String(parts[0])
        let domain = String(parts[1])

        // 5. Validate username
        try validateUsername(username)

        // 6. Validate domain
        try validateDomain(domain)

        return trimmed
    }

    /// Validate Lightning Address username component
    /// Allowed: alphanumeric, hyphen, underscore, dot
    private func validateUsername(_ username: String) throws {
        // Length check
        guard username.count >= 1, username.count <= 64 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Character validation (alphanumeric + hyphen + underscore + dot)
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_."))

        guard username.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Must start with alphanumeric
        guard let firstChar = username.first,
              firstChar.isLetter || firstChar.isNumber else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Block directory traversal
        guard !username.contains(".."),
              !username.contains("//"),
              !username.contains("\\") else {
            throw LNURLServiceError.invalidLightningAddress
        }
    }

    /// Validate Lightning Address domain component
    private func validateDomain(_ domain: String) throws {
        // Length check
        guard domain.count >= 3, domain.count <= 253 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Convert to lowercase for validation
        let lowercaseDomain = domain.lowercased()

        // Block localhost
        guard lowercaseDomain != "localhost",
              lowercaseDomain != "127.0.0.1",
              lowercaseDomain != "::1" else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Block private IP ranges
        if lowercaseDomain.starts(with: "10.") ||
           lowercaseDomain.starts(with: "192.168.") ||
           lowercaseDomain.starts(with: "169.254.") {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Check for 172.16.0.0 - 172.31.255.255
        if lowercaseDomain.starts(with: "172.") {
            let parts = lowercaseDomain.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
                throw LNURLServiceError.invalidLightningAddress
            }
        }

        // Basic domain format validation
        // Must contain at least one dot
        guard lowercaseDomain.contains(".") else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Domain labels (separated by dots)
        let labels = lowercaseDomain.split(separator: ".")

        // At least 2 labels (e.g., "domain.com")
        guard labels.count >= 2 else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Validate each label
        for label in labels {
            // Label length: 1-63 characters
            guard label.count >= 1, label.count <= 63 else {
                throw LNURLServiceError.invalidLightningAddress
            }

            // Label must start and end with alphanumeric
            guard let first = label.first, first.isLetter || first.isNumber,
                  let last = label.last, last.isLetter || last.isNumber else {
                throw LNURLServiceError.invalidLightningAddress
            }

            // Label can only contain alphanumeric and hyphen
            let allowedCharacters = CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "-"))

            guard label.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
                throw LNURLServiceError.invalidLightningAddress
            }
        }

        // TLD (top-level domain) must be at least 2 characters
        if let tld = labels.last {
            guard tld.count >= 2 else {
                throw LNURLServiceError.invalidLightningAddress
            }
        }
    }

    /// Validate LNURL endpoint doesn't target internal networks
    private func validateLNURLEndpoint(_ url: URL) throws {
        // Check scheme
        guard url.scheme?.lowercased() == "https" else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Check host
        guard let host = url.host?.lowercased() else {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Block localhost
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Block private IPs (redundant check, but defense in depth)
        if host.starts(with: "10.") ||
           host.starts(with: "192.168.") ||
           host.starts(with: "169.254.") {
            throw LNURLServiceError.invalidLightningAddress
        }

        // Block 172.16-31 range
        if host.starts(with: "172.") {
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16, second <= 31 {
                throw LNURLServiceError.invalidLightningAddress
            }
        }
    }
}

// MARK: - Errors

enum LNURLServiceError: Error, LocalizedError {
    case invalidLightningAddress
    case invalidResponse
    case invalidCallback
    case serverError
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
        case .amountOutOfRange(let min, let max):
            return "Amount must be between \(min) and \(max) sats"
        case .noWalletInstalled:
            return "No Lightning wallet installed"
        case .zapNotSupported:
            return "This recipient doesn't support zaps"
        }
    }
}
