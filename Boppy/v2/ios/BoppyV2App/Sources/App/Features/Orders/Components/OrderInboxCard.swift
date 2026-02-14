import SwiftUI
import BoppyV2Core

struct OrderInboxCard<Actions: View, Timeline: View>: View {
    let order: OrderRequest
    let isExpanded: Bool
    let onToggleTimeline: () -> Void
    @ViewBuilder let actions: Actions
    @ViewBuilder let timeline: () -> Timeline

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Order \(order.id)")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(order.updatedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                OrderStatusPill(status: order.status)
            }

            if !order.quoteNote.isEmpty {
                Text(order.quoteNote)
                    .font(.subheadline)
            }

            Text(order.deliveryAddress.singleLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            actions

            Divider()

            Button(isExpanded ? "Hide Timeline" : "Show Timeline") {
                onToggleTimeline()
            }
            .buttonStyle(.borderless)

            if isExpanded {
                timeline()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
