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
                HStack(spacing: 2) {
                    Button(action: onMoveUp) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canReorder || stop.stopIndex == 0)
                    .accessibilityLabel("Move stop up")
                    .accessibilityHint("Reorders this stop earlier in the route.")
                    .accessibilityIdentifier("dispatch.stop.moveUp")

                    Button(action: onMoveDown) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canReorder || stop.stopIndex == route.stops.count - 1)
                    .accessibilityLabel("Move stop down")
                    .accessibilityHint("Reorders this stop later in the route.")
                    .accessibilityIdentifier("dispatch.stop.moveDown")
                }
                .font(AppTheme.inter(12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(AppTheme.textMuted)
                .opacity(canReorder ? 0.72 : 0.30)
                .padding(.bottom, 8)

                ZStack {
                    Circle()
                        .fill(stop.completedAt == nil ? (isCurrentStop ? AppTheme.accentBlue : AppTheme.surfaceElevated) : AppTheme.success.opacity(0.18))
                        .frame(width: 40, height: 40)
                    if stop.completedAt == nil {
                        Text("\(stop.stopIndex + 1)")
                            .font(AppTheme.inter(17, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(AppTheme.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(AppTheme.inter(13, weight: .bold, relativeTo: .subheadline))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                if !isLastStop {
                    Rectangle()
                        .fill(AppTheme.border.opacity(0.72))
                        .frame(width: 2, height: 72)
                        .padding(.top, 6)
                }
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(primaryLine)
                        .font(AppTheme.inter(22, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(AppTheme.textPrimary)
                        .strikethrough(stop.completedAt != nil, color: AppTheme.textMuted)
                        .lineLimit(1)
                    Spacer()
                    statusBadge
                }

                Text(secondaryLine)
                    .font(AppTheme.inter(15, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                if let eta = stop.etaMinutes {
                    Text("ETA \(eta) min")
                        .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
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
                    .accessibilityLabel("Call customer")
                    .accessibilityHint(callURL == nil ? "Phone number unavailable." : "Calls the customer for this stop.")
                    .accessibilityIdentifier("dispatch.stop.call")
                    .font(AppTheme.inter(13, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 9)
                    .background(AppTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
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
                    .accessibilityLabel("Stop details")
                    .accessibilityHint("Opens full details for this stop.")
                    .accessibilityIdentifier("dispatch.stop.details")
                    .font(AppTheme.inter(13, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 9)
                    .background(AppTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }

                if canComplete && stop.completedAt == nil {
                    Button("Mark Completed", action: onComplete)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Mark stop completed")
                        .accessibilityHint("Marks this route stop as completed.")
                        .accessibilityIdentifier("dispatch.stop.complete")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(stopBackgroundStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrentStop ? AppTheme.accentBlue : AppTheme.border.opacity(0.65), lineWidth: isCurrentStop ? 2 : 1)
        )
        .shadow(color: isCurrentStop ? AppTheme.accentBlue.opacity(0.3) : .clear, radius: 12, y: 4)
        .opacity(stop.completedAt == nil ? 1 : 0.62)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stop \(stop.stopIndex + 1), \(stopStateText)")
    }

    private var callURL: URL? {
        guard let phone = order?.customerPhone else { return nil }
        return URL(string: "tel://\(phone)")
    }

    private var stopBackgroundStyle: AnyShapeStyle {
        if isCurrentStop {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.surfaceElevated.opacity(0.95), AppTheme.surface.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if stop.completedAt != nil {
            return AnyShapeStyle(AppTheme.surface.opacity(0.62))
        }
        return AnyShapeStyle(AppTheme.surface.opacity(0.86))
    }

    private var statusBadge: some View {
        Text(stopStateText.uppercased())
            .font(AppTheme.inter(10, weight: .bold, relativeTo: .caption2))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stopStateColor.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(stopStateColor.opacity(0.30), lineWidth: 1)
            )
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
        if isPending { return "Pending" }
        return "Pending"
    }

    private var stopStateColor: Color {
        if stop.completedAt != nil { return AppTheme.success }
        if isInProgress { return AppTheme.accentBlue }
        if isPending { return AppTheme.textMuted }
        return AppTheme.textMuted
    }
}
