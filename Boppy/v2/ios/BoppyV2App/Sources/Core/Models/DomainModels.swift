import Foundation

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case owner
    case driver
    case follower
}

public struct SessionUser: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let phoneE164: String
    public let displayName: String
    public let role: UserRole

    public init(id: String, phoneE164: String, displayName: String, role: UserRole) {
        self.id = id
        self.phoneE164 = phoneE164
        self.displayName = displayName
        self.role = role
    }
}

public struct Channel: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let isActive: Bool

    public init(id: String, title: String, description: String, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.description = description
        self.isActive = isActive
    }
}

public enum PostType: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case video
}

public struct ChannelPost: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let authorID: String
    public let postType: PostType
    public let caption: String
    public let mediaPath: String?
    public let createdAt: Date

    public init(
        id: String,
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.channelID = channelID
        self.authorID = authorID
        self.postType = postType
        self.caption = caption
        self.mediaPath = mediaPath
        self.createdAt = createdAt
    }
}

public struct ChannelInvite: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let token: String
    public let inviteURL: String
    public let expiresAt: Date
    public let maxUses: Int?

    public init(id: String, channelID: String, token: String, inviteURL: String, expiresAt: Date, maxUses: Int?) {
        self.id = id
        self.channelID = channelID
        self.token = token
        self.inviteURL = inviteURL
        self.expiresAt = expiresAt
        self.maxUses = maxUses
    }
}

public struct DeliveryAddress: Codable, Equatable, Sendable {
    public var line1: String
    public var line2: String
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String

    public init(line1: String, line2: String = "", city: String, state: String, postalCode: String, country: String = "US") {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }

    public var singleLine: String {
        [line1, line2, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

public enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case requested
    case quoted
    case accepted
    case assigned
    case outForDelivery = "out_for_delivery"
    case delivered
    case cancelled
    case addressReview = "address_review"
}

public struct OrderRequest: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let postID: String
    public let customerID: String
    public let customerPhone: String
    public let deliveryAddress: DeliveryAddress
    public let lat: Double?
    public let lng: Double?
    public var quoteNote: String
    public var status: OrderStatus
    public var assignedDriverID: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        channelID: String,
        postID: String,
        customerID: String,
        customerPhone: String,
        deliveryAddress: DeliveryAddress,
        lat: Double? = nil,
        lng: Double? = nil,
        quoteNote: String,
        status: OrderStatus = .requested,
        assignedDriverID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.channelID = channelID
        self.postID = postID
        self.customerID = customerID
        self.customerPhone = customerPhone
        self.deliveryAddress = deliveryAddress
        self.lat = lat
        self.lng = lng
        self.quoteNote = quoteNote
        self.status = status
        self.assignedDriverID = assignedDriverID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OrderLedgerEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let orderID: String
    public let actorID: String
    public let eventType: String
    public let payloadSummary: String
    public let createdAt: Date

    public init(
        id: String,
        orderID: String,
        actorID: String,
        eventType: String,
        payloadSummary: String,
        createdAt: Date
    ) {
        self.id = id
        self.orderID = orderID
        self.actorID = actorID
        self.eventType = eventType
        self.payloadSummary = payloadSummary
        self.createdAt = createdAt
    }
}

public struct OrderLineItemInput: Codable, Equatable, Sendable {
    public let itemID: String?
    public let variantID: String?
    public let title: String
    public let sku: String
    public let quantity: Int
    public let unitPriceCents: Int

    public init(
        itemID: String? = nil,
        variantID: String? = nil,
        title: String,
        sku: String,
        quantity: Int,
        unitPriceCents: Int
    ) {
        self.itemID = itemID
        self.variantID = variantID
        self.title = title
        self.sku = sku
        self.quantity = quantity
        self.unitPriceCents = unitPriceCents
    }
}

public struct OrderLineItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let orderID: String
    public let itemID: String?
    public let variantID: String?
    public let title: String
    public let sku: String
    public let quantity: Int
    public let unitPriceCents: Int
    public let lineTotalCents: Int
    public let createdAt: Date

    public init(
        id: String,
        orderID: String,
        itemID: String?,
        variantID: String?,
        title: String,
        sku: String,
        quantity: Int,
        unitPriceCents: Int,
        lineTotalCents: Int,
        createdAt: Date
    ) {
        self.id = id
        self.orderID = orderID
        self.itemID = itemID
        self.variantID = variantID
        self.title = title
        self.sku = sku
        self.quantity = quantity
        self.unitPriceCents = unitPriceCents
        self.lineTotalCents = lineTotalCents
        self.createdAt = createdAt
    }
}

public struct InventoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let name: String
    public let sku: String
    public let description: String
    public let defaultPriceCents: Int
    public let currencyCode: String
    public let trackStock: Bool
    public let stockOnHand: Int
    public let lowStockThreshold: Int
    public let isActive: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let variants: [InventoryVariant]

    public init(
        id: String,
        channelID: String,
        name: String,
        sku: String,
        description: String,
        defaultPriceCents: Int,
        currencyCode: String,
        trackStock: Bool,
        stockOnHand: Int,
        lowStockThreshold: Int,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date,
        variants: [InventoryVariant]
    ) {
        self.id = id
        self.channelID = channelID
        self.name = name
        self.sku = sku
        self.description = description
        self.defaultPriceCents = defaultPriceCents
        self.currencyCode = currencyCode
        self.trackStock = trackStock
        self.stockOnHand = stockOnHand
        self.lowStockThreshold = lowStockThreshold
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.variants = variants
    }
}

public struct InventoryVariant: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let name: String
    public let sku: String
    public let priceCents: Int
    public let stockOnHand: Int
    public let isActive: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        itemID: String,
        name: String,
        sku: String,
        priceCents: Int,
        stockOnHand: Int,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.itemID = itemID
        self.name = name
        self.sku = sku
        self.priceCents = priceCents
        self.stockOnHand = stockOnHand
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct InventoryStockEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let variantID: String?
    public let delta: Int
    public let balanceAfter: Int
    public let reason: String
    public let createdAt: Date

    public init(
        id: String,
        itemID: String,
        variantID: String?,
        delta: Int,
        balanceAfter: Int,
        reason: String,
        createdAt: Date
    ) {
        self.id = id
        self.itemID = itemID
        self.variantID = variantID
        self.delta = delta
        self.balanceAfter = balanceAfter
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct InventoryCatalog: Codable, Equatable, Sendable {
    public let channelID: String
    public let items: [InventoryItem]
    public let ledger: [InventoryStockEvent]

    public init(channelID: String, items: [InventoryItem], ledger: [InventoryStockEvent]) {
        self.channelID = channelID
        self.items = items
        self.ledger = ledger
    }
}

public enum AdminDeleteMode: String, Codable, Equatable, Sendable {
    case softDelete = "soft_delete"
    case hardDelete = "hard_delete"
}

public enum DriverMembershipOperation: String, Codable, Equatable, Sendable {
    case add
    case remove
}

public struct AdminAuditEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let actorID: String
    public let action: String
    public let targetType: String
    public let targetID: String
    public let reason: String?
    public let payloadSummary: String
    public let createdAt: Date

    public init(
        id: String,
        channelID: String,
        actorID: String,
        action: String,
        targetType: String,
        targetID: String,
        reason: String?,
        payloadSummary: String,
        createdAt: Date
    ) {
        self.id = id
        self.channelID = channelID
        self.actorID = actorID
        self.action = action
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.payloadSummary = payloadSummary
        self.createdAt = createdAt
    }
}

public struct DriverProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct RouteStop: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let orderID: String
    public let stopIndex: Int
    public let etaMinutes: Int?
    public var completedAt: Date?

    public init(id: String, orderID: String, stopIndex: Int, etaMinutes: Int? = nil, completedAt: Date? = nil) {
        self.id = id
        self.orderID = orderID
        self.stopIndex = stopIndex
        self.etaMinutes = etaMinutes
        self.completedAt = completedAt
    }
}

public struct DeliveryRoute: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelID: String
    public let driverID: String
    public var status: RouteStatus
    public var approximate: Bool
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var stops: [RouteStop]

    public init(
        id: String,
        channelID: String,
        driverID: String,
        status: RouteStatus,
        approximate: Bool,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        stops: [RouteStop]
    ) {
        self.id = id
        self.channelID = channelID
        self.driverID = driverID
        self.status = status
        self.approximate = approximate
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.stops = stops
    }
}

public enum RouteStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress = "in_progress"
    case completed
    case cancelled
}

public struct GeoPoint: Equatable, Sendable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

public struct RouteCandidate: Identifiable, Equatable, Sendable {
    public let id: String
    public let point: GeoPoint

    public init(id: String, point: GeoPoint) {
        self.id = id
        self.point = point
    }
}

public struct RoutePlan: Equatable, Sendable {
    public let orderedIDs: [String]
    public let etaMinutes: [Int]
    public let approximate: Bool

    public init(orderedIDs: [String], etaMinutes: [Int], approximate: Bool) {
        self.orderedIDs = orderedIDs
        self.etaMinutes = etaMinutes
        self.approximate = approximate
    }
}
