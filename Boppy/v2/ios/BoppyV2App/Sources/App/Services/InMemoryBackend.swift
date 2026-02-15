import Foundation
import BoppyV2Core

private struct InviteRecord {
    var id: String
    var channelID: String
    var token: String
    var expiresAt: Date
    var maxUses: Int?
    var usesCount: Int
}

private struct Membership {
    var channelID: String
    var userID: String
    var role: UserRole
}

private struct InventoryItemRecord {
    var id: String
    var channelID: String
    var ownerID: String
    var name: String
    var sku: String
    var description: String
    var defaultPriceCents: Int
    var currencyCode: String
    var trackStock: Bool
    var stockOnHand: Int
    var lowStockThreshold: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

private struct InventoryVariantRecord {
    var id: String
    var itemID: String
    var name: String
    var sku: String
    var priceCents: Int
    var stockOnHand: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum InMemoryBackendError: LocalizedError {
    case invalidOTP
    case invalidInput(String)
    case permissionDenied
    case channelNotFound
    case inviteInvalid
    case orderNotFound
    case routeNotFound
    case stopNotFound
    case inventoryItemNotFound
    case inventoryVariantNotFound

    var errorDescription: String? {
        switch self {
        case .invalidOTP:
            return "Invalid OTP code."
        case let .invalidInput(message):
            return message
        case .permissionDenied:
            return "Permission denied for this operation."
        case .channelNotFound:
            return "Channel not found."
        case .inviteInvalid:
            return "Invite is invalid or expired."
        case .orderNotFound:
            return "Order not found."
        case .routeNotFound:
            return "Route not found."
        case .stopNotFound:
            return "Stop not found."
        case .inventoryItemNotFound:
            return "Inventory item not found."
        case .inventoryVariantNotFound:
            return "Inventory variant not found."
        }
    }
}

final class InMemoryBackend: AuthServiceProtocol, ChannelFeedServiceProtocol, OrderServiceProtocol, DispatchServiceProtocol, InventoryServiceProtocol, AdminServiceProtocol {
    private let owner = SessionUser(id: "owner-1", phoneE164: "+15550000001", displayName: "Owner", role: .owner)
    private let driver = SessionUser(id: "driver-1", phoneE164: "+15550000002", displayName: "Driver", role: .driver)

    private var usersByPhone: [String: SessionUser] = [:]
    private var otpByPhone: [String: String] = [:]
    private var session: SessionUser?

    private var channels: [Channel] = []
    private var postsByChannel: [String: [ChannelPost]] = [:]
    private var orders: [OrderRequest] = []
    private var routes: [DeliveryRoute] = []
    private var memberships: [Membership] = []
    private var invitesByToken: [String: InviteRecord] = [:]
    private var ledgerByOrderID: [String: [OrderLedgerEvent]] = [:]
    private var orderLineItemsByOrderID: [String: [OrderLineItem]] = [:]
    private var inventoryItems: [InventoryItemRecord] = []
    private var inventoryVariants: [InventoryVariantRecord] = []
    private var inventoryStockLedger: [InventoryStockEvent] = []
    private var adminAuditEvents: [AdminAuditEvent] = []

    init() {
        usersByPhone[owner.phoneE164] = owner
        usersByPhone[driver.phoneE164] = driver

        channels = [
            Channel(id: "channel-main", title: "Main Gallery", description: "Owner-only channel posts for latest art drops."),
            Channel(id: "channel-limited", title: "Limited Drops", description: "Invite-only limited edition releases.")
        ]

        memberships = [
            Membership(channelID: "channel-main", userID: owner.id, role: .owner),
            Membership(channelID: "channel-limited", userID: owner.id, role: .owner),
            Membership(channelID: "channel-main", userID: driver.id, role: .driver),
            Membership(channelID: "channel-limited", userID: driver.id, role: .driver)
        ]

        postsByChannel["channel-main"] = [
            ChannelPost(id: "post-1", channelID: "channel-main", authorID: owner.id, postType: .image, caption: "Sunset Canvas #18", mediaPath: "https://example.com/art1.jpg"),
            ChannelPost(id: "post-2", channelID: "channel-main", authorID: owner.id, postType: .video, caption: "Studio walkthrough", mediaPath: "https://example.com/studio.mp4")
        ]

        postsByChannel["channel-limited"] = [
            ChannelPost(id: "post-3", channelID: "channel-limited", authorID: owner.id, postType: .text, caption: "Limited release opens Friday 8PM.", mediaPath: nil)
        ]

        let seedItem = InventoryItemRecord(
            id: "item-1",
            channelID: "channel-main",
            ownerID: owner.id,
            name: "Premium Canvas",
            sku: "CANVAS-001",
            description: "A-grade canvas stock",
            defaultPriceCents: 12000,
            currencyCode: "USD",
            trackStock: true,
            stockOnHand: 25,
            lowStockThreshold: 5,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        inventoryItems = [seedItem]
    }

    // MARK: - Auth

    func requestOTP(phoneE164: String) async throws {
        otpByPhone[phoneE164] = "123456"
    }

    func verifyOTP(phoneE164: String, code: String) async throws -> SessionUser {
        guard otpByPhone[phoneE164] == code else {
            throw InMemoryBackendError.invalidOTP
        }

        if let existing = usersByPhone[phoneE164] {
            session = existing
            return existing
        }

        let generated = SessionUser(
            id: "follower-\(UUID().uuidString.prefix(8))",
            phoneE164: phoneE164,
            displayName: "Follower",
            role: .follower
        )
        usersByPhone[phoneE164] = generated
        session = generated
        return generated
    }

    func currentSession() async throws -> SessionUser? {
        session
    }

    func signOut() async {
        session = nil
    }

    // MARK: - Channels

    func createChannel(ownerID: String, title: String, description: String) async throws -> Channel {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InMemoryBackendError.invalidInput("Channel title is required.")
        }

        guard ownerID == owner.id else {
            throw InMemoryBackendError.permissionDenied
        }

        let channel = Channel(
            id: "channel-\(UUID().uuidString.prefix(8))",
            title: title,
            description: description
        )
        channels.insert(channel, at: 0)

        if role(for: ownerID, in: channel.id) == nil {
            memberships.append(Membership(channelID: channel.id, userID: ownerID, role: .owner))
        }

        postsByChannel[channel.id] = []
        return channel
    }

    func fetchChannels(userID: String) async throws -> [Channel] {
        let channelIDs = Set(memberships.filter { $0.userID == userID }.map(\.channelID))
        return channels.filter { channelIDs.contains($0.id) && $0.isActive }
    }

    func fetchPosts(channelID: String) async throws -> [ChannelPost] {
        (postsByChannel[channelID] ?? []).sorted(by: { $0.createdAt > $1.createdAt })
    }

    func fetchDrivers(channelID: String) async throws -> [DriverProfile] {
        let driverIDs = memberships
            .filter { $0.channelID == channelID && $0.role == .driver }
            .map(\.userID)

        return usersByPhone.values
            .filter { driverIDs.contains($0.id) }
            .map { DriverProfile(id: $0.id, displayName: $0.displayName) }
            .sorted(by: { $0.displayName < $1.displayName })
    }

    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?
    ) async throws -> ChannelPost {
        guard role(for: authorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let post = ChannelPost(
            id: "post-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            authorID: authorID,
            postType: postType,
            caption: caption,
            mediaPath: mediaPath
        )

        postsByChannel[channelID, default: []].insert(post, at: 0)
        return post
    }

    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?
    ) async throws -> ChannelInvite {
        guard role(for: ownerID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        guard channels.contains(where: { $0.id == channelID }) else {
            throw InMemoryBackendError.channelNotFound
        }

        let token = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresInHours) * 3600)
        let record = InviteRecord(
            id: "invite-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            token: token,
            expiresAt: expiresAt,
            maxUses: maxUses,
            usesCount: 0
        )
        invitesByToken[token] = record

        return ChannelInvite(
            id: record.id,
            channelID: channelID,
            token: token,
            inviteURL: "boppyv2://invite/\(token)",
            expiresAt: expiresAt,
            maxUses: maxUses
        )
    }

    func joinChannel(token: String, userID: String) async throws -> Channel {
        guard var invite = invitesByToken[token], invite.expiresAt > Date() else {
            throw InMemoryBackendError.inviteInvalid
        }
        if let maxUses = invite.maxUses, invite.usesCount >= maxUses {
            throw InMemoryBackendError.inviteInvalid
        }

        guard let channel = channels.first(where: { $0.id == invite.channelID }) else {
            throw InMemoryBackendError.channelNotFound
        }

        if role(for: userID, in: channel.id) == nil {
            memberships.append(Membership(channelID: channel.id, userID: userID, role: .follower))
        }

        invite.usesCount += 1
        invitesByToken[token] = invite
        return channel
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
        guard role(for: customerID, in: channelID) == .follower else {
            throw InMemoryBackendError.permissionDenied
        }

        let geocodeFailed = deliveryAddress.postalCode.hasPrefix("000")
        let request = OrderRequest(
            id: "order-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            postID: postID,
            customerID: customerID,
            customerPhone: customerPhone,
            deliveryAddress: deliveryAddress,
            lat: geocodeFailed ? nil : 30.2672,
            lng: geocodeFailed ? nil : -97.7431,
            quoteNote: quoteNote,
            status: geocodeFailed ? .addressReview : .requested,
            assignedDriverID: nil
        )

        orders.insert(request, at: 0)
        appendLedger(
            orderID: request.id,
            actorID: customerID,
            eventType: geocodeFailed ? "address_geocode_failed" : "order_requested",
            payloadSummary: geocodeFailed ? "No coordinate match; requires review" : "Request submitted"
        )
        return request
    }

    func fetchOrders(userID: String, role: UserRole) async throws -> [OrderRequest] {
        let result: [OrderRequest]
        switch role {
        case .owner:
            let ownedChannels = Set(memberships.filter { $0.userID == userID && $0.role == .owner }.map(\.channelID))
            result = orders.filter { ownedChannels.contains($0.channelID) }
        case .driver:
            result = orders.filter { $0.assignedDriverID == userID }
        case .follower:
            result = orders.filter { $0.customerID == userID }
        }

        return result.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func fetchLedgerEvents(orderID: String, userID: String, role: UserRole) async throws -> [OrderLedgerEvent] {
        guard let order = orders.first(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }

        let allowed: Bool
        switch role {
        case .owner:
            allowed = self.role(for: userID, in: order.channelID) == .owner
        case .driver:
            allowed = order.assignedDriverID == userID
        case .follower:
            allowed = order.customerID == userID
        }

        guard allowed else {
            throw InMemoryBackendError.permissionDenied
        }

        return (ledgerByOrderID[orderID] ?? []).sorted(by: { $0.createdAt < $1.createdAt })
    }

    func upsertOrderLineItems(orderID: String, lineItems: [OrderLineItemInput], actorID: String) async throws -> [OrderLineItem] {
        guard let order = orders.first(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }

        guard role(for: actorID, in: order.channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let now = Date()
        let rows = lineItems.map { item in
            OrderLineItem(
                id: "oli-\(UUID().uuidString.prefix(8))",
                orderID: orderID,
                itemID: item.itemID,
                variantID: item.variantID,
                title: item.title,
                sku: item.sku,
                quantity: item.quantity,
                unitPriceCents: item.unitPriceCents,
                lineTotalCents: item.quantity * item.unitPriceCents,
                createdAt: now
            )
        }

        orderLineItemsByOrderID[orderID] = rows
        appendLedger(orderID: orderID, actorID: actorID, eventType: "order_line_items_upserted", payloadSummary: "\(rows.count) line items")
        return rows
    }

    func updateOrderStatus(orderID: String, status: OrderStatus, quoteNote: String?, actorID: String) async throws -> OrderRequest {
        guard let idx = orders.firstIndex(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }

        guard role(for: actorID, in: orders[idx].channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        var updated = orders[idx]
        let previous = updated.status
        updated.status = status
        if let quoteNote {
            updated.quoteNote = quoteNote
        }
        updated.updatedAt = Date()
        orders[idx] = updated

        appendLedger(
            orderID: updated.id,
            actorID: actorID,
            eventType: "status_\(status.rawValue)",
            payloadSummary: "\(previous.rawValue) -> \(status.rawValue)"
        )

        return updated
    }

    func assignDriver(orderID: String, driverID: String, actorID: String) async throws -> OrderRequest {
        guard let idx = orders.firstIndex(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }

        let channelID = orders[idx].channelID
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        guard role(for: driverID, in: channelID) == .driver else {
            throw InMemoryBackendError.permissionDenied
        }

        var updated = orders[idx]
        updated.assignedDriverID = driverID
        updated.status = .assigned
        updated.updatedAt = Date()
        orders[idx] = updated

        appendLedger(
            orderID: updated.id,
            actorID: actorID,
            eventType: "driver_assigned",
            payloadSummary: "Assigned driver \(driverID)"
        )

        return updated
    }

    // MARK: - Dispatch

    func fetchRoutes(userID: String, role: UserRole) async throws -> [DeliveryRoute] {
        let result: [DeliveryRoute]
        switch role {
        case .owner:
            let ownedChannels = Set(memberships.filter { $0.userID == userID && $0.role == .owner }.map(\.channelID))
            result = routes.filter { ownedChannels.contains($0.channelID) }
        case .driver:
            result = routes.filter { $0.driverID == userID }
        case .follower:
            result = []
        }

        return result.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func buildRoute(channelID: String, driverID: String, start: GeoPoint, actorID: String) async throws -> DeliveryRoute {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let assigned = orders
            .filter {
                $0.channelID == channelID
                && $0.assignedDriverID == driverID
                && ($0.status == .assigned || $0.status == .accepted || $0.status == .quoted)
                && $0.lat != nil
                && $0.lng != nil
            }

        let candidates = assigned.map {
            RouteCandidate(id: $0.id, point: GeoPoint(lat: $0.lat ?? 0, lng: $0.lng ?? 0))
        }
        let plan = await DistanceRouter().buildFallbackRoute(start: start, candidates: candidates)

        var stops: [RouteStop] = []
        for (index, orderID) in plan.orderedIDs.enumerated() {
            stops.append(
                RouteStop(
                    id: "stop-\(UUID().uuidString.prefix(8))",
                    orderID: orderID,
                    stopIndex: index,
                    etaMinutes: plan.etaMinutes.indices.contains(index) ? plan.etaMinutes[index] : nil,
                    completedAt: nil
                )
            )
        }

        let route = DeliveryRoute(
            id: "route-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            driverID: driverID,
            status: .planned,
            approximate: true,
            stops: stops
        )

        for idx in orders.indices {
            if plan.orderedIDs.contains(orders[idx].id) {
                orders[idx].status = .outForDelivery
                orders[idx].updatedAt = Date()
                appendLedger(
                    orderID: orders[idx].id,
                    actorID: actorID,
                    eventType: "route_built",
                    payloadSummary: "Route \(route.id) planned"
                )
            }
        }

        routes.insert(route, at: 0)
        return route
    }

    func reorderRouteStops(routeID: String, orderedStopIDs: [String], actorID: String) async throws -> DeliveryRoute {
        guard let routeIndex = routes.firstIndex(where: { $0.id == routeID }) else {
            throw InMemoryBackendError.routeNotFound
        }

        guard role(for: actorID, in: routes[routeIndex].channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        var route = routes[routeIndex]
        guard route.status == .planned else {
            throw InMemoryBackendError.permissionDenied
        }

        let existingIDs = Set(route.stops.map(\.id))
        let incomingIDs = Set(orderedStopIDs)
        guard existingIDs == incomingIDs else {
            throw InMemoryBackendError.stopNotFound
        }

        let mapping = Dictionary(uniqueKeysWithValues: route.stops.map { ($0.id, $0) })
        route.stops = orderedStopIDs.enumerated().compactMap { index, stopID in
            guard var stop = mapping[stopID] else { return nil }
            let eta = max(5, (index + 1) * 8)
            stop = RouteStop(
                id: stop.id,
                orderID: stop.orderID,
                stopIndex: index,
                etaMinutes: eta,
                completedAt: stop.completedAt
            )
            return stop
        }

        routes[routeIndex] = route

        for stop in route.stops {
            appendLedger(
                orderID: stop.orderID,
                actorID: actorID,
                eventType: "route_reordered",
                payloadSummary: "Route \(routeID) stop #\(stop.stopIndex + 1)"
            )
        }

        return route
    }

    func completeStop(routeID: String, stopID: String, actorID: String) async throws -> DeliveryRoute {
        guard let routeIndex = routes.firstIndex(where: { $0.id == routeID }) else {
            throw InMemoryBackendError.routeNotFound
        }

        let canAct = routes[routeIndex].driverID == actorID || role(for: actorID, in: routes[routeIndex].channelID) == .owner
        guard canAct else {
            throw InMemoryBackendError.permissionDenied
        }

        guard let stopIndex = routes[routeIndex].stops.firstIndex(where: { $0.id == stopID }) else {
            throw InMemoryBackendError.stopNotFound
        }

        var route = routes[routeIndex]
        route.stops[stopIndex].completedAt = Date()

        if let orderIdx = orders.firstIndex(where: { $0.id == route.stops[stopIndex].orderID }) {
            orders[orderIdx].status = .delivered
            orders[orderIdx].updatedAt = Date()
            appendLedger(
                orderID: orders[orderIdx].id,
                actorID: actorID,
                eventType: "order_delivered",
                payloadSummary: "Completed route stop"
            )
        }

        let remaining = route.stops.filter { $0.completedAt == nil }
        if remaining.isEmpty {
            route.status = .completed
            route.completedAt = Date()
            route.startedAt = route.startedAt ?? Date()
        } else {
            route.status = .inProgress
            route.startedAt = route.startedAt ?? Date()
        }

        routes[routeIndex] = route
        return route
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
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let now = Date()
        if let itemID, let index = inventoryItems.firstIndex(where: { $0.id == itemID && $0.channelID == channelID }) {
            inventoryItems[index].name = name
            inventoryItems[index].sku = sku
            inventoryItems[index].description = description
            inventoryItems[index].defaultPriceCents = defaultPriceCents
            inventoryItems[index].currencyCode = currencyCode
            inventoryItems[index].trackStock = trackStock
            inventoryItems[index].stockOnHand = max(0, stockOnHand)
            inventoryItems[index].lowStockThreshold = max(0, lowStockThreshold)
            inventoryItems[index].updatedAt = now

            appendAdminAudit(channelID: channelID, actorID: actorID, action: "inventory_item_updated", targetType: "inventory_item", targetID: itemID, reason: nil, payload: "sku=\(sku)")
            return toInventoryItem(inventoryItems[index])
        }

        let row = InventoryItemRecord(
            id: "item-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            ownerID: actorID,
            name: name,
            sku: sku,
            description: description,
            defaultPriceCents: defaultPriceCents,
            currencyCode: currencyCode,
            trackStock: trackStock,
            stockOnHand: max(0, stockOnHand),
            lowStockThreshold: max(0, lowStockThreshold),
            isActive: true,
            createdAt: now,
            updatedAt: now
        )
        inventoryItems.insert(row, at: 0)
        appendAdminAudit(channelID: channelID, actorID: actorID, action: "inventory_item_created", targetType: "inventory_item", targetID: row.id, reason: nil, payload: "sku=\(sku)")
        return toInventoryItem(row)
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
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        guard inventoryItems.contains(where: { $0.id == itemID && $0.channelID == channelID }) else {
            throw InMemoryBackendError.inventoryItemNotFound
        }

        let now = Date()
        if let variantID, let index = inventoryVariants.firstIndex(where: { $0.id == variantID && $0.itemID == itemID }) {
            inventoryVariants[index].name = name
            inventoryVariants[index].sku = sku
            inventoryVariants[index].priceCents = max(0, priceCents)
            inventoryVariants[index].stockOnHand = max(0, stockOnHand)
            inventoryVariants[index].isActive = isActive
            inventoryVariants[index].updatedAt = now

            appendAdminAudit(channelID: channelID, actorID: actorID, action: "inventory_variant_updated", targetType: "inventory_variant", targetID: variantID, reason: nil, payload: "sku=\(sku)")
            return toInventoryVariant(inventoryVariants[index])
        }

        let row = InventoryVariantRecord(
            id: "var-\(UUID().uuidString.prefix(8))",
            itemID: itemID,
            name: name,
            sku: sku,
            priceCents: max(0, priceCents),
            stockOnHand: max(0, stockOnHand),
            isActive: isActive,
            createdAt: now,
            updatedAt: now
        )
        inventoryVariants.append(row)
        appendAdminAudit(channelID: channelID, actorID: actorID, action: "inventory_variant_created", targetType: "inventory_variant", targetID: row.id, reason: nil, payload: "sku=\(sku)")
        return toInventoryVariant(row)
    }

    func adjustInventoryStock(
        channelID: String,
        itemID: String,
        variantID: String?,
        delta: Int,
        reason: String,
        actorID: String
    ) async throws -> InventoryStockEvent {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        guard let itemIndex = inventoryItems.firstIndex(where: { $0.id == itemID && $0.channelID == channelID }) else {
            throw InMemoryBackendError.inventoryItemNotFound
        }

        let now = Date()
        let balanceAfter: Int
        if let variantID {
            guard let variantIndex = inventoryVariants.firstIndex(where: { $0.id == variantID && $0.itemID == itemID }) else {
                throw InMemoryBackendError.inventoryVariantNotFound
            }
            let next = inventoryVariants[variantIndex].stockOnHand + delta
            guard next >= 0 else { throw InMemoryBackendError.invalidInput("Insufficient stock.") }
            inventoryVariants[variantIndex].stockOnHand = next
            inventoryVariants[variantIndex].updatedAt = now
            balanceAfter = next
        } else {
            let next = inventoryItems[itemIndex].stockOnHand + delta
            guard next >= 0 else { throw InMemoryBackendError.invalidInput("Insufficient stock.") }
            inventoryItems[itemIndex].stockOnHand = next
            inventoryItems[itemIndex].updatedAt = now
            balanceAfter = next
        }

        let event = InventoryStockEvent(
            id: "stk-\(UUID().uuidString.prefix(8))",
            itemID: itemID,
            variantID: variantID,
            delta: delta,
            balanceAfter: balanceAfter,
            reason: reason,
            createdAt: now
        )
        inventoryStockLedger.insert(event, at: 0)
        appendAdminAudit(channelID: channelID, actorID: actorID, action: "inventory_stock_adjusted", targetType: variantID == nil ? "inventory_item" : "inventory_variant", targetID: variantID ?? itemID, reason: reason, payload: "delta=\(delta);balance=\(balanceAfter)")
        return event
    }

    func fetchInventoryCatalog(channelID: String, includeInactive: Bool, includeLedger: Bool, actorID: String) async throws -> InventoryCatalog {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let items = inventoryItems
            .filter { $0.channelID == channelID && (includeInactive || $0.isActive) }
            .map(toInventoryItem)
            .sorted(by: { $0.createdAt > $1.createdAt })

        let ledger = includeLedger ? inventoryStockLedger.filter { event in
            items.contains(where: { $0.id == event.itemID })
        } : []

        return InventoryCatalog(channelID: channelID, items: items, ledger: ledger)
    }

    // MARK: - Admin

    func archiveChannel(channelID: String, reason: String, actorID: String) async throws {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        guard let index = channels.firstIndex(where: { $0.id == channelID }) else {
            throw InMemoryBackendError.channelNotFound
        }
        let old = channels[index]
        channels[index] = Channel(id: old.id, title: old.title, description: old.description, isActive: false)
        appendAdminAudit(channelID: channelID, actorID: actorID, action: "channel_archived", targetType: "channel", targetID: channelID, reason: reason, payload: "")
    }

    func deleteOrder(orderID: String, mode: AdminDeleteMode, reason: String, actorID: String) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }
        guard role(for: actorID, in: orders[index].channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let channelID = orders[index].channelID
        switch mode {
        case .softDelete:
            orders[index].status = .cancelled
            orders[index].updatedAt = Date()
            appendLedger(orderID: orderID, actorID: actorID, eventType: "order_admin_archived", payloadSummary: reason)
            appendAdminAudit(channelID: channelID, actorID: actorID, action: "order_soft_deleted", targetType: "order_request", targetID: orderID, reason: reason, payload: "")
        case .hardDelete:
            orders.remove(at: index)
            orderLineItemsByOrderID.removeValue(forKey: orderID)
            ledgerByOrderID.removeValue(forKey: orderID)
            appendAdminAudit(channelID: channelID, actorID: actorID, action: "order_hard_deleted", targetType: "order_request", targetID: orderID, reason: reason, payload: "")
        }
    }

    func unassignDriver(orderID: String, reason: String, actorID: String) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw InMemoryBackendError.orderNotFound
        }
        guard role(for: actorID, in: orders[index].channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        let previous = orders[index].assignedDriverID
        orders[index].assignedDriverID = nil
        orders[index].status = .accepted
        orders[index].updatedAt = Date()
        appendLedger(orderID: orderID, actorID: actorID, eventType: "driver_unassigned", payloadSummary: reason)
        appendAdminAudit(channelID: orders[index].channelID, actorID: actorID, action: "order_driver_unassigned", targetType: "order_request", targetID: orderID, reason: reason, payload: "previous_driver=\(previous ?? "none")")
    }

    func upsertDriverMembership(channelID: String, driverUserID: String, operation: DriverMembershipOperation, reason: String, actorID: String) async throws {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        switch operation {
        case .add:
            if role(for: driverUserID, in: channelID) == nil {
                memberships.append(Membership(channelID: channelID, userID: driverUserID, role: .driver))
            }
            appendAdminAudit(channelID: channelID, actorID: actorID, action: "driver_membership_added", targetType: "channel_membership", targetID: "\(channelID):\(driverUserID)", reason: reason, payload: "")
        case .remove:
            memberships.removeAll { $0.channelID == channelID && $0.userID == driverUserID && $0.role == .driver }
            appendAdminAudit(channelID: channelID, actorID: actorID, action: "driver_membership_removed", targetType: "channel_membership", targetID: "\(channelID):\(driverUserID)", reason: reason, payload: "")
        }
    }

    func fetchAdminAuditEvents(channelID: String, action: String?, limit: Int, actorID: String) async throws -> [AdminAuditEvent] {
        guard role(for: actorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }
        let rows = adminAuditEvents.filter { event in
            event.channelID == channelID && (action == nil || event.action == action)
        }
        return Array(rows.prefix(max(1, limit)))
    }

    // MARK: - Helpers

    private func role(for userID: String, in channelID: String) -> UserRole? {
        memberships.first(where: { $0.userID == userID && $0.channelID == channelID })?.role
    }

    private func appendLedger(orderID: String, actorID: String, eventType: String, payloadSummary: String) {
        let event = OrderLedgerEvent(
            id: "evt-\(UUID().uuidString.prefix(8))",
            orderID: orderID,
            actorID: actorID,
            eventType: eventType,
            payloadSummary: payloadSummary,
            createdAt: Date()
        )
        ledgerByOrderID[orderID, default: []].append(event)
    }

    private func appendAdminAudit(
        channelID: String,
        actorID: String,
        action: String,
        targetType: String,
        targetID: String,
        reason: String?,
        payload: String
    ) {
        let event = AdminAuditEvent(
            id: "audit-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            actorID: actorID,
            action: action,
            targetType: targetType,
            targetID: targetID,
            reason: reason,
            payloadSummary: payload,
            createdAt: Date()
        )
        adminAuditEvents.insert(event, at: 0)
    }

    private func toInventoryVariant(_ row: InventoryVariantRecord) -> InventoryVariant {
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

    private func toInventoryItem(_ row: InventoryItemRecord) -> InventoryItem {
        let variants = inventoryVariants
            .filter { $0.itemID == row.id }
            .map(toInventoryVariant)
        return InventoryItem(
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
            variants: variants
        )
    }
}
