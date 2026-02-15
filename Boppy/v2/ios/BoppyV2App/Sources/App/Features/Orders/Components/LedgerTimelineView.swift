import SwiftUI
import BoppyV2Core

struct LedgerTimelineView: View {
    let events: [OrderLedgerEvent]
    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading timeline")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        } else if events.isEmpty {
            Text("No ledger events yet")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(color(for: event).opacity(0.20))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(color(for: event), lineWidth: 1.4)
                                )
                                .overlay(
                                    Image(systemName: icon(for: event))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(color(for: event))
                                )

                            if index != events.count - 1 {
                                Rectangle()
                                    .fill(color(for: event).opacity(0.44))
                                    .frame(width: 1, height: 28)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(title(for: event))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer(minLength: 8)
                                Text(event.createdAt, style: .time)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.textMuted)
                            }

                            Text(event.payloadSummary)
                                .font(.caption2)
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
