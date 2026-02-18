import Foundation

struct FeatureFlags {
    var glassChromeV2 = true
    var motionV2 = true

    // Demo role shortcuts remain hidden unless explicitly enabled.
    var showDemoAuthShortcuts = false

    static func fromLaunchArguments(_ arguments: [String]) -> FeatureFlags {
        var flags = FeatureFlags()

        if arguments.contains("-legacy-glass") { flags.glassChromeV2 = false }
        if arguments.contains("-legacy-motion") { flags.motionV2 = false }

        if arguments.contains("-auth-demo-shortcuts") || arguments.contains("-debug-auth-shortcuts") {
            flags.showDemoAuthShortcuts = true
        }

        return flags
    }
}
