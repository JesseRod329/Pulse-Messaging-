import SwiftUI
import UIKit
import BoppyV2Core

struct OrdersView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var orderStore: OrderStore

    @State private var selectedFilter: InboxFilter = .all
    @State private var readOrderIDs: Set<String> = []
    @State private var timelineOrder: OrderRequest?
    @State private var assignDriverOrder: OrderRequest?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            filterBar

                            if filteredOrders.isEmpty {
                                AppEmptyStateView(
                                    icon: "tray",
                                    title: selectedFilter == .all ? "No Orders" : "No \(selectedFilter.rawValue) Orders",
                                    subtitle: "Quote requests will appear here."
                                )
                            } else {
                                ForEach(filteredOrders) { order in
                                    OrderInboxCard(
                                        order: order,
                                        isUnread: isUnread(order),
                                        showOwnerActions: authStore.user?.role == .owner,
                                        onOpenTimeline: { openTimeline(order) },
                                        onOpenAssign: {
                                            assignDriverOrder = order
                                        }
                                    )
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
                    .refreshable {
                        await coordinator.refreshAll()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AppTheme.screenGradient)
                }

                ordersFab
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await coordinator.refreshAll() }
                        } label: {
                            DesignIconView(icon: .refresh, size: 16, color: AppTheme.textSecondary)
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityLabel("Refresh orders")
                        .accessibilityHint("Reloads the latest order statuses.")
                        .accessibilityIdentifier("orders.refresh")

                        Circle()
                            .fill(AppTheme.accentBlue.opacity(0.25))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(avatarInitial)
                                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(AppTheme.textPrimary)
                            )
                    }
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
                bootstrapReadState()
            }
            .onChange(of: orderStore.orders) { _, _ in
                bootstrapReadState()
            }
        }
        .fullScreenCover(item: Binding(
            get: { timelineOrder.map(OrderTimelineToken.init(order:)) },
            set: { token in timelineOrder = token?.order }
        )) { token in
            OrderTimelineView(order: token.order)
                .environmentObject(coordinator)
        }
        .fullScreenCover(item: Binding(
            get: { assignDriverOrder.map(OrderTimelineToken.init(order:)) },
            set: { token in assignDriverOrder = token?.order }
        )) { token in
            AssignDriverView(order: token.order) { driverID in
                Task {
                    await coordinator.assignDriver(orderID: token.order.id, driverID: driverID)
                    assignDriverOrder = nil
                }
            }
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
        authStore.user?.role ?? .follower
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        count: count(for: filter)
                    ) {
                        selectedFilter = filter
                    }
                    .accessibilityLabel("\(filter.rawValue) filter")
                    .accessibilityHint("Shows \(count(for: filter)) \(filter.rawValue.lowercased()) orders.")
                    .accessibilityIdentifier("orders.filter.\(filter.rawValue.lowercased())")
                }
            }
        }
    }

    private var ordersFab: some View {
        FloatingActionButton(title: "Pending", icon: .menu) {
            if coordinator.featureFlags.motionV2 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            selectedFilter = .pending
        }
        .padding(.trailing, 18)
        .padding(.bottom, AppTheme.fabBottomPadding)
        .accessibilityLabel("Show pending orders")
        .accessibilityHint("Switches the inbox to pending orders.")
        .accessibilityIdentifier("orders.fab")
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

    private func openTimeline(_ order: OrderRequest) {
        if coordinator.featureFlags.motionV2 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        readOrderIDs.insert(order.id)
        Task {
            await coordinator.loadLedger(for: order.id)
            timelineOrder = order
        }
    }

    private func bootstrapReadState() {
        let knownOrderIDs = Set(orderStore.orders.map(\.id))
        readOrderIDs = readOrderIDs.intersection(knownOrderIDs)
    }

    private func isUnread(_ order: OrderRequest) -> Bool {
        guard !readOrderIDs.contains(order.id) else { return false }
        return [.requested, .quoted, .addressReview].contains(order.status)
    }
}

private enum InboxFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case active = "Active"
    case done = "Done"
}

private struct OrderTimelineToken: Identifiable {
    let order: OrderRequest
    var id: String { order.id }
}
