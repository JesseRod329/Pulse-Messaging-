import SwiftUI
import BoppyV2Core

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var orderStore: OrderStore
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        Group {
            if authStore.user == nil {
                PhoneAuthView()
            } else if needsProfileSetup(authStore.user) {
                ProfileSetupView(role: authStore.user!.role) { name in
                    Task { await coordinator.updateDisplayName(name) }
                }
            } else {
                MainShellView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenBackground()
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if !networkMonitor.isOnline {
                    Text("No connection — showing cached data")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                        .foregroundStyle(AppTheme.warning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(AppTheme.surfaceElevated)
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.warning.opacity(0.55), lineWidth: 1)
                        )
                        .accessibilityLabel("Offline mode")
                        .accessibilityHint("Network is unavailable. Cached data is shown.")
                        .accessibilityIdentifier("root.offlineBanner")
                }

                if authStore.isLoading {
                    ProgressView()
                        .tint(AppTheme.textMuted)
                        .scaleEffect(0.8)
                        .padding(AppTheme.space8)
                        .background(AppTheme.surfaceElevated.opacity(0.85), in: Circle())
                        .accessibilityLabel("Syncing data")
                        .accessibilityHint("Updates are in progress.")
                        .accessibilityIdentifier("root.syncing")
                }
            }
            .padding(.top, 10)
        }
        .alert("Error", isPresented: Binding(
            get: { authStore.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    coordinator.clearPresentedError()
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authStore.errorMessage ?? "Unknown error")
        }
        .fullScreenCover(item: Binding(
            get: { orderStore.activeOrderPost.map(OrderSheetToken.init) },
            set: { value in
                if value == nil {
                    orderStore.activeOrderPost = nil
                    orderStore.activeOrderPrefilledQuote = nil
                }
            }
        )) { token in
            OrderRequestSheet(post: token.post)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            coordinator.setNetworkOnline(networkMonitor.isOnline)
        }
        .onChange(of: networkMonitor.isOnline) { _, isOnline in
            coordinator.setNetworkOnline(isOnline)
        }
    }

    private func needsProfileSetup(_ user: SessionUser?) -> Bool {
        guard let user, user.role != .owner else { return false }
        let defaults: Set<String> = ["Follower", "Driver", "follower", "driver", "Member", "member", ""]
        return defaults.contains(user.displayName.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct OrderSheetToken: Identifiable {
    let post: ChannelPost
    var id: String { post.id }
}
