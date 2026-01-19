//
//  SettingsView.swift
//  Pulse
//
//  Settings and preferences for Pulse.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared
    @State private var unifiedTransport = UnifiedTransportManager.shared
    @State private var geohashService = GeohashService.shared
    @StateObject private var soundManager = SoundManager.shared

    // Settings state
    @AppStorage("meshEnabled") private var meshEnabled = true
    @AppStorage("nostrEnabled") private var nostrEnabled = false
    @AppStorage("locationChannelsEnabled") private var locationChannelsEnabled = false
    @AppStorage("maxHops") private var maxHops = 7
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("linkPreviewsEnabled") private var linkPreviewsEnabled = true
    @AppStorage("shareProfileInDiscovery") private var shareProfileInDiscovery = true
    @AppStorage("autoAcceptInvites") private var autoAcceptInvites = true

    // Lightning settings
    @AppStorage("preferredWallet") private var preferredWallet: String = LightningWallet.automatic.rawValue
    @AppStorage("defaultZapAmount") private var defaultZapAmount = 1000
    @AppStorage("lightningAddress") private var lightningAddress = ""

    // Animation state
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Theme Section
                    themeSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Transport Section
                    transportSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.05), value: showContent)

                    // Network Section
                    networkSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)

                    // Privacy Section
                    privacySection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: showContent)

                    // Lightning Section
                    lightningSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.175), value: showContent)

                    // About Section
                    aboutSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
                }
                .padding()
            }
            .background(themeManager.colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if hapticFeedback {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.accent)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Closes settings")
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
        .onChange(of: nostrEnabled) { _, newValue in
            if newValue && !NostrTransport.supportsSigning {
                ErrorManager.shared.showBanner("Nostr relay is disabled: signing support not available yet.")
                nostrEnabled = false
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Appearance", icon: "paintbrush.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PulseTheme.allCases) { theme in
                    themeButton(theme)
                }
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func themeButton(_ theme: PulseTheme) -> some View {
        let colors = ThemeColors.colors(for: theme)
        let isSelected = themeManager.currentTheme == theme

        return Button {
            themeManager.setTheme(theme)
            if hapticFeedback {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(colors.background)
                        .frame(width: 50, height: 50)

                    Circle()
                        .fill(colors.accent)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .strokeBorder(themeManager.colors.accent, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }

                Text(theme.displayName)
                    .font(.pulseCaption)
                    .foregroundStyle(isSelected ? themeManager.colors.accent : themeManager.colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to select this theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Transport Section

    private var transportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Transport", icon: "antenna.radiowaves.left.and.right")

            VStack(spacing: 0) {
                settingsToggle(
                    "Mesh Network",
                    subtitle: "Local P2P via Bluetooth & WiFi",
                    icon: "dot.radiowaves.left.and.right",
                    isOn: $meshEnabled
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Nostr Relay",
                    subtitle: "Global messaging via internet",
                    icon: "globe",
                    isOn: $nostrEnabled
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Location Channels",
                    subtitle: "Join area-based chat rooms",
                    icon: "location.fill",
                    isOn: $locationChannelsEnabled
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Auto-Accept Invites",
                    subtitle: "Automatically accept nearby session requests",
                    icon: "checkmark.shield",
                    isOn: $autoAcceptInvites
                )
            }

            if nostrEnabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(themeManager.colors.accent)
                    Text("Connected to \(unifiedTransport.stats.nostrRelays) Nostr relays")
                        .font(.pulseCaption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Network", icon: "network")

            VStack(spacing: 12) {
                HStack {
                    Text("Max Relay Hops")
                        .foregroundStyle(themeManager.colors.text)
                    Spacer()
                    Picker("", selection: $maxHops) {
                        ForEach([3, 5, 7, 10], id: \.self) { hop in
                            Text("\(hop)").tag(hop)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                // Network Stats
                let stats = unifiedTransport.stats
                VStack(spacing: 8) {
                    statRow("Direct Peers", value: "\(stats.networkStats.directConnections)")
                    statRow("Relayed Peers", value: "\(stats.networkStats.relayedConnections)")
                    statRow("Messages Sent", value: "\(stats.totalSent)")
                    statRow("Messages Received", value: "\(stats.totalReceived)")
                    statRow("Duplicates Blocked", value: "\(stats.dedupStats.blocked)")
                }
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Privacy & Feedback", icon: "hand.raised.fill")

            VStack(spacing: 0) {
                settingsToggle(
                    "Haptic Feedback",
                    subtitle: "Vibration on interactions",
                    icon: "iphone.radiowaves.left.and.right",
                    isOn: $hapticFeedback
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Sound Effects",
                    subtitle: "Audio feedback",
                    icon: "speaker.wave.2.fill",
                    isOn: $soundManager.soundEnabled
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Link Previews",
                    subtitle: "Fetch previews for links in chat",
                    icon: "link",
                    isOn: $linkPreviewsEnabled
                )

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                settingsToggle(
                    "Share Profile in Discovery",
                    subtitle: "Broadcast handle, tech stack, and place",
                    icon: "eye",
                    isOn: $shareProfileInDiscovery
                )
            }

            Button {
                clearAllData()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
                .foregroundStyle(themeManager.colors.error)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.colors.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Clear all data")
            .accessibilityHint("Deletes all app data including messages and settings")
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func clearAllData() {
        HapticManager.shared.notify(.warning)

        // Reset UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Reset Keychain
        _ = IdentityManager.shared.deleteIdentity()

        // Reset Files
        VoiceNoteManager.shared.cleanupOrphanedFiles()

        // Reset Database
        PersistenceManager.shared.deleteAllData()

        // Reset Places
        PlaceManager.shared.clearPlace()

        // Success feedback
        HapticManager.shared.notify(.success)

        // Dismiss to restart/onboarding (in a real app, might need a hard reset or state update)
        dismiss()
    }

    // MARK: - Lightning Section

    private var lightningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Lightning", icon: "bolt.fill")

            VStack(spacing: 0) {
                // Lightning Address display
                HStack(spacing: 12) {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundStyle(.yellow)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lightning Address")
                            .foregroundStyle(themeManager.colors.text)
                        if lightningAddress.isEmpty {
                            Text("Set in Profile to receive zaps")
                                .font(.pulseCaption)
                                .foregroundStyle(themeManager.colors.textSecondary)
                        } else {
                            Text(lightningAddress)
                                .font(.pulseCaption)
                                .foregroundStyle(themeManager.colors.accent)
                        }
                    }

                    Spacer()

                    if !lightningAddress.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(themeManager.colors.success)
                    }
                }
                .padding(.vertical, 8)

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                // Preferred Wallet
                HStack(spacing: 12) {
                    Image(systemName: "wallet.pass.fill")
                        .foregroundStyle(themeManager.colors.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preferred Wallet")
                            .foregroundStyle(themeManager.colors.text)
                        Text("App to open for payments")
                            .font(.pulseCaption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }

                    Spacer()

                    Picker("", selection: $preferredWallet) {
                        ForEach(LightningWallet.allCases, id: \.rawValue) { wallet in
                            Text(wallet.rawValue).tag(wallet.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.colors.accent)
                }
                .padding(.vertical, 8)

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                // Default Zap Amount
                HStack(spacing: 12) {
                    Image(systemName: "number.circle.fill")
                        .foregroundStyle(themeManager.colors.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Zap Amount")
                            .foregroundStyle(themeManager.colors.text)
                        Text("For quick zaps")
                            .font(.pulseCaption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }

                    Spacer()

                    Picker("", selection: $defaultZapAmount) {
                        ForEach(ZapAmount.allCases, id: \.rawValue) { amount in
                            Text(amount.displayName).tag(amount.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.colors.accent)
                }
                .padding(.vertical, 8)
            }

            // Info about zaps
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(themeManager.colors.accent)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zaps are Bitcoin micropayments sent via Lightning Network.")
                        .font(.pulseCaption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                    Text("You need a Lightning wallet to send and receive zaps.")
                        .font(.pulseCaption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("About", icon: "info.circle.fill")

            VStack(spacing: 12) {
                HStack {
                    Text("Version")
                        .foregroundStyle(themeManager.colors.text)
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(themeManager.colors.textSecondary)
                }

                Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                HStack {
                    Text("Build")
                        .foregroundStyle(themeManager.colors.text)
                    Spacer()
                    Text("Phase 5 - BitChat Integration")
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .font(.pulseCaption)
                }
            }

            // Features list
            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.pulseLabel)
                    .foregroundStyle(themeManager.colors.text)

                featureRow("E2E Encryption", description: "Curve25519 + AES-GCM")
                featureRow("Multi-hop Mesh", description: "Up to 7 relay hops")
                featureRow("Nostr Fallback", description: "Global internet relay")
                featureRow("Location Channels", description: "Geohash-based rooms")
                featureRow("Lightning Zaps", description: "NIP-57 micropayments")
            }
            .padding(.top, 8)
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.colors.accent)
            Text(title)
                .font(.pulseSectionHeader)
                .foregroundStyle(themeManager.colors.text)
        }
    }

    private func settingsToggle(_ title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.colors.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(themeManager.colors.text)
                Text(subtitle)
                    .font(.pulseCaption)
                    .foregroundStyle(themeManager.colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(themeManager.colors.accent)
                .accessibilityLabel(title)
                .accessibilityValue(isOn.wrappedValue ? "Enabled" : "Disabled")
                .accessibilityHint(subtitle)
        }
        .padding(.vertical, 8)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(themeManager.colors.textSecondary)
            Spacer()
            Text(value)
                .font(.pulseTimestamp)
                .foregroundStyle(themeManager.colors.text)
        }
    }

    private func featureRow(_ title: String, description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(themeManager.colors.success)
                .font(.caption)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundStyle(themeManager.colors.text)
            Text("·")
                .foregroundStyle(themeManager.colors.textSecondary)
                .accessibilityHidden(true)
            Text(description)
                .font(.caption)
                .foregroundStyle(themeManager.colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

#Preview {
    SettingsView()
}
