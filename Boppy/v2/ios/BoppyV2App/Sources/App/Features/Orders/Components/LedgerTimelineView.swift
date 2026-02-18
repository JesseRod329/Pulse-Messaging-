import SwiftUI
import BoppyV2Core

struct LedgerTimelineView: View {
    let events: [OrderLedgerEvent]
    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack {
                ShimmerBlock(cornerRadius: AppTheme.radiusSmall)
                    .frame(width: 28, height: 28)
                Text("Loading timeline")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(AppTheme.textMuted)
            }
        } else if events.isEmpty {
            Text("No ledger events yet")
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                .foregroundStyle(AppTheme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .stroke(color(for: event).opacity(0.75), lineWidth: 2)
                                    .frame(width: AppTheme.timelineNodeSize, height: AppTheme.timelineNodeSize)
                                Circle()
                                    .fill(color(for: event).opacity(0.24))
                                    .frame(width: AppTheme.timelineNodeSize - 8, height: AppTheme.timelineNodeSize - 8)
                                Image(systemName: icon(for: event))
                                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(color(for: event))
                            }

                            if index != events.count - 1 {
                                LinearGradient(
                                    colors: [color(for: event).opacity(0.7), color(for: events[index + 1]).opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: 2, height: 36)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(title(for: event))
                                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer(minLength: 8)
                                Text(event.createdAt, style: .time)
                                    .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold, relativeTo: .caption2))
                                    .foregroundStyle(AppTheme.textMuted)
                            }

                            Text(event.payloadSummary)
                                .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func title(for event: OrderLedgerEvent) -> String {
        event.eventType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func icon(for event: OrderLedgerEvent) -> String {
        let normalized = event.eventType.lowercased()
        if normalized.contains("quote") { return "tag.fill" }
        if normalized.contains("assign") { return "person.fill.checkmark" }
        if normalized.contains("deliver") || normalized.contains("stop_complete") { return "checkmark" }
        if normalized.contains("request") || normalized.contains("create") { return "cart.fill" }
        return "clock.fill"
    }

    private func color(for event: OrderLedgerEvent) -> Color {
        let normalized = event.eventType.lowercased()
        if normalized.contains("deliver") || normalized.contains("complete") { return AppTheme.success }
        if normalized.contains("cancel") { return AppTheme.danger }
        if normalized.contains("quote") || normalized.contains("assign") { return AppTheme.accentBlue }
        return AppTheme.warning
    }
}
