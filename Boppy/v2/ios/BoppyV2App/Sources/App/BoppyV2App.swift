import SwiftUI
import UIKit

@main
struct BoppyV2App: App {
    @StateObject private var coordinator = AppCoordinator(environment: .bootstrap())
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.authStore)
                .environmentObject(coordinator.feedStore)
                .environmentObject(coordinator.orderStore)
                .environmentObject(coordinator.dispatchStore)
                .environmentObject(coordinator.inventoryStore)
                .environmentObject(coordinator.adminStore)
                .preferredColorScheme(.dark)
                .task {
                    await coordinator.bootstrap()
                }
                .onOpenURL { url in
                    Task {
                        await coordinator.handleDeepLink(url)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await coordinator.handleSceneDidBecomeActive()
                    }
                }
            
        }
    }

    private func configureGlobalAppearance() {
        let flags = FeatureFlags.fromLaunchArguments(ProcessInfo.processInfo.arguments)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundColor = flags.glassChromeV2 ? UIColor(AppTheme.navBar).withAlphaComponent(0.25) : UIColor(AppTheme.navBar).withAlphaComponent(0.96)
        navAppearance.backgroundEffect = flags.glassChromeV2 ? UIBlurEffect(style: .systemUltraThinMaterialDark) : nil
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        UIScrollView.appearance().backgroundColor = .clear
    }
}
