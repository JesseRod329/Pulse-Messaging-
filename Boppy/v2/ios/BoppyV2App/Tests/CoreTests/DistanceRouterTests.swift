import XCTest
@testable import BoppyV2Core

final class DistanceRouterTests: XCTestCase {
    func testEmptyCandidatesReturnsEmptyPlan() async {
        let router = DistanceRouter()
        let plan = await router.buildFallbackRoute(start: .init(lat: 30, lng: -97), candidates: [])
        XCTAssertEqual(plan.orderedIDs, [])
        XCTAssertEqual(plan.etaMinutes, [])
        XCTAssertTrue(plan.approximate)
    }

    func testSingleCandidateRoute() async {
        let router = DistanceRouter()
        let candidate = RouteCandidate(id: "A", point: .init(lat: 30.2672, lng: -97.7431))
        let plan = await router.buildFallbackRoute(start: .init(lat: 30.2672, lng: -97.7431), candidates: [candidate])
        XCTAssertEqual(plan.orderedIDs, ["A"])
        XCTAssertEqual(plan.etaMinutes.count, 1)
        XCTAssertGreaterThanOrEqual(plan.etaMinutes[0], 4)
    }

    func testDeterministicNearestNeighborOrdering() async {
        let router = DistanceRouter()
        let candidates = [
            RouteCandidate(id: "A", point: .init(lat: 30.275, lng: -97.74)),
            RouteCandidate(id: "B", point: .init(lat: 30.30, lng: -97.80)),
            RouteCandidate(id: "C", point: .init(lat: 30.26, lng: -97.74))
        ]

        let start = GeoPoint(lat: 30.2672, lng: -97.7431)
        let first = await router.buildFallbackRoute(start: start, candidates: candidates)
        let second = await router.buildFallbackRoute(start: start, candidates: candidates)

        XCTAssertEqual(first.orderedIDs, second.orderedIDs)
        XCTAssertEqual(first.etaMinutes, second.etaMinutes)
        XCTAssertEqual(first.orderedIDs.first, "C")
    }
}
