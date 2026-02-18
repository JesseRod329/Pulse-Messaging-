import SwiftUI
import BoppyV2Core

struct AdminControlsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var feedStore: FeedStore
    @EnvironmentObject private var adminStore: AdminStore
    @State private var filter: ChannelFilter = .active
    @State private var maxUses = ""
    @State private var inviteExpiry = Date().addingTimeInterval(72 * 3600)
    @State private var inviteCopied = false
    @State private var showArchiveConfirmation = false
    @ScaledMetric(relativeTo: .caption) private var inviteStatusDotSize: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var sectionPadding: CGFloat = 10

    var body: some View {
        ScrollView {
            VStack(spacing: sectionSpacing) {
                driverManagementLink
                channelManagement
                invitesCard
                securityLogsCard
                dangerZone
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await coordinator.refreshInventoryAndAudit()
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("Admin Controls")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
    }

    private var driverManagementLink: some View {
        NavigationLink {
            DriverManagementView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.accentBlue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Drivers")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(feedStore.drivers.count) active driver\(feedStore.drivers.count == 1 ? "" : "s")")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(sectionPadding)
            .profileCardStyle()
        }
        .accessibilityLabel("Manage drivers")
        .accessibilityHint("View, add, or remove drivers from your channel.")
        .accessibilityIdentifier("profile.admin.manageDrivers")
    }

    private var channelManagement: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Channel Management")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            Picker("Filter", selection: $filter) {
                Text("Active").tag(ChannelFilter.active)
                Text("Archived").tag(ChannelFilter.archived)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Channel filter")
            .accessibilityHint("Switch between active and archived channels.")
            .accessibilityIdentifier("profile.admin.channelFilter")

            ForEach(filteredChannels, id: \.id) { channel in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.title)
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(channel.description)
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)
                        Text(channelMeta(channel))
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Spacer()

                    Button("Select") {
                        Task { await coordinator.selectChannel(channel.id) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Select channel")
                    .accessibilityHint("Sets \(channel.title) as the active channel.")
                    .accessibilityIdentifier("profile.selectChannel.\(channel.id)")
                }
                .padding(sectionPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
        }
        .profileCardStyle()
    }

    private var invitesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite Links")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            DatePicker("Expires", selection: $inviteExpiry, displayedComponents: [.date, .hourAndMinute])
                .tint(AppTheme.accentBlue)
                .accessibilityLabel("Invite expiration")
                .accessibilityHint("Sets invite expiry date and time.")

            TextField("Usage limit", text: $maxUses)
                .keyboardType(.numberPad)
                .accessibilityLabel("Invite usage limit")
                .accessibilityHint("Maximum number of times this invite can be used.")
                .accessibilityIdentifier("profile.admin.inviteUsageLimit")
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

            HStack {
                Button("Generate Invite") {
                    let hours = max(1, Int(inviteExpiry.timeIntervalSinceNow / 3600))
                    Task {
                        await coordinator.createInvite(expiresInHours: hours, maxUses: Int(maxUses))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authStore.isOffline)
                .accessibilityLabel("Generate invite")
                .accessibilityHint("Creates a new channel invite link.")
                .accessibilityIdentifier("profile.generateInvite")

                Spacer()

                if let invite = authStore.latestInvite {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: inviteStatusDotSize, height: inviteStatusDotSize)
                        Text(inviteUsageLabel(invite))
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                    }
                    .accessibilityLabel("Invite usage")
                    .accessibilityValue(inviteUsageLabel(invite))
                }
            }

            if let invite = authStore.latestInvite {
                Text(invite.token)
                    .font(.system(size: AppTheme.typeCaption, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
                    .textSelection(.enabled)
                    .accessibilityLabel("Invite token")
                    .accessibilityValue(invite.token)
                    .accessibilityIdentifier("profile.admin.inviteToken")
                Text("Expires \(invite.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppTheme.inter(AppTheme.typeCaption, weight: .regular))
                    .foregroundStyle(AppTheme.textMuted)
                    .accessibilityLabel("Invite expiration")
                    .accessibilityValue(invite.expiresAt.formatted(date: .abbreviated, time: .shortened))

                HStack(spacing: 8) {
                    ShareLink(item: invite.inviteURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentBlue)
                    .accessibilityLabel("Share invite link")
                    .accessibilityIdentifier("profile.admin.shareInvite")

                    Button {
                        UIPasteboard.general.string = invite.inviteURL
                        inviteCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            inviteCopied = false
                        }
                    } label: {
                        Label(inviteCopied ? "Copied!" : "Copy Link", systemImage: inviteCopied ? "checkmark" : "doc.on.doc")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy invite link")
                    .accessibilityIdentifier("profile.admin.copyInvite")
                }
            }
        }
        .profileCardStyle()
    }

    private var securityLogsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security & Logs")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(adminStore.adminAuditEvents.prefix(5), id: \.id) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.action)
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(event.createdAt.formatted())
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .regular))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            if adminStore.adminAuditEvents.isEmpty {
                Text("No audit events yet")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .profileCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Security and logs")
        .accessibilityHint("Recent admin audit activity.")
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Danger Zone")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.danger)

            Text("Archive the currently selected channel. This action is reversible through admin operations.")
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)

            Button("Archive Active Channel", role: .destructive) {
                showArchiveConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.danger)
            .disabled(authStore.isOffline)
            .accessibilityLabel("Archive active channel")
            .accessibilityHint("Archives the currently selected channel.")
            .accessibilityIdentifier("profile.archiveChannel")
            .alert("Archive Channel?", isPresented: $showArchiveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Archive", role: .destructive) {
                    Task { await coordinator.archiveActiveChannel() }
                }
            } message: {
                Text("This will archive the currently selected channel. You can restore it later through admin operations.")
            }
        }
        .profileCardStyle()
        .background(AppTheme.danger.opacity(0.05), in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.danger.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Danger zone")
        .accessibilityHint("Contains destructive channel administration actions.")
    }

    private var filteredChannels: [Channel] {
        switch filter {
        case .active:
            return feedStore.channels.filter(\.isActive)
        case .archived:
            return feedStore.channels.filter { !$0.isActive }
        }
    }

    private func inviteUsageLabel(_ invite: ChannelInvite) -> String {
        if let maxUses = invite.maxUses {
            return "0/\(maxUses) used"
        }
        return "Unlimited"
    }

    private func channelMeta(_ channel: Channel) -> String {
        let selected = feedStore.selectedChannelID == channel.id ? "selected" : "available"
        return selected.capitalized
    }
}

private enum ChannelFilter: String {
    case active
    case archived
}

private extension View {
    func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
