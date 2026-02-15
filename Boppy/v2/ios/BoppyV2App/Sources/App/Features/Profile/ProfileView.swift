import SwiftUI
import BoppyV2Core

struct ProfileView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var channelFilter: ChannelFilter = .active
    @State private var inviteMaxUsesInput = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            profileHero

                            if coordinator.user?.role == .owner {
                                ownerOpsSnapshot
                            }

                            sessionCard
                            deliveryCard

                            if coordinator.user?.role == .owner {
                                channelManagementCard
                                inviteLinksCard
                                inventoryCard
                                securityAndLogsCard
                                auditCard
                            }

                            Button("Sign Out", role: .destructive) {
                                Task { await coordinator.signOut() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AppTheme.screenGradient)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(coordinator.user?.role == .owner ? "Admin Controls" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if coordinator.user?.role == .owner {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await coordinator.refreshInventoryAndAudit() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityIdentifier("profile.refreshAdmin")
                    }
                }
            }
        }
        .task {
            if coordinator.user?.role == .owner {
                await coordinator.refreshInventoryAndAudit()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appScreenBackground()
    }

    private var activeChannels: [Channel] {
        coordinator.channels.filter(\.isActive)
    }

    private var archivedChannels: [Channel] {
        coordinator.channels.filter { !$0.isActive }
    }

    private var filteredChannels: [Channel] {
        switch channelFilter {
        case .active:
            return activeChannels
        case .archived:
            return archivedChannels
        }
    }

    private var profileHero: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.accentBlue)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: AppTheme.brandSymbolName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("BeamBox Control")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Owner operations and channel governance")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            Text((coordinator.user?.role.rawValue ?? "follower").uppercased())
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accentBlue.opacity(0.20), in: Capsule())
                .foregroundStyle(AppTheme.accentBlue)
        }
        .profileCardStyle()
    }

    private var ownerOpsSnapshot: some View {
        HStack(spacing: 8) {
            snapshotMetric(title: "Channels", value: "\(coordinator.channels.count)")
            snapshotMetric(title: "Drivers", value: "\(coordinator.drivers.count)")
            snapshotMetric(title: "Audits", value: "\(coordinator.adminAuditEvents.count)")
        }
        .profileCardStyle()
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let user = coordinator.user {
                infoRow(label: "Backend", value: coordinator.backendModeLabel)
                infoRow(label: "User ID", value: user.id)
                infoRow(label: "Phone", value: user.phoneE164)
                infoRow(label: "Role", value: user.role.rawValue.capitalized)
            }
        }
        .profileCardStyle()
    }

    private var deliveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delivery Model")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Invite-only channels. Followers can view posts and request quotes.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Owners and drivers manage routing, stop completion, and order workflow.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .profileCardStyle()
    }

    private var channelManagementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Channel Management")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .textCase(.uppercase)
                Spacer()
                Text("\(coordinator.channels.count) total")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentBlue.opacity(0.16), in: Capsule())
                    .foregroundStyle(AppTheme.accentBlue)
            }

            HStack(spacing: 8) {
                channelFilterButton(.active, count: activeChannels.count)
                channelFilterButton(.archived, count: archivedChannels.count)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            if filteredChannels.isEmpty {
                Text(channelFilter == .active ? "No active channels." : "No archived channels.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredChannels.prefix(6), id: \.id) { channel in
                        channelRow(channel)
                    }
                }
            }
        }
        .profileCardStyle()
    }

    private func channelFilterButton(_ filter: ChannelFilter, count: Int) -> some View {
        Button {
            channelFilter = filter
        } label: {
            HStack(spacing: 6) {
                Text(filter.rawValue)
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(channelFilter == filter ? AppTheme.accentBlue : AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(channelFilter == filter ? AppTheme.surface.opacity(0.55) : AppTheme.surface.opacity(0.24))
                    )
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(channelFilter == filter ? AppTheme.textPrimary : AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(channelFilter == filter ? AppTheme.accentBlue.opacity(0.85) : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.channelFilter.\(filter.rawValue.lowercased())")
    }

    private func channelRow(_ channel: Channel) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(channel.isActive ? AppTheme.accentBlue.opacity(0.18) : AppTheme.surfaceElevated.opacity(0.32))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: channel.isActive ? "number" : "archivebox")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(channel.isActive ? AppTheme.accentBlue : AppTheme.textMuted)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(channel.description.isEmpty ? (channel.isActive ? "Active channel" : "Archived channel") : channel.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if coordinator.selectedChannelID == channel.id {
                    Text("Selected")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.success.opacity(0.18), in: Capsule())
                        .foregroundStyle(AppTheme.success)
                }

                Button {
                    Task { await coordinator.selectChannel(channel.id) }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.selectChannel")

                if channel.isActive {
                    Button {
                        Task {
                            if coordinator.selectedChannelID != channel.id {
                                await coordinator.selectChannel(channel.id)
                            }
                            await coordinator.archiveActiveChannel()
                        }
                    } label: {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.archiveChannel")
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var inviteLinksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Invite Links")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    Task {
                        await coordinator.createInvite(expiresInHours: 72, maxUses: parsedInviteMaxUses)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Create New")
                    }
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accentBlue)
                .disabled(coordinator.selectedChannelID == nil)
                .accessibilityIdentifier("profile.createInvite")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Channel")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                    .textCase(.uppercase)
                Text(coordinator.selectedChannel?.title ?? "No channel selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if let invite = coordinator.latestInvite {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(invite.token)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(invite.maxUses.map { "\($0) max uses" } ?? "Unlimited uses")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Text(invite.inviteURL)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accentBlue)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.84))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }

            Text("Quick Creation")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)
                .textCase(.uppercase)

            TextField("Max usage limit (optional)", text: $inviteMaxUsesInput)
                .keyboardType(.numberPad)
                .feedInputFieldStyle()

            Button {
                Task {
                    await coordinator.createInvite(expiresInHours: 72, maxUses: parsedInviteMaxUses)
                }
            } label: {
                Label("Generate Invite Link", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentBlue)
            .disabled(coordinator.selectedChannelID == nil)
            .accessibilityIdentifier("profile.generateInvite")
        }
        .profileCardStyle()
    }

    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inventory")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let channel = coordinator.selectedChannel {
                infoRow(label: "Channel", value: channel.title)
            }

            if let catalog = coordinator.inventoryCatalog {
                let lowStock = catalog.items.filter { $0.trackStock && $0.stockOnHand <= $0.lowStockThreshold }.count
                Text("Items: \(catalog.items.count) • Low stock: \(lowStock)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                if let first = catalog.items.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick adjust: \(first.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack(spacing: 10) {
                            Button("-1") {
                                Task {
                                    await coordinator.adjustInventory(itemID: first.id, delta: -1, reason: "Owner manual adjustment (-1)")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.surfaceElevated)
                            .accessibilityIdentifier("profile.inventory.decrement")

                            Text("Stock \(first.stockOnHand)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textMuted)

                            Button("+1") {
                                Task {
                                    await coordinator.adjustInventory(itemID: first.id, delta: 1, reason: "Owner manual adjustment (+1)")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.surfaceElevated)
                            .accessibilityIdentifier("profile.inventory.increment")
                        }
                    }
                }

                ForEach(catalog.items.prefix(4), id: \.id) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(item.sku)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                        Text("\(item.stockOnHand)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No inventory loaded yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
            }

            HStack(spacing: 10) {
                Button("Add Sample Item") {
                    Task { await coordinator.createInventoryDraftItem() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentBlue)
                .accessibilityIdentifier("profile.inventory.addSample")

                Button("Refresh") {
                    Task { await coordinator.refreshInventoryAndAudit() }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.surfaceElevated)
                .accessibilityIdentifier("profile.inventory.refresh")
            }
        }
        .profileCardStyle()
    }

    private var securityAndLogsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security & Logs")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)
                .textCase(.uppercase)

            Button {
                Task { await coordinator.refreshInventoryAndAudit() }
            } label: {
                AdminPanelCard(
                    title: "View Sensitive Actions",
                    subtitle: "Audit trail for owner-level changes",
                    icon: "shield.lefthalf.filled"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.viewSensitiveActions")

            VStack(alignment: .leading, spacing: 4) {
                Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.danger)
                Text("Deactivating a channel is irreversible. Messages and media are queued for deletion.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.danger.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.danger.opacity(0.25), lineWidth: 1)
            )
        }
        .profileCardStyle()
    }

    private var auditCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Audit Events")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            if coordinator.adminAuditEvents.isEmpty {
                Text("No audit events yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ForEach(coordinator.adminAuditEvents.prefix(6), id: \.id) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(event.targetType): \(event.targetID)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
            }
        }
        .profileCardStyle()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var parsedInviteMaxUses: Int? {
        let trimmed = inviteMaxUsesInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func snapshotMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private enum ChannelFilter: String, CaseIterable {
    case active = "Active"
    case archived = "Archived"
}

private extension View {
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
            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    func feedInputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .tint(AppTheme.accentBlue)
    }
}
