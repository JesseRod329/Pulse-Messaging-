import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, AppTheme.tabBarOverlayHeight + AppTheme.tabBarBottomInset)
                .appScreenBackground()
                .ignoresSafeArea(edges: .bottom)

            customTabBar
                .padding(.horizontal, 14)
                .padding(.bottom, AppTheme.tabBarBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            normalizeSelectionIfNeeded()
        }
        .onChange(of: coordinator.user?.role) { _, _ in
            normalizeSelectionIfNeeded()
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch coordinator.selectedTab {
        case .feed:
            if availableTabs.contains(.feed) {
                FeedView()
            } else {
                OrdersView()
            }
        case .orders:
            OrdersView()
        case .dispatch:
            if availableTabs.contains(.dispatch) {
                DispatchView()
            } else {
                OrdersView()
            }
        case .profile:
            ProfileView()
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 8) {
            ForEach(availableTabs, id: \.self) { tab in
                Button {
                    coordinator.selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 20, weight: .semibold))
                        Text(tabTitle(tab))
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(coordinator.selectedTab == tab ? AppTheme.accentBlue : AppTheme.textMuted)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(coordinator.selectedTab == tab ? AppTheme.accentBlue.opacity(0.18) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tabTitle(tab).lowercased())")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.tabBar.opacity(0.94), AppTheme.navBar.opacity(0.90)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    private var availableTabs: [MainTab] {
        guard let role = coordinator.user?.role else {
            return [.feed, .orders, .dispatch, .profile]
        }
        switch role {
        case .owner:
            return [.feed, .orders, .dispatch, .profile]
        case .driver:
            return [.orders, .dispatch, .profile]
        case .follower:
            return [.feed, .orders, .profile]
        }
    }

    private func normalizeSelectionIfNeeded() {
        guard let first = availableTabs.first else { return }
        if !availableTabs.contains(coordinator.selectedTab) {
            coordinator.selectedTab = first
        }
    }

    private func tabTitle(_ tab: MainTab) -> String {
        switch tab {
        case .feed:
            return "Feed"
        case .orders:
            return "Orders"
        case .dispatch:
            return "Dispatch"
        case .profile:
            return "Profile"
        }
    }

    private func tabIcon(_ tab: MainTab) -> String {
        switch tab {
        case .feed:
            return "photo.stack"
        case .orders:
            return "shippingbox"
        case .dispatch:
            return "map"
        case .profile:
            return "person.crop.circle"
        }
    }
}
