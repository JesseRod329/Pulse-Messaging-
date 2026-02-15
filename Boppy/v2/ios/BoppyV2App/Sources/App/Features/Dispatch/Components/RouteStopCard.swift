import SwiftUI
import BoppyV2Core

struct RouteStopCard: View {
    @Environment(\.openURL) private var openURL

    let stop: RouteStop
    let route: DeliveryRoute
    let order: OrderRequest?
    let canReorder: Bool
    let canComplete: Bool
    let isCurrentStop: Bool
    let isLastStop: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDetails: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                if canReorder {
                    HStack(spacing: 6) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(stop.stopIndex == 0)
                        .accessibilityIdentifier("dispatch.stop.moveUp")

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(stop.stopIndex == route.stops.count - 1)
                        .accessibilityIdentifier("dispatch.stop.moveDown")
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.bottom, 8)
                }

                ZStack {
                    Circle()
                        .fill(stop.completedAt == nil ? AppTheme.surfaceElevated : AppTheme.success.opacity(0.18))
                        .frame(width: 34, height: 34)
                    if stop.completedAt == nil {
                        Text("\(stop.stopIndex + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                if !isLastStop {
                    Rectangle()
                        .fill(AppTheme.border.opacity(0.84))
                        .frame(width: 2, height: 58)
                        .padding(.top, 8)
                }
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(primaryLine)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    statusBadge
                }

                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                if let eta = stop.etaMinutes {
                    Text("ETA \(eta) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accentBlue)
                }

                HStack(spacing: 8) {
                    Button {
                        guard let callURL else { return }
                        openURL(callURL)
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dispatch.stop.call")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .disabled(callURL == nil)

                    Button {
                        onDetails()
                    } label: {
                        Label("Details", systemImage: "info.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dispatch.stop.details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }

                if canComplete && stop.completedAt == nil {
                    Button("Mark Completed", action: onComplete)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("dispatch.stop.complete")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(stopBackgroundStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCurrentStop ? AppTheme.accentBlue : AppTheme.border, lineWidth: isCurrentStop ? 1.6 : 1)
        )
    }

    private var callURL: URL? {
        guard let phone = order?.customerPhone else { return nil }
        return URL(string: "tel://\(phone)")
    }

    private var stopBackgroundStyle: AnyShapeStyle {
        if isCurrentStop {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.surfaceElevated.opacity(0.92), AppTheme.surface.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if stop.completedAt != nil {
            return AnyShapeStyle(AppTheme.surface.opacity(0.85))
        }
        return AnyShapeStyle(AppTheme.cardGradient)
    }

    private var statusBadge: some View {
        Text(stopStateText.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(stopStateColor.opacity(0.18), in: Capsule())
            .foregroundStyle(stopStateColor)
    }

    private var primaryLine: String {
        if let line1 = order?.deliveryAddress.line1, !line1.isEmpty {
            return line1
        }
        return "Order \(shortOrderID)"
    }

    private var secondaryLine: String {
        if let order {
            let pieces = [order.deliveryAddress.city, order.deliveryAddress.state, order.deliveryAddress.postalCode]
                .filter { !$0.isEmpty }
            if !pieces.isEmpty {
                return pieces.joined(separator: ", ")
            }
        }
        return "Order \(shortOrderID)"
    }

    private var shortOrderID: String {
        if let hashIndex = stop.orderID.lastIndex(of: "-") {
            return String(stop.orderID[stop.orderID.index(after: hashIndex)...])
        }
        return stop.orderID
    }

    private var activeStopIndex: Int? {
        route.stops
            .sorted(by: { $0.stopIndex < $1.stopIndex })
            .first(where: { $0.completedAt == nil })?
            .stopIndex
    }

    private var isInProgress: Bool {
        guard let activeStopIndex else { return false }
        return stop.stopIndex == activeStopIndex && stop.completedAt == nil
    }

    private var isPending: Bool {
        guard let activeStopIndex else { return false }
        return stop.stopIndex > activeStopIndex && stop.completedAt == nil
    }

    private var stopStateText: String {
        if stop.completedAt != nil { return "Completed" }
        if isInProgress { return "In Progress" }
        if isPending { return "Queued" }
        return "Pending"
    }

    private var stopStateColor: Color {
        if stop.completedAt != nil { return AppTheme.success }
        if isInProgress { return AppTheme.accentBlue }
        if isPending { return AppTheme.warning }
        return AppTheme.textMuted
    }
}
