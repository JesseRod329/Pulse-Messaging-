import Foundation
import BoppyV2Core

extension LiveSupabaseBackend {
    // MARK: - Dispatch

    func fetchRoutes(userID: String, role: UserRole) async throws -> [DeliveryRoute] {
        let accessToken = try requireAccessToken()
        let query: String

        switch role {
        case .owner:
            let ownerChannels = try await fetchOwnedChannelIDs(userID: userID, accessToken: accessToken)
            guard !ownerChannels.isEmpty else { return [] }
            query = "delivery_routes?select=id,channel_id,driver_id,status,approximate,created_at,started_at,completed_at&channel_id=in.\(inFilter(ownerChannels))&order=created_at.desc"
        case .driver:
            query = "delivery_routes?select=id,channel_id,driver_id,status,approximate,created_at,started_at,completed_at&driver_id=eq.\(escape(userID))&order=created_at.desc"
        case .follower:
            return []
        }

        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let routeRows = try decode([RouteRow].self, from: data)
        return try await hydrateRoutes(routeRows: routeRows, accessToken: accessToken)
    }

    func buildRoute(channelID: String, driverID: String, start: GeoPoint, actorID: String) async throws -> DeliveryRoute {
        let accessToken = try requireAccessToken()
        _ = actorID

        let data: BuildRouteResponse = try await client.edgeCall(
            functionName: "build-route",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "driver_id": driverID,
                "start_lat": start.lat,
                "start_lng": start.lng,
            ]
        )

        return try await fetchRouteByID(data.route.id, accessToken: accessToken)
    }

    func reorderRouteStops(routeID: String, orderedStopIDs: [String], actorID: String) async throws -> DeliveryRoute {
        let accessToken = try requireAccessToken()
        _ = actorID

        let data: ReorderStopsResponse = try await client.edgeCall(
            functionName: "reorder-route-stops",
            accessToken: accessToken,
            body: [
                "route_id": routeID,
                "ordered_stop_ids": orderedStopIDs
            ]
        )

        return try await fetchRouteByID(data.route_id, accessToken: accessToken)
    }

    func completeStop(routeID: String, stopID: String, actorID: String) async throws -> DeliveryRoute {
        let accessToken = try requireAccessToken()
        _ = actorID

        let data: CompleteStopResponse = try await client.edgeCall(
            functionName: "complete-stop",
            accessToken: accessToken,
            body: [
                "route_id": routeID,
                "stop_id": stopID,
            ]
        )

        return try await fetchRouteByID(data.route_id, accessToken: accessToken)
    }

    func clearRoute(routeID: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()

        _ = try await client.restPatch(
            pathAndQuery: "delivery_routes?id=eq.\(escape(routeID))",
            body: ["status": "cancelled"],
            accessToken: accessToken
        )
    }
}
