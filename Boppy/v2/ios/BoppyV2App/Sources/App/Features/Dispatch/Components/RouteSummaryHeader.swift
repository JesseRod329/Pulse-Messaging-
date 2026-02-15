import SwiftUI
import BoppyV2Core

struct RouteSummaryHeader: View {
    let route: DeliveryRoute?
    let isOwner: Bool
    let routeDurationLabel: String
    let nextStopLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Route Summary")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if isOwner {
                    Text("OWNER")
                        .font(.caption2.weight(.bold))
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("•")
                        .foregroundStyle(AppTheme.textMuted)
                    Text(routeDurationLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: 8) {
                    Label("NEXT", systemImage: "location.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue)
                    Text(nextStopLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    summaryChip(label: "Driver \(route.driverID.suffix(4))", tone: .neutral)
                    summaryChip(label: "\(route.stops.count) total stops", tone: .accent)
                    if route.approximate {
                        summaryChip(label: "Fallback", tone: .warning)
                    }
                }
            } else {
                Text("No active route yet")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
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

    private enum SummaryTone {
        case accent
        case warning
        case neutral
    }

    private func summaryChip(label: String, tone: SummaryTone) -> some View {
        let background: Color
        let foreground: Color

        switch tone {
        case .accent:
            background = AppTheme.accentBlue.opacity(0.18)
            foreground = AppTheme.accentBlue
        case .warning:
            background = AppTheme.warning.opacity(0.18)
            foreground = AppTheme.warning
        case .neutral:
            background = AppTheme.surface.opacity(0.75)
            foreground = AppTheme.textSecondary
        }

        return Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }
}
