import SwiftUI
import BoppyV2Core

struct OrdersView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var expandedOrderIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            List(coordinator.orders) { order in
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
                .padding(.vertical, 6)
            }
            .navigationTitle("Orders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await coordinator.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
    }

    private func timeline(orderID: String) -> some View {
        LedgerTimelineView(
            events: coordinator.ledgerByOrderID[orderID] ?? [],
            isLoading: coordinator.loadingLedgerOrderIDs.contains(orderID)
        )
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
                }
            }
        }
    }
}
