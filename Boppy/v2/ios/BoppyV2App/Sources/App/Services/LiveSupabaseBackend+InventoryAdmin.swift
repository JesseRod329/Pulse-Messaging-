import Foundation
import BoppyV2Core

extension LiveSupabaseBackend {
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
}
