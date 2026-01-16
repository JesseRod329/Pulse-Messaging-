//
//  LocationChannelsView.swift
//  Pulse
//
//  Location-based chat channels using geohash.
//

import SwiftUI
import CoreLocation

struct LocationChannelsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared
    @State private var geohashService = GeohashService.shared
    @State private var selectedPrecision: GeohashPrecision = .neighborhood
    @State private var showContent = false
    @State private var locationPulse = false
    @State private var joinAnimation = false
    @State private var showCreateChannel = false
    @State private var joinFeedback: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()

                if geohashService.locationPermissionStatus == .authorizedWhenInUse || geohashService.locationPermissionStatus == .authorizedAlways {
                    mainContentView
                } else {
                    permissionRequestView
                }
                
                // Feedback Toast
                if let feedback = joinFeedback {
                    VStack {
                        Text(feedback)
                            .font(.pulseLabel)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.green))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .zIndex(100)
                }
            }
            .navigationTitle("Location Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.accent)
                }
            }
            .sheet(isPresented: $showCreateChannel) {
                CreateChannelSheet(precision: selectedPrecision)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didJoinChannel)) { notification in
                if let name = notification.object as? String {
                    showJoinFeedback(name: name)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            // Only request if not determined, don't spam
            if geohashService.locationPermissionStatus == .notDetermined {
                geohashService.requestPermission()
            }
        }
    }
    
    private func showJoinFeedback(name: String) {
        joinFeedback = "Joined #\(name)"
        withAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                joinFeedback = nil
            }
        }
    }

    // MARK: - Views

    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(themeManager.colors.accent.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(themeManager.colors.accent)
            }

            VStack(spacing: 12) {
                Text("Enable Location")
                    .font(.title2.bold())
                    .foregroundStyle(themeManager.colors.text)

                Text("Pulse needs your location to find\nchannels in your area.")
                    .font(.body)
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                geohashService.requestPermission()
            } label: {
                Text("Allow Location Access")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(themeManager.colors.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
        .padding()
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Compact Status Header
            compactLocationHeader
                .padding(.vertical, 12)
                .background(themeManager.colors.cardBackground)

            // Precision Picker
            precisionPicker
                .padding(.vertical, 8)

            // Channel List
            channelList
        }
    }

    private var compactLocationHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.colors.accent)

                if let geohash = geohashService.currentGeohashes[selectedPrecision] {
                    Text(geohash.uppercased())
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(themeManager.colors.text)
                } else {
                    Text("Locating...")
                        .font(.caption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(themeManager.colors.accent.opacity(0.1))
            .clipShape(Capsule())

            Spacer()

            // Create/Join Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCreateChannel = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                    Text("Create Channel Here")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.colors.accent)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    private func joinCurrentLocation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        geohashService.selectedPrecision = selectedPrecision
        geohashService.joinCurrentChannel()
    }

    // MARK: - Location Header (Deprecated/Removed in favor of compact)
    // ... (Old locationHeader code removed/replaced)

    // MARK: - Precision Picker

    private var precisionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Range")
                .font(.subheadline.bold())
                .foregroundStyle(themeManager.colors.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(GeohashPrecision.allCases.enumerated()), id: \.element.id) { index, precision in
                        precisionChip(precision, index: index)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func precisionChip(_ precision: GeohashPrecision, index: Int) -> some View {
        let isSelected = selectedPrecision == precision

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPrecision = precision
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? themeManager.colors.accent : themeManager.colors.cardBackground)
                        .frame(width: 50, height: 50)

                    Text(precision.emoji)
                        .font(.title2)
                }

                Text(precision.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? themeManager.colors.accent : themeManager.colors.text)

                Text(precision.range)
                    .font(.pulseTimestamp)
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            .frame(width: 85)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? themeManager.colors.accent.opacity(0.15) : themeManager.colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? themeManager.colors.accent : themeManager.colors.textSecondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
            .shadow(color: isSelected ? themeManager.colors.accent.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel List

    private var channelList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if geohashService.activeChannels.isEmpty {
                    emptyState
                } else {
                    // Active channels header
                    HStack {
                        Text("Active Channels")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.colors.textSecondary)

                        Spacer()

                        Text("\(geohashService.activeChannels.count)")
                            .font(.caption.bold())
                            .foregroundStyle(themeManager.colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.colors.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(geohashService.activeChannels.enumerated()), id: \.element.id) { index, channel in
                        channelRow(channel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            // Animated map icon
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(locationPulse ? 1.2 : 1)
                    .opacity(locationPulse ? 0 : 1)

                Image(systemName: "map.fill")
                    .font(.pulseDisplay)
                    .foregroundStyle(themeManager.colors.accent)
            }

            VStack(spacing: 8) {
                Text("No Active Channels")
                    .font(.title3.bold())
                    .foregroundStyle(themeManager.colors.text)

                Text("Join a location channel to chat with\ndevelopers in your area")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Quick tips
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "location.fill", text: "Enable location for automatic channel detection")
                tipRow(icon: "slider.horizontal.3", text: "Choose range to find nearby or city-wide channels")
                tipRow(icon: "bubble.left.and.bubble.right.fill", text: "Chat with developers in the same area")
            }
            .padding()
            .background(themeManager.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .padding(.horizontal)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(themeManager.colors.accent)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundStyle(themeManager.colors.textSecondary)
        }
    }

    private func channelRow(_ channel: LocationChannel) -> some View {
        HStack(spacing: 14) {
            // Channel icon with glow
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent.opacity(0.2))
                    .frame(width: 54, height: 54)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.accent.opacity(0.3), themeManager.colors.accent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(channel.precisionLevel?.emoji ?? "📍")
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(channel.displayName ?? channel.id)
                    .font(.headline)
                    .foregroundStyle(themeManager.colors.text)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(channel.participantCount)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.green)

                    Text("•")
                        .foregroundStyle(themeManager.colors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.caption2)
                        Text(channel.precisionLevel?.range ?? "")
                            .font(.caption)
                    }
                    .foregroundStyle(themeManager.colors.textSecondary)
                }
            }

            Spacer()

            // Leave button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    geohashService.leaveChannel(id: channel.id)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(themeManager.colors.error.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "xmark")
                        .font(.pulseLabel)
                        .foregroundStyle(themeManager.colors.error)
                }
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(themeManager.colors.accent.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    LocationChannelsView()
}
