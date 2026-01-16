//
//  LaunchRadarView.swift
//  Pulse
//
//  Created by Jesse on 2025
//

import SwiftUI

enum OnboardingPhase {
    case launching    // 0-3s: Radar pulsing, scanning text
    case permission   // 3-6s: System permission appears
    case identity     // 6-12s: Identity card slides up
    case aha          // 12-18s: Self node appears, ring expands
    case discovery    // 18-30s: Peers start appearing
}

@MainActor
struct LaunchRadarView: View {
    @EnvironmentObject var meshManager: MeshManager
    @State private var phase: OnboardingPhase = .launching
    @State private var pulse = false
    @State private var showIdentity = false
    @State private var showAha = false
    @State private var ringExpanded = false
    @State private var selectedPeer: PulsePeer?
    @ObservedObject var placeManager = PlaceManager.shared

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            // Radar Pulse (Always present but fades or moves)
            RadarPulseView(pulse: $pulse)
                .opacity(phase == .launching || phase == .permission ? 1 : 0.4)
                .scaleEffect(phase == .aha || phase == .discovery ? 0.8 : 1.0)
            
            // Radius Ring (Aha Moment)
            if showAha {
                RadiusRingView(expanded: $ringExpanded)
                    .animation(.easeOut(duration: placeManager.currentPlace?.pulseSpeed ?? 1.2), value: ringExpanded)
            }

            // Self Node (Aha Moment)
            if showAha {
                SelfNodeView()
                    .transition(.scale.combined(with: .opacity))
            }

            // Discovery Phase Peers (Simulated)
            if phase == .discovery {
                ZStack {
                    DiscoveryPeerNode(peer: PulsePeer(id: "sim1", handle: "@swift_sarah", status: .active, techStack: ["Swift"], distance: 15, publicKey: nil, signingPublicKey: nil), offset: CGSize(width: -100, height: -150))
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedPeer = PulsePeer(id: "sim1", handle: "@swift_sarah", status: .active, techStack: ["Swift"], distance: 15, publicKey: nil, signingPublicKey: nil)
                            }
                        }
                    
                    DiscoveryPeerNode(peer: PulsePeer(id: "sim2", handle: "@rust_dev", status: .flowState, techStack: ["Rust"], distance: 45, publicKey: nil, signingPublicKey: nil), offset: CGSize(width: 120, height: 80))
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedPeer = PulsePeer(id: "sim2", handle: "@rust_dev", status: .flowState, techStack: ["Rust"], distance: 45, publicKey: nil, signingPublicKey: nil)
                            }
                        }
                    
                    // Fallback for "No real peers yet"
                    VStack {
                        Spacer()
                        Text("Expanding reach securely")
                            .font(.pulseCaption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 120)
                    }
                    .transition(.opacity)
                }
            }

            VStack {
                if phase == .discovery {
                    PlacePillView()
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if phase == .launching || phase == .permission {
                    Spacer()
                    Text("Scanning for developers nearby")
                        .font(.pulseBody)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 80)
                        .transition(.opacity)
                }

                if phase == .aha {
                    Spacer()
                    Text("Anyone inside this circle can see you")
                        .font(.pulseBody)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 80)
                        .transition(.opacity)
                }
            }

            // Identity Card
            if phase == .identity {
                VStack {
                    Spacer()
                    IdentityCardView(onComplete: {
                        withAnimation(.spring(response: 0.8)) {
                            phase = .aha
                            showAha = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 1.2)) {
                                    ringExpanded = true
                                }
                            }
                        }

                        // Move to discovery after aha moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                phase = .discovery
                            }
                        }
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 40)
                }
            }
            
            // Interaction Card
            if let peer = selectedPeer {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { selectedPeer = nil }
                        }
                    
                    VStack {
                        Spacer()
                        PeerCardView(peer: peer)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                }
            }
            
            // Places Selector
            if placeManager.showSelector {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                placeManager.showSelector = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        PlaceSelectorView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            startOnboardingSequence()
        }
    }

    private func startOnboardingSequence() {
        // Phase 1: Launching
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulse = true
        }

        // Phase 2: Permission (3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                phase = .permission
            }
            // Trigger the actual permission request
            meshManager.requestBluetoothPermission()
        }

        // Phase 3: Identity (6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation(.spring()) {
                phase = .identity
            }
        }
    }
}

struct RadarPulseView: View {
    @Binding var pulse: Bool
    @ObservedObject var placeManager = PlaceManager.shared

    var body: some View {
        ZStack {
            // Center glow dot
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 12, height: 12)
                .shadow(color: .white.opacity(0.5), radius: 8)

            // Expanding pulse rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(pulse ? 0 : (placeManager.currentPlace?.ringTextureOpacity ?? 0.3)), lineWidth: 1)
                    .frame(width: 40 + CGFloat(index * 40), height: 40 + CGFloat(index * 40))
                    .scaleEffect(pulse ? 2.5 : 1)
                    .opacity(pulse ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: placeManager.currentPlace?.pulseSpeed ?? 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: pulse
                    )
            }
        }
    }
}

struct SelfNodeView: View {
    @State private var appear = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.9))
            .frame(width: 16, height: 16)
            .shadow(color: .white.opacity(0.5), radius: 10)
            .scaleEffect(appear ? 1.0 : 0.4)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    appear = true
                }
            }
    }
}

struct RadiusRingView: View {
    @Binding var expanded: Bool

    var body: some View {
        Circle()
            .stroke(.white.opacity(0.15), lineWidth: 1.5)
            .frame(width: expanded ? 300 : 40, height: expanded ? 300 : 40)
            .background(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: expanded ? 150 : 20
                        )
                    )
            )
    }
}

struct DiscoveryPeerNode: View {
    let peer: PulsePeer
    let offset: CGSize
    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(peer.status == .active ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
                .shadow(color: (peer.status == .active ? Color.green : Color.orange).opacity(0.5), radius: 6)
                .scaleEffect(pulse ? 1.2 : 1.0)

            VStack(spacing: 2) {
                Text(peer.handle)
                    .font(.pulseCaption)
                    .foregroundStyle(.white)
                Text("~\(Int(peer.distance))m")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .offset(offset)
        .scaleEffect(appear ? 1.0 : 0.5)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(Double.random(in: 0...1))) {
                appear = true
            }
            
            if peer.status == .active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

#Preview {
    LaunchRadarView()
        .environmentObject(MeshManager())
}

// MARK: - Peer Interaction Components

struct PeerCardView: View {
    let peer: PulsePeer

    var body: some View {
        VStack(spacing: 20) {
            // Header with Avatar and Handle
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                    
                    Text(String(peer.handle.dropFirst().prefix(1)).uppercased())
                        .font(.pulseTitle)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.handle)
                        .font(.pulseHandle)
                        .foregroundStyle(.white)
                    
                    Text(peer.techStack.joined(separator: ", "))
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                StatusBadge(status: peer.status)
            }
            
            // Interaction Buttons
            HStack(spacing: 12) {
                InteractionButton(title: "Wave", icon: "hand.wave.fill") {}
                InteractionButton(title: "Ping", icon: "bolt.fill") {}
                InteractionButton(title: "Chat", icon: "bubble.left.fill", primary: true) {}
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct StatusBadge: View {
    let status: PeerStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .flowState: return .orange
        case .idle: return .gray
        }
    }
}

struct InteractionButton: View {
    let title: String
    let icon: String
    var primary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.pulseLabel)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(primary ? Color.white : Color.white.opacity(0.1))
            .foregroundStyle(primary ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}