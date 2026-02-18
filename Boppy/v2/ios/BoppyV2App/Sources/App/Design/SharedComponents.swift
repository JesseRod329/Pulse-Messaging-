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
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
    var cornerRadius: CGFloat = AppTheme.radiusMedium

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

// MARK: - CardSkeleton

struct CardSkeleton: View {
    var height: CGFloat = 80

    var body: some View {
        ShimmerBlock(cornerRadius: AppTheme.radiusMedium)
            .frame(height: height)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    var isSelected: Bool = false
    var count: Int? = nil
    var statusDot: Color? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.space4) {
                if let statusDot {
                    Circle()
                        .fill(statusDot)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: isSelected ? .semibold : .medium, relativeTo: .caption))
                    .foregroundStyle(isSelected ? AppTheme.accentBlue : AppTheme.textSecondary)
                if let count {
                    Text("\(count)")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(isSelected ? AppTheme.accentBlue : AppTheme.textMuted)
                }
            }
            .padding(.horizontal, AppTheme.space12)
            .padding(.vertical, AppTheme.space8)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.accentBlue.opacity(0.18) : AppTheme.surface.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppTheme.accentBlue.opacity(0.4) : AppTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - SearchField

struct SearchField: View {
    var placeholder: String = "Search…"
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppTheme.space8) {
            Image(systemName: DesignIcon.search.systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
            TextField(placeholder, text: $text)
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .regular, relativeTo: .subheadline))
                .foregroundStyle(AppTheme.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.space12)
        .padding(.vertical, AppTheme.space8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - AppEmptyStateView

struct AppEmptyStateView: View {
    var icon: String = "tray"
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: AppTheme.space12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.textMuted)
            Text(title)
                .font(AppTheme.inter(AppTheme.typeBody, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}
