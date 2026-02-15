import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .appScreenBackground()
                .ignoresSafeArea(.container, edges: .bottom)

            customTabBar
                .padding(.bottom, AppTheme.tabBarBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
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
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.6))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(availableTabs, id: \.self) { tab in
                    Button {
                        coordinator.selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabIcon(tab))
                                .font(.system(size: 19, weight: .semibold))
                                .frame(width: 34, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(coordinator.selectedTab == tab ? AppTheme.accentBlue.opacity(0.18) : .clear)
                                )

                            Text(tabTitle(tab).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                        .foregroundStyle(coordinator.selectedTab == tab ? AppTheme.accentBlue : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab.\(tabTitle(tab).lowercased())")
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .background(AppTheme.tabBar.opacity(0.95))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(AppTheme.tabBar.opacity(0.95))
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
            return "square.stack.3d.up.fill"
        case .orders:
            return "shippingbox.fill"
        case .dispatch:
            return "map.fill"
        case .profile:
            return "person.crop.circle.fill"
        }
    }
}
