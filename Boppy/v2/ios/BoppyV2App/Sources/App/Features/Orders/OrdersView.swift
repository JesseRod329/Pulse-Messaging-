import SwiftUI
import BoppyV2Core

struct OrdersView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var expandedOrderIDs: Set<String> = []
    @State private var selectedFilter: InboxFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            filterBar

                            if filteredOrders.isEmpty {
                                ContentUnavailableView(
                                    selectedFilter == .all ? "No Orders" : "No \(selectedFilter.rawValue) Orders",
                                    systemImage: "tray",
                                    description: Text("Quote requests will appear here.")
                                )
                            } else {
                                ForEach(filteredOrders) { order in
                                    OrderInboxCard(
                                        order: order,
                                        isExpanded: expandedOrderIDs.contains(order.id),
                                        onToggleTimeline: {
                                            if expandedOrderIDs.contains(order.id) {
                                                expandedOrderIDs.remove(order.id)
                                            } else {
                                                expandedOrderIDs.insert(order.id)
                                                Task { await coordinator.loadLedger(for: order.id) }
                                            }
                                        }
                                    ) {
                                        if coordinator.user?.role == .owner {
                                            ownerActions(order: order)
                                        }
                                    } timeline: {
                                        timeline(orderID: order.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, AppTheme.contentBottomPadding)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                            alignment: .top
                        )
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AppTheme.screenGradient)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await coordinator.refreshAll() }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .accessibilityIdentifier("orders.menu")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await coordinator.refreshAll() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityIdentifier("orders.refresh")

                        Circle()
                            .fill(AppTheme.accentBlue.opacity(0.25))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(avatarInitial)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            )
                    }
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appScreenBackground()
    }

    private func timeline(orderID: String) -> some View {
        LedgerTimelineView(
            events: coordinator.ledgerByOrderID[orderID] ?? [],
            isLoading: coordinator.loadingLedgerOrderIDs.contains(orderID)
        )
    }

    private var sortedOrders: [OrderRequest] {
        coordinator.orders.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private var filteredOrders: [OrderRequest] {
        switch selectedFilter {
        case .all:
            return sortedOrders
        case .pending:
            return sortedOrders.filter { [.requested, .quoted, .addressReview].contains($0.status) }
        case .active:
            return sortedOrders.filter { [.accepted, .assigned, .outForDelivery].contains($0.status) }
        case .done:
            return sortedOrders.filter { [.delivered, .cancelled].contains($0.status) }
        }
    }

    private var navigationTitle: String {
        role == .follower ? "My Orders" : "Inbox"
    }

    private var avatarInitial: String {
        switch role {
        case .owner: return "O"
        case .driver: return "D"
        case .follower: return "F"
        }
    }

    private var role: UserRole {
        coordinator.user?.role ?? .follower
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(InboxFilter.allCases, id: \.self) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    HStack(spacing: 6) {
                        Text(filter.rawValue)
                        Text("\(count(for: filter))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(selectedFilter == filter ? AppTheme.accentBlue : AppTheme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? AppTheme.surface.opacity(0.55) : AppTheme.surface.opacity(0.24))
                            )
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedFilter == filter ? AppTheme.accentBlue.opacity(0.30) : AppTheme.surface.opacity(0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedFilter == filter ? AppTheme.accentBlue : AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedFilter == filter ? AppTheme.accentBlue : AppTheme.textMuted)
                .accessibilityIdentifier("orders.filter.\(filter.rawValue.lowercased())")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func count(for filter: InboxFilter) -> Int {
        switch filter {
        case .all:
            return sortedOrders.count
        case .pending:
            return sortedOrders.filter { [.requested, .quoted, .addressReview].contains($0.status) }.count
        case .active:
            return sortedOrders.filter { [.accepted, .assigned, .outForDelivery].contains($0.status) }.count
        case .done:
            return sortedOrders.filter { [.delivered, .cancelled].contains($0.status) }.count
        }
    }

    @ViewBuilder
    private func ownerActions(order: OrderRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu("Update Status") {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) {
                            Task {
                                await coordinator.updateOrderStatus(
                                    orderID: order.id,
                                    status: status,
                                    quoteNote: order.quoteNote
                                )
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accentBlue)
                .accessibilityIdentifier("orders.updateStatus")

                if !coordinator.drivers.isEmpty {
                    Menu("Assign Driver") {
                        ForEach(coordinator.drivers) { driver in
                            Button(driver.displayName) {
                                Task {
                                    await coordinator.assignDriver(orderID: order.id, driverID: driver.id)
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accentBlue)
                    .accessibilityIdentifier("orders.assignDriver")
                }
            }
            .font(.caption.weight(.semibold))
        }
    }
}

private enum InboxFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case active = "Active"
    case done = "Done"
}
