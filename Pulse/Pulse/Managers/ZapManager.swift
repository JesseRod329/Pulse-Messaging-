//
//  ZapManager.swift
//  Pulse
//
//  Orchestrates NIP-57 zap flow: request creation, invoice fetching,
//  wallet integration, and receipt tracking.
//

import Foundation
import Combine

/// Manages Lightning zaps for Pulse messages
@MainActor
final class ZapManager: ObservableObject {
    static let shared = ZapManager()

    // MARK: - Published State

    @Published private(set) var pendingZaps: [String: PendingZap] = [:]
    @Published private(set) var receivedZaps: [String: [ZapReceipt]] = [:]  // messageId -> zaps
    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: String?

    // MARK: - Services

    private let lnurlService = LNURLService.shared
    private let nostrTransport = NostrTransport.shared
    private let nostrIdentityManager = NostrIdentityManager.shared

    // User preferences
    @Published var preferredWallet: LightningWallet = .automatic
    @Published var defaultZapAmount: Int = 1000  // sats

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupZapReceiptListener()
        loadPreferences()
    }

    enum ZapManagerError: Error, LocalizedError {
        case invoiceMissingAmount
        case invoiceAmountMismatch(expected: Int, actual: Int)
        case receiptSignatureInvalid
        case receiptPubkeyMismatch

        var errorDescription: String? {
            switch self {
            case .invoiceMissingAmount:
                return "Invoice does not include an amount."
            case .invoiceAmountMismatch(let expected, let actual):
                return "Invoice amount mismatch. Expected \(expected) msats, got \(actual) msats."
            case .receiptSignatureInvalid:
                return "Zap receipt signature is invalid."
            case .receiptPubkeyMismatch:
                return "Zap receipt signer does not match the LNURL provider."
            }
        }
    }

    // MARK: - Zap Flow

    /// Initiate a zap on a message
    func zapMessage(
        messageId: String?,
        recipientPubkey: String,
        lightningAddress: String,
        amount: Int,  // sats
        comment: String? = nil
    ) async throws {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        let zapId = UUID().uuidString
        let amountMillisats = amount * 1000

        // Create pending zap for tracking
        var pendingZap = PendingZap(
            id: zapId,
            zapRequestId: "",
            recipientPubkey: recipientPubkey,
            providerPubkey: nil,
            messageId: messageId,
            amount: amountMillisats,
            comment: comment,
            status: .pending,
            bolt11: nil,
            errorMessage: nil,
            createdAt: Date()
        )
        pendingZaps[zapId] = pendingZap

        do {
            // Step 1: Resolve Lightning Address
            let payResponse = try await lnurlService.resolveLightningAddress(lightningAddress)

            // Verify zap support
            guard payResponse.supportsZaps else {
                throw LNURLServiceError.zapNotSupported
            }

            // Step 2: Create zap request event (kind 9734)
            let zapRequestEvent = try await nostrTransport.publishZapRequest(
                recipientPubkey: recipientPubkey,
                lightningAddress: lightningAddress,
                amount: amountMillisats,
                messageEventId: messageId,
                comment: comment
            )

            // Update pending zap with request ID
            pendingZap.zapRequestId = zapRequestEvent.id
            pendingZap.providerPubkey = payResponse.nostrPubkey
            pendingZaps[zapId] = pendingZap

            // Step 3: Request invoice with zap request
            let invoiceResponse = try await lnurlService.requestInvoice(
                payResponse: payResponse,
                amount: amountMillisats,
                zapRequest: zapRequestEvent,
                comment: comment
            )

            let parsedInvoice = try Bolt11Validator.validate(invoiceResponse.pr)
            guard let invoiceAmount = parsedInvoice.amountMillisats else {
                throw ZapManagerError.invoiceMissingAmount
            }
            guard invoiceAmount == amountMillisats else {
                throw ZapManagerError.invoiceAmountMismatch(
                    expected: amountMillisats,
                    actual: invoiceAmount
                )
            }

            // Update status
            pendingZap.bolt11 = invoiceResponse.pr
            pendingZap.status = .invoiceReady
            pendingZaps[zapId] = pendingZap

            // Step 3b: Verify invoice matches zap request + UI intent
            _ = try ZapSecurityGuard.validate(
                invoice: invoiceResponse.pr,
                zapRequest: zapRequestEvent,
                expectedAmountMsat: amountMillisats
            )

            // Step 4: Open wallet for payment
            pendingZap.status = .paying
            pendingZaps[zapId] = pendingZap

            let walletOpened = lnurlService.openWallet(
                invoice: invoiceResponse.pr,
                preferredWallet: preferredWallet
            )

            if !walletOpened {
                throw LNURLServiceError.noWalletInstalled
            }

            // Mark as paid (user will complete in wallet)
            pendingZap.status = .paid
            pendingZaps[zapId] = pendingZap

            // Haptic feedback
            HapticManager.shared.impact(.medium)

        } catch {
            pendingZap.status = .failed
            pendingZap.errorMessage = error.localizedDescription
            pendingZaps[zapId] = pendingZap
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Quick zap with default amount
    func quickZap(
        messageId: String?,
        recipientPubkey: String,
        lightningAddress: String
    ) async throws {
        try await zapMessage(
            messageId: messageId,
            recipientPubkey: recipientPubkey,
            lightningAddress: lightningAddress,
            amount: defaultZapAmount,
            comment: nil
        )
    }

    // MARK: - Zap Receipt Handling

    private func setupZapReceiptListener() {
        // Listen for zap receipts from Nostr transport
        nostrTransport.onZapReceived = { [weak self] event in
            Task { @MainActor in
                self?.handleZapReceipt(event)
            }
        }

        // Subscribe to zap receipts for our pubkey
        if let pubkey = nostrIdentityManager.publicKeyHex {
            nostrTransport.subscribeToZapReceipts(for: pubkey)
        }
    }

    private func handleZapReceipt(_ event: NostrEvent) {
        // Validate zap receipt using dedicated validator (includes signature check)
        do {
            try NostrEventValidator.validateZapReceipt(event)
        } catch {
            print("Ignoring invalid zap receipt: \(error.localizedDescription)")
            return
        }

        guard let receipt = ZapReceipt.from(event: event) else {
            return
        }

        // Update pending zap if we have one matching
        for (zapId, var pendingZap) in pendingZaps {
            if pendingZap.zapRequestId == receipt.zapRequestId {
                // Verify the receipt is from the expected provider
                if let providerPubkey = pendingZap.providerPubkey,
                   providerPubkey.lowercased() != event.pubkey.lowercased() {
                    return
                }
                pendingZap.status = .confirmed
                pendingZaps[zapId] = pendingZap

                // Play success sound
                SoundManager.shared.playZapReceived()
                HapticManager.shared.notify(.success)
                break
            }
        }

        // Store receipt by message ID
        if let messageId = receipt.messageEventId {
            var zapsForMessage = receivedZaps[messageId] ?? []
            // Avoid duplicates
            if !zapsForMessage.contains(where: { $0.id == receipt.id }) {
                zapsForMessage.append(receipt)
                receivedZaps[messageId] = zapsForMessage
            }
        }
    }

    // MARK: - Query Methods

    /// Get total zap amount for a message (in sats)
    func totalZapsForMessage(_ messageId: String) -> Int {
        let receipts = receivedZaps[messageId] ?? []
        return receipts.reduce(0) { $0 + $1.sats }
    }

    /// Get zap count for a message
    func zapCountForMessage(_ messageId: String) -> Int {
        return receivedZaps[messageId]?.count ?? 0
    }

    /// Get zaps for a specific message
    func zapsForMessage(_ messageId: String) -> [ZapReceipt] {
        return receivedZaps[messageId] ?? []
    }

    /// Get pending zap by ID
    func pendingZap(_ zapId: String) -> PendingZap? {
        return pendingZaps[zapId]
    }

    /// Clean up expired pending zaps
    func cleanupExpiredZaps() {
        let expireThreshold = Date().addingTimeInterval(-3600)  // 1 hour

        pendingZaps = pendingZaps.filter { _, zap in
            zap.createdAt > expireThreshold || zap.status == .confirmed
        }
    }

    // MARK: - Preferences

    private func loadPreferences() {
        if let walletString = UserDefaults.standard.string(forKey: "preferredLightningWallet"),
           let wallet = LightningWallet(rawValue: walletString) {
            preferredWallet = wallet
        }

        let savedAmount = UserDefaults.standard.integer(forKey: "defaultZapAmount")
        if savedAmount > 0 {
            defaultZapAmount = savedAmount
        }
    }

    func savePreferences() {
        UserDefaults.standard.set(preferredWallet.rawValue, forKey: "preferredLightningWallet")
        UserDefaults.standard.set(defaultZapAmount, forKey: "defaultZapAmount")
    }

    func setPreferredWallet(_ wallet: LightningWallet) {
        preferredWallet = wallet
        savePreferences()
    }

    func setDefaultZapAmount(_ amount: Int) {
        defaultZapAmount = amount
        savePreferences()
    }
}

// MARK: - SoundManager Extension

extension SoundManager {
    func playZapReceived() {
        // Use existing sound infrastructure or add a zap-specific sound
        // For now, use the existing message received sound
        messageReceived()
    }
}
