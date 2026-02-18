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

        #if !DEBUG
        // In Release builds, never silently fall back to demo mode.
        // If Supabase config is missing, the app should fail visibly
        // rather than shipping InMemoryBackend to TestFlight/App Store.
        if !forceLocalDemo {
            fatalError("Supabase configuration missing. Add a valid Release.xcconfig with SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_EDGE_BASE_URL.")
        }
        #endif

        let backend = InMemoryBackend()

        var localFlags = featureFlags
        localFlags.showDemoAuthShortcuts = true

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
            featureFlags: localFlags
        )
    }
}
