import Foundation
import BoppyV2Core

@MainActor
final class InventoryStore: ObservableObject {
    @Published var inventoryCatalog: InventoryCatalog?

    func refreshInventory(
        channelID: String,
        actorID: String,
        inventoryService: InventoryServiceProtocol
    ) async throws {
        inventoryCatalog = try await inventoryService.fetchInventoryCatalog(
            channelID: channelID,
            includeInactive: false,
            includeLedger: true,
            actorID: actorID
        )
    }

    func createDraftItem(
        channelID: String,
        actorID: String,
        inventoryService: InventoryServiceProtocol
    ) async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        _ = try await inventoryService.upsertInventoryItem(
            channelID: channelID,
            itemID: nil,
            name: "Catalog Item \(timestamp % 1000)",
            sku: "SKU-\(timestamp)",
            description: "Added from Profile admin tools",
            defaultPriceCents: 1200,
            currencyCode: "USD",
            trackStock: true,
            stockOnHand: 8,
            lowStockThreshold: 2,
            actorID: actorID
        )
    }

    func createItem(
        channelID: String,
        actorID: String,
        draft: InventoryDraftInput,
        inventoryService: InventoryServiceProtocol
    ) async throws {
        let descriptionWithMeta = """
        \(draft.description)

        category=\(draft.category);show_in_catalog=\(draft.showInCatalog);thumbnail=\(draft.thumbnailURL ?? "")
        """
        let item = try await inventoryService.upsertInventoryItem(
            channelID: channelID,
            itemID: nil,
            name: draft.name,
            sku: draft.sku,
            description: descriptionWithMeta.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultPriceCents: draft.defaultPriceCents,
            currencyCode: "USD",
            trackStock: true,
            stockOnHand: draft.stockOnHand,
            lowStockThreshold: draft.lowStockThreshold,
            actorID: actorID
        )

        // Create variants for each non-nil pricing tier
        let tiers: [(name: String, skuSuffix: String, cents: Int?)] = [
            ("Wholesale", "WH", draft.wholesalePriceCents),
            ("Distributor", "DS", draft.distributorPriceCents),
            ("Bulk", "BK", draft.bulkPriceCents),
        ]

        for tier in tiers {
            guard let priceCents = tier.cents else { continue }
            _ = try await inventoryService.upsertInventoryVariant(
                channelID: channelID,
                itemID: item.id,
                variantID: nil,
                name: tier.name,
                sku: "\(draft.sku)-\(tier.skuSuffix)",
                priceCents: priceCents,
                stockOnHand: draft.stockOnHand,
                isActive: true,
                actorID: actorID
            )
        }
    }

    func updateItem(
        channelID: String,
        actorID: String,
        draft: InventoryDraftInput,
        inventoryService: InventoryServiceProtocol
    ) async throws {
        guard let itemID = draft.itemID else { return }

        let descriptionWithMeta = """
        \(draft.description)

        category=\(draft.category);show_in_catalog=\(draft.showInCatalog);thumbnail=\(draft.thumbnailURL ?? "")
        """
        _ = try await inventoryService.upsertInventoryItem(
            channelID: channelID,
            itemID: itemID,
            name: draft.name,
            sku: draft.sku,
            description: descriptionWithMeta.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultPriceCents: draft.defaultPriceCents,
            currencyCode: "USD",
            trackStock: true,
            stockOnHand: draft.stockOnHand,
            lowStockThreshold: draft.lowStockThreshold,
            actorID: actorID
        )

        // Upsert variants for each pricing tier
        let tiers: [(name: String, skuSuffix: String, cents: Int?)] = [
            ("Wholesale", "WH", draft.wholesalePriceCents),
            ("Distributor", "DS", draft.distributorPriceCents),
            ("Bulk", "BK", draft.bulkPriceCents),
        ]

        for tier in tiers {
            guard let priceCents = tier.cents else { continue }
            _ = try await inventoryService.upsertInventoryVariant(
                channelID: channelID,
                itemID: itemID,
                variantID: nil,
                name: tier.name,
                sku: "\(draft.sku)-\(tier.skuSuffix)",
                priceCents: priceCents,
                stockOnHand: draft.stockOnHand,
                isActive: true,
                actorID: actorID
            )
        }
    }

    func adjustInventory(
        channelID: String,
        actorID: String,
        itemID: String,
        delta: Int,
        reason: String,
        inventoryService: InventoryServiceProtocol
    ) async throws {
        _ = try await inventoryService.adjustInventoryStock(
            channelID: channelID,
            itemID: itemID,
            variantID: nil,
            delta: delta,
            reason: reason,
            actorID: actorID
        )
    }

    func clear() {
        inventoryCatalog = nil
    }
}
