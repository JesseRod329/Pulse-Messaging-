import Foundation

public final class DistanceRouter: RoutingServiceProtocol {
    public init() {}

    public func buildFallbackRoute(start: GeoPoint, candidates: [RouteCandidate]) async -> RoutePlan {
        guard !candidates.isEmpty else {
            return RoutePlan(orderedIDs: [], etaMinutes: [], approximate: true)
        }

        var remaining = candidates
        var current = start
        var ordered: [String] = []
        var etas: [Int] = []
        var elapsed = 0

        while !remaining.isEmpty {
            let best = remaining.enumerated().min { lhs, rhs in
                let leftDistance = haversineDistance(current, lhs.element.point)
                let rightDistance = haversineDistance(current, rhs.element.point)

                if leftDistance == rightDistance {
                    return lhs.element.id < rhs.element.id
                }
                return leftDistance < rightDistance
            }

            guard let chosen = best else { break }
            let distance = haversineDistance(current, chosen.element.point)
            elapsed += max(4, Int(((distance / 35.0) * 60.0).rounded()))
            ordered.append(chosen.element.id)
            etas.append(elapsed)
            current = chosen.element.point
            remaining.remove(at: chosen.offset)
        }

        return RoutePlan(orderedIDs: ordered, etaMinutes: etas, approximate: true)
    }

    private func haversineDistance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let r = 6371.0
        let dLat = (b.lat - a.lat).degreesToRadians
        let dLng = (b.lng - a.lng).degreesToRadians
        let lat1 = a.lat.degreesToRadians
        let lat2 = b.lat.degreesToRadians

        let value = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2)
            * sin(dLng / 2) * sin(dLng / 2)

        return 2.0 * r * asin(min(1.0, sqrt(value)))
    }
}

private extension Double {
    var degreesToRadians: Double {
        self * .pi / 180.0
    }
}
