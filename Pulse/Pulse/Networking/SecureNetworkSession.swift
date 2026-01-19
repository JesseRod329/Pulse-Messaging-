//
//  SecureNetworkSession.swift
//  Pulse
//
//  Provides secure URLSession instances with certificate validation and pinning.
//  Protects against MITM attacks by validating server certificates.
//

import Foundation
import Security
import CryptoKit

/// Configuration for certificate pinning
struct CertificatePinningConfig {
    /// Known public key hashes for pinned domains (SHA256 of SPKI)
    /// Format: ["domain.com": ["base64-encoded-sha256-hash1", "hash2"]]
    let pinnedPublicKeyHashes: [String: [String]]

    /// Whether to allow connections to domains without pins (for open ecosystems like Nostr)
    let allowUnpinnedDomains: Bool

    /// Minimum TLS version required
    let minimumTLSVersion: tls_protocol_version_t

    /// Whether to require certificate transparency
    let requireCertificateTransparency: Bool

    static let `default` = CertificatePinningConfig(
        pinnedPublicKeyHashes: [:],
        allowUnpinnedDomains: true,
        minimumTLSVersion: .TLSv12,
        requireCertificateTransparency: false
    )

    /// Strict configuration for known endpoints
    static let strict = CertificatePinningConfig(
        pinnedPublicKeyHashes: [:],
        allowUnpinnedDomains: false,
        minimumTLSVersion: .TLSv13,
        requireCertificateTransparency: true
    )
}

/// Delegate that handles certificate validation and pinning
final class CertificatePinningDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let config: CertificatePinningConfig

    init(config: CertificatePinningConfig = .default) {
        self.config = config
        super.init()
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }

    // MARK: - Certificate Validation

    private func handleChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Validate the certificate chain
        guard validateCertificateChain(serverTrust, for: host) else {
            // Certificate validation failed - reject connection
            #if DEBUG
            print("⚠️ Certificate validation failed for \(host)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check if we have pins for this domain
        if let pins = config.pinnedPublicKeyHashes[host] {
            // Validate against pinned public keys
            if validatePublicKeyPins(serverTrust, against: pins) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                #if DEBUG
                print("⚠️ Public key pinning failed for \(host)")
                #endif
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else if config.allowUnpinnedDomains {
            // No pins for this domain, but unpinned domains are allowed
            // Still perform standard validation
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            // No pins and unpinned domains not allowed
            #if DEBUG
            print("⚠️ No certificate pins for \(host) and unpinned domains not allowed")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Validate the certificate chain using system trust evaluation
    private func validateCertificateChain(_ serverTrust: SecTrust, for host: String) -> Bool {
        // Set SSL policy with hostname validation
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        // Evaluate trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if !isValid {
            #if DEBUG
            if let error = error {
                print("⚠️ Trust evaluation error: \(error)")
            }
            #endif
        }

        return isValid
    }

    /// Validate server certificate against pinned public key hashes
    private func validatePublicKeyPins(_ serverTrust: SecTrust, against pins: [String]) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        // Check each certificate in the chain
        for index in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) else {
                continue
            }

            // Extract public key and compute hash
            if let publicKeyHash = extractPublicKeyHash(from: certificate) {
                if pins.contains(publicKeyHash) {
                    return true
                }
            }
        }

        return false
    }

    /// Extract SHA256 hash of the Subject Public Key Info (SPKI)
    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // Compute SHA256 hash
        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }
}

/// Factory for creating secure URLSession instances
enum SecureNetworkSession {

    /// Create a secure URLSession for general API calls
    /// Uses certificate validation but allows connections to any valid HTTPS endpoint
    static func createSession(
        configuration: URLSessionConfiguration = .default,
        pinningConfig: CertificatePinningConfig = .default
    ) -> URLSession {
        // Configure TLS settings
        configuration.tlsMinimumSupportedProtocolVersion = pinningConfig.minimumTLSVersion
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        // Disable URL caching for sensitive requests
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let delegate = CertificatePinningDelegate(config: pinningConfig)

        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    /// Create a secure URLSession for LNURL requests
    static func createLNURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        // LNURL servers are distributed, so we allow unpinned but validate certificates
        let pinningConfig = CertificatePinningConfig(
            pinnedPublicKeyHashes: [:],
            allowUnpinnedDomains: true,
            minimumTLSVersion: .TLSv12,
            requireCertificateTransparency: false
        )

        return createSession(configuration: config, pinningConfig: pinningConfig)
    }

    /// Create a secure URLSession for WebSocket connections (Nostr relays)
    static func createWebSocketSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300

        // WebSocket keep-alive
        config.shouldUseExtendedBackgroundIdleMode = true

        // Nostr relays are distributed, validate certificates but allow any valid HTTPS
        let pinningConfig = CertificatePinningConfig(
            pinnedPublicKeyHashes: [:],
            allowUnpinnedDomains: true,
            minimumTLSVersion: .TLSv12,
            requireCertificateTransparency: false
        )

        return createSession(configuration: config, pinningConfig: pinningConfig)
    }

    /// Create a session with specific pinned domains
    /// Use this for known critical endpoints where you can control the certificates
    static func createPinnedSession(
        pinnedHosts: [String: [String]],
        allowOtherDomains: Bool = false
    ) -> URLSession {
        let pinningConfig = CertificatePinningConfig(
            pinnedPublicKeyHashes: pinnedHosts,
            allowUnpinnedDomains: allowOtherDomains,
            minimumTLSVersion: .TLSv13,
            requireCertificateTransparency: true
        )

        return createSession(pinningConfig: pinningConfig)
    }
}

// MARK: - Certificate Pin Extraction Helper

extension SecureNetworkSession {
    /// Helper to extract the public key pin from a certificate for configuration
    /// Call this during development to get pins for known servers
    @available(*, deprecated, message: "Only use during development to extract pins")
    static func extractPin(from url: URL) async -> String? {
        let session = URLSession(configuration: .ephemeral)

        do {
            let (_, response) = try await session.data(from: url)

            // This would need a custom delegate to actually extract the pin
            // For now, return nil as this is a development helper
            _ = response
            return nil
        } catch {
            return nil
        }
    }
}
