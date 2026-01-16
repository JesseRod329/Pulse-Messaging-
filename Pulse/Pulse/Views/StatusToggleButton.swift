//
//  StatusToggleButton.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import SwiftUI

struct StatusToggleButton: View {
    @State private var isExpanded = false
    @State private var currentStatus: PeerStatus = {
        let statusRawValue = UserDefaults.standard.integer(forKey: "userStatus")
        return PeerStatus(rawValue: statusRawValue) ?? .active
    }()
    @Namespace private var statusNamespace

    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Expanded: Show all status options
                HStack(spacing: 12) {
                    StatusButton(status: .active, isSelected: currentStatus == .active) {
                        selectStatus(.active)
                    }
                    .matchedGeometryEffect(id: "status-1", in: statusNamespace)

                    StatusButton(status: .flowState, isSelected: currentStatus == .flowState) {
                        selectStatus(.flowState)
                    }
                    .matchedGeometryEffect(id: "status-2", in: statusNamespace)

                    StatusButton(status: .idle, isSelected: currentStatus == .idle) {
                        selectStatus(.idle)
                    }
                    .matchedGeometryEffect(id: "status-3", in: statusNamespace)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Collapsed: Show current status only
                Button {
                    withAnimation(.bouncy(duration: 0.5)) {
                        isExpanded = true
                    }
                } label: {
                    Text(currentStatus.emoji)
                        .font(.title)
                        .frame(width: 56, height: 56)
                }
                .matchedGeometryEffect(id: "status-toggle", in: statusNamespace)
                .liquidGlass(style: .regular, tint: colorFor(currentStatus), interactive: true)
            }
        }
    }

    private func selectStatus(_ status: PeerStatus) {
        currentStatus = status
        UserDefaults.standard.set(status.rawValue, forKey: "userStatus")

        withAnimation(.bouncy(duration: 0.5)) {
            isExpanded = false
        }
    }

    private func colorFor(_ status: PeerStatus) -> Color {
        switch status {
        case .active: return .green.opacity(0.7)
        case .flowState: return .yellow.opacity(0.7)
        case .idle: return .gray.opacity(0.5)
        }
    }
}

struct StatusButton: View {
    let status: PeerStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(status.emoji)
                    .font(.title2)

                Text(status.displayName)
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            .frame(width: 70, height: 60)
        }
        .liquidGlass(style: .regular, tint: colorFor(status), interactive: true)
        .opacity(isSelected ? 1.0 : 0.7)
    }

    private func colorFor(_ status: PeerStatus) -> Color {
        switch status {
        case .active: return .green.opacity(0.7)
        case .flowState: return .yellow.opacity(0.7)
        case .idle: return .gray.opacity(0.5)
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue, .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                StatusToggleButton()
                    .padding(32)
            }
        }
    }
}
