import XCTest
import BoppyV2Core
@testable import Boppy_V2

final class SmokeTests: XCTestCase {
    private func makeEnvironment() -> AppEnvironment {
        let backend = InMemoryBackend()
        let flags = FeatureFlags.fromLaunchArguments([])
        return AppEnvironment(
            authService: backend,
            channelFeedService: backend,
            orderService: backend,
            dispatchService: backend,
            inventoryService: backend,
            adminService: backend,
            routingService: DistanceRouter(),
            analyticsService: NoopAnalyticsService(),
            backendMode: .localDemo,
            featureFlags: flags
        )
    }

    func testFeatureFlagsDefaultToV2() {
        let flags = FeatureFlags.fromLaunchArguments([])
        XCTAssertTrue(flags.authV2)
        XCTAssertTrue(flags.feedV2)
        XCTAssertTrue(flags.ordersV2)
        XCTAssertTrue(flags.timelineV2)
        XCTAssertTrue(flags.assignDriverV2)
        XCTAssertTrue(flags.inventoryV2)
        XCTAssertTrue(flags.adminV2)
        XCTAssertTrue(flags.orderSheetV2)
    }

    func testFeatureFlagsCanForceLegacy() {
        let flags = FeatureFlags.fromLaunchArguments([
            "-legacy-auth",
            "-legacy-feed",
            "-legacy-orders",
            "-legacy-timeline",
            "-legacy-assign-driver",
            "-legacy-inventory",
            "-legacy-admin",
            "-legacy-order-sheet",
            "-legacy-glass",
            "-legacy-motion"
        ])

        XCTAssertFalse(flags.authV2)
        XCTAssertFalse(flags.feedV2)
        XCTAssertFalse(flags.ordersV2)
        XCTAssertFalse(flags.timelineV2)
        XCTAssertFalse(flags.assignDriverV2)
        XCTAssertFalse(flags.inventoryV2)
        XCTAssertFalse(flags.adminV2)
        XCTAssertFalse(flags.orderSheetV2)
        XCTAssertFalse(flags.glassChromeV2)
        XCTAssertFalse(flags.motionV2)
    }

    func testDomainModelsAcceptOptionalFidelityMetadata() {
        let post = ChannelPost(
            id: "p1",
            channelID: "c1",
            authorID: "u1",
            postType: .image,
            caption: "caption",
            mediaPath: nil,
            slotRemaining: 4,
            slotLabel: "4 SLOTS LEFT",
            heroSubtitle: "priority",
            heroAspectRatio: 16.0 / 9.0
        )

        XCTAssertEqual(post.slotRemaining, 4)
        XCTAssertEqual(post.slotLabel, "4 SLOTS LEFT")

        let driver = DriverProfile(
            id: "d1",
            displayName: "Driver",
            avatarURL: "https://example.com/a.png",
            availability: "available",
            rating: 4.8,
            tripCount: 10,
            lastLat: 30,
            lastLng: -97
        )

        XCTAssertEqual(driver.availability, "available")
        XCTAssertEqual(driver.tripCount, 10)
    }

    @MainActor
    func testSignOutClearsInviteAndTransientState() async {
        let coordinator = AppCoordinator(environment: makeEnvironment())
        coordinator.authStore.user = SessionUser(id: "owner-1", phoneE164: "+15550000001", displayName: "Owner", role: .owner)
        coordinator.authStore.inviteTokenInput = "abc123"
        coordinator.authStore.latestInvite = ChannelInvite(
            id: "invite-1",
            channelID: "channel-main",
            token: "abc123",
            inviteURL: "https://example.com/i/abc123",
            expiresAt: Date().addingTimeInterval(3600),
            maxUses: 5
        )
        coordinator.orderStore.activeOrderPrefilledQuote = "quote"
        coordinator.authStore.errorMessage = "error"
        coordinator.authStore.appError = .validation("error")

        await coordinator.signOut()

        XCTAssertNil(coordinator.authStore.user)
        XCTAssertEqual(coordinator.authStore.inviteTokenInput, "")
        XCTAssertNil(coordinator.authStore.latestInvite)
        XCTAssertNil(coordinator.orderStore.activeOrderPrefilledQuote)
        XCTAssertNil(coordinator.authStore.errorMessage)
        XCTAssertNil(coordinator.authStore.appError)
    }

    @MainActor
    func testSetNetworkOnlineUpdatesAuthStoreOfflineState() {
        let coordinator = AppCoordinator(environment: makeEnvironment())

        coordinator.setNetworkOnline(false)
        XCTAssertTrue(coordinator.authStore.isOffline)

        coordinator.setNetworkOnline(true)
        XCTAssertFalse(coordinator.authStore.isOffline)
    }

    @MainActor
    func testHandleSceneDidBecomeActiveRefreshesThenThrottles() async {
        let coordinator = AppCoordinator(environment: makeEnvironment())
        coordinator.authStore.user = SessionUser(
            id: "owner-1",
            phoneE164: "+15550000001",
            displayName: "Owner",
            role: .owner
        )

        await coordinator.handleSceneDidBecomeActive()
        XCTAssertFalse(coordinator.feedStore.channels.isEmpty)

        coordinator.feedStore.channels = []
        await coordinator.handleSceneDidBecomeActive()
        XCTAssertTrue(
            coordinator.feedStore.channels.isEmpty,
            "Second foreground activation within throttle window should not trigger refresh."
        )
    }

    @MainActor
    func testOpenOrderSheetRequiresFollowerRole() {
        let coordinator = AppCoordinator(environment: makeEnvironment())
        let post = ChannelPost(
            id: "post-1",
            channelID: "channel-main",
            authorID: "owner-1",
            postType: .text,
            caption: "Sample",
            mediaPath: nil
        )

        coordinator.authStore.user = SessionUser(
            id: "owner-1",
            phoneE164: "+15550000001",
            displayName: "Owner",
            role: .owner
        )
        coordinator.openOrderSheet(for: post, prefilledQuote: "owner-note")
        XCTAssertNil(coordinator.orderStore.activeOrderPost)

        coordinator.authStore.user = SessionUser(
            id: "follower-1",
            phoneE164: "+15550000002",
            displayName: "Follower",
            role: .follower
        )
        coordinator.openOrderSheet(for: post, prefilledQuote: "follower-note")
        XCTAssertEqual(coordinator.orderStore.activeOrderPost?.id, post.id)
        XCTAssertEqual(coordinator.orderStore.activeOrderPrefilledQuote, "follower-note")
    }

    @MainActor
    func testUnauthorizedRefreshSignsOutAndPreservesSessionExpiredError() async {
        let backend = InMemoryBackend()
        let failingFeedService = UnauthorizedChannelFeedService(delegate: backend)
        let flags = FeatureFlags.fromLaunchArguments([])
        let environment = AppEnvironment(
            authService: backend,
            channelFeedService: failingFeedService,
            orderService: backend,
            dispatchService: backend,
            inventoryService: backend,
            adminService: backend,
            routingService: DistanceRouter(),
            analyticsService: NoopAnalyticsService(),
            backendMode: .localDemo,
            featureFlags: flags
        )

        let coordinator = AppCoordinator(environment: environment)
        coordinator.authStore.user = SessionUser(
            id: "owner-1",
            phoneE164: "+15550000001",
            displayName: "Owner",
            role: .owner
        )

        await coordinator.refreshAll()

        for _ in 0..<20 {
            if coordinator.authStore.user == nil { break }
            await Task.yield()
        }

        XCTAssertNil(coordinator.authStore.user)
        XCTAssertEqual(coordinator.authStore.appError, .auth(.sessionExpired))
        XCTAssertEqual(
            coordinator.authStore.errorMessage,
            AppError.auth(.sessionExpired).errorDescription
        )
        XCTAssertEqual(coordinator.authStore.inviteTokenInput, "")
        XCTAssertNil(coordinator.authStore.latestInvite)
    }
}

private struct UnauthorizedChannelFeedService: ChannelFeedServiceProtocol {
    let delegate: InMemoryBackend

    func createChannel(ownerID: String, title: String, description: String) async throws -> Channel {
        try await delegate.createChannel(ownerID: ownerID, title: title, description: description)
    }

    func fetchChannels(userID: String) async throws -> [Channel] {
        _ = userID
        throw SupabaseClientError.unauthorized
    }

    func fetchPosts(channelID: String) async throws -> [ChannelPost] {
        try await delegate.fetchPosts(channelID: channelID)
    }

    func fetchDrivers(channelID: String) async throws -> [DriverProfile] {
        try await delegate.fetchDrivers(channelID: channelID)
    }

    func fetchDriverCandidates(channelID: String, orderID: String?) async throws -> [DriverProfile] {
        try await delegate.fetchDriverCandidates(channelID: channelID, orderID: orderID)
    }

    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?
    ) async throws -> ChannelPost {
        try await delegate.createPost(
            channelID: channelID,
            authorID: authorID,
            postType: postType,
            caption: caption,
            mediaPath: mediaPath
        )
    }

    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?
    ) async throws -> ChannelInvite {
        try await delegate.createInvite(
            channelID: channelID,
            ownerID: ownerID,
            expiresInHours: expiresInHours,
            maxUses: maxUses
        )
    }

    func joinChannel(token: String, userID: String) async throws -> Channel {
        try await delegate.joinChannel(token: token, userID: userID)
    }
}
