import Foundation
import BoppyV2Core

actor SessionStateActor {
    private var cachedSession: SessionUser?

    func read() -> SessionUser? {
        cachedSession
    }

    func write(_ session: SessionUser?) {
        cachedSession = session
    }
}

final class LiveSupabaseBackend: AuthServiceProtocol, ChannelFeedServiceProtocol, OrderServiceProtocol, DispatchServiceProtocol, InventoryServiceProtocol, AdminServiceProtocol {
    struct MembershipRow: Decodable {
        let channelID: String
        let role: String

        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case role
        }
    }

    struct ChannelRow: Decodable {
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

    struct ProfileRow: Decodable {
        let id: String
        let phoneE164: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case phoneE164 = "phone_e164"
            case displayName = "display_name"
        }
    }

    struct DriverProfileRow: Decodable {
        let id: String
        let displayName: String?
        let avatarURL: String?
        let availability: String?
        let rating: Double?
        let tripCount: Int?
        let lastLat: Double?
        let lastLng: Double?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarURL = "avatar_url"
            case availability = "driver_availability"
            case rating = "driver_rating"
            case tripCount = "driver_trip_count"
            case lastLat = "last_lat"
            case lastLng = "last_lng"
        }
    }

    struct PostRow: Decodable {
        let id: String
        let channelID: String
        let authorID: String
        let postType: String
        let caption: String?
        let mediaPath: String?
        let slotRemaining: Int?
        let slotLabel: String?
        let heroSubtitle: String?
        let heroAspectRatio: Double?
        let priceCents: Int?
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case channelID = "channel_id"
            case authorID = "author_id"
            case postType = "post_type"
            case caption
            case mediaPath = "media_path"
            case slotRemaining = "slot_remaining"
            case slotLabel = "slot_label"
            case heroSubtitle = "hero_subtitle"
            case heroAspectRatio = "hero_aspect_ratio"
            case priceCents = "price_cents"
            case createdAt = "created_at"
        }
    }

    struct DeliveryAddressRow: Decodable {
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

    struct OrderRow: Decodable {
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
        let externalRef: String?
        let summaryTitle: String?
        let summaryImageURL: String?
        let summaryTotalCents: Int?
        let summaryEtaText: String?
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
            case externalRef = "external_ref"
            case summaryTitle = "summary_title"
            case summaryImageURL = "summary_image_url"
            case summaryTotalCents = "summary_total_cents"
            case summaryEtaText = "summary_eta_text"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    struct RouteRow: Decodable {
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

    struct StopRow: Decodable {
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

    struct LedgerRow: Decodable {
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

    struct OrderLineItemRow: Decodable {
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

    struct InventoryVariantRow: Decodable {
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

    struct InventoryItemRow: Decodable {
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
        let thumbnailURL: String?
        let category: String?
        let activeOrderCount: Int?
        let showInCatalog: Bool?
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
            case thumbnailURL = "thumbnail_url"
            case category
            case activeOrderCount = "active_order_count"
            case showInCatalog = "show_in_catalog"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case variants
        }
    }

    struct InventoryStockRow: Decodable {
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

    struct AdminAuditRow: Decodable {
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

    struct CreateInviteResponse: Decodable {
        let id: String
        let channel_id: String
        let token: String
        let invite_url: String
        let expires_at: Date
        let max_uses: Int?
    }

    struct JoinChannelResponse: Decodable {
        let channel_id: String
        let already_joined: Bool
    }

    struct CreateOrderResponse: Decodable {
        let id: String
    }

    struct BuildRouteResponse: Decodable {
        struct EmbeddedRoute: Decodable {
            let id: String
        }

        let route: EmbeddedRoute
    }

    struct CompleteStopResponse: Decodable {
        let route_id: String
    }

    struct ReorderStopsResponse: Decodable {
        let route_id: String
    }

    struct InventoryCatalogResponse: Decodable {
        let channel_id: String
        let items: [InventoryItemRow]
        let ledger: [InventoryStockRow]
    }

    struct InventoryAdjustResponse: Decodable {
        let item_id: String
        let variant_id: String?
        let delta: Int
        let balance_after: Int
    }

    struct OrderLineItemsResponse: Decodable {
        let order_id: String
        let line_items: [OrderLineItemRow]
    }

    struct AdminAuditEventsResponse: Decodable {
        let events: [AdminAuditRow]
    }

    let client: SupabaseRESTClient
    let sessionStore: SessionTokenStore
    let analytics: AnalyticsServiceProtocol
    let sessionState = SessionStateActor()

    init(config: SupabaseConfig, analytics: AnalyticsServiceProtocol, sessionStore: SessionTokenStore = MigratingSessionTokenStore()) {
        self.sessionStore = sessionStore
        self.client = SupabaseRESTClient(config: config, tokenStore: sessionStore)
        self.analytics = analytics
        self.sessionStore.migrateFromLegacyStoreIfNeeded()
    }

    // MARK: - Helpers

    func requireAccessToken() throws -> String {
        guard let token = sessionStore.readTokens()?.accessToken else {
            throw SupabaseClientError.missingSession
        }
        return token
    }

    func resolveSessionUser(userID: String, fallbackPhone: String, accessToken: String) async throws -> SessionUser {
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

    func upsertProfile(userID: String, phoneE164: String, displayName: String?, accessToken: String) async throws {
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

    func fetchProfile(userID: String, accessToken: String) async throws -> ProfileRow? {
        let query = "profiles?select=id,phone_e164,display_name&id=eq.\(escape(userID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        return try decode([ProfileRow].self, from: data).first
    }

    func fetchMemberships(userID: String, accessToken: String) async throws -> [MembershipRow] {
        let query = "channel_memberships?select=channel_id,role&user_id=eq.\(escape(userID))"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        return try decode([MembershipRow].self, from: data)
    }

    func fetchOwnedChannelIDs(userID: String, accessToken: String) async throws -> [String] {
        let query = "channels?select=id&owner_id=eq.\(escape(userID))&is_active=eq.true"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([[String: String]].self, from: data)
        return rows.compactMap { $0["id"] }
    }

    func fetchChannelByID(_ channelID: String, accessToken: String) async throws -> Channel {
        let query = "channels?select=id,title,description,is_active&id=eq.\(escape(channelID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([ChannelRow].self, from: data)
        guard let row = rows.first else {
            throw SupabaseClientError.invalidResponse
        }

        return Channel(id: row.id, title: row.title, description: row.description, isActive: row.isActive)
    }

    func fetchOrderByID(_ orderID: String, accessToken: String) async throws -> OrderRequest {
        let query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,external_ref,summary_title,summary_image_url,summary_total_cents,summary_eta_text,created_at,updated_at&id=eq.\(escape(orderID))&limit=1"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([OrderRow].self, from: data)
        guard let first = rows.first, let order = mapOrder(first) else {
            throw SupabaseClientError.invalidResponse
        }
        return order
    }

    func fetchRouteByID(_ routeID: String, accessToken: String) async throws -> DeliveryRoute {
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

    func hydrateRoutes(routeRows: [RouteRow], accessToken: String) async throws -> [DeliveryRoute] {
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

    func mapPost(_ row: PostRow) -> ChannelPost? {
        guard let type = PostType(rawValue: row.postType) else { return nil }
        return ChannelPost(
            id: row.id,
            channelID: row.channelID,
            authorID: row.authorID,
            postType: type,
            caption: row.caption ?? "",
            mediaPath: row.mediaPath,
            slotRemaining: row.slotRemaining,
            slotLabel: row.slotLabel,
            heroSubtitle: row.heroSubtitle,
            heroAspectRatio: row.heroAspectRatio,
            priceCents: row.priceCents,
            createdAt: row.createdAt
        )
    }

    func mapOrder(_ row: OrderRow) -> OrderRequest? {
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
            externalRef: row.externalRef,
            summaryTitle: row.summaryTitle,
            summaryImageURL: row.summaryImageURL,
            summaryTotalCents: row.summaryTotalCents,
            summaryEtaText: row.summaryEtaText,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    func mapOrderLineItem(_ row: OrderLineItemRow) -> OrderLineItem {
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

    func mapInventoryVariant(_ row: InventoryVariantRow) -> InventoryVariant {
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

    func mapInventoryItem(_ row: InventoryItemRow) -> InventoryItem {
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
            thumbnailURL: row.thumbnailURL,
            category: row.category,
            activeOrderCount: row.activeOrderCount,
            showInCatalog: row.showInCatalog,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            variants: (row.variants ?? []).map(mapInventoryVariant)
        )
    }

    func mapInventoryStock(_ row: InventoryStockRow) -> InventoryStockEvent {
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

    func mapAdminAudit(_ row: AdminAuditRow) -> AdminAuditEvent {
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

    func mapRouteStatus(_ value: String) -> RouteStatus {
        RouteStatus(rawValue: value) ?? .planned
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.supabase.decode(T.self, from: data)
        } catch {
            throw SupabaseClientError.decoding(error)
        }
    }

    func inFilter(_ ids: [String]) -> String {
        "(\(ids.map(escape).joined(separator: ",")))"
    }

    func escape(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: .supabaseFilterAllowed) ?? raw
    }

    func sanitizeDictionary(_ value: [String: Any?]) -> [String: Any] {
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

enum JSONValue: Decodable {
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
