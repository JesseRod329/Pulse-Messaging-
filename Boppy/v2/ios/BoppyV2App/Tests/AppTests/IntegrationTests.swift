import XCTest
import BoppyV2Core
@testable import Boppy_V2

final class IntegrationTests: XCTestCase {
    func testAuthFlowRequestAndVerifyOTP() async throws {
        let backend = InMemoryBackend()
        let phone = "+15551112222"

        try await backend.requestOTP(phoneE164: phone)
        let user = try await backend.verifyOTP(phoneE164: phone, code: "123456")
        let session = try await backend.currentSession()

        XCTAssertEqual(user.phoneE164, phone)
        XCTAssertEqual(user.role, .follower)
        XCTAssertEqual(session?.id, user.id)
    }

    func testOrderLifecycleFromRequestToOutForDelivery() async throws {
        let backend = InMemoryBackend()

        try await backend.requestOTP(phoneE164: "+15553334444")
        let follower = try await backend.verifyOTP(phoneE164: "+15553334444", code: "123456")

        let invite = try await backend.createInvite(
            channelID: "channel-main",
            ownerID: "owner-1",
            expiresInHours: 24,
            maxUses: 10
        )

        _ = try await backend.joinChannel(token: invite.token, userID: follower.id)

        guard let post = try await backend.fetchPosts(channelID: "channel-main").first else {
            XCTFail("Expected at least one post in channel-main")
            return
        }

        let created = try await backend.createOrderRequest(
            channelID: "channel-main",
            postID: post.id,
            customerID: follower.id,
            customerPhone: follower.phoneE164,
            deliveryAddress: DeliveryAddress(
                line1: "101 Test Ave",
                city: "Austin",
                state: "TX",
                postalCode: "78701",
                country: "US"
            ),
            quoteNote: "Need fast delivery"
        )

        _ = try await backend.updateOrderStatus(orderID: created.id, status: .quoted, quoteNote: "Quote $120", actorID: "owner-1")
        _ = try await backend.updateOrderStatus(orderID: created.id, status: .accepted, quoteNote: "Accepted", actorID: "owner-1")
        _ = try await backend.assignDriver(orderID: created.id, driverID: "driver-1", actorID: "owner-1")

        let route = try await backend.buildRoute(
            channelID: "channel-main",
            driverID: "driver-1",
            start: GeoPoint(lat: 30.2672, lng: -97.7431),
            actorID: "owner-1"
        )

        XCTAssertTrue(route.stops.contains(where: { $0.orderID == created.id }))

        let ownerOrders = try await backend.fetchOrders(userID: "owner-1", role: .owner)
        let updated = ownerOrders.first(where: { $0.id == created.id })
        XCTAssertEqual(updated?.status, .outForDelivery)
    }

    func testInventoryCreateAdjustAndFetchBalance() async throws {
        let backend = InMemoryBackend()

        let item = try await backend.upsertInventoryItem(
            channelID: "channel-main",
            itemID: nil,
            name: "Integration Lamp",
            sku: "INT-LAMP-001",
            description: "Inventory integration test item",
            defaultPriceCents: 12900,
            currencyCode: "USD",
            trackStock: true,
            stockOnHand: 10,
            lowStockThreshold: 2,
            actorID: "owner-1"
        )

        _ = try await backend.adjustInventoryStock(
            channelID: "channel-main",
            itemID: item.id,
            variantID: nil,
            delta: -3,
            reason: "integration_test",
            actorID: "owner-1"
        )

        let catalog = try await backend.fetchInventoryCatalog(
            channelID: "channel-main",
            includeInactive: false,
            includeLedger: true,
            actorID: "owner-1"
        )

        let refreshed = catalog.items.first(where: { $0.id == item.id })
        XCTAssertEqual(refreshed?.stockOnHand, 7)
        XCTAssertTrue(catalog.ledger.contains(where: { $0.itemID == item.id && $0.delta == -3 }))
    }

    func testRouteFlowSupportsReorderAndStopCompletion() async throws {
        let backend = InMemoryBackend()

        try await backend.requestOTP(phoneE164: "+15554445555")
        let follower = try await backend.verifyOTP(phoneE164: "+15554445555", code: "123456")

        let invite = try await backend.createInvite(
            channelID: "channel-main",
            ownerID: "owner-1",
            expiresInHours: 24,
            maxUses: 10
        )
        _ = try await backend.joinChannel(token: invite.token, userID: follower.id)

        guard let post = try await backend.fetchPosts(channelID: "channel-main").first else {
            XCTFail("Expected at least one post in channel-main")
            return
        }

        let address = DeliveryAddress(
            line1: "500 Route St",
            city: "Austin",
            state: "TX",
            postalCode: "78702",
            country: "US"
        )

        let orderA = try await backend.createOrderRequest(
            channelID: "channel-main",
            postID: post.id,
            customerID: follower.id,
            customerPhone: follower.phoneE164,
            deliveryAddress: address,
            quoteNote: "route-test-a"
        )

        let orderB = try await backend.createOrderRequest(
            channelID: "channel-main",
            postID: post.id,
            customerID: follower.id,
            customerPhone: follower.phoneE164,
            deliveryAddress: address,
            quoteNote: "route-test-b"
        )

        _ = try await backend.assignDriver(orderID: orderA.id, driverID: "driver-1", actorID: "owner-1")
        _ = try await backend.assignDriver(orderID: orderB.id, driverID: "driver-1", actorID: "owner-1")

        let route = try await backend.buildRoute(
            channelID: "channel-main",
            driverID: "driver-1",
            start: GeoPoint(lat: 30.2672, lng: -97.7431),
            actorID: "owner-1"
        )

        XCTAssertEqual(route.stops.count, 2)

        let reversedStopIDs = route.stops.map(\.id).reversed()
        let reordered = try await backend.reorderRouteStops(
            routeID: route.id,
            orderedStopIDs: Array(reversedStopIDs),
            actorID: "owner-1"
        )

        XCTAssertEqual(reordered.stops.map(\.id), Array(reversedStopIDs))
        XCTAssertEqual(reordered.stops.map(\.stopIndex), [0, 1])

        let afterFirstCompletion = try await backend.completeStop(
            routeID: reordered.id,
            stopID: reordered.stops[0].id,
            actorID: "driver-1"
        )

        XCTAssertEqual(afterFirstCompletion.status, .inProgress)
        XCTAssertNotNil(afterFirstCompletion.startedAt)

        let completedRoute = try await backend.completeStop(
            routeID: reordered.id,
            stopID: reordered.stops[1].id,
            actorID: "driver-1"
        )

        XCTAssertEqual(completedRoute.status, .completed)
        XCTAssertNotNil(completedRoute.completedAt)
        XCTAssertTrue(completedRoute.stops.allSatisfy { $0.completedAt != nil })

        let ownerOrders = try await backend.fetchOrders(userID: "owner-1", role: .owner)
        let deliveredOrderIDs = Set(ownerOrders.filter { $0.status == .delivered }.map(\.id))
        XCTAssertTrue(deliveredOrderIDs.contains(orderA.id))
        XCTAssertTrue(deliveredOrderIDs.contains(orderB.id))
    }
}
