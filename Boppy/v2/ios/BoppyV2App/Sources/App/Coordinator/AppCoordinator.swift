import Foundation
import SwiftUI
import BoppyV2Core

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var user: SessionUser?
    @Published var selectedTab: MainTab = .feed

    @Published var channels: [Channel] = []
    @Published var selectedChannelID: String?
    @Published var posts: [ChannelPost] = []
    @Published var orders: [OrderRequest] = []
    @Published var routes: [DeliveryRoute] = []
    @Published var drivers: [DriverProfile] = []
    @Published var inventoryCatalog: InventoryCatalog?
    @Published var adminAuditEvents: [AdminAuditEvent] = []

    @Published var ledgerByOrderID: [String: [OrderLedgerEvent]] = [:]
    @Published var loadingLedgerOrderIDs: Set<String> = []

    @Published var activeOrderPost: ChannelPost?
    @Published var activeOrderPrefilledQuote: String?
    @Published var inviteTokenInput = ""
    @Published var latestInvite: ChannelInvite?

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private var pollingTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    deinit {
        pollingTask?.cancel()
    }

    func bootstrap() async {
        do {
            user = try await environment.authService.currentSession()
            if user == nil, environment.backendMode == .localDemo {
                try await environment.authService.requestOTP(phoneE164: "+15550000001")
                user = try await environment.authService.verifyOTP(phoneE164: "+15550000001", code: "123456")
            }
            if user != nil {
                startPollingLoop()
                await refreshAll()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestOTP(phone: String) async {
        do {
            try await environment.authService.requestOTP(phoneE164: phone)
            environment.analyticsService.track(event: "otp_requested", properties: ["phone": phone])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyOTP(phone: String, code: String) async {
        do {
            user = try await environment.authService.verifyOTP(phoneE164: phone, code: code)
            environment.analyticsService.track(event: "otp_verified", properties: ["role": user?.role.rawValue ?? "unknown"])
            startPollingLoop()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        stopPollingLoop()
        await environment.authService.signOut()
        user = nil
        channels = []
        posts = []
        orders = []
        routes = []
        drivers = []
        ledgerByOrderID = [:]
        loadingLedgerOrderIDs = []
        selectedChannelID = nil
        activeOrderPost = nil
        activeOrderPrefilledQuote = nil
        inventoryCatalog = nil
        adminAuditEvents = []
    }

    func handleDeepLink(_ url: URL) async {
        guard url.scheme == "boppyv2" else { return }

        if url.host == "invite" {
            let token = url.pathComponents.dropFirst().joined(separator: "")
            if !token.isEmpty {
                inviteTokenInput = token
                await joinChannel(using: token)
            }
        }
    }

    func refreshAll() async {
        await refreshAll(trigger: "manual")
    }

    func selectChannel(_ channelID: String) async {
        selectedChannelID = channelID
        await refreshAll()
    }

    func createChannel(title: String, description: String) async {
        guard let user, user.role == .owner else { return }

        do {
            let channel = try await environment.channelFeedService.createChannel(
                ownerID: user.id,
                title: title,
                description: description
            )
            selectedChannelID = channel.id
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinChannel(using token: String? = nil) async {
        guard let user else { return }

        let inviteToken = token ?? inviteTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inviteToken.isEmpty else { return }

        do {
            _ = try await environment.channelFeedService.joinChannel(token: inviteToken, userID: user.id)
            inviteTokenInput = ""
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createInvite(expiresInHours: Int = 72, maxUses: Int? = nil) async {
        guard let user, user.role == .owner, let channelID = selectedChannelID else { return }

        do {
            latestInvite = try await environment.channelFeedService.createInvite(
                channelID: channelID,
                ownerID: user.id,
                expiresInHours: expiresInHours,
                maxUses: maxUses
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPost(type: PostType, caption: String, mediaPath: String?) async {
        guard let user, let channelID = selectedChannelID else { return }

        do {
            _ = try await environment.channelFeedService.createPost(
                channelID: channelID,
                authorID: user.id,
                postType: type,
                caption: caption,
                mediaPath: mediaPath
            )
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openOrderSheet(for post: ChannelPost, prefilledQuote: String? = nil) {
        guard user?.role == .follower else { return }
        activeOrderPrefilledQuote = prefilledQuote
        activeOrderPost = post
    }

    func submitOrderRequest(postID: String, address: DeliveryAddress, quoteNote: String) async {
        guard let user, let channelID = selectedChannelID else { return }

        do {
            _ = try await environment.orderService.createOrderRequest(
                channelID: channelID,
                postID: postID,
                customerID: user.id,
                customerPhone: user.phoneE164,
                deliveryAddress: address,
                quoteNote: quoteNote
            )
            activeOrderPrefilledQuote = nil
            activeOrderPost = nil
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateOrderStatus(orderID: String, status: OrderStatus, quoteNote: String?) async {
        guard let user else { return }

        do {
            _ = try await environment.orderService.updateOrderStatus(
                orderID: orderID,
                status: status,
                quoteNote: quoteNote,
                actorID: user.id
            )
            await loadLedger(for: orderID, force: true)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignDriver(orderID: String, driverID: String) async {
        guard let user else { return }

        do {
            _ = try await environment.orderService.assignDriver(orderID: orderID, driverID: driverID, actorID: user.id)
            await loadLedger(for: orderID, force: true)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLedger(for orderID: String, force: Bool = false) async {
        guard let user else { return }
        if loadingLedgerOrderIDs.contains(orderID) { return }
        if !force, ledgerByOrderID[orderID] != nil { return }

        loadingLedgerOrderIDs.insert(orderID)
        defer { loadingLedgerOrderIDs.remove(orderID) }

        do {
            let events = try await environment.orderService.fetchLedgerEvents(orderID: orderID, userID: user.id, role: user.role)
            ledgerByOrderID[orderID] = events
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buildRoute(start: GeoPoint, driverID: String) async {
        guard let user, let channelID = selectedChannelID else { return }

        do {
            _ = try await environment.dispatchService.buildRoute(
                channelID: channelID,
                driverID: driverID,
                start: start,
                actorID: user.id
            )
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorderStop(routeID: String, stopID: String, direction: RouteStopReorderDirection) async {
        guard let user, user.role == .owner else { return }
        guard let route = routes.first(where: { $0.id == routeID }), route.status == .planned else { return }

        let orderedStops = route.stops.sorted(by: { $0.stopIndex < $1.stopIndex })
        let ids = orderedStops.map(\.id)
        guard let currentIndex = ids.firstIndex(of: stopID) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }

        guard ids.indices.contains(targetIndex) else { return }

        var reordered = ids
        reordered.swapAt(currentIndex, targetIndex)

        do {
            let updatedRoute = try await environment.dispatchService.reorderRouteStops(
                routeID: routeID,
                orderedStopIDs: reordered,
                actorID: user.id
            )
            if let routeIndex = routes.firstIndex(where: { $0.id == routeID }) {
                routes[routeIndex] = updatedRoute
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeStop(routeID: String, stopID: String) async {
        guard let user else { return }

        do {
            _ = try await environment.dispatchService.completeStop(routeID: routeID, stopID: stopID, actorID: user.id)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshInventoryAndAudit() async {
        guard let user, user.role == .owner, let channelID = selectedChannelID else {
            inventoryCatalog = nil
            adminAuditEvents = []
            return
        }

        do {
            async let catalog = environment.inventoryService.fetchInventoryCatalog(
                channelID: channelID,
                includeInactive: false,
                includeLedger: true,
                actorID: user.id
            )
            async let events = environment.adminService.fetchAdminAuditEvents(
                channelID: channelID,
                action: nil,
                limit: 25,
                actorID: user.id
            )

            inventoryCatalog = try await catalog
            adminAuditEvents = try await events
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createInventoryDraftItem() async {
        guard let user, user.role == .owner, let channelID = selectedChannelID else { return }

        do {
            let timestamp = Int(Date().timeIntervalSince1970)
            _ = try await environment.inventoryService.upsertInventoryItem(
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
                actorID: user.id
            )
            await refreshInventoryAndAudit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func adjustInventory(itemID: String, delta: Int, reason: String) async {
        guard let user, user.role == .owner, let channelID = selectedChannelID else { return }

        do {
            _ = try await environment.inventoryService.adjustInventoryStock(
                channelID: channelID,
                itemID: itemID,
                variantID: nil,
                delta: delta,
                reason: reason,
                actorID: user.id
            )
            await refreshInventoryAndAudit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveActiveChannel() async {
        guard let user, user.role == .owner, let channelID = selectedChannelID else { return }

        do {
            try await environment.adminService.archiveChannel(
                channelID: channelID,
                reason: "Archived from iOS owner admin controls",
                actorID: user.id
            )
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var selectedChannel: Channel? {
        channels.first(where: { $0.id == selectedChannelID })
    }

    var backendModeLabel: String {
        switch environment.backendMode {
        case .liveSupabase:
            return "Live Cloud"
        case .localDemo:
            return "Local Demo"
        }
    }

    var isDemoMode: Bool {
        environment.backendMode == .localDemo
    }

    private func refreshAll(trigger: String) async {
        guard let user else { return }
        if isLoading { return }

        normalizeSelectedTab(for: user.role)

        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedChannels = environment.channelFeedService.fetchChannels(userID: user.id)
            async let fetchedOrders = environment.orderService.fetchOrders(userID: user.id, role: user.role)
            async let fetchedRoutes = environment.dispatchService.fetchRoutes(userID: user.id, role: user.role)

            channels = try await fetchedChannels

            if selectedChannelID == nil || !channels.contains(where: { $0.id == selectedChannelID }) {
                selectedChannelID = channels.first?.id
            }

            if let selectedChannelID {
                async let fetchedPosts = environment.channelFeedService.fetchPosts(channelID: selectedChannelID)
                async let fetchedDrivers = environment.channelFeedService.fetchDrivers(channelID: selectedChannelID)
                posts = try await fetchedPosts
                drivers = try await fetchedDrivers
            } else {
                posts = []
                drivers = []
                inventoryCatalog = nil
                adminAuditEvents = []
            }

            orders = try await fetchedOrders
            routes = try await fetchedRoutes

            let validOrderIDs = Set(orders.map(\.id))
            ledgerByOrderID = ledgerByOrderID.filter { validOrderIDs.contains($0.key) }

            if user.role == .owner {
                await refreshInventoryAndAudit()
            } else {
                inventoryCatalog = nil
                adminAuditEvents = []
            }

            environment.analyticsService.track(event: "refresh_all", properties: ["trigger": trigger])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPollingLoop() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self else { return }
                if self.user == nil { continue }
                await self.refreshAll(trigger: "polling")
            }
        }
    }

    private func stopPollingLoop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func normalizeSelectedTab(for role: UserRole) {
        switch role {
        case .owner:
            return
        case .driver:
            if selectedTab == .feed {
                selectedTab = .orders
            }
        case .follower:
            if selectedTab == .dispatch {
                selectedTab = .feed
            }
        }
    }
}

enum RouteStopReorderDirection {
    case up
    case down
}
