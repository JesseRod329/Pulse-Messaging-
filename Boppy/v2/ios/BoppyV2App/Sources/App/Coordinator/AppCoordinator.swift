import Foundation
import SwiftUI
import Combine
import BoppyV2Core

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var selectedTab: MainTab = .feed

    let authStore: AuthStore
    let feedStore: FeedStore
    let orderStore: OrderStore
    let dispatchStore: DispatchStore
    let inventoryStore: InventoryStore
    let adminStore: AdminStore

    let environment: AppEnvironment
    var pollingTask: Task<Void, Never>?
    let launchArguments = ProcessInfo.processInfo.arguments
    var lastRefreshAt: Date?
    var storeObservers: [AnyCancellable] = []

    init(
        environment: AppEnvironment,
        authStore: AuthStore,
        feedStore: FeedStore,
        orderStore: OrderStore,
        dispatchStore: DispatchStore,
        inventoryStore: InventoryStore,
        adminStore: AdminStore
    ) {
        self.environment = environment
        self.authStore = authStore
        self.feedStore = feedStore
        self.orderStore = orderStore
        self.dispatchStore = dispatchStore
        self.inventoryStore = inventoryStore
        self.adminStore = adminStore
        bindStoreUpdates()
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            environment: environment,
            authStore: AuthStore(),
            feedStore: FeedStore(),
            orderStore: OrderStore(),
            dispatchStore: DispatchStore(),
            inventoryStore: InventoryStore(),
            adminStore: AdminStore()
        )
    }

    deinit {
        pollingTask?.cancel()
    }

    func bindStoreUpdates() {
        authStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
        feedStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
        orderStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
        dispatchStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
        inventoryStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
        adminStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeObservers)
    }

    func bootstrap() async {
        do {
            try await authStore.bootstrapSession(authService: environment.authService)

            // QA override to force auth screen visibility in local demo mode.
            if launchArguments.contains("-show-auth-screen") {
                authStore.user = nil
                return
            }

            if authStore.user == nil, environment.backendMode == .localDemo {
                try await authStore.requestOTP(
                    phone: "+15550000001",
                    authService: environment.authService,
                    analyticsService: environment.analyticsService
                )
                _ = try await authStore.verifyOTP(
                    phone: "+15550000001",
                    code: "123456",
                    authService: environment.authService,
                    analyticsService: environment.analyticsService
                )
            }
            if authStore.user != nil {
                if let startTab = launchStartTab() {
                    selectedTab = startTab
                }
                startPollingLoop()
                await refreshAll()
                if let startTab = launchStartTab() {
                    selectedTab = startTab
                }
            }
        } catch {
            handleError(error)
        }
    }

    func requestOTP(phone: String) async {
        guard ensureOnline() else { return }
        do {
            try await authStore.requestOTP(
                phone: phone,
                authService: environment.authService,
                analyticsService: environment.analyticsService
            )
        } catch {
            handleError(error)
        }
    }

    func verifyOTP(phone: String, code: String) async {
        guard ensureOnline() else { return }
        do {
            _ = try await authStore.verifyOTP(
                phone: phone,
                code: code,
                authService: environment.authService,
                analyticsService: environment.analyticsService
            )
            startPollingLoop()
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func signOut(preserveError: Bool = false) async {
        stopPollingLoop()
        await environment.authService.signOut()
        feedStore.clear()
        orderStore.clear()
        dispatchStore.clear()
        inventoryStore.clear()
        adminStore.clear()
        authStore.applySignOutState(preserveError: preserveError)
        lastRefreshAt = nil
    }

    func handleDeepLink(_ url: URL) async {
        guard url.scheme == "beambox" else { return }

        if url.host == "invite" {
            let token = url.pathComponents.dropFirst().joined(separator: "")
            if !token.isEmpty {
                authStore.inviteTokenInput = token
                await joinChannel(using: token)
            }
        }
    }

    func refreshAll() async {
        await refreshAll(trigger: "manual")
    }

    func setNetworkOnline(_ isOnline: Bool) {
        authStore.isOffline = !isOnline
    }

    func handleSceneDidBecomeActive() async {
        guard authStore.user != nil else { return }
        if let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < 30 {
            return
        }
        await refreshAll(trigger: "foreground")
    }

    func clearPresentedError() {
        authStore.clearPresentedError()
    }

    func present(_ appError: AppError) {
        authStore.present(appError)
    }

    func present(_ error: Error) {
        handleError(error)
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

    var featureFlags: FeatureFlags {
        environment.featureFlags
    }

    func refreshAll(trigger: String) async {
        guard let user = authStore.user else { return }
        if authStore.isLoading { return }

        normalizeSelectedTab(for: user.role)

        authStore.isLoading = true
        defer { authStore.isLoading = false }

        do {
            async let feedRefresh: Void = feedStore.refresh(
                userID: user.id,
                channelFeedService: environment.channelFeedService
            )
            async let orderRefresh: Void = orderStore.refreshOrders(
                userID: user.id,
                role: user.role,
                orderService: environment.orderService
            )
            async let routeRefresh: Void = dispatchStore.refreshRoutes(
                userID: user.id,
                role: user.role,
                dispatchService: environment.dispatchService
            )
            _ = try await (feedRefresh, orderRefresh, routeRefresh)

            if user.role == .owner, let channelID = feedStore.selectedChannelID {
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
            } else {
                inventoryStore.clear()
                adminStore.clear()
            }

            environment.analyticsService.track(event: "refresh_all", properties: ["trigger": trigger])
            lastRefreshAt = Date()
        } catch {
            handleError(error)
        }
    }

    func startPollingLoop() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self else { return }
                if self.authStore.user == nil { continue }
                await self.refreshAll(trigger: "polling")
            }
        }
    }

    func stopPollingLoop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func normalizeSelectedTab(for role: UserRole) {
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

    func launchStartTab() -> MainTab? {
        guard let flagIndex = launchArguments.firstIndex(of: "-start-tab") else { return nil }
        let valueIndex = launchArguments.index(after: flagIndex)
        guard launchArguments.indices.contains(valueIndex) else { return nil }

        switch launchArguments[valueIndex].lowercased() {
        case "feed":
            return .feed
        case "orders":
            return .orders
        case "dispatch":
            return .dispatch
        case "profile":
            return .profile
        default:
            return nil
        }
    }

    func ensureOnline() -> Bool {
        if authStore.isOffline {
            authStore.present(.network(URLError(.notConnectedToInternet)))
            return false
        }
        return true
    }

    func handleError(_ error: Error) {
        let mapped = mapError(error)
        authStore.present(mapped, fallbackMessage: error.localizedDescription)

        if case .auth(.sessionExpired) = mapped, authStore.user != nil {
            Task { [weak self] in
                guard let self else { return }
                // Verify the token is truly invalid before nuking the session.
                // A single 401 from a data/edge endpoint shouldn't sign out
                // if the underlying auth token is still valid.
                do {
                    _ = try await self.environment.authService.currentSession()
                    // Token is still good — the 401 was from a data endpoint,
                    // not an expired session. Error is already shown, don't sign out.
                } catch {
                    // Token is truly expired/invalid — sign out.
                    await self.signOut(preserveError: true)
                }
            }
        }
    }

    func mapError(_ error: Error) -> AppError {
        if let clientError = error as? SupabaseClientError {
            switch clientError {
            case .unauthorized:
                return .auth(.sessionExpired)
            case .missingSession:
                return .auth(.missingSession)
            case let .server(status, message):
                if status == 401 {
                    return .auth(.sessionExpired)
                }
                if status == 403 {
                    return .auth(.forbidden)
                }
                return .backend(statusCode: status, message: message)
            case let .decoding(decodingError):
                return .unknown("Response decode failed: \(decodingError.localizedDescription)")
            case .invalidURL:
                return .validation("Invalid backend URL configuration.")
            case .invalidResponse:
                return .backend(statusCode: 500, message: "Invalid backend response.")
            }
        }
        return AppError.map(error)
    }
}

enum RouteStopReorderDirection {
    case up
    case down
}
