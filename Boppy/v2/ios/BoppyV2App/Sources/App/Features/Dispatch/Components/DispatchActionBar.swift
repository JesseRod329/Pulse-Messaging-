import SwiftUI

struct DispatchActionBar: View {
    let onRefresh: () -> Void
    let onOptimizeRoute: () -> Void
    let onSaveRouteChanges: () -> Void
    let optimizeDisabled: Bool
    let offline: Bool
    let isBusy: Bool
    var glass: Bool = true

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
                        .font(AppTheme.inter(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Optimize route")
                .accessibilityHint("Builds or re-optimizes the route for the selected driver.")
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
                .disabled(optimizeDisabled || offline || isBusy)

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTheme.inter(15, weight: .bold, relativeTo: .body))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh dispatch")
                .accessibilityHint("Reloads routes, stops, and order statuses.")
                .accessibilityIdentifier("dispatch.refresh")
                .disabled(isBusy)
            }

            Button {
                onSaveRouteChanges()
            } label: {
                Label("Save Route Changes", systemImage: "square.and.arrow.down.fill")
                    .font(AppTheme.inter(18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save route changes")
            .accessibilityHint("Saves current route state and refreshes dispatch.")
            .accessibilityIdentifier("dispatch.saveRouteChanges")
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.accentBlue)
            )
            .disabled(offline || isBusy)
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background {
            AppTheme.chromeBackground(glass: glass)
        }
    }

    private func navItem(icon: String, label: String, active: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(AppTheme.inter(14, weight: .semibold))
            Text(label)
                .font(AppTheme.inter(10, weight: .bold))
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
