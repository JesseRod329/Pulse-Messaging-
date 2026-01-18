//
//  ZapButton.swift
//  Pulse
//
//  Lightning bolt button for initiating zaps on messages.
//

import SwiftUI

struct ZapButton: View {
    let messageId: String?
    let recipientPubkey: String
    let lightningAddress: String?
    let totalZapAmount: Int  // sats
    let zapCount: Int
    let onTap: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            // Animate on tap
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
            onTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(zapCount > 0 ? .yellow : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)

                if totalZapAmount > 0 {
                    Text(totalZapAmount.formattedSats)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(
                zapCount > 0 ?
                Color.yellow.opacity(0.15) :
                Color(.secondarySystemBackground)
            )
            .cornerRadius(12)
        }
        .disabled(lightningAddress == nil || lightningAddress!.isEmpty)
        .opacity(lightningAddress == nil || lightningAddress!.isEmpty ? 0.5 : 1.0)
    }
}

// MARK: - Zap Pill (for displaying zap summary)

struct ZapPill: View {
    let totalAmount: Int  // sats
    let zapCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)

                Text(totalAmount.formattedSats)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if zapCount > 1 {
                    Text("(\(zapCount))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Quick Zap Button (single-tap default amount)

struct QuickZapButton: View {
    let defaultAmount: Int
    let isLoading: Bool
    let onQuickZap: () -> Void

    var body: some View {
        Button(action: onQuickZap) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)
                }

                Text("\(defaultAmount)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(height: 32)
            .padding(.horizontal, 12)
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Zap button with zaps
        ZapButton(
            messageId: "msg123",
            recipientPubkey: "pubkey",
            lightningAddress: "user@getalby.com",
            totalZapAmount: 21000,
            zapCount: 5,
            onTap: {}
        )

        // Zap button without zaps
        ZapButton(
            messageId: "msg456",
            recipientPubkey: "pubkey",
            lightningAddress: "user@getalby.com",
            totalZapAmount: 0,
            zapCount: 0,
            onTap: {}
        )

        // Disabled zap button (no lightning address)
        ZapButton(
            messageId: "msg789",
            recipientPubkey: "pubkey",
            lightningAddress: nil,
            totalZapAmount: 0,
            zapCount: 0,
            onTap: {}
        )

        // Zap pill
        ZapPill(totalAmount: 5000, zapCount: 3) {}

        // Quick zap button
        QuickZapButton(defaultAmount: 1000, isLoading: false) {}
    }
    .padding()
}
