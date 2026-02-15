import Foundation
import BoppyV2Core

final class LiveSupabaseBackend: AuthServiceProtocol, ChannelFeedServiceProtocol, OrderServiceProtocol, DispatchServiceProtocol, InventoryServiceProtocol, AdminServiceProtocol {
    private struct MembershipRow: Decodable {
        let channelID: String
        let role: String

        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case role
        }
    }

    private struct ChannelRow: Decodable {
        let id: String
        let title: String
        let description: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case description
            case isActive = "is_active"
        }
    }

    private struct ProfileRow: Decodable {
        let id: String
        let phoneE164: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case phoneE164 = "phone_e164"
            case displayName = "display_name"
        }
    }

    private struct DriverProfileRow: Decodable {
        let id: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    private struct PostRow: Decodable {
        let id: String
        let channelID: String
        let authorID: String
        let postType: String
        let caption: String?
        let mediaPath: String?
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case authorID = "author_id"
            case postType = "post_type"
            case caption
            case mediaPath = "media_path"
            case createdAt = "created_at"
        }
    }

    private struct DeliveryAddressRow: Decodable {
        let line1: String
        let line2: String?
        let city: String
        let state: String
        let postalCode: String
        let country: String?

        enum CodingKeys: String, CodingKey {
            case line1
            case line2
            case city
            case state
            case postalCode = "postal_code"
            case country
        }
    }

    private struct OrderRow: Decodable {
        let id: String
        let channelID: String
        let postID: String
        let customerID: String
        let customerPhone: String
        let deliveryAddress: DeliveryAddressRow
        let lat: Double?
        let lng: Double?
        let quoteNote: String?
        let status: String
        let assignedDriverID: String?
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case postID = "post_id"
            case customerID = "customer_id"
            case customerPhone = "customer_phone"
            case deliveryAddress = "delivery_address_json"
            case lat
            case lng
            case quoteNote = "quote_note"
            case status
            case assignedDriverID = "assigned_driver_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct RouteRow: Decodable {
        let id: String
        let channelID: String
        let driverID: String
        let status: String
        let approximate: Bool
        let createdAt: Date
        let startedAt: Date?
        let completedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case driverID = "driver_id"
            case status
            case approximate
            case createdAt = "created_at"
            case startedAt = "started_at"
            case completedAt = "completed_at"
        }
    }

    private struct StopRow: Decodable {
        let id: String
        let routeID: String
        let orderID: String
        let stopIndex: Int
        let etaMinutes: Int?
        let completedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case routeID = "route_id"
            case orderID = "order_id"
            case stopIndex = "stop_index"
            case etaMinutes = "eta_minutes"
            case completedAt = "completed_at"
        }
    }

    private struct LedgerRow: Decodable {
        let id: String
        let orderID: String
        let actorID: String
        let eventType: String
        let payload: JSONValue
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case orderID = "order_id"
            case actorID = "actor_id"
            case eventType = "event_type"
            case payload = "event_payload_json"
            case createdAt = "created_at"
        }
    }

    private struct OrderLineItemRow: Decodable {
        let id: String
        let orderID: String
        let itemID: String?
        let variantID: String?
        let title: String
        let sku: String
        let quantity: Int
        let unitPriceCents: Int
        let lineTotalCents: Int
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case orderID = "order_id"
            case itemID = "item_id"
            case variantID = "variant_id"
            case title
            case sku
            case quantity
            case unitPriceCents = "unit_price_cents"
            case lineTotalCents = "line_total_cents"
            case createdAt = "created_at"
        }
    }

    private struct InventoryVariantRow: Decodable {
        let id: String
        let itemID: String
        let name: String
        let sku: String
        let priceCents: Int
        let stockOnHand: Int
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case itemID = "item_id"
            case name
            case sku
            case priceCents = "price_cents"
            case stockOnHand = "stock_on_hand"
            case isActive = "is_active"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct InventoryItemRow: Decodable {
        let id: String
        let channelID: String
        let name: String
        let sku: String
        let description: String
        let defaultPriceCents: Int
        let currencyCode: String
        let trackStock: Bool
        let stockOnHand: Int
        let lowStockThreshold: Int
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date
        let variants: [InventoryVariantRow]?

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case name
            case sku
            case description
            case defaultPriceCents = "default_price_cents"
            case currencyCode = "currency_code"
            case trackStock = "track_stock"
            case stockOnHand = "stock_on_hand"
            case lowStockThreshold = "low_stock_threshold"
            case isActive = "is_active"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case variants
        }
    }

    private struct InventoryStockRow: Decodable {
        let id: String
        let itemID: String
        let variantID: String?
        let delta: Int
        let balanceAfter: Int
        let reason: String
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case itemID = "item_id"
            case variantID = "variant_id"
            case delta
            case balanceAfter = "balance_after"
            case reason
            case createdAt = "created_at"
        }
    }

    private struct AdminAuditRow: Decodable {
        let id: String
        let channelID: String
        let actorID: String
        let action: String
        let targetType: String
        let targetID: String
        let reason: String?
        let payload: JSONValue
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case actorID = "actor_id"
            case action
            case targetType = "target_type"
            case targetID = "target_id"
            case reason
            case payload = "event_payload_json"
            case createdAt = "created_at"
        }
    }

    private struct CreateInviteResponse: Decodable {
        let id: String
        let channel_id: String
        let token: String
        let invite_url: String
        let expires_at: Date
        let max_uses: Int?
    }

    private struct JoinChannelResponse: Decodable {
        let channel_id: String
        let already_joined: Bool
    }

    private struct CreateOrderResponse: Decodable {
        let id: String
    }

    private struct BuildRouteResponse: Decodable {
        struct EmbeddedRoute: Decodable {
            let id: String
        }

        let route: EmbeddedRoute
    }

    private struct CompleteStopResponse: Decodable {
        let route_id: String
    }

    private struct ReorderStopsResponse: Decodable {
        let route_id: String
    }

    private struct InventoryCatalogResponse: Decodable {
        let channel_id: String
        let items: [InventoryItemRow]
        let ledger: [InventoryStockRow]
    }

    private struct InventoryAdjustResponse: Decodable {
        let item_id: String
        let variant_id: String?
        let delta: Int
        let balance_after: Int
    }

    private struct OrderLineItemsResponse: Decodable {
        let order_id: String
        let line_items: [OrderLineItemRow]
    }

    private struct AdminAuditEventsResponse: Decodable {
        let events: [AdminAuditRow]
    }

    private let client: SupabaseRESTClient
    private let sessionStore: SupabaseSessionStore
    private let analytics: AnalyticsServiceProtocol

    private var cachedSession: SessionUser?

    init(config: SupabaseConfig, analytics: AnalyticsServiceProtocol, sessionStore: SupabaseSessionStore = SupabaseSessionStore()) {
        self.client = SupabaseRESTClient(config: config)
        self.sessionStore = sessionStore
        self.analytics = analytics
    }

    // MARK: - Auth

    func requestOTP(phoneE164: String) async throws {
        try await client.requestOTP(phoneE164: phoneE164)
    }

    func verifyOTP(phoneE164: String, code: String) async throws -> SessionUser {
        let response = try await client.verifyOTP(phoneE164: phoneE164, code: code)
        sessionStore.save(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            userID: response.user.id,
            userPhone: response.user.phone
        )

        try await upsertProfile(
            userID: response.user.id,
            phoneE164: response.user.phone ?? phoneE164,
            displayName: nil,
            accessToken: response.access_token
        )

        let sessionUser = try await resolveSessionUser(
            userID: response.user.id,
            fallbackPhone: response.user.phone ?? phoneE164,
            accessToken: response.access_token
        )
        cachedSession = sessionUser
        analytics.track(event: "live_auth_verify", properties: ["role": sessionUser.role.rawValue])
        return sessionUser
    }

    func currentSession() async throws -> SessionUser? {
        if let cachedSession {
            return cachedSession
        }

        guard let accessToken = sessionStore.accessToken,
              let userID = sessionStore.userID else {
            return nil
        }

        do {
            let authUser = try await client.fetchAuthUser(accessToken: accessToken)
            let sessionUser = try await resolveSessionUser(
                userID: userID,
                fallbackPhone: authUser.phone ?? sessionStore.userPhone ?? "+10000000000",
                accessToken: accessToken
            )
            cachedSession = sessionUser
            return sessionUser
        } catch {
            sessionStore.clear()
            cachedSession = nil
            return nil
        }
    }

    func signOut() async {
        cachedSession = nil
        sessionStore.clear()
    }

    // MARK: - Channels

    func createChannel(ownerID: String, title: String, description: String) async throws -> Channel {
        let accessToken = try requireAccessToken()
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw SupabaseClientError.server(status: 400, message: "Channel title is required.")
        }

        let body: [String: Any] = [
            "owner_id": ownerID,
            "title": normalizedTitle,
            "description": description,
            "is_active": true,
        ]

        let data = try await client.restPost(
            pathAndQuery: "channels?select=id,title,description,is_active",
            body: body,
            accessToken: accessToken,
            prefer: "return=representation"
        )

        let rows = try decode([ChannelRow].self, from: data)
        guard let channel = rows.first else {
            throw SupabaseClientError.invalidResponse
        }

        _ = try await client.restPost(
            pathAndQuery: "channel_memberships?select=channel_id,user_id",
            body: [
                "channel_id": channel.id,
                "user_id": ownerID,
                "role": "owner",
            ],
            accessToken: accessToken,
            prefer: "return=representation"
        )

        return Channel(id: channel.id, title: channel.title, description: channel.description, isActive: channel.isActive)
    }

    func fetchChannels(userID: String) async throws -> [Channel] {
        let accessToken = try requireAccessToken()
        let memberships = try await fetchMemberships(userID: userID, accessToken: accessToken)
        let ids = memberships.map(\.channelID)
        guard !ids.isEmpty else { return [] }

        let query = "channels?select=id,title,description,is_active&id=in.\(inFilter(ids))&is_active=eq.true&order=created_at.desc"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([ChannelRow].self, from: data)

        return rows.map { row in
            Channel(id: row.id, title: row.title, description: row.description, isActive: row.isActive)
        }
    }

    func fetchPosts(channelID: String) async throws -> [ChannelPost] {
        let accessToken = try requireAccessToken()
        let query = "posts?select=id,channel_id,author_id,post_type,caption,media_path,created_at&channel_id=eq.\(escape(channelID))&archived_at=is.null&order=created_at.desc"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([PostRow].self, from: data)

        return rows.compactMap(mapPost)
    }

    func fetchDrivers(channelID: String) async throws -> [DriverProfile] {
        let accessToken = try requireAccessToken()
        let membershipQuery = "channel_memberships?select=user_id&channel_id=eq.\(escape(channelID))&role=eq.driver"
        let membershipData = try await client.restGet(pathAndQuery: membershipQuery, accessToken: accessToken)
        let membershipRows = try decode([[String: String]].self, from: membershipData)
        let userIDs = membershipRows.compactMap { $0["user_id"] }

        guard !userIDs.isEmpty else { return [] }

        let profilesQuery = "profiles?select=id,display_name&id=in.\(inFilter(userIDs))"
        let profilesData = try await client.restGet(pathAndQuery: profilesQuery, accessToken: accessToken)
        let profileRows = try decode([DriverProfileRow].self, from: profilesData)

        return profileRows
            .map { DriverProfile(id: $0.id, displayName: $0.displayName ?? "Driver") }
            .sorted(by: { $0.displayName < $1.displayName })
    }

    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?
    ) async throws -> ChannelPost {
        let accessToken = try requireAccessToken()
        let body: [String: Any?] = [
            "channel_id": channelID,
            "author_id": authorID,
            "post_type": postType.rawValue,
            "caption": caption,
            "media_path": mediaPath,
        ]

        let payload = sanitizeDictionary(body)
        let data = try await client.restPost(
            pathAndQuery: "posts?select=id,channel_id,author_id,post_type,caption,media_path,created_at",
            body: payload,
            accessToken: accessToken,
            prefer: "return=representation"
        )

        let rows = try decode([PostRow].self, from: data)
        guard let first = rows.first, let post = mapPost(first) else {
            throw SupabaseClientError.invalidResponse
        }

        return post
    }

    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?
    ) async throws -> ChannelInvite {
        let accessToken = try requireAccessToken()
        _ = ownerID

        let data: CreateInviteResponse = try await client.edgeCall(
            functionName: "create-invite",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "expires_in_hours": expiresInHours,
                "max_uses": maxUses as Any
            ]
        )

        return ChannelInvite(
            id: data.id,
            channelID: data.channel_id,
            token: data.token,
            inviteURL: data.invite_url,
            expiresAt: data.expires_at,
            maxUses: data.max_uses
        )
    }

    func joinChannel(token: String, userID: String) async throws -> Channel {
        let accessToken = try requireAccessToken()
        _ = userID

        let data: JoinChannelResponse = try await client.edgeCall(
            functionName: "join-channel",
            accessToken: accessToken,
            body: ["token": token]
        )

        return try await fetchChannelByID(data.channel_id, accessToken: accessToken)
    }

    // MARK: - Orders

    func createOrderRequest(
        channelID: String,
        postID: String,
        customerID: String,
        customerPhone: String,
        deliveryAddress: DeliveryAddress,
        quoteNote: String
    ) async throws -> OrderRequest {
        let accessToken = try requireAccessToken()
        _ = customerID
        _ = customerPhone

        let payload: [String: Any] = [
            "channel_id": channelID,
            "post_id": postID,
            "quote_note": quoteNote,
            "delivery_address": [
                "line1": deliveryAddress.line1,
                "line2": deliveryAddress.line2,
                "city": deliveryAddress.city,
                "state": deliveryAddress.state,
                "postal_code": deliveryAddress.postalCode,
                "country": deliveryAddress.country,
            ]
        ]

        let data: CreateOrderResponse = try await client.edgeCall(
            functionName: "create-order-request",
            accessToken: accessToken,
            body: payload
        )

        return try await fetchOrderByID(data.id, accessToken: accessToken)
    }

    func fetchOrders(userID: String, role: UserRole) async throws -> [OrderRequest] {
        let accessToken = try requireAccessToken()
        let query: String

        switch role {
        case .owner:
            let ownerChannels = try await fetchOwnedChannelIDs(userID: userID, accessToken: accessToken)
            guard !ownerChannels.isEmpty else { return [] }
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,created_at,updated_at&channel_id=in.\(inFilter(ownerChannels))&order=updated_at.desc"
        case .driver:
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,created_at,updated_at&assigned_driver_id=eq.\(escape(userID))&order=updated_at.desc"
        case .follower:
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,created_at,updated_at&customer_id=eq.\(escape(userID))&order=updated_at.desc"
        }

        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([OrderRow].self, from: data)
        return rows.compactMap(mapOrder)
    }

    func fetchLedgerEvents(orderID: String, userID: String, role: UserRole) async throws -> [OrderLedgerEvent] {
        _ = userID
        _ = role

        let accessToken = try requireAccessToken()
        let query = "order_ledger_events?select=id,order_id,actor_id,event_type,event_payload_json,created_at&order_id=eq.\(escape(orderID))&order=created_at.asc"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([LedgerRow].self, from: data)

        return rows.map { row in
            OrderLedgerEvent(
                id: row.id,
                orderID: row.orderID,
                actorID: row.actorID,
                eventType: row.eventType,
                payloadSummary: row.payload.summary,
                createdAt: row.createdAt
            )
        }
    }

    func updateOrderStatus(orderID: String, status: OrderStatus, quoteNote: String?, actorID: String) async throws -> OrderRequest {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any?] = [
            "order_id": orderID,
            "status": status.rawValue,
            "quote_note": quoteNote,
        ]

        _ = try await client.edgeCall(
            functionName: "update-order-status",
            accessToken: accessToken,
            body: sanitizeDictionary(body)
        ) as [String: String]

        return try await fetchOrderByID(orderID, accessToken: accessToken)
    }

    func assignDriver(orderID: String, driverID: String, actorID: String) async throws -> OrderRequest {
        let accessToken = try requireAccessToken()
        _ = actorID

        _ = try await client.edgeCall(
            functionName: "assign-driver",
            accessToken: accessToken,
            body: [
                "order_id": orderID,
                "driver_id": driverID,
            ]
        ) as [String: String]

        return try await fetchOrderByID(orderID, accessToken: accessToken)
    }

    func upsertOrderLineItems(orderID: String, lineItems: [OrderLineItemInput], actorID: String) async throws -> [OrderLineItem] {
        let accessToken = try requireAccessToken()
        _ = actorID

        let payloadLineItems = lineItems.map { item in
            [
                "item_id": item.itemID as Any,
                "variant_id": item.variantID as Any,
                "title": item.title,
                "sku": item.sku,
                "quantity": item.quantity,
                "unit_price_cents": item.unitPriceCents,
            ]
        }

        let data: OrderLineItemsResponse = try await client.edgeCall(
            functionName: "order-upsert-line-items",
            accessToken: accessToken,
            body: [
                "order_id": orderID,
                "line_items": payloadLineItems
            ]
        )

        _ = data.order_id
        return data.line_items.map(mapOrderLineItem)
    }

    // MARK: - Inventory

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
    ) async throws -> InventoryItem {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any?] = [
            "channel_id": channelID,
            "item_id": itemID,
            "name": name,
            "sku": sku,
            "description": description,
            "default_price_cents": defaultPriceCents,
            "currency_code": currencyCode,
            "track_stock": trackStock,
            "stock_on_hand": stockOnHand,
            "low_stock_threshold": lowStockThreshold,
        ]

        let row: InventoryItemRow = try await client.edgeCall(
            functionName: "inventory-upsert-item",
            accessToken: accessToken,
            body: sanitizeDictionary(body)
        )

        return mapInventoryItem(row)
    }

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
    ) async throws -> InventoryVariant {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any?] = [
            "channel_id": channelID,
            "item_id": itemID,
            "variant_id": variantID,
            "name": name,
            "sku": sku,
            "price_cents": priceCents,
            "stock_on_hand": stockOnHand,
            "is_active": isActive,
        ]

        let row: InventoryVariantRow = try await client.edgeCall(
            functionName: "inventory-upsert-variant",
            accessToken: accessToken,
            body: sanitizeDictionary(body)
        )

        return mapInventoryVariant(row)
    }

    func adjustInventoryStock(
        channelID: String,
        itemID: String,
        variantID: String?,
        delta: Int,
        reason: String,
        actorID: String
    ) async throws -> InventoryStockEvent {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any?] = [
            "channel_id": channelID,
            "item_id": itemID,
            "variant_id": variantID,
            "delta": delta,
            "reason": reason,
        ]

        let row: InventoryStockRow = try await client.edgeCall(
            functionName: "inventory-adjust-stock",
            accessToken: accessToken,
            body: sanitizeDictionary(body)
        )

        return mapInventoryStock(row)
    }

    func fetchInventoryCatalog(channelID: String, includeInactive: Bool, includeLedger: Bool, actorID: String) async throws -> InventoryCatalog {
        let accessToken = try requireAccessToken()
        _ = actorID

        let data: InventoryCatalogResponse = try await client.edgeCall(
            functionName: "inventory-list",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "include_inactive": includeInactive,
                "include_ledger": includeLedger,
            ]
        )

        let items = data.items.map(mapInventoryItem)
        let ledger = data.ledger.map(mapInventoryStock)
        return InventoryCatalog(channelID: data.channel_id, items: items, ledger: ledger)
    }

    // MARK: - Admin

    func archiveChannel(channelID: String, reason: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()
        _ = actorID

        _ = try await client.edgeCall(
            functionName: "admin-archive-channel",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "reason": reason,
            ]
        ) as [String: JSONValue]
    }

    func deleteOrder(orderID: String, mode: AdminDeleteMode, reason: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any] = [
            "order_id": orderID,
            "reason": reason,
            "hard_delete": mode == .hardDelete,
        ]

        _ = try await client.edgeCall(
            functionName: "admin-delete-order",
            accessToken: accessToken,
            body: body
        ) as [String: JSONValue]
    }

    func unassignDriver(orderID: String, reason: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()
        _ = actorID

        _ = try await client.edgeCall(
            functionName: "admin-unassign-driver",
            accessToken: accessToken,
            body: [
                "order_id": orderID,
                "reason": reason,
            ]
        ) as [String: JSONValue]
    }

    func upsertDriverMembership(channelID: String, driverUserID: String, operation: DriverMembershipOperation, reason: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()
        _ = actorID

        _ = try await client.edgeCall(
            functionName: "admin-driver-memberships-upsert",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "driver_user_id": driverUserID,
                "operation": operation.rawValue,
                "reason": reason,
            ]
        ) as [String: JSONValue]
    }

    func fetchAdminAuditEvents(channelID: String, action: String?, limit: Int, actorID: String) async throws -> [AdminAuditEvent] {
        let accessToken = try requireAccessToken()
        _ = actorID

        let body: [String: Any?] = [
            "channel_id": channelID,
            "action": action,
            "limit": limit,
        ]

        let data: AdminAuditEventsResponse = try await client.edgeCall(
            functionName: "admin-audit-events-list",
            accessToken: accessToken,
            body: sanitizeDictionary(body)
        )

        return data.events.map(mapAdminAudit)
    }

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

    // MARK: - Helpers

    private func requireAccessToken() throws -> String {
        guard let token = sessionStore.accessToken else {
            throw SupabaseClientError.missingSession
        }
        return token
    }

    private func resolveSessionUser(userID: String, fallbackPhone: String, accessToken: String) async throws -> SessionUser {
        let memberships = try await fetchMemberships(userID: userID, accessToken: accessToken)
        let role: UserRole
        if memberships.contains(where: { $0.role == "owner" }) {
            role = .owner
        } else if memberships.contains(where: { $0.role == "driver" }) {
            role = .driver
        } else {
            role = .follower
        }

        let profile = try await fetchProfile(userID: userID, accessToken: accessToken)

        return SessionUser(
            id: userID,
            phoneE164: profile?.phoneE164 ?? fallbackPhone,
            displayName: profile?.displayName ?? role.rawValue.capitalized,
            role: role
        )
    }

    private func upsertProfile(userID: String, phoneE164: String, displayName: String?, accessToken: String) async throws {
        let body = [[
            "id": userID,
            "phone_e164": phoneE164,
            "display_name": displayName ?? "",
        ]]

        _ = try await client.restPost(
            pathAndQuery: "profiles?on_conflict=id&select=id,phone_e164,display_name",
            body: body,
            accessToken: accessToken,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    private func fetchProfile(userID: String, accessToken: String) async throws -> ProfileRow? {
        let query = "profiles?select=id,phone_e164,display_name&id=eq.\(escape(userID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        return try decode([ProfileRow].self, from: data).first
    }

    private func fetchMemberships(userID: String, accessToken: String) async throws -> [MembershipRow] {
        let query = "channel_memberships?select=channel_id,role&user_id=eq.\(escape(userID))"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        return try decode([MembershipRow].self, from: data)
    }

    private func fetchOwnedChannelIDs(userID: String, accessToken: String) async throws -> [String] {
        let query = "channels?select=id&owner_id=eq.\(escape(userID))&is_active=eq.true"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([[String: String]].self, from: data)
        return rows.compactMap { $0["id"] }
    }

    private func fetchChannelByID(_ channelID: String, accessToken: String) async throws -> Channel {
        let query = "channels?select=id,title,description,is_active&id=eq.\(escape(channelID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([ChannelRow].self, from: data)
        guard let row = rows.first else {
            throw SupabaseClientError.invalidResponse
        }

        return Channel(id: row.id, title: row.title, description: row.description, isActive: row.isActive)
    }

    private func fetchOrderByID(_ orderID: String, accessToken: String) async throws -> OrderRequest {
        let query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,created_at,updated_at&id=eq.\(escape(orderID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([OrderRow].self, from: data)
        guard let first = rows.first, let order = mapOrder(first) else {
            throw SupabaseClientError.invalidResponse
        }
        return order
    }

    private func fetchRouteByID(_ routeID: String, accessToken: String) async throws -> DeliveryRoute {
        let routeQuery = "delivery_routes?select=id,channel_id,driver_id,status,approximate,created_at,started_at,completed_at&id=eq.\(escape(routeID))&limit=1"
        let routeData = try await client.restGet(pathAndQuery: routeQuery, accessToken: accessToken)
        let routeRows = try decode([RouteRow].self, from: routeData)
        guard let routeRow = routeRows.first else {
            throw SupabaseClientError.invalidResponse
        }

        let routes = try await hydrateRoutes(routeRows: [routeRow], accessToken: accessToken)
        guard let first = routes.first else {
            throw SupabaseClientError.invalidResponse
        }
        return first
    }

    private func hydrateRoutes(routeRows: [RouteRow], accessToken: String) async throws -> [DeliveryRoute] {
        guard !routeRows.isEmpty else { return [] }

        let routeIDs = routeRows.map(\.id)
        let stopQuery = "delivery_route_stops?select=id,route_id,order_id,stop_index,eta_minutes,completed_at&route_id=in.\(inFilter(routeIDs))&order=stop_index.asc"
        let stopData = try await client.restGet(pathAndQuery: stopQuery, accessToken: accessToken)
        let stopRows = try decode([StopRow].self, from: stopData)

        let groupedStops = Dictionary(grouping: stopRows, by: \.routeID)

        return routeRows.map { row in
            let stops = (groupedStops[row.id] ?? []).map { stopRow in
                RouteStop(
                    id: stopRow.id,
                    orderID: stopRow.orderID,
                    stopIndex: stopRow.stopIndex,
                    etaMinutes: stopRow.etaMinutes,
                    completedAt: stopRow.completedAt
                )
            }

            return DeliveryRoute(
                id: row.id,
                channelID: row.channelID,
                driverID: row.driverID,
                status: mapRouteStatus(row.status),
                approximate: row.approximate,
                createdAt: row.createdAt,
                startedAt: row.startedAt,
                completedAt: row.completedAt,
                stops: stops
            )
        }
        .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func mapPost(_ row: PostRow) -> ChannelPost? {
        guard let type = PostType(rawValue: row.postType) else { return nil }
        return ChannelPost(
            id: row.id,
            channelID: row.channelID,
            authorID: row.authorID,
            postType: type,
            caption: row.caption ?? "",
            mediaPath: row.mediaPath,
            createdAt: row.createdAt
        )
    }

    private func mapOrder(_ row: OrderRow) -> OrderRequest? {
        guard let status = OrderStatus(rawValue: row.status) else { return nil }

        let address = DeliveryAddress(
            line1: row.deliveryAddress.line1,
            line2: row.deliveryAddress.line2 ?? "",
            city: row.deliveryAddress.city,
            state: row.deliveryAddress.state,
            postalCode: row.deliveryAddress.postalCode,
            country: row.deliveryAddress.country ?? "US"
        )

        return OrderRequest(
            id: row.id,
            channelID: row.channelID,
            postID: row.postID,
            customerID: row.customerID,
            customerPhone: row.customerPhone,
            deliveryAddress: address,
            lat: row.lat,
            lng: row.lng,
            quoteNote: row.quoteNote ?? "",
            status: status,
            assignedDriverID: row.assignedDriverID,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    private func mapOrderLineItem(_ row: OrderLineItemRow) -> OrderLineItem {
        OrderLineItem(
            id: row.id,
            orderID: row.orderID,
            itemID: row.itemID,
            variantID: row.variantID,
            title: row.title,
            sku: row.sku,
            quantity: row.quantity,
            unitPriceCents: row.unitPriceCents,
            lineTotalCents: row.lineTotalCents,
            createdAt: row.createdAt
        )
    }

    private func mapInventoryVariant(_ row: InventoryVariantRow) -> InventoryVariant {
        InventoryVariant(
            id: row.id,
            itemID: row.itemID,
            name: row.name,
            sku: row.sku,
            priceCents: row.priceCents,
            stockOnHand: row.stockOnHand,
            isActive: row.isActive,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    private func mapInventoryItem(_ row: InventoryItemRow) -> InventoryItem {
        InventoryItem(
            id: row.id,
            channelID: row.channelID,
            name: row.name,
            sku: row.sku,
            description: row.description,
            defaultPriceCents: row.defaultPriceCents,
            currencyCode: row.currencyCode,
            trackStock: row.trackStock,
            stockOnHand: row.stockOnHand,
            lowStockThreshold: row.lowStockThreshold,
            isActive: row.isActive,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            variants: (row.variants ?? []).map(mapInventoryVariant)
        )
    }

    private func mapInventoryStock(_ row: InventoryStockRow) -> InventoryStockEvent {
        InventoryStockEvent(
            id: row.id,
            itemID: row.itemID,
            variantID: row.variantID,
            delta: row.delta,
            balanceAfter: row.balanceAfter,
            reason: row.reason,
            createdAt: row.createdAt
        )
    }

    private func mapAdminAudit(_ row: AdminAuditRow) -> AdminAuditEvent {
        AdminAuditEvent(
            id: row.id,
            channelID: row.channelID,
            actorID: row.actorID,
            action: row.action,
            targetType: row.targetType,
            targetID: row.targetID,
            reason: row.reason,
            payloadSummary: row.payload.summary,
            createdAt: row.createdAt
        )
    }

    private func mapRouteStatus(_ value: String) -> RouteStatus {
        RouteStatus(rawValue: value) ?? .planned
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.supabase.decode(T.self, from: data)
        } catch {
            throw SupabaseClientError.decoding(error)
        }
    }

    private func inFilter(_ ids: [String]) -> String {
        "(\(ids.map(escape).joined(separator: ",")))"
    }

    private func escape(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: .supabaseFilterAllowed) ?? raw
    }

    private func sanitizeDictionary(_ value: [String: Any?]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, entry in
            if let unwrapped = entry.value {
                partial[entry.key] = unwrapped
            }
        }
    }
}

private extension CharacterSet {
    static let supabaseFilterAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=?+")
        return set
    }()
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.withoutFractional.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private enum JSONValue: Decodable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown JSONValue")
        }
    }

    var summary: String {
        switch self {
        case let .object(object):
            if object.isEmpty { return "{}" }
            return object.map { "\($0.key): \($0.value.summary)" }.sorted().joined(separator: ", ")
        case let .array(array):
            if array.isEmpty { return "[]" }
            return array.map(\.summary).joined(separator: ", ")
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }
}
