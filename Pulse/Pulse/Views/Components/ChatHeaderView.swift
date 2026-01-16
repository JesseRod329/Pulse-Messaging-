//
//  ChatHeaderView.swift
//  Pulse
//
//  Header for chat interface showing peer info and connection status
//

import SwiftUI

struct ChatHeaderView: View {
    let peer: PulsePeer
    let isConnected: Bool
    let onBack: () -> Void
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                HapticManager.shared.impact(.light)
                onBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to nearby developers list")

            ProfileImageView(size: 40, handle: peer.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.handle)
                    .font(.pulseHandle)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text(connectionStatusText)
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(peer.handle), \(connectionStatusText)")

            Spacer()

            Button(action: {
                HapticManager.shared.impact(.light)
                onSearch()
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Search messages")
            .accessibilityHint("Open message search")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var connectionStatusColor: Color {
        isConnected ? .green : .orange
    }

    private var connectionStatusText: String {
        isConnected ? "Connected" : "Connecting..."
    }
}
