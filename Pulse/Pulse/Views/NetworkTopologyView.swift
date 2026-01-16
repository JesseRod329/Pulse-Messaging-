//
//  NetworkTopologyView.swift
//  Pulse
//
//  Visual representation of the mesh network topology.
//

import SwiftUI

struct NetworkTopologyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared
    @State private var topologyTracker = MeshTopologyTracker.shared
    @State private var animationPhase: Double = 0
    @State private var showContent = false
    @State private var dataFlowPhase: CGFloat = 0
    @State private var selectedNode: MeshNode?
    @State private var pulseRings: [UUID] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle grid
                themeManager.colors.background.ignoresSafeArea()

                // Subtle grid pattern
                gridBackground
                    .opacity(showContent ? 0.05 : 0)

                VStack(spacing: 0) {
                    // Stats header
                    statsHeader
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -20)

                    // Topology visualization
                    GeometryReader { geometry in
                        topologyCanvas(in: geometry.size)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1 : 0.9)
                    }

                    // Legend
                    legendView
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
            }
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(themeManager.colors.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.accent)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                dataFlowPhase = 1
            }
        }
        .sheet(item: $selectedNode) { node in
            NodeDetailSheet(node: node)
        }
    }

    private func triggerRefresh() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Add a pulse ring
        let ringId = UUID()
        pulseRings.append(ringId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pulseRings.removeAll { $0 == ringId }
        }
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 30
                // Vertical lines
                for x in stride(from: 0, to: geometry.size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                // Horizontal lines
                for y in stride(from: 0, to: geometry.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(themeManager.colors.textSecondary, lineWidth: 0.5)
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        let stats = topologyTracker.stats
        let health = topologyTracker.networkHealth

        return VStack(spacing: 16) {
            // Main stats row
            HStack(spacing: 0) {
                statPill("Nodes", value: "\(stats.totalNodes)", icon: "circle.fill", color: themeManager.colors.accent)
                    .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)
                    .background(themeManager.colors.textSecondary.opacity(0.2))

                statPill("Direct", value: "\(stats.directConnections)", icon: "link", color: .green)
                    .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)
                    .background(themeManager.colors.textSecondary.opacity(0.2))

                statPill("Relayed", value: "\(stats.relayedConnections)", icon: "arrow.triangle.swap", color: .orange)
                    .frame(maxWidth: .infinity)
            }

            // Health bar
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(healthColor(health))
                        Text("Network Health")
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }

                    Spacer()

                    Text("\(Int(health * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(healthColor(health))
                        .contentTransition(.numericText())
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.colors.textSecondary.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [healthColor(health).opacity(0.8), healthColor(health)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * health)
                            .animation(.spring(response: 0.5), value: health)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
    }

    private func healthColor(_ health: Double) -> Color {
        if health > 0.7 { return .green }
        if health > 0.4 { return .orange }
        return .red
    }

    private func statPill(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.pulseCaption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.pulseSectionHeader)
                    .foregroundStyle(themeManager.colors.text)
                    .contentTransition(.numericText())
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(themeManager.colors.textSecondary)
        }
    }

    // MARK: - Topology Canvas

    private func topologyCanvas(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let nodes = topologyTracker.sortedNodes
        let edges = topologyTracker.allEdges

        return ZStack {
            // Concentric rings guide
            ForEach(1..<4) { ring in
                Circle()
                    .stroke(themeManager.colors.textSecondary.opacity(0.1), lineWidth: 1)
                    .frame(
                        width: min(size.width, size.height) * 0.3 * CGFloat(ring),
                        height: min(size.width, size.height) * 0.3 * CGFloat(ring)
                    )
                    .position(center)
            }

            // Draw edges first (behind nodes)
            ForEach(edges) { edge in
                edgeLine(edge: edge, nodes: nodes, center: center, size: size)
            }

            // Draw data flow particles on edges
            ForEach(edges) { edge in
                dataFlowParticle(edge: edge, nodes: nodes, center: center, size: size)
            }

            // Refresh pulse rings
            ForEach(pulseRings, id: \.self) { _ in
                PulseRingView(color: themeManager.colors.accent)
                    .position(center)
            }

            // Draw nodes
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                nodeView(node: node, index: index, total: nodes.count, center: center, size: size)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedNode = node
                    }
            }

            // Center pulse effect
            Circle()
                .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 2)
                .frame(width: 100 + animationPhase * 50, height: 100 + animationPhase * 50)
                .opacity(1 - animationPhase)
                .position(center)

            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [themeManager.colors.accent.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .position(center)
        }
    }

    private func dataFlowParticle(edge: MeshEdge, nodes: [MeshNode], center: CGPoint, size: CGSize) -> some View {
        let sourceIndex = nodes.firstIndex { $0.id == edge.sourceId } ?? 0
        let targetIndex = nodes.firstIndex { $0.id == edge.targetId } ?? 0

        let sourceNode = nodes.first { $0.id == edge.sourceId }
        let targetNode = nodes.first { $0.id == edge.targetId }

        let sourcePos = nodePosition(
            index: sourceIndex,
            total: nodes.count,
            hopCount: sourceNode?.hopCount ?? 0,
            center: center,
            size: size
        )
        let targetPos = nodePosition(
            index: targetIndex,
            total: nodes.count,
            hopCount: targetNode?.hopCount ?? 0,
            center: center,
            size: size
        )

        let progress = dataFlowPhase
        let x = sourcePos.x + (targetPos.x - sourcePos.x) * progress
        let y = sourcePos.y + (targetPos.y - sourcePos.y) * progress

        return Circle()
            .fill(themeManager.colors.accent)
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
            .opacity(edge.strength > 0.5 ? 0.8 : 0)
    }

    private func nodeView(node: MeshNode, index: Int, total: Int, center: CGPoint, size: CGSize) -> some View {
        let position = nodePosition(index: index, total: total, hopCount: node.hopCount, center: center, size: size)
        let isMe = node.id == topologyTracker.myNodeId
        let nodeColor: Color = node.isDirectConnection ? .green : .orange

        return ZStack {
            // Outer glow for active connections
            if isMe {
                Circle()
                    .fill(themeManager.colors.accent.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .blur(radius: 15)
            } else if node.isDirectConnection {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)
            }

            // Status ring (animated for "Me")
            Circle()
                .stroke(
                    isMe ? themeManager.colors.accent.opacity(0.5) : nodeColor.opacity(0.3),
                    lineWidth: 2
                )
                .frame(width: isMe ? 58 : 44, height: isMe ? 58 : 44)

            // Node circle with gradient
            Circle()
                .fill(
                    isMe ?
                    LinearGradient(
                        colors: [themeManager.colors.accent, themeManager.colors.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [themeManager.colors.cardBackground, themeManager.colors.cardBackground.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isMe ? 50 : 36, height: isMe ? 50 : 36)
                .overlay(
                    Circle()
                        .strokeBorder(
                            nodeColor.opacity(isMe ? 0 : 0.8),
                            lineWidth: 2
                        )
                )
                .shadow(color: isMe ? themeManager.colors.accent.opacity(0.5) : .clear, radius: 8)

            // Signal strength indicator
            if let strength = node.signalStrength, !isMe {
                signalIndicator(strength: strength)
                    .offset(x: 18, y: -18)
            }

            // Handle label
            VStack(spacing: 2) {
                Text(isMe ? "Me" : String(node.handle.dropFirst().prefix(2).uppercased()))
                    .font(.system(size: isMe ? 14 : 11, weight: .bold))
                    .foregroundStyle(isMe ? themeManager.colors.background : themeManager.colors.text)
            }

            // Hop count badge for relayed nodes
            if !isMe && !node.isDirectConnection && node.hopCount > 1 {
                Text("\(node.hopCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(Color.orange))
                    .offset(x: -16, y: 16)
            }
        }
        .position(position)
    }

    private func signalIndicator(strength: Double) -> some View {
        let bars = Int(strength * 4)
        return HStack(spacing: 1) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? themeManager.colors.success : themeManager.colors.textSecondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
    }

    private func edgeLine(edge: MeshEdge, nodes: [MeshNode], center: CGPoint, size: CGSize) -> some View {
        let sourceIndex = nodes.firstIndex { $0.id == edge.sourceId } ?? 0
        let targetIndex = nodes.firstIndex { $0.id == edge.targetId } ?? 0

        let sourceNode = nodes.first { $0.id == edge.sourceId }
        let targetNode = nodes.first { $0.id == edge.targetId }

        let sourcePos = nodePosition(
            index: sourceIndex,
            total: nodes.count,
            hopCount: sourceNode?.hopCount ?? 0,
            center: center,
            size: size
        )
        let targetPos = nodePosition(
            index: targetIndex,
            total: nodes.count,
            hopCount: targetNode?.hopCount ?? 0,
            center: center,
            size: size
        )

        return Path { path in
            path.move(to: sourcePos)
            path.addLine(to: targetPos)
        }
        .stroke(
            themeManager.colors.accent.opacity(edge.strength * 0.5),
            style: StrokeStyle(lineWidth: 1 + edge.strength * 2, lineCap: .round)
        )
    }

    private func nodePosition(index: Int, total: Int, hopCount: Int, center: CGPoint, size: CGSize) -> CGPoint {
        if hopCount == 0 {
            return center
        }

        let radius = min(size.width, size.height) * 0.3 * Double(hopCount)
        let angle = (Double(index) / Double(max(total - 1, 1))) * 2 * .pi - .pi / 2

        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                legendItem(color: themeManager.colors.accent, label: "You", icon: "person.fill")
                legendItem(color: .green, label: "Direct", icon: "link")
                legendItem(color: .orange, label: "Relayed", icon: "arrow.triangle.swap")
            }

            // Tap hint
            Text("Tap a node for details")
                .font(.caption2)
                .foregroundStyle(themeManager.colors.textSecondary.opacity(0.6))
        }
        .padding()
        .background(themeManager.colors.cardBackground)
    }

    private func legendItem(color: Color, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.pulseTimestamp)
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(themeManager.colors.text)
        }
    }
}

// MARK: - Pulse Ring Animation

struct PulseRingView: View {
    let color: Color
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 3
                    opacity = 0
                }
            }
    }
}

// MARK: - Node Detail Sheet

struct NodeDetailSheet: View {
    let node: MeshNode
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Node avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    node.isDirectConnection ? .green : .orange,
                                    (node.isDirectConnection ? Color.green : Color.orange).opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Text(String(node.handle.dropFirst().prefix(2).uppercased()))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                .shadow(color: (node.isDirectConnection ? Color.green : Color.orange).opacity(0.4), radius: 15)

                // Node info
                VStack(spacing: 8) {
                    Text(node.handle)
                        .font(.title2.bold())
                        .foregroundStyle(themeManager.colors.text)

                    HStack(spacing: 6) {
                        Image(systemName: node.isDirectConnection ? "link" : "arrow.triangle.swap")
                            .font(.caption)
                        Text(node.isDirectConnection ? "Direct Connection" : "Relayed (\(node.hopCount) hops)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(themeManager.colors.textSecondary)
                }

                // Stats
                VStack(spacing: 16) {
                    if let strength = node.signalStrength {
                        detailRow("Signal Strength", value: "\(Int(strength * 100))%", icon: "antenna.radiowaves.left.and.right")
                    }

                    detailRow("Hop Count", value: "\(node.hopCount)", icon: "arrow.triangle.branch")

                    detailRow("Connection Type", value: node.isDirectConnection ? "Bluetooth/WiFi" : "Multi-hop Relay", icon: "network")
                }
                .padding()
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()
            }
            .padding()
            .background(themeManager.colors.background)
            .navigationTitle("Node Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(themeManager.colorScheme)
    }

    private func detailRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(themeManager.colors.accent)
                    .frame(width: 24)
                Text(label)
                    .foregroundStyle(themeManager.colors.text)
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(themeManager.colors.textSecondary)
        }
    }
}

#Preview {
    NetworkTopologyView()
}
