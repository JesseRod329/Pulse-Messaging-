import Foundation
import BoppyV2Core

@MainActor
final class OrderStore: ObservableObject {
    @Published var orders: [OrderRequest] = []
    @Published var ledgerByOrderID: [String: [OrderLedgerEvent]] = [:]
    @Published var loadingLedgerOrderIDs: Set<String> = []
    @Published var activeOrderPost: ChannelPost?
    @Published var activeOrderPrefilledQuote: String?

    func refreshOrders(
        userID: String,
        role: UserRole,
        orderService: OrderServiceProtocol
    ) async throws {
        orders = try await orderService.fetchOrders(userID: userID, role: role)
        pruneLedger()
    }

    func openOrderSheet(for post: ChannelPost, prefilledQuote: String?) {
        activeOrderPrefilledQuote = prefilledQuote
        activeOrderPost = post
    }

    func clearOrderSheet() {
        activeOrderPrefilledQuote = nil
        activeOrderPost = nil
    }

    func submitOrderRequest(
        channelID: String,
        postID: String,
        customerID: String,
        customerPhone: String,
        address: DeliveryAddress,
        quoteNote: String,
        orderService: OrderServiceProtocol
    ) async throws {
        _ = try await orderService.createOrderRequest(
            channelID: channelID,
            postID: postID,
            customerID: customerID,
            customerPhone: customerPhone,
            deliveryAddress: address,
            quoteNote: quoteNote
        )
        clearOrderSheet()
    }

    func updateStatus(
        orderID: String,
        status: OrderStatus,
        quoteNote: String?,
        actorID: String,
        orderService: OrderServiceProtocol
    ) async throws {
        _ = try await orderService.updateOrderStatus(
            orderID: orderID,
            status: status,
            quoteNote: quoteNote,
            actorID: actorID
        )
    }

    func assignDriver(
        orderID: String,
        driverID: String,
        actorID: String,
        orderService: OrderServiceProtocol
    ) async throws {
        _ = try await orderService.assignDriver(orderID: orderID, driverID: driverID, actorID: actorID)
    }

    func loadLedger(
        orderID: String,
        userID: String,
        role: UserRole,
        force: Bool = false,
        orderService: OrderServiceProtocol
    ) async throws {
        if loadingLedgerOrderIDs.contains(orderID) { return }
        if !force, ledgerByOrderID[orderID] != nil { return }

        loadingLedgerOrderIDs.insert(orderID)
        defer { loadingLedgerOrderIDs.remove(orderID) }

        let events = try await orderService.fetchLedgerEvents(orderID: orderID, userID: userID, role: role)
        ledgerByOrderID[orderID] = events
    }

    func clear() {
        orders = []
        ledgerByOrderID = [:]
        loadingLedgerOrderIDs = []
        clearOrderSheet()
    }

    private func pruneLedger() {
        let validOrderIDs = Set(orders.map(\.id))
        ledgerByOrderID = ledgerByOrderID.filter { validOrderIDs.contains($0.key) }
    }
}
