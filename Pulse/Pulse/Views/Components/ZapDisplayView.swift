//
//  ZapDisplayView.swift
//  Pulse
//
//  Displays zaps on a message (similar to ReactionDisplayView).
//

import SwiftUI

struct ZapDisplayView: View {
    let messageId: String
    let recipientPubkey: String
    let lightningAddress: String?
    let onZap: () -> Void
    let onShowZapDetails: () -> Void

    @ObservedObject private var zapManager = ZapManager.shared

    private var totalAmount: Int {
        zapManager.totalZapsForMessage(messageId)
    }

    private var zapCount: Int {
        zapManager.zapCountForMessage(messageId)
    }

    private var zaps: [ZapReceipt] {
        zapManager.zapsForMessage(messageId)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Show zap summary if there are zaps
            if zapCount > 0 {
                ZapPill(
                    totalAmount: totalAmount,
                    zapCount: zapCount,
                    onTap: onShowZapDetails
                )
            }

            // Add zap button
            ZapButton(
                messageId: messageId,
                recipientPubkey: recipientPubkey,
                lightningAddress: lightningAddress,
                totalZapAmount: zapCount > 0 ? 0 : 0,  // Don't show amount on button if pill shows it
                zapCount: 0,
                onTap: onZap
            )

            Spacer()
        }
        .padding(.top, 6)
    }
}

// MARK: - Zap Details Sheet

struct ZapDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let messageId: String
    let zaps: [ZapReceipt]
    @State private var revealSensitive = false

    var totalAmount: Int {
        zaps.reduce(0) { $0 + $1.sats }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Reveal sensitive data", isOn: $revealSensitive)
                        .privacySensitiveIfAvailable()
                }

                // Summary section
                Section {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                        Text("Total Zapped")
                        Spacer()
                        Text(revealSensitive ? "\(totalAmount.formattedSats) sats" : "Hidden")
                            .fontWeight(.semibold)
                            .privacySensitiveIfAvailable()
                    }
                }

                // Individual zaps
                Section("Zaps") {
                    ForEach(zaps) { zap in
                        ZapRow(zap: zap, revealSensitive: revealSensitive)
                    }
                }
            }
            .navigationTitle("Zap Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Zap Row

struct ZapRow: View {
    let zap: ZapReceipt
    let revealSensitive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Sender info
                Text(revealSensitive ? formatPubkey(zap.senderPubkey) : "Hidden")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .privacySensitiveIfAvailable()

                // Comment if any
                if let comment = zap.comment, !comment.isEmpty {
                    Text(revealSensitive ? comment : "Hidden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .privacySensitiveIfAvailable()
                }

                // Timestamp
                Text(zap.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Amount
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(revealSensitive ? "\(zap.sats)" : "—")
                    .fontWeight(.semibold)
                    .privacySensitiveIfAvailable()
            }
        }
        .padding(.vertical, 4)
    }

    private func formatPubkey(_ pubkey: String) -> String {
        if pubkey.count > 12 {
            return "\(pubkey.prefix(6))...\(pubkey.suffix(4))"
        }
        return pubkey
    }
}

// MARK: - Zap Animation Overlay

struct ZapAnimationOverlay: View {
    let amount: Int
    @Binding var isVisible: Bool

    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    @State private var yOffset: CGFloat = 0

    var body: some View {
        if isVisible {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("+\(amount)")
                    .fontWeight(.bold)
            }
            .font(.title2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                    opacity = 0
                    yOffset = -50
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ZapDisplayView(
            messageId: "msg123",
            recipientPubkey: "pubkey",
            lightningAddress: "user@getalby.com",
            onZap: {},
            onShowZapDetails: {}
        )

        ZapDetailsSheet(
            messageId: "msg123",
            zaps: [
                ZapReceipt(
                    id: "1",
                    senderPubkey: "abc123def456",
                    recipientPubkey: "xyz789",
                    amount: 1000000,
                    bolt11: "lnbc...",
                    preimage: nil,
                    zapRequestId: "req1",
                    messageEventId: "msg123",
                    comment: "Great message!",
                    createdAt: Date()
                ),
                ZapReceipt(
                    id: "2",
                    senderPubkey: "def456abc123",
                    recipientPubkey: "xyz789",
                    amount: 21000000,
                    bolt11: "lnbc...",
                    preimage: nil,
                    zapRequestId: "req2",
                    messageEventId: "msg123",
                    comment: nil,
                    createdAt: Date().addingTimeInterval(-3600)
                )
            ]
        )
    }
    .padding()
}
