import Foundation
import BoppyV2Core

extension AppCoordinator {
    func refreshInventoryAndAudit() async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else {
            inventoryStore.clear()
            adminStore.clear()
            return
        }
        guard ensureOnline() else { return }

        do {
            async let inventoryRefresh: Void = inventoryStore.refreshInventory(
                channelID: channelID,
                actorID: user.id,
                inventoryService: environment.inventoryService
            )
            async let adminRefresh: Void = adminStore.refreshAuditEvents(
                channelID: channelID,
                actorID: user.id,
                adminService: environment.adminService
            )

            _ = try await (inventoryRefresh, adminRefresh)
        } catch {
            handleError(error)
        }
    }

    func createInventoryDraftItem() async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await inventoryStore.createDraftItem(
                channelID: channelID,
                actorID: user.id,
                inventoryService: environment.inventoryService
            )
            await refreshInventoryAndAudit()
        } catch {
            handleError(error)
        }
    }

    func createInventoryItem(from draft: InventoryDraftInput) async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await inventoryStore.createItem(
                channelID: channelID,
                actorID: user.id,
                draft: draft,
                inventoryService: environment.inventoryService
            )
            await refreshInventoryAndAudit()
        } catch {
            handleError(error)
        }
    }

    func adjustInventory(itemID: String, delta: Int, reason: String) async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await inventoryStore.adjustInventory(
                channelID: channelID,
                actorID: user.id,
                itemID: itemID,
                delta: delta,
                reason: reason,
                inventoryService: environment.inventoryService
            )
            await refreshInventoryAndAudit()
        } catch {
            handleError(error)
        }
    }

    func archiveActiveChannel() async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await adminStore.archiveChannel(
                channelID: channelID,
                actorID: user.id,
                adminService: environment.adminService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }


}
