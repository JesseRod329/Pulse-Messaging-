import SwiftUI
import UIKit
import BoppyV2Core

struct FollowerOrdersView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var orderStore: OrderStore

    @State private var selectedFilter: FollowerOrderFilter = .all
    @State private var readOrderIDs: Set<String> = []
    @State private var timelineOrder: OrderRequest?
    @ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 56
    @ScaledMetric(relativeTo: .caption) private var statusDotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var unreadDotSize: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var rowVerticalPadding: CGFloat = 10

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.screenGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        filterRail

                        if filteredOrders.isEmpty {
                            AppEmptyStateView(
                                icon: "shippingbox",
                                title: "No Orders",
                                subtitle: "Your order updates will appear here."
                            )
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredOrders) { order in
                                    followerRow(order)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, AppTheme.contentBottomPadding)
                }
                .scrollDismissesKeyboard(.immediately)
                .refreshable {
                    await coordinator.refreshAll()
                }

                FloatingActionButton(title: "Pending", icon: .menu) {
                    selectedFilter = .requested
                }
                .padding(.trailing, 18)
                .padding(.bottom, AppTheme.fabBottomPadding)
                .accessibilityLabel("Pending orders shortcut")
                .accessibilityHint("Filters your orders to requested status.")
                .accessibilityIdentifier("orders.fab")
            }
            .navigationTitle("My Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await coordinator.refreshAll() }
                    } label: {
                        DesignIconView(icon: .refresh, size: 16, color: AppTheme.textSecondary)
                    }
                    .accessibilityLabel("Refresh orders")
                    .accessibilityHint("Reloads your latest order statuses.")
                    .accessibilityIdentifier("orders.refresh")
                }
            }
            .task {
                await coordinator.refreshAll()
                bootstrapReadState()
            }
            .onChange(of: orderStore.orders) { _, _ in
                bootstrapReadState()
            }
        }
        .fullScreenCover(item: Binding(
            get: { timelineOrder.map(OrderTimelineToken.init(order:)) },
            set: { timelineOrder = $0?.order }
        )) { token in
            OrderTimelineView(order: token.order)
                .environmentObject(coordinator)
        }
        .appScreenBackground()
    }

    private var sortedOrders: [OrderRequest] {
        orderStore.orders.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private var filteredOrders: [OrderRequest] {
        switch selectedFilter {
        case .all:
            return sortedOrders
        case .requested:
            return sortedOrders.filter { [.requested, .addressReview].contains($0.status) }
        case .quoted:
            return sortedOrders.filter { $0.status == .quoted }
        case .inProgress:
            return sortedOrders.filter { [.accepted, .assigned, .outForDelivery].contains($0.status) }
        case .completed:
            return sortedOrders.filter { [.delivered, .cancelled].contains($0.status) }
        }
    }

    private var filterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FollowerOrderFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                    .accessibilityLabel("\(filter.rawValue) filter")
                    .accessibilityHint("Shows \(filter.rawValue.lowercased()) orders.")
                    .accessibilityIdentifier("orders.filter.\(filter.rawValue.lowercased().replacingOccurrences(of: " ", with: ""))")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Order status filters")
    }

    private func followerRow(_ order: OrderRequest) -> some View {
        Button {
            if coordinator.featureFlags.motionV2 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            readOrderIDs.insert(order.id)
            timelineOrder = order
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.accentBlue.opacity(0.16))
                        .frame(width: iconContainerSize, height: iconContainerSize)
                        .overlay(
                            Text(iconGlyph(order))
                                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                                .foregroundStyle(AppTheme.accentBlue)
                        )

                    Circle()
                        .fill(statusColor(order.status))
                        .frame(width: statusDotSize, height: statusDotSize)
                        .overlay(Circle().stroke(AppTheme.navBar, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(order.summaryTitle ?? "Order \(shortID(order.id))")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(order.externalRef ?? shortID(order.id))
                        .font(.system(size: AppTheme.typeCaption, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted)

                    Text(order.quoteNote.isEmpty ? "Awaiting update" : order.quoteNote)
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.updatedAt, style: .time)
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)

                    OrderStatusPill(status: order.status)
                }

                if isUnread(order) {
                    Circle()
                        .fill(AppTheme.accentBlue)
                        .frame(width: unreadDotSize, height: unreadDotSize)
                }
            }
            .padding(.vertical, rowVerticalPadding)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.borderSubtle)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(order.summaryTitle ?? "Order \(shortID(order.id))")
        .accessibilityValue(order.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        .accessibilityHint("Opens the full order timeline.")
        .accessibilityIdentifier("orders.row.\(order.id)")
    }

    private func iconGlyph(_ order: OrderRequest) -> String {
        if order.status == .delivered { return "✓" }
        if order.status == .outForDelivery { return "→" }
        return "□"
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
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

    private func shortID(_ id: String) -> String {
        "#\(String(id.replacingOccurrences(of: "-", with: "").suffix(6)).uppercased())"
    }

    private func bootstrapReadState() {
        readOrderIDs = readOrderIDs.intersection(Set(orderStore.orders.map(\.id)))
    }

    private func isUnread(_ order: OrderRequest) -> Bool {
        guard !readOrderIDs.contains(order.id) else { return false }
        return [.requested, .quoted, .addressReview].contains(order.status)
    }
}

private enum FollowerOrderFilter: String, CaseIterable {
    case all = "All"
    case requested = "Requested"
    case quoted = "Quoted"
    case inProgress = "In Progress"
    case completed = "Completed"
}

private struct OrderTimelineToken: Identifiable {
    let order: OrderRequest
    var id: String { order.id }
}
