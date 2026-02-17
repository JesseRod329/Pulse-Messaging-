import Foundation

struct FeatureFlags {
    var authV2 = true
    var feedV2 = true
    var ordersV2 = true
    var timelineV2 = true
    var assignDriverV2 = true
    var inventoryV2 = true
    var adminV2 = true
    var orderSheetV2 = true
    var glassChromeV2 = true
    var motionV2 = true

    // Demo role shortcuts remain hidden unless explicitly enabled.
    var showDemoAuthShortcuts = false

    static func fromLaunchArguments(_ arguments: [String]) -> FeatureFlags {
        var flags = FeatureFlags()

        if arguments.contains("-legacy-auth") { flags.authV2 = false }
        if arguments.contains("-legacy-feed") { flags.feedV2 = false }
        if arguments.contains("-legacy-orders") { flags.ordersV2 = false }
        if arguments.contains("-legacy-timeline") { flags.timelineV2 = false }
        if arguments.contains("-legacy-assign-driver") { flags.assignDriverV2 = false }
        if arguments.contains("-legacy-inventory") { flags.inventoryV2 = false }
        if arguments.contains("-legacy-admin") { flags.adminV2 = false }
        if arguments.contains("-legacy-order-sheet") { flags.orderSheetV2 = false }
        if arguments.contains("-legacy-glass") { flags.glassChromeV2 = false }
        if arguments.contains("-legacy-motion") { flags.motionV2 = false }

        if arguments.contains("-auth-demo-shortcuts") || arguments.contains("-debug-auth-shortcuts") {
            flags.showDemoAuthShortcuts = true
        }

        return flags
    }
}
