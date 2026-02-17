import Foundation
import BoppyV2Core

extension LiveSupabaseBackend {
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
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,external_ref,summary_title,summary_image_url,summary_total_cents,summary_eta_text,created_at,updated_at&channel_id=in.\(inFilter(ownerChannels))&order=updated_at.desc"
        case .driver:
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,external_ref,summary_title,summary_image_url,summary_total_cents,summary_eta_text,created_at,updated_at&assigned_driver_id=eq.\(escape(userID))&order=updated_at.desc"
        case .follower:
            query = "order_requests?select=id,channel_id,post_id,customer_id,customer_phone,delivery_address_json,lat,lng,quote_note,status,assigned_driver_id,external_ref,summary_title,summary_image_url,summary_total_cents,summary_eta_text,created_at,updated_at&customer_id=eq.\(escape(userID))&order=updated_at.desc"
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


}
