import SwiftUI
import UIKit

struct MainShellView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @State private var roleToastMessage: String?
    @ScaledMetric(relativeTo: .body) private var tabIconFrameWidth: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var tabIconFrameHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var tabVerticalPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var tabLabelTracking: CGFloat = 0.6

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabView
                .id(coordinator.selectedTab)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .animation(.easeOut(duration: 0.2), value: coordinator.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .appScreenBackground()
                .ignoresSafeArea(.container, edges: .bottom)

            customTabBar
                .padding(.bottom, AppTheme.tabBarBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            normalizeSelectionIfNeeded()
        }
        .onChange(of: authStore.user?.role) { _, _ in
            normalizeSelectionIfNeeded()
        }
        .overlay(alignment: .top) {
            if let roleToastMessage {
                Text(roleToastMessage)
                    .font(AppTheme.inter(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.surfaceElevated)
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityLabel(roleToastMessage)
                    .accessibilityHint("Role-restricted tab feedback.")
                    .accessibilityIdentifier("shell.roleToast")
            }
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
            if authStore.user?.role == .follower {
                FollowerOrdersView()
            } else {
                OrdersView()
            }
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
        let glass = coordinator.featureFlags.glassChromeV2
        return VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.6))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(allTabs, id: \.self) { tab in
                    Button {
                        guard availableTabs.contains(tab) else {
                            if coordinator.featureFlags.motionV2 {
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                            showRoleToast(for: tab)
                            return
                        }
                        if coordinator.featureFlags.motionV2 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        roleToastMessage = nil
                        coordinator.selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            DesignIconView(
                                icon: tabIcon(tab),
                                size: 19,
                                color: tabTint(for: tab)
                            )
                                .frame(width: tabIconFrameWidth, height: tabIconFrameHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(coordinator.selectedTab == tab && availableTabs.contains(tab) ? AppTheme.accentBlue.opacity(0.18) : .clear)
                                )

                            Text(tabTitle(tab).uppercased())
                                .font(AppTheme.inter(10, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .tracking(tabLabelTracking)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, tabVerticalPadding)
                        .padding(.bottom, tabVerticalPadding)
                        .foregroundStyle(tabTint(for: tab))
                        .opacity(availableTabs.contains(tab) ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tabTitle(tab)) tab")
                    .accessibilityHint(availableTabs.contains(tab) ? "Opens \(tabTitle(tab)) screen." : "\(tabTitle(tab)) is unavailable for your role.")
                    .accessibilityIdentifier("tab.\(tabTitle(tab).lowercased())")
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .background {
                if glass {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(AppTheme.tabBar.opacity(0.45))
                } else {
                    AppTheme.tabBar.opacity(0.95)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background {
            if glass {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(AppTheme.tabBar.opacity(0.45))
            } else {
                AppTheme.tabBar.opacity(0.95)
            }
        }
    }

    private var availableTabs: [MainTab] {
        guard let role = authStore.user?.role else {
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

    private var allTabs: [MainTab] {
        [.feed, .orders, .dispatch, .profile]
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

    private func tabTint(for tab: MainTab) -> Color {
        guard availableTabs.contains(tab) else {
            return AppTheme.textMuted
        }
        return coordinator.selectedTab == tab ? AppTheme.accentBlue : AppTheme.textMuted
    }

    private func showRoleToast(for tab: MainTab) {
        guard let role = authStore.user?.role else { return }

        let message: String
        switch (role, tab) {
        case (.driver, .feed):
            message = "Feed is unavailable for driver accounts."
        case (.follower, .dispatch):
            message = "Dispatch is unavailable for follower accounts."
        default:
            message = "\(tabTitle(tab)) is unavailable for your role."
        }

        withAnimation(.easeOut(duration: 0.2)) {
            roleToastMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    roleToastMessage = nil
                }
            }
        }
    }

    private func tabIcon(_ tab: MainTab) -> DesignIcon {
        switch tab {
        case .feed:
            return .feed
        case .orders:
            return .orders
        case .dispatch:
            return .dispatch
        case .profile:
            return .profile
        }
    }
}
