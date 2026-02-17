import Foundation
import BoppyV2Core

enum BackendMode: String {
    case liveSupabase
    case localDemo
}

struct AppEnvironment {
    let authService: AuthServiceProtocol
    let channelFeedService: ChannelFeedServiceProtocol
    let orderService: OrderServiceProtocol
    let dispatchService: DispatchServiceProtocol
    let inventoryService: InventoryServiceProtocol
    let adminService: AdminServiceProtocol
    let routingService: RoutingServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let backendMode: BackendMode
    let featureFlags: FeatureFlags

    static func bootstrap() -> AppEnvironment {
        let analytics = NoopAnalyticsService()
        let routing = DistanceRouter()
        let launchArguments = ProcessInfo.processInfo.arguments
        let forceLocalDemo = launchArguments.contains("-force-local-demo")
        let featureFlags = FeatureFlags.fromLaunchArguments(launchArguments)

        if !forceLocalDemo, let config = SupabaseConfig.fromBundle() {
            let backend = LiveSupabaseBackend(config: config, analytics: analytics)
            return AppEnvironment(
                authService: backend,
                channelFeedService: backend,
                orderService: backend,
                dispatchService: backend,
                inventoryService: backend,
                adminService: backend,
                routingService: routing,
                analyticsService: analytics,
                backendMode: .liveSupabase,
                featureFlags: featureFlags
            )
        }

        let backend = InMemoryBackend()

        return AppEnvironment(
            authService: backend,
            channelFeedService: backend,
            orderService: backend,
            dispatchService: backend,
            inventoryService: backend,
            adminService: backend,
            routingService: routing,
            analyticsService: analytics,
            backendMode: .localDemo,
            featureFlags: featureFlags
        )
    }
}
