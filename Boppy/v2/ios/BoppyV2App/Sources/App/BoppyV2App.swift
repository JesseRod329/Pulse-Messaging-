import SwiftUI
import UIKit

@main
struct BoppyV2App: App {
    @StateObject private var coordinator = AppCoordinator(environment: .bootstrap())

    init() {
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .preferredColorScheme(.dark)
                .task {
                    await coordinator.bootstrap()
                }
                .onOpenURL { url in
                    Task {
                        await coordinator.handleDeepLink(url)
                    }
                }
            
        }
    }

    private func configureGlobalAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.backgroundEffect = nil
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
