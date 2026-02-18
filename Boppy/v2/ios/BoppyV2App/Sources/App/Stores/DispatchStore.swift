import Foundation
import BoppyV2Core

@MainActor
final class DispatchStore: ObservableObject {
    @Published var routes: [DeliveryRoute] = []

    func refreshRoutes(
        userID: String,
        role: UserRole,
        dispatchService: DispatchServiceProtocol
    ) async throws {
        routes = try await dispatchService.fetchRoutes(userID: userID, role: role)
    }

    func buildRoute(
        channelID: String,
        driverID: String,
        start: GeoPoint,
        actorID: String,
        dispatchService: DispatchServiceProtocol
    ) async throws {
        let newRoute = try await dispatchService.buildRoute(
            channelID: channelID,
            driverID: driverID,
            start: start,
            actorID: actorID
        )
        if let existingIndex = routes.firstIndex(where: { $0.id == newRoute.id }) {
            routes[existingIndex] = newRoute
        } else {
            routes.append(newRoute)
        }
    }

    func reorderStop(
        routeID: String,
        stopID: String,
        actorID: String,
        direction: RouteStopReorderDirection,
        dispatchService: DispatchServiceProtocol
    ) async throws {
        guard let route = routes.first(where: { $0.id == routeID }), route.status == .planned else { return }

        let orderedStops = route.stops.sorted(by: { $0.stopIndex < $1.stopIndex })
        let ids = orderedStops.map(\.id)
        guard let currentIndex = ids.firstIndex(of: stopID) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }

        guard ids.indices.contains(targetIndex) else { return }

        var reordered = ids
        reordered.swapAt(currentIndex, targetIndex)

        let updatedRoute = try await dispatchService.reorderRouteStops(
            routeID: routeID,
            orderedStopIDs: reordered,
            actorID: actorID
        )
        if let routeIndex = routes.firstIndex(where: { $0.id == routeID }) {
            routes[routeIndex] = updatedRoute
        }
    }

    func completeStop(
        routeID: String,
        stopID: String,
        actorID: String,
        dispatchService: DispatchServiceProtocol
    ) async throws {
        let updatedRoute = try await dispatchService.completeStop(routeID: routeID, stopID: stopID, actorID: actorID)
        if let routeIndex = routes.firstIndex(where: { $0.id == routeID }) {
            routes[routeIndex] = updatedRoute
        }
    }

    func clearRoute(
        routeID: String,
        actorID: String,
        dispatchService: DispatchServiceProtocol
    ) async throws {
        try await dispatchService.clearRoute(routeID: routeID, actorID: actorID)
        routes.removeAll(where: { $0.id == routeID })
    }

    func clear() {
        routes = []
    }
}
