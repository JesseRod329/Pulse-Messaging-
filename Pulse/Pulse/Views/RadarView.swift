//
//  RadarView.swift
//  Pulse
//
//  Clean, minimal radar view showing nearby developers.
//

import SwiftUI

struct RadarView: View {
    @EnvironmentObject var meshManager: MeshManager
    @State private var themeManager = ThemeManager.shared
    @State private var selectedPeer: PulsePeer?
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showNetwork = false
    @State private var showLocationChannels = false
    @State private var showCreateGroup = false
    @State private var showGroupList = false
    @State private var showContent = false
    @State private var pulseAnimation = false
    @State private var isRefreshing = false
    @State private var refreshRotation: Double = 0
    @ObservedObject var placeManager = PlaceManager.shared

    var body: some View {
        ZStack {
            // Themed background
            themeManager.colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                
                // Places Pill
                PlacePillView()
                    .padding(.top, 12)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)

                // Quick actions
                quickActions
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                // Status indicator
                statusBadge
                    .padding(.top, 16)
                    .opacity(showContent ? 1 : 0)

                // Peer list
                if meshManager.nearbyPeers.isEmpty {
                    emptyState
                        .opacity(showContent ? 1 : 0)
                } else {
                    peerList
                        .opacity(showContent ? 1 : 0)
                }

                Spacer()
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
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
        .sheet(item: $selectedPeer) { peer in
            ChatView(peer: peer)
                .environmentObject(meshManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showNetwork) {
            NetworkTopologyView()
        }
        .sheet(isPresented: $showLocationChannels) {
            LocationChannelsView()
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView(meshManager: meshManager)
        }
        .sheet(isPresented: $showGroupList) {
            GroupListView()
                .environmentObject(meshManager)
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nearby")
                    .font(.pulseTitle)
                    .foregroundStyle(themeManager.colors.text)

                HStack(spacing: 8) {
                    // Animated pulse dot
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 1)
                        .opacity(pulseAnimation ? 0.7 : 1)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }

                    Text("\(meshManager.nearbyPeers.count) developer\(meshManager.nearbyPeers.count == 1 ? "" : "s") nearby")
                        .font(.pulseBodySecondary)
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            HStack(spacing: 12) {
                // Profile button with ring
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showProfile = true
                }) {
                    ZStack {
                        Circle()
                            .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 2)
                            .frame(width: 42, height: 42)

                        ProfileHeaderImage(size: 36)
                    }
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("Opens your profile settings")

                // Settings button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettings = true
                }) {
                    Circle()
                        .fill(themeManager.colors.cardBackground)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(themeManager.colors.textSecondary)
                        )
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens app settings")
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(
                icon: "person.2.fill",
                label: "Groups",
                action: { showGroupList = true }
            )

            quickActionButton(
                icon: "network",
                label: "Network",
                action: { showNetwork = true }
            )

            quickActionButton(
                icon: "location.fill",
                label: "Channels",
                action: { showLocationChannels = true }
            )
        }
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.pulseLabel)
                Text(label)
                    .font(.pulseLabel)
            }
            .foregroundStyle(themeManager.colors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .fill(themeManager.colors.accent.opacity(0.15))
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeManager.colors.accent.opacity(0.4),
                                    themeManager.colors.accent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: themeManager.colors.accent.opacity(0.25), radius: 8, y: 4)
        }
        .accessibilityLabel(label)
        .accessibilityHint("Opens \(label.lowercased()) view")
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 8) {
            ZStack {
                // Glow
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 12, height: 12)
                    .blur(radius: 4)

                // Dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            .accessibilityHidden(true)

            Text("Discovering")
                .font(.pulseLabel)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.green.opacity(0.1))
                Capsule()
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: Color.green.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: Discovering nearby developers")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            AnimatedRadarEmptyState()

            Spacer()
        }
    }
}

// MARK: - Animated Radar Empty State

struct AnimatedRadarEmptyState: View {
    @ObservedObject var placeManager = PlaceManager.shared
    @State private var isPulsing = false
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Outer pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(isPulsing ? 0 : (placeManager.currentPlace?.ringTextureOpacity ?? 0.15)), lineWidth: 1)
                        .frame(width: 100 + CGFloat(index * 50), height: 100 + CGFloat(index * 50))
                        .scaleEffect(isPulsing ? 1.3 : 1)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: placeManager.currentPlace?.pulseSpeed ?? 2.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.5),
                            value: isPulsing
                        )
                }

                // Rotating radar sweep
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        AngularGradient(
                            colors: [.white.opacity(0.3), .clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(90)
                        ),
                        lineWidth: 40
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotation))

                // Center dot
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.5), radius: 8)

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
            }
            .frame(width: 250, height: 250)

            VStack(spacing: 12) {
                Text("Scanning for developers...")
                    .font(.pulseBody)
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 4) {
                    Text("Make sure Bluetooth is enabled on your device")
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Move closer to other developers to discover them")
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.4))
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green.opacity(0.7))
                    Text("Bluetooth enabled")
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning for nearby developers")
        .accessibilityHint("Make sure Bluetooth is enabled and move closer to other developers")
        .onAppear {
            isPulsing = true
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Peer List Extension

extension RadarView {
    var peerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Refresh indicator
                if isRefreshing {
                    RefreshIndicatorView(rotation: refreshRotation)
                        .transition(.opacity.combined(with: .scale))
                }

                ForEach(Array(meshManager.nearbyPeers.enumerated()), id: \.element.id) { index, peer in
                    PeerCard(peer: peer)
                        .onTapGesture {
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            selectedPeer = peer
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens chat with \(peer.handle)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .refreshable {
            await performRefresh()
        }
    }

    @MainActor
    private func performRefresh() async {
        // Start refresh animation
        withAnimation(.spring(response: 0.3)) {
            isRefreshing = true
        }

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Start rotation animation
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            refreshRotation = 360
        }

        // Play sound
        SoundManager.shared.playPeerDiscoveredSound()

        // Simulate network scan (in real app, this would trigger mesh scan)
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Stop animation
        withAnimation(.spring(response: 0.3)) {
            isRefreshing = false
            refreshRotation = 0
        }

        // Success haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Refresh Indicator

struct RefreshIndicatorView: View {
    let rotation: Double
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(themeManager.colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(rotation))
            }

            Text("Scanning for developers...")
                .font(.pulseBodySecondary)
                .foregroundStyle(themeManager.colors.textSecondary)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Peer Card

struct PeerCard: View {
    let peer: PulsePeer
    @State private var isPressed = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 16) {
            // Avatar with status ring and glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .blur(radius: 12)

                // Outer status ring with glass effect
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                statusColor.opacity(0.6),
                                statusColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 54, height: 54)

                // Avatar (image or initials)
                ProfileImageView(size: 48, handle: peer.handle)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                // Online indicator with glow
                ZStack {
                    // Glow
                    Circle()
                        .fill(statusColor.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .blur(radius: 6)

                    // Indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.5), lineWidth: 2)
                        )
                }
                .offset(x: 18, y: 18)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(peer.handle)
                    .font(.pulseHandle)
                    .foregroundStyle(.white)

                // Tech stack as liquid glass pills
                HStack(spacing: 6) {
                    ForEach(peer.techStack.prefix(2), id: \.self) { tech in
                        Text(tech)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                    Capsule()
                                        .fill(getTechColor(tech).opacity(0.2))
                                    Capsule()
                                        .strokeBorder(getTechColor(tech).opacity(0.4), lineWidth: 1)
                                }
                            )
                            .shadow(color: getTechColor(tech).opacity(0.3), radius: 4, y: 2)
                    }
                    if peer.techStack.count > 2 {
                        Text("+\(peer.techStack.count - 2)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Distance & signal with glass badge
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    signalStrengthIcon
                    Text(distanceText)
                        .font(.pulseTimestamp)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        Capsule()
                            .fill(.ultraThinMaterial)
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                        Capsule()
                            .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
                    }
                )
                .shadow(color: statusColor.opacity(0.2), radius: 6, y: 3)

                if let place = peer.place {
                    Text(place.title)
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(peer.status.displayName)
                    .font(.pulseCaption)
                    .foregroundStyle(statusColor)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            ZStack {
                // Base glass layer
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)

                // Tint overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(statusColor.opacity(0.08))

                // Gradient border
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.05),
                                .white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: statusColor.opacity(0.2), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .scaleEffect(isPressed ? 0.97 : (appeared ? 1 : 0.95))
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(peer.handle), \(peer.status.displayName), \(distanceText) away, technologies: \(peer.techStack.prefix(3).joined(separator: ", "))")
    }

    private func getTechColor(_ tech: String) -> Color {
        switch tech.lowercased() {
        case "swift": return .orange
        case "rust": return .orange
        case "python": return .blue
        case "javascript", "js": return .yellow
        case "go": return .cyan
        case "java": return .red
        case "kotlin": return .purple
        default: return .cyan
        }
    }

    private var signalStrengthIcon: some View {
        let bars = signalBars
        return HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < bars ? Color.white.opacity(0.7) : Color.white.opacity(0.2))
                    .frame(width: 3, height: CGFloat(6 + index * 3))
            }
        }
    }

    private var signalBars: Int {
        if peer.distance < 20 { return 3 }
        if peer.distance < 50 { return 2 }
        return 1
    }

    private var avatarGradient: LinearGradient {
        switch peer.status {
        case .active:
            return LinearGradient(
                colors: [.green.opacity(0.8), .green.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .flowState:
            return LinearGradient(
                colors: [.orange.opacity(0.8), .orange.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .idle:
            return LinearGradient(
                colors: [.gray.opacity(0.6), .gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var statusColor: Color {
        switch peer.status {
        case .active: return .green
        case .flowState: return .orange
        case .idle: return .gray
        }
    }

    private var distanceText: String {
        if peer.distance < 10 {
            return "< 10m"
        } else if peer.distance < 50 {
            return "~\(Int(peer.distance))m"
        } else {
            return "Far"
        }
    }
}

// MARK: - Profile Header Image

struct ProfileHeaderImage: View {
    let size: CGFloat

    @State private var profileImage: UIImage?
    @State private var themeManager = ThemeManager.shared
    @AppStorage("handle") private var handle = ""

    var body: some View {
        SwiftUI.Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(themeManager.colors.accent)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(themeManager.colors.background)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private var initials: String {
        let cleaned = handle.replacingOccurrences(of: "@", with: "")
        if cleaned.isEmpty { return "?" }
        return String(cleaned.prefix(2)).uppercased()
    }

    private func loadImage() {
        if let imageData = UserDefaults.standard.data(forKey: "profileImage"),
           let image = UIImage(data: imageData) {
            profileImage = image
        }
    }
}

#Preview {
    RadarView()
        .environmentObject(MeshManager())
}
