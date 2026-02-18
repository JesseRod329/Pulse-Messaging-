import SwiftUI
import BoppyV2Core

struct OrderInboxCard: View {
    let order: OrderRequest
    let isUnread: Bool
    let showOwnerActions: Bool
    let onOpenTimeline: () -> Void
    let onOpenAssign: () -> Void

    var body: some View {
        Button(action: onOpenTimeline) {
            HStack(spacing: 12) {
                avatar
                    .overlay(alignment: .topTrailing) {
                        if isUnread {
                            Circle()
                                .fill(AppTheme.accentBlue)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleLine)
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 7) {
                        Text(subtitleLine)
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)

                        if let externalRef = order.externalRef {
                            Text(externalRef)
                                .font(.system(size: AppTheme.typeCaption, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }

                    if showOwnerActions {
                        HStack(spacing: 8) {
                            Button {
                                onOpenAssign()
                            } label: {
                                Label("Assign", systemImage: "person.badge.plus")
                                    .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.accentBlue)
                            .accessibilityLabel("Assign driver")
                            .accessibilityHint("Opens the driver assignment screen for this order.")
                            .accessibilityIdentifier("orders.assignDriver")
                        }
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(timestampLabel)
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                    OrderStatusPill(status: order.status)
                    DesignIconView(icon: .chevronRight, size: 12, color: AppTheme.textMuted)
                }
            }
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.borderSubtle)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Opens order timeline details.")
        .accessibilityIdentifier("orders.row")
    }

    private var avatar: some View {
        AvatarView(
            url: URL(string: order.summaryImageURL ?? ""),
            size: AppTheme.avatarSizeMedium,
            fallbackInitials: initials,
            statusColor: statusColor
        )
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

    private var initials: String {
        if let ref = order.externalRef, !ref.isEmpty {
            return String(ref.prefix(2)).uppercased()
        }
        return "OR"
    }

    private var titleLine: String {
        if let summaryTitle = order.summaryTitle,
           !summaryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summaryTitle
        }

        let destination = order.deliveryAddress.line1.trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.isEmpty {
            return "Order \(shortOrderID)"
        }
        return destination
    }

    private var subtitleLine: String {
        if let driverID = order.assignedDriverID, !driverID.isEmpty {
            return "Assigned • Driver \(driverID.suffix(4))"
        }
        return order.quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Awaiting quote" : order.quoteNote
    }

    private var shortOrderID: String {
        let compact = order.id.replacingOccurrences(of: "-", with: "")
        let suffix = String(compact.suffix(6)).uppercased()
        return "#\(suffix)"
    }

    private var timestampLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDateInToday(order.updatedAt) ? .none : .short
        return formatter.string(from: order.updatedAt)
    }

    private var rowAccessibilityLabel: String {
        "\(titleLine). \(order.status.rawValue.replacingOccurrences(of: "_", with: " ")). Updated \(timestampLabel)."
    }
}
