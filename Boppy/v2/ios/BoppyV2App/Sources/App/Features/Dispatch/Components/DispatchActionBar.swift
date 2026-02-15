import SwiftUI

struct DispatchActionBar: View {
    let onRefresh: () -> Void
    let onOptimizeRoute: () -> Void
    let onSaveRouteChanges: () -> Void
    let optimizeDisabled: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                navItem(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Routes", active: true)
                navItem(icon: "clock.arrow.circlepath", label: "History", active: false)
                navItem(icon: "person.fill", label: "Profile", active: false)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button {
                    onOptimizeRoute()
                } label: {
                    Label("Optimize Route (Apple Maps)", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dispatch.optimizeRoute")
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .disabled(optimizeDisabled)

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dispatch.refresh")
            }

            Button {
                onSaveRouteChanges()
            } label: {
                Label("Save Route Changes", systemImage: "square.and.arrow.down")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dispatch.saveRouteChanges")
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.accentBlue)
            )
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surface, AppTheme.navBar],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func navItem(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(active ? AppTheme.accentBlue : AppTheme.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(active ? AppTheme.accentBlue.opacity(0.18) : .clear)
        )
    }
}
