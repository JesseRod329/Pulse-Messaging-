import SwiftUI

struct DispatchActionBar: View {
    let onRefresh: () -> Void
    let onOptimizeRoute: () -> Void
    let optimizeDisabled: Bool
    let offline: Bool
    let isBusy: Bool
    var glass: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onOptimizeRoute()
            } label: {
                Label(isBusy ? "Optimizing..." : "Optimize Route", systemImage: "sparkles")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .semibold))
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
                    .fill(AppTheme.accentBlue)
            )
            .disabled(optimizeDisabled || offline || isBusy)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.surfaceCard, in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh dispatch")
            .accessibilityHint("Reloads routes, stops, and order statuses.")
            .accessibilityIdentifier("dispatch.refresh")
            .disabled(isBusy)
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background {
            AppTheme.chromeBackground(glass: glass)
        }
    }
}
