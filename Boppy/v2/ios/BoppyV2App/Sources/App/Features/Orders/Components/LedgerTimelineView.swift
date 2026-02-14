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
                    .foregroundStyle(.secondary)
            }
        } else if events.isEmpty {
            Text("No ledger events yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.bold())
                        Text(event.payloadSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(event.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
