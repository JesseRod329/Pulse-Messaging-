import SwiftUI
import UIKit

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = AppTheme.avatarSizeMedium
    var fallbackInitials: String
    var statusColor: Color? = nil
    var accessibilityLabel: String? = nil
    @ScaledMetric(relativeTo: .body) private var baseAvatarSize: CGFloat = AppTheme.avatarSizeMedium
    @ScaledMetric(relativeTo: .caption) private var statusDotSize: CGFloat = 10

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: resolvedAvatarSize, height: resolvedAvatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if let statusColor {
                Circle()
                    .fill(statusColor)
                    .frame(width: statusDotSize, height: statusDotSize)
                    .overlay(Circle().stroke(AppTheme.navBar, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "\(fallbackInitials) avatar")
        .accessibilityHint("Profile image")
    }

    private var resolvedAvatarSize: CGFloat {
        let ratio = size / max(AppTheme.avatarSizeMedium, 1)
        return max(28, baseAvatarSize * ratio)
    }

    private var fallback: some View {
        Circle()
            .fill(AppTheme.accentBlue.opacity(0.22))
            .overlay(
                Text(fallbackInitials)
                    .font(AppTheme.inter(12, weight: .bold))
                    .foregroundStyle(AppTheme.accentBlue)
            )
    }
}

struct FloatingActionButton: View {
    let title: String
    var icon: DesignIcon = .add
    let action: () -> Void
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil
    var accessibilityIdentifier: String? = nil
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 8

    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                DesignIconView(icon: icon, size: iconSize, color: AppTheme.textPrimary)
                Text(title)
                    .font(AppTheme.inter(13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(AppTheme.accentBlue))
            .overlay(
                Capsule()
                    .stroke(AppTheme.accentBlue.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint ?? "Performs primary action.")
        .accessibilityIdentifier(
            accessibilityIdentifier
                ?? "shared.fab.\(title.lowercased().replacingOccurrences(of: " ", with: ""))"
        )
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct HapticButton<Label: View>: View {
    var enabled: Bool
    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            if enabled {
                UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
            }
            action()
        } label: {
            label()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PulseDot: View {
    var color: Color = AppTheme.success
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: size * 2.2, height: size * 2.2)
                .scaleEffect(pulse ? 1.1 : 0.7)
                .opacity(pulse ? 0.2 : 0.65)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct ShimmerBlock: View {
    var cornerRadius: CGFloat = 12

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.surfaceElevated)
            .overlay {
                LinearGradient(
                    colors: [Color.clear, Color.white.opacity(0.18), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 240)
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}
