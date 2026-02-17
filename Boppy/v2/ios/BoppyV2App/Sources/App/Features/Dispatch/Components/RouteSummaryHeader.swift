import SwiftUI
import BoppyV2Core

struct RouteSummaryHeader: View {
    let route: DeliveryRoute?
    let isOwner: Bool
    let routeDurationLabel: String
    let nextStopLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Route Summary")
                    .font(AppTheme.inter(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(AppTheme.textPrimary)
                if isOwner {
                    Text("OWNER")
                        .font(AppTheme.inter(10, weight: .bold, relativeTo: .caption2))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentBlue.opacity(0.20), in: Capsule())
                        .foregroundStyle(AppTheme.accentBlue)
                }
                Spacer()
                if let route {
                    Text(statusLabel(route.status))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(route.status).opacity(0.20), in: Capsule())
                        .foregroundStyle(statusColor(route.status))
                }
            }

            if let route {
                HStack(spacing: 10) {
                    Label("\(remainingStops(route)) stops remaining", systemImage: "flag.checkered")
                        .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("•")
                        .foregroundStyle(AppTheme.textMuted)
                    Text(routeDurationLabel)
                        .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: 8) {
                    Label("NEXT", systemImage: "location.fill")
                        .font(AppTheme.inter(10, weight: .bold, relativeTo: .caption2))
                        .foregroundStyle(AppTheme.accentBlue)
                    Text(nextStopLabel)
                        .font(AppTheme.inter(15, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
            } else {
                Text("No active route yet")
                    .font(AppTheme.inter(14, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func remainingStops(_ route: DeliveryRoute) -> Int {
        route.stops.filter { $0.completedAt == nil }.count
    }

    private func statusLabel(_ status: RouteStatus) -> String {
        status.rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private func statusColor(_ status: RouteStatus) -> Color {
        switch status {
        case .planned:
            return AppTheme.warning
        case .inProgress:
            return AppTheme.accentBlue
        case .completed:
            return AppTheme.success
        case .cancelled:
            return AppTheme.danger
        }
    }
}
