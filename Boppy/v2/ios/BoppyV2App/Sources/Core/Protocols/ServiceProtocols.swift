import Foundation

public protocol AuthServiceProtocol {
    func requestOTP(phoneE164: String) async throws
    func verifyOTP(phoneE164: String, code: String) async throws -> SessionUser
    func currentSession() async throws -> SessionUser?
    func signOut() async
}

public protocol ChannelFeedServiceProtocol {
    func createChannel(ownerID: String, title: String, description: String) async throws -> Channel
    func fetchChannels(userID: String) async throws -> [Channel]
    func fetchPosts(channelID: String) async throws -> [ChannelPost]
    func fetchDrivers(channelID: String) async throws -> [DriverProfile]
    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?
    ) async throws -> ChannelPost
    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?
    ) async throws -> ChannelInvite
    func joinChannel(token: String, userID: String) async throws -> Channel
}

public protocol OrderServiceProtocol {
    func createOrderRequest(
        channelID: String,
        postID: String,
        customerID: String,
        customerPhone: String,
        deliveryAddress: DeliveryAddress,
        quoteNote: String
    ) async throws -> OrderRequest
    func fetchOrders(userID: String, role: UserRole) async throws -> [OrderRequest]
    func fetchLedgerEvents(orderID: String, userID: String, role: UserRole) async throws -> [OrderLedgerEvent]
    func upsertOrderLineItems(orderID: String, lineItems: [OrderLineItemInput], actorID: String) async throws -> [OrderLineItem]
    func updateOrderStatus(orderID: String, status: OrderStatus, quoteNote: String?, actorID: String) async throws -> OrderRequest
    func assignDriver(orderID: String, driverID: String, actorID: String) async throws -> OrderRequest
}

public protocol DispatchServiceProtocol {
    func fetchRoutes(userID: String, role: UserRole) async throws -> [DeliveryRoute]
    func buildRoute(
        channelID: String,
        driverID: String,
        start: GeoPoint,
        actorID: String
    ) async throws -> DeliveryRoute
    func reorderRouteStops(routeID: String, orderedStopIDs: [String], actorID: String) async throws -> DeliveryRoute
    func completeStop(routeID: String, stopID: String, actorID: String) async throws -> DeliveryRoute
}

public protocol RoutingServiceProtocol {
    func buildFallbackRoute(start: GeoPoint, candidates: [RouteCandidate]) async -> RoutePlan
}

public protocol AnalyticsServiceProtocol {
    func track(event: String, properties: [String: String])
}

public protocol InventoryServiceProtocol {
    func upsertInventoryItem(
        channelID: String,
        itemID: String?,
        name: String,
        sku: String,
        description: String,
        defaultPriceCents: Int,
        currencyCode: String,
        trackStock: Bool,
        stockOnHand: Int,
        lowStockThreshold: Int,
        actorID: String
    ) async throws -> InventoryItem

    func upsertInventoryVariant(
        channelID: String,
        itemID: String,
        variantID: String?,
        name: String,
        sku: String,
        priceCents: Int,
        stockOnHand: Int,
        isActive: Bool,
        actorID: String
    ) async throws -> InventoryVariant

    func adjustInventoryStock(
        channelID: String,
        itemID: String,
        variantID: String?,
        delta: Int,
        reason: String,
        actorID: String
    ) async throws -> InventoryStockEvent

    func fetchInventoryCatalog(channelID: String, includeInactive: Bool, includeLedger: Bool, actorID: String) async throws -> InventoryCatalog
}

public protocol AdminServiceProtocol {
    func archiveChannel(channelID: String, reason: String, actorID: String) async throws
    func deleteOrder(orderID: String, mode: AdminDeleteMode, reason: String, actorID: String) async throws
    func unassignDriver(orderID: String, reason: String, actorID: String) async throws
    func upsertDriverMembership(channelID: String, driverUserID: String, operation: DriverMembershipOperation, reason: String, actorID: String) async throws
    func fetchAdminAuditEvents(channelID: String, action: String?, limit: Int, actorID: String) async throws -> [AdminAuditEvent]
}
