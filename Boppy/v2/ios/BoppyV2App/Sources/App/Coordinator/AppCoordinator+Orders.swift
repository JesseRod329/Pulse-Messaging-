import Foundation
import BoppyV2Core

extension AppCoordinator {
    func openOrderSheet(for post: ChannelPost, prefilledQuote: String? = nil) {
        guard authStore.user?.role == .follower else { return }
        orderStore.openOrderSheet(for: post, prefilledQuote: prefilledQuote)
    }

    func submitOrderRequest(postID: String, address: DeliveryAddress, quoteNote: String) async {
        guard let user = authStore.user, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await orderStore.submitOrderRequest(
                channelID: channelID,
                postID: postID,
                customerID: user.id,
                customerPhone: user.phoneE164,
                address: address,
                quoteNote: quoteNote,
                orderService: environment.orderService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func updateOrderStatus(orderID: String, status: OrderStatus, quoteNote: String?) async {
        guard let user = authStore.user else { return }
        guard ensureOnline() else { return }

        do {
            try await orderStore.updateStatus(
                orderID: orderID,
                status: status,
                quoteNote: quoteNote,
                actorID: user.id,
                orderService: environment.orderService
            )
            await loadLedger(for: orderID, force: true)
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func assignDriver(orderID: String, driverID: String) async {
        guard let user = authStore.user else { return }
        guard ensureOnline() else { return }

        do {
            try await orderStore.assignDriver(
                orderID: orderID,
                driverID: driverID,
                actorID: user.id,
                orderService: environment.orderService
            )
            await loadLedger(for: orderID, force: true)
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func loadLedger(for orderID: String, force: Bool = false) async {
        guard let user = authStore.user else { return }

        do {
            try await orderStore.loadLedger(
                orderID: orderID,
                userID: user.id,
                role: user.role,
                force: force,
                orderService: environment.orderService
            )
        } catch {
            handleError(error)
        }
    }


}
