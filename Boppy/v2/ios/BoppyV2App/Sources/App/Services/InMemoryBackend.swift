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
    var thumbnailURL: String?
    var category: String?
    var showInCatalog: Bool
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

private struct InventoryMetadataPayload {
    let category: String?
    let showInCatalog: Bool?
    let thumbnailURL: String?
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
            ChannelPost(
                id: "post-1",
                channelID: "channel-main",
                authorID: owner.id,
                postType: .image,
                caption: "Immutable LED Lantern batch with final QA check.",
                mediaPath: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1400&q=80",
                slotRemaining: 12,
                slotLabel: "12 SLOTS LEFT",
                heroSubtitle: "Express lane available",
                heroAspectRatio: 16.0 / 9.0,
                priceCents: 8900
            ),
            ChannelPost(
                id: "post-2",
                channelID: "channel-main",
                authorID: owner.id,
                postType: .video,
                caption: "Warehouse packaging line ready for overnight dispatch.",
                mediaPath: "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1400&q=80",
                slotRemaining: 8,
                slotLabel: "CONSOLIDATED SHIP",
                heroSubtitle: "Bulk tier still open",
                heroAspectRatio: 16.0 / 9.0,
                priceCents: 6900
            )
        ]

        postsByChannel["channel-limited"] = [
            ChannelPost(
                id: "post-3",
                channelID: "channel-limited",
                authorID: owner.id,
                postType: .text,
                caption: "Limited release opens Friday 8PM.",
                mediaPath: nil,
                slotRemaining: 4,
                slotLabel: "LIMITED",
                heroSubtitle: "Invite-only allocation"
            )
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
            thumbnailURL: "https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=900&q=80",
            category: "Lighting",
            showInCatalog: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        inventoryItems = [seedItem]

        // Seed inventory variants for 4-tier pricing on Premium Canvas
        inventoryVariants = [
            InventoryVariantRecord(
                id: "var-wholesale",
                itemID: "item-1",
                name: "Wholesale",
                sku: "CANVAS-001-WH",
                priceCents: 10800,
                stockOnHand: 25,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            InventoryVariantRecord(
                id: "var-distributor",
                itemID: "item-1",
                name: "Distributor",
                sku: "CANVAS-001-DS",
                priceCents: 9600,
                stockOnHand: 25,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            InventoryVariantRecord(
                id: "var-bulk",
                itemID: "item-1",
                name: "Bulk",
                sku: "CANVAS-001-BK",
                priceCents: 8400,
                stockOnHand: 25,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
        ]

        // Seed follower user (aligns with PhoneAuthView shortcut at +15550000003)
        let follower = SessionUser(
            id: "follower-1",
            phoneE164: "+15550000003",
            displayName: "Follower",
            role: .follower
        )
        usersByPhone[follower.phoneE164] = follower
        memberships.append(Membership(channelID: "channel-main", userID: follower.id, role: .follower))

        // Seed 4 orders at different pipeline stages (Austin-area addresses)
        orders = [
            OrderRequest(
                id: "order-seed-1",
                channelID: "channel-main",
                postID: "post-1",
                customerID: follower.id,
                customerPhone: follower.phoneE164,
                deliveryAddress: DeliveryAddress(
                    line1: "1100 Congress Ave",
                    city: "Austin",
                    state: "TX",
                    postalCode: "78701"
                ),
                lat: 30.2747,
                lng: -97.7404,
                quoteNote: "tier=retail;qty=2;note=Needed by Friday",
                status: .requested,
                externalRef: "BXB-SEED1",
                summaryTitle: "Premium Canvas",
                summaryImageURL: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80",
                summaryTotalCents: 24000,
                summaryEtaText: "ETA 2h 15m"
            ),
            OrderRequest(
                id: "order-seed-2",
                channelID: "channel-main",
                postID: "post-1",
                customerID: follower.id,
                customerPhone: follower.phoneE164,
                deliveryAddress: DeliveryAddress(
                    line1: "2222 Rio Grande St",
                    city: "Austin",
                    state: "TX",
                    postalCode: "78705"
                ),
                lat: 30.2860,
                lng: -97.7470,
                quoteNote: "tier=wholesale;qty=5;note=Wholesale order for gallery",
                status: .assigned,
                assignedDriverID: driver.id,
                externalRef: "BXB-SEED2",
                summaryTitle: "Premium Canvas",
                summaryImageURL: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80",
                summaryTotalCents: 54000,
                summaryEtaText: "ETA 1h 30m"
            ),
            OrderRequest(
                id: "order-seed-3",
                channelID: "channel-main",
                postID: "post-2",
                customerID: follower.id,
                customerPhone: follower.phoneE164,
                deliveryAddress: DeliveryAddress(
                    line1: "500 E 4th St",
                    city: "Austin",
                    state: "TX",
                    postalCode: "78701"
                ),
                lat: 30.2655,
                lng: -97.7370,
                quoteNote: "tier=distributor;qty=3;note=Distributor pickup",
                status: .assigned,
                assignedDriverID: driver.id,
                externalRef: "BXB-SEED3",
                summaryTitle: "Warehouse LED Kit",
                summaryImageURL: "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80",
                summaryTotalCents: 28800,
                summaryEtaText: "ETA 45m"
            ),
            OrderRequest(
                id: "order-seed-4",
                channelID: "channel-main",
                postID: "post-1",
                customerID: follower.id,
                customerPhone: follower.phoneE164,
                deliveryAddress: DeliveryAddress(
                    line1: "301 W 2nd St",
                    city: "Austin",
                    state: "TX",
                    postalCode: "78701"
                ),
                lat: 30.2640,
                lng: -97.7460,
                quoteNote: "tier=bulk;qty=10;note=Completed bulk order",
                status: .delivered,
                assignedDriverID: driver.id,
                externalRef: "BXB-SEED4",
                summaryTitle: "Premium Canvas",
                summaryImageURL: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80",
                summaryTotalCents: 84000,
                summaryEtaText: "Delivered"
            ),
        ]

        // Seed ledger events for order history
        for order in orders {
            appendLedger(
                orderID: order.id,
                actorID: order.customerID,
                eventType: "order_requested",
                payloadSummary: "Request submitted"
            )
        }
        appendLedger(orderID: "order-seed-2", actorID: owner.id, eventType: "driver_assigned", payloadSummary: "Assigned driver driver-1")
        appendLedger(orderID: "order-seed-3", actorID: owner.id, eventType: "driver_assigned", payloadSummary: "Assigned driver driver-1")
        appendLedger(orderID: "order-seed-4", actorID: owner.id, eventType: "driver_assigned", payloadSummary: "Assigned driver driver-1")
        appendLedger(orderID: "order-seed-4", actorID: driver.id, eventType: "order_delivered", payloadSummary: "Completed route stop")
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
            .map {
                let isBusy = $0.id.hashValue % 3 == 0
                return DriverProfile(
                    id: $0.id,
                    displayName: $0.displayName,
                    avatarURL: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=240&q=80",
                    availability: isBusy ? "busy" : "available",
                    rating: isBusy ? 4.3 : 4.8,
                    tripCount: isBusy ? 86 : 142,
                    lastLat: 30.2672 + Double($0.id.hashValue % 5) * 0.01,
                    lastLng: -97.7431 + Double($0.id.hashValue % 5) * 0.01
                )
            }
            .sorted(by: { $0.displayName < $1.displayName })
    }

    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?,
        heroSubtitle: String?,
        priceCents: Int?
    ) async throws -> ChannelPost {
        guard role(for: authorID, in: channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        let resolvedSubtitle: String? = {
            if let subtitle = heroSubtitle,
               !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return subtitle
            }
            return "Freshly posted"
        }()

        let post = ChannelPost(
            id: "post-\(UUID().uuidString.prefix(8))",
            channelID: channelID,
            authorID: authorID,
            postType: postType,
            caption: caption,
            mediaPath: mediaPath,
            slotRemaining: postType == .text ? nil : 10,
            slotLabel: postType == .video ? "CONSOLIDATED SHIP" : "10 SLOTS LEFT",
            heroSubtitle: resolvedSubtitle,
            heroAspectRatio: 16.0 / 9.0,
            priceCents: priceCents
        )

        postsByChannel[channelID, default: []].insert(post, at: 0)
        return post
    }

    func updatePost(
        postID: String,
        caption: String,
        mediaPath: String?,
        heroSubtitle: String?,
        priceCents: Int?,
        actorID: String
    ) async throws -> ChannelPost {
        for (channelID, posts) in postsByChannel {
            guard role(for: actorID, in: channelID) == .owner else { continue }
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                let old = posts[index]
                let updated = ChannelPost(
                    id: old.id,
                    channelID: old.channelID,
                    authorID: old.authorID,
                    postType: old.postType,
                    caption: caption,
                    mediaPath: mediaPath ?? old.mediaPath,
                    slotRemaining: old.slotRemaining,
                    slotLabel: old.slotLabel,
                    heroSubtitle: heroSubtitle,
                    heroAspectRatio: old.heroAspectRatio,
                    priceCents: priceCents,
                    createdAt: old.createdAt
                )
                postsByChannel[channelID]?[index] = updated
                return updated
            }
        }
        throw InMemoryBackendError.orderNotFound
    }

    func deletePost(postID: String, actorID: String) async throws {
        for (channelID, posts) in postsByChannel {
            guard role(for: actorID, in: channelID) == .owner else { continue }
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                postsByChannel[channelID]?.remove(at: index)
                return
            }
        }
        throw InMemoryBackendError.orderNotFound
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
            inviteURL: "beambox://invite/\(token)",
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
        let externalRefSuffix = String(postID.suffix(4)).uppercased()
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
            assignedDriverID: nil,
            externalRef: "BXB-\(externalRefSuffix)",
            summaryTitle: "Immutable LED Lantern",
            summaryImageURL: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=80",
            summaryTotalCents: 48900,
            summaryEtaText: geocodeFailed ? "Address review required" : "ETA 2h 15m"
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

    func clearRoute(routeID: String, actorID: String) async throws {
        guard let routeIndex = routes.firstIndex(where: { $0.id == routeID }) else {
            throw InMemoryBackendError.routeNotFound
        }

        let route = routes[routeIndex]
        guard role(for: actorID, in: route.channelID) == .owner else {
            throw InMemoryBackendError.permissionDenied
        }

        for stop in route.stops where stop.completedAt == nil {
            if let orderIdx = orders.firstIndex(where: { $0.id == stop.orderID }) {
                orders[orderIdx].status = .assigned
                orders[orderIdx].updatedAt = Date()
                appendLedger(
                    orderID: orders[orderIdx].id,
                    actorID: actorID,
                    eventType: "route_cleared",
                    payloadSummary: "Route \(routeID) cleared by owner"
                )
            }
        }

        routes.remove(at: routeIndex)
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

        let metadata = parseInventoryMetadata(description)
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
            inventoryItems[index].category = metadata.category ?? inventoryItems[index].category ?? "General"
            inventoryItems[index].thumbnailURL = metadata.thumbnailURL ?? inventoryItems[index].thumbnailURL
            inventoryItems[index].showInCatalog = metadata.showInCatalog ?? inventoryItems[index].showInCatalog
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
            thumbnailURL: metadata.thumbnailURL ?? "https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=900&q=80",
            category: metadata.category ?? "General",
            showInCatalog: metadata.showInCatalog ?? true,
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

    func lookupUserByPhone(phoneE164: String) async throws -> SessionUser? {
        usersByPhone[phoneE164]
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

    private func parseInventoryMetadata(_ description: String) -> InventoryMetadataPayload {
        let lowered = description.lowercased()
        guard lowered.contains("category=") || lowered.contains("thumbnail=") || lowered.contains("show_in_catalog=") else {
            return InventoryMetadataPayload(category: nil, showInCatalog: nil, thumbnailURL: nil)
        }

        let components = description
            .replacingOccurrences(of: "\n", with: ";")
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var category: String?
        var showInCatalog: Bool?
        var thumbnailURL: String?

        for component in components {
            let parts = component.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            switch key {
            case "category":
                category = value.isEmpty ? nil : value
            case "show_in_catalog":
                if value.lowercased() == "true" { showInCatalog = true }
                if value.lowercased() == "false" { showInCatalog = false }
            case "thumbnail":
                thumbnailURL = value.isEmpty ? nil : value
            default:
                continue
            }
        }

        return InventoryMetadataPayload(category: category, showInCatalog: showInCatalog, thumbnailURL: thumbnailURL)
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
        let activeOrderCount = orders.filter { order in
            order.status == .accepted || order.status == .assigned || order.status == .outForDelivery
        }.count
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
            thumbnailURL: row.thumbnailURL,
            category: row.category,
            activeOrderCount: activeOrderCount,
            showInCatalog: row.showInCatalog,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            variants: variants
        )
    }
}
