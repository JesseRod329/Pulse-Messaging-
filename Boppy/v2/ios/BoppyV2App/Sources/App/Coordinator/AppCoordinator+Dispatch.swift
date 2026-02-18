import Foundation
import BoppyV2Core

extension AppCoordinator {
    func buildRoute(start: GeoPoint, driverID: String) async {
        guard let user = authStore.user, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await dispatchStore.buildRoute(
                channelID: channelID,
                driverID: driverID,
                start: start,
                actorID: user.id,
                dispatchService: environment.dispatchService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func reorderStop(routeID: String, stopID: String, direction: RouteStopReorderDirection) async {
        guard let user = authStore.user, user.role == .owner else { return }
        guard ensureOnline() else { return }

        do {
            try await dispatchStore.reorderStop(
                routeID: routeID,
                stopID: stopID,
                actorID: user.id,
                direction: direction,
                dispatchService: environment.dispatchService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func completeStop(routeID: String, stopID: String) async {
        guard let user = authStore.user else { return }
        guard ensureOnline() else { return }

        do {
            try await dispatchStore.completeStop(
                routeID: routeID,
                stopID: stopID,
                actorID: user.id,
                dispatchService: environment.dispatchService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func clearRoute() async {
        guard let user = authStore.user, user.role == .owner else { return }
        guard ensureOnline() else { return }
        guard let routeID = dispatchStore.routes.first?.id else { return }

        do {
            try await dispatchStore.clearRoute(
                routeID: routeID,
                actorID: user.id,
                dispatchService: environment.dispatchService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }
}
