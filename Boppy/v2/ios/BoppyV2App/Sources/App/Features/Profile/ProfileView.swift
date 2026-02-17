import SwiftUI
import BoppyV2Core

struct ProfileView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @ScaledMetric(relativeTo: .body) private var heroIconSize: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var heroGlyphSize: CGFloat = 16

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        profileHero
                        sessionCard

                        if authStore.user?.role == .owner {
                            ownerEntryPoints
                        }

                        Button("Sign Out", role: .destructive) {
                            Task { await coordinator.signOut() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Sign out")
                        .accessibilityHint("Signs out and clears your session.")
                        .accessibilityIdentifier("profile.signOut")
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, AppTheme.contentBottomPadding)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                        alignment: .top
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .refreshable {
                if authStore.user?.role == .owner {
                    await coordinator.refreshInventoryAndAudit()
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle(authStore.user?.role == .owner ? "Admin Controls" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if authStore.user?.role == .owner {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await coordinator.refreshInventoryAndAudit() }
                        } label: {
                            DesignIconView(icon: .refresh, size: 16, color: AppTheme.textSecondary)
                        }
                        .accessibilityLabel("Refresh admin data")
                        .accessibilityHint("Reloads inventory and audit data.")
                        .accessibilityIdentifier("profile.refreshAdmin")
                    }
                }
            }
        }
        .task {
            if authStore.user?.role == .owner {
                await coordinator.refreshInventoryAndAudit()
            }
        }
        .appScreenBackground()
    }

    private var profileHero: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.accentBlue)
                .frame(width: heroIconSize, height: heroIconSize)
                .overlay {
                    Image(systemName: AppTheme.brandSymbolName)
                        .font(AppTheme.symbolFont(heroGlyphSize, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("BeamBox Control")
                    .font(AppTheme.inter(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Owner operations and channel governance")
                    .font(AppTheme.inter(12, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            Text((authStore.user?.role.rawValue ?? "follower").uppercased())
                .font(AppTheme.inter(10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accentBlue.opacity(0.20), in: Capsule())
                .foregroundStyle(AppTheme.accentBlue)
        }
        .profileCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile summary")
        .accessibilityHint("Shows role context and app scope.")
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(AppTheme.inter(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let user = authStore.user {
                infoRow(label: "Backend", value: coordinator.backendModeLabel)
                infoRow(label: "User ID", value: user.id)
                infoRow(label: "Phone", value: user.phoneE164)
                infoRow(label: "Role", value: user.role.rawValue.capitalized)
            }
        }
        .profileCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session details")
        .accessibilityHint("Displays user and environment details.")
    }

    private var ownerEntryPoints: some View {
        VStack(spacing: 10) {
            NavigationLink {
                InventoryCatalogView()
                    .environmentObject(coordinator)
            } label: {
                AdminPanelCard(
                    title: "Inventory Catalog",
                    subtitle: "Search, stock badges, active order counts",
                    icon: "shippingbox"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open inventory catalog")
            .accessibilityHint("Opens inventory search, stock, and badge management.")
            .accessibilityIdentifier("profile.openInventoryCatalog")

            NavigationLink {
                AdminControlsView()
                    .environmentObject(coordinator)
            } label: {
                AdminPanelCard(
                    title: "Admin Controls",
                    subtitle: "Channels, invites, security logs, danger zone",
                    icon: "slider.horizontal.3"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open admin controls")
            .accessibilityHint("Opens channel, invite, and security controls.")
            .accessibilityIdentifier("profile.openAdminControls")
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(AppTheme.inter(10, weight: .bold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 86, alignment: .leading)

            Text(value)
                .font(AppTheme.inter(13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }
}

struct InventoryDraftInput {
    let name: String
    let sku: String
    let description: String
    let category: String
    let thumbnailURL: String?
    let stockOnHand: Int
    let lowStockThreshold: Int
    let defaultPriceCents: Int
    let showInCatalog: Bool
}

extension View {
    func profileCardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}
