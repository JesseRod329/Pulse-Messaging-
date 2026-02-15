import SwiftUI
import BoppyV2Core

struct OrderInboxCard<Actions: View, Timeline: View>: View {
    let order: OrderRequest
    let isExpanded: Bool
    let onToggleTimeline: () -> Void
    @ViewBuilder let actions: Actions
    @ViewBuilder let timeline: () -> Timeline

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                timelineRail

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(titleLine)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        Text(timestampLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)

                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                    }

                    Text(subtitleLine)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        OrderStatusPill(status: order.status)
                        Text(detailLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }

            if !order.quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(order.quoteNote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
            }

            actions

            Button {
                onToggleTimeline()
            } label: {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Hide ledger timeline" : "View ledger timeline")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    Spacer(minLength: 6)
                    Text(shortOrderID)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentBlue)
            .accessibilityIdentifier("orders.toggleTimeline")

            if isExpanded {
                timeline()
                    .padding(.top, 2)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.surface.opacity(0.80))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(statusColor.opacity(0.20))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(statusColor)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(statusColor.opacity(0.35), lineWidth: 1)
                )

            Rectangle()
                .fill(statusColor.opacity(0.32))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, 6)
                .opacity(isExpanded ? 1 : 0.6)
        }
        .frame(minWidth: 44, maxWidth: 44, maxHeight: .infinity, alignment: .top)
    }

    private var statusSymbol: String {
        switch order.status {
        case .requested, .addressReview:
            return "clock.badge.exclamationmark.fill"
        case .quoted:
            return "doc.text.fill"
        case .accepted, .assigned:
            return "checkmark.seal.fill"
        case .outForDelivery:
            return "truck.box.fill"
        case .delivered:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch order.status {
        case .requested, .addressReview:
            return AppTheme.warning
        case .quoted, .outForDelivery:
            return AppTheme.accentBlue
        case .accepted, .assigned, .delivered:
            return AppTheme.success
        case .cancelled:
            return AppTheme.danger
        }
    }

    private var titleLine: String {
        let destination = order.deliveryAddress.line1.trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.isEmpty {
            return "Order \(shortOrderID)"
        }
        return destination
    }

    private var subtitleLine: String {
        if let driverID = order.assignedDriverID, !driverID.isEmpty {
            return "Assigned • Driver \(driverID.suffix(4)) • \(shortOrderID)"
        }
        return "Customer request • \(shortOrderID)"
    }

    private var detailLine: String {
        if let driverID = order.assignedDriverID, !driverID.isEmpty {
            return "Worker: \(driverID.suffix(4))"
        }
        if order.quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Awaiting quote"
        }
        return "Quote pending"
    }

    private var shortOrderID: String {
        let compact = order.id.replacingOccurrences(of: "-", with: "")
        let suffix = String(compact.suffix(6)).uppercased()
        return "#ORD-\(suffix)"
    }

    private var timestampLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDateInToday(order.updatedAt) ? .none : .short
        return formatter.string(from: order.updatedAt)
    }
}
