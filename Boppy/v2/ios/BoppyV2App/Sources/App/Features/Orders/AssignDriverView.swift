import SwiftUI
import UIKit
import BoppyV2Core

struct AssignDriverView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var feedStore: FeedStore
    @Environment(\.dismiss) private var dismiss

    let order: OrderRequest
    let onAssign: (String) -> Void

    @State private var searchText = ""
    @State private var selectedTab: DriverFilterTab = .nearby

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                searchField
                tabRail
                contextBanner

                ScrollView {
                    if filteredDrivers.isEmpty {
                        AppEmptyStateView(
                            icon: "person.crop.circle.badge.xmark",
                            title: "No Drivers Found",
                            subtitle: "Try a different filter or search term."
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredDrivers) { driver in
                                driverRow(driver)
                            }
                        }
                        .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    }
                }

                OrderMapPreview(order: order)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.bottom, 12)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close assign driver")
                        .accessibilityHint("Returns to orders without changing assignment.")
                        .accessibilityIdentifier("orders.assign.close")
                }
            }
        }
    }

    private var filteredDrivers: [DriverProfile] {
        let base: [DriverProfile] = {
            switch selectedTab {
            case .nearby:
                return feedStore.drivers
            case .available:
                return feedStore.drivers.filter { ($0.availability ?? "").lowercased() != "busy" }
            case .topRated:
                return feedStore.drivers.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            }
        }()

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return base
        }

        let query = searchText.lowercased()
        return base.filter { driver in
            driver.displayName.lowercased().contains(query)
        }
    }

    private var searchField: some View {
        SearchField(placeholder: "Search nearby drivers", text: $searchText)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 10)
            .accessibilityLabel("Search drivers")
            .accessibilityHint("Filters available drivers by name.")
            .accessibilityIdentifier("orders.assign.search")
    }

    private var tabRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DriverFilterTab.allCases, id: \.self) { tab in
                    FilterChip(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                    .accessibilityLabel("\(tab.rawValue) drivers")
                    .accessibilityHint("Filters the driver list.")
                    .accessibilityIdentifier("orders.assign.tab.\(tab.rawValue.lowercased())")
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
        }
    }

    private var contextBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(order.summaryTitle ?? "Order")
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(order.externalRef ?? order.id)
                    .font(.system(size: AppTheme.typeCaption, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            OrderStatusPill(status: order.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Order context")
        .accessibilityHint("Shows the selected order reference and current status.")
    }

    private func driverRow(_ driver: DriverProfile) -> some View {
        let distanceText = distanceMiles(from: driver, to: order).map { String(format: "%.1f mi", $0) } ?? "-"
        let etaText = distanceMiles(from: driver, to: order).map { "\(Int(max(8, $0 * 5)))m" } ?? "--"
        let isBusy = (driver.availability ?? "").lowercased() == "busy"

        return HStack(spacing: 10) {
            AvatarView(
                url: URL(string: driver.avatarURL ?? ""),
                size: AppTheme.avatarSizeLarge,
                fallbackInitials: initials(driver.displayName),
                statusColor: isBusy ? AppTheme.warning : AppTheme.success
            )
            .grayscale(isBusy ? 0.8 : 0)
            .opacity(isBusy ? 0.72 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.displayName)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 8) {
                    Text(distanceText)
                    Text("ETA \(etaText)")
                    Text("★ \(String(format: "%.1f", driver.rating ?? 4.5))")
                    Text("\(driver.tripCount ?? 0) trips")
                }
                .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            Button {
                guard !isBusy else { return }
                if coordinator.featureFlags.motionV2 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onAssign(driver.id)
            } label: {
                Text(isBusy ? "Busy" : "Assign")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous).fill(isBusy ? AppTheme.surfaceElevated : AppTheme.accentBlue))
                    .foregroundStyle(isBusy ? AppTheme.textMuted : AppTheme.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(isBusy ? "Driver busy" : "Assign \(driver.displayName)")
            .accessibilityHint(isBusy ? "This driver is currently unavailable." : "Assigns this driver to the selected order.")
            .accessibilityIdentifier(isBusy ? "orders.assign.busy.\(driver.id)" : "orders.assign.cta.\(driver.id)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func distanceMiles(from driver: DriverProfile, to order: OrderRequest) -> Double? {
        guard let dLat = driver.lastLat,
              let dLng = driver.lastLng,
              let oLat = order.lat,
              let oLng = order.lng else {
            return nil
        }

        let earthRadiusMiles = 3958.8
        let lat1 = dLat * .pi / 180
        let lat2 = oLat * .pi / 180
        let deltaLat = (oLat - dLat) * .pi / 180
        let deltaLng = (oLng - dLng) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2)
            * sin(deltaLng / 2) * sin(deltaLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMiles * c
    }

    private func initials(_ value: String) -> String {
        let parts = value.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(value.prefix(2)).uppercased()
    }
}

private enum DriverFilterTab: String, CaseIterable {
    case nearby = "Nearby"
    case available = "Available"
    case topRated = "Top Rated"
}
