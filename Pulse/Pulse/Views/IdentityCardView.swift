//
//  IdentityCardView.swift
//  Pulse
//
//  Created by Jesse on 2025
//

import SwiftUI

enum Role: String, CaseIterable, Identifiable, Codable {
    case builder = "Builder"
    case designer = "Designer"
    case researcher = "Researcher"
    case manager = "Manager"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .builder: return "hammer.fill"
        case .designer: return "paintbrush.fill"
        case .researcher: return "magnifyingglass"
        case .manager: return "person.3.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

struct IdentityCardView: View {
    let onComplete: () -> Void

    @State private var handle = ""
    @State private var role: Role = .builder
    @State private var isAppearing = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your handle")
                    .font(.pulseLabel)
                    .foregroundStyle(.white.opacity(0.6))

                TextField("your_name", text: $handle)
                    .font(.sfMono(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Your primary role")
                    .font(.pulseLabel)
                    .foregroundStyle(.white.opacity(0.6))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Role.allCases) { roleOption in
                            RolePill(
                                role: roleOption,
                                isSelected: role == roleOption,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        role = roleOption
                                    }
                                }
                            )
                        }
                    }
                }
            }

            Button(action: completeIdentity) {
                Text("Enter Pulse")
                    .font(.pulseButton)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(handle.count >= 2 ? Color.white : Color.white.opacity(0.3))
                    )
            }
            .disabled(handle.count < 2)
            .animation(.easeInOut(duration: 0.2), value: handle.count)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .onAppear {
            isAppearing = true
        }
    }

    private func completeIdentity() {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespaces)
        if trimmedHandle.count >= 2 {
            // Save identity
            _ = IdentityManager.shared.createIdentity(handle: trimmedHandle)
            UserDefaults.standard.set(role.rawValue, forKey: "userRole")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            onComplete()
        }
    }
}

struct RolePill: View {
    let role: Role
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: role.icon)
                    .font(.system(size: 14))
                Text(role.rawValue)
                    .font(.pulseLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.08))
            )
            .foregroundStyle(isSelected ? .black : .white)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        IdentityCardView(onComplete: {})
    }
}
