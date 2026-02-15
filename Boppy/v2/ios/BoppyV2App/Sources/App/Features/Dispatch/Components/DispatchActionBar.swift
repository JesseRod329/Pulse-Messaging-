import SwiftUI

struct DispatchActionBar: View {
    let onRefresh: () -> Void
    let onOptimizeRoute: () -> Void
    let onSaveRouteChanges: () -> Void
    let optimizeDisabled: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                navItem(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Routes", active: true)
                navItem(icon: "clock.arrow.circlepath", label: "History", active: false)
                navItem(icon: "person.fill", label: "Profile", active: false)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button {
                    onOptimizeRoute()
                } label: {
                    Label("Optimize Route (Mapbox)", systemImage: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dispatch.optimizeRoute")
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .disabled(optimizeDisabled)

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 44, height: 44)
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
                Label("Save Route Changes", systemImage: "square.and.arrow.down.fill")
                    .font(.system(size: 22, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dispatch.saveRouteChanges")
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.accentBlue)
            )
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            AppTheme.navBar.opacity(0.94)
        )
    }

    private func navItem(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(active ? AppTheme.accentBlue : AppTheme.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(active ? AppTheme.accentBlue.opacity(0.18) : .clear)
        )
    }
}
