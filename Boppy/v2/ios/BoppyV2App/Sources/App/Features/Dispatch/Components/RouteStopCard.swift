import SwiftUI
import BoppyV2Core

struct RouteStopCard: View {
    let stop: RouteStop
    let route: DeliveryRoute
    let canReorder: Bool
    let canComplete: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                if canReorder {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(stop.stopIndex == 0)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(stop.stopIndex == route.stops.count - 1)
                }
            }
            .frame(width: 24)

            ZStack {
                Circle()
                    .fill(stop.completedAt == nil ? Color(.tertiarySystemFill) : .green.opacity(0.15))
                    .frame(width: 34, height: 34)
                if stop.completedAt == nil {
                    Text("\(stop.stopIndex + 1)")
                        .font(.caption.weight(.bold))
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Order \(stop.orderID)")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                if let eta = stop.etaMinutes {
                    Text("ETA \(eta)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(stopStateText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(stopStateColor)
            }

            Spacer()

            if canComplete && stop.completedAt == nil {
                Button("Complete", action: onComplete)
                    .buttonStyle(.borderedProminent)
            } else if stop.completedAt != nil {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(stop.completedAt == nil ? Color(.secondarySystemBackground) : Color(.tertiarySystemFill))
        )
    }

    private var stopStateText: String {
        if stop.completedAt != nil { return "Completed" }
        if stop.stopIndex == 0 && route.status != .completed { return "In Progress" }
        return "Pending"
    }

    private var stopStateColor: Color {
        if stop.completedAt != nil { return .green }
        if stop.stopIndex == 0 && route.status != .completed { return Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255) }
        return .secondary
    }
}
