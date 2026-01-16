//
//  PeerNode.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import SwiftUI

struct PeerNode: View {
    let peer: PulsePeer
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: iconFor(peer.techStack.first ?? ""))
                .font(.system(size: sizeFor(peer.distance)))
                .foregroundStyle(.white)

            // Handle
            Text(peer.handle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            // Tech Stack
            Text(peer.techStack.prefix(2).joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            // Distance
            Text(distanceText(peer.distance))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(paddingFor(peer.distance))
        .scaleEffect(isPulsing && peer.isActive ? 1.08 : 1.0)
        .animation(
            peer.isActive ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default,
            value: isPulsing
        )
        .onAppear {
            if peer.isActive {
                isPulsing = true
            }
        }
    }

    private func sizeFor(_ distance: Double) -> CGFloat {
        switch distance {
        case 0..<15: return 44
        case 15..<50: return 34
        default: return 24
        }
    }

    private func paddingFor(_ distance: Double) -> CGFloat {
        switch distance {
        case 0..<15: return 18
        case 15..<50: return 14
        default: return 10
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if meters < 15 {
            return "< \(Int(meters))m"
        } else if meters < 50 {
            return "~\(Int(meters))m"
        } else {
            return "far"
        }
    }

    private func iconFor(_ tech: String) -> String {
        switch tech.lowercased() {
        case "swift": return "swift"
        case "rust": return "gear.badge"
        case "python": return "chevron.left.forwardslash.chevron.right"
        case "javascript", "js": return "curlybraces"
        case "go": return "g.circle.fill"
        case "java", "kotlin": return "cup.and.saucer.fill"
        default: return "person.circle.fill"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PeerNode(
            peer: PulsePeer(
                id: "1",
                handle: "@jesse_codes",
                status: .active,
                techStack: ["Swift", "Rust"],
                distance: 12,
                publicKey: nil,
                signingPublicKey: nil
            )
        )
        .liquidGlass(style: .regular, tint: .green.opacity(0.7), interactive: true)
    }
}
