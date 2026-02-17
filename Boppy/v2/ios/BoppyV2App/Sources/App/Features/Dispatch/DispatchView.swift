import SwiftUI
import MapKit
import UIKit
import CoreLocation
import BoppyV2Core

struct DispatchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var feedStore: FeedStore
    @EnvironmentObject private var orderStore: OrderStore
    @EnvironmentObject private var dispatchStore: DispatchStore

    @State private var selectedDriverID: String = ""
    @State private var startAddress = "Austin, TX"
    @State private var startLat = "30.2672"
    @State private var startLng = "-97.7431"
    @State private var routePathCoordinates: [CLLocationCoordinate2D] = []
    @State private var isRoutePathLoading = false
    @State private var isRouteActionInFlight = false
    @State private var selectedStopOrder: OrderRequest?
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.32, longitudeDelta: 0.32)
        )
    )

    var body: some View {
        NavigationStack {
            dispatchScreen
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    syncDriverSelectionIfNeeded()
                    syncMapCamera()
                    Task {
                        await coordinator.refreshAll()
                        await refreshRoutePath()
                    }
                }
                .onChange(of: dispatchStore.routes) { _, _ in
                    syncMapCamera()
                    Task { await refreshRoutePath() }
                }
                .onChange(of: orderStore.orders) { _, _ in
                    syncMapCamera()
                    Task { await refreshRoutePath() }
                }
                .onChange(of: feedStore.drivers) { _, _ in
                    syncDriverSelectionIfNeeded()
                }
        }
        .appScreenBackground()
        .fullScreenCover(item: $selectedStopOrder) { order in
            DispatchStopDetailsSheet(order: order)
        }
    }

    private var dispatchScreen: some View {
        DispatchShellView {
            dispatchHeader
        } mapSection: {
            mapHero
        } stopList: {
            routesContent
        } actionBar: {
            DispatchActionBar(
                onRefresh: {
                    Task { await coordinator.refreshAll() }
                },
                onOptimizeRoute: buildOrOptimizeRoute,
                onSaveRouteChanges: {
                    Task { await coordinator.refreshAll() }
                },
                optimizeDisabled: selectedDriverID.isEmpty || authStore.user?.role != .owner,
                offline: authStore.isOffline,
                isBusy: isRouteActionInFlight,
                glass: coordinator.featureFlags.glassChromeV2
            )
        }
    }

    @ViewBuilder
    private var routesContent: some View {
        DispatchStopListView(
            routes: dispatchStore.routes,
            primaryRoute: primaryRoute,
            isOwner: authStore.user?.role == .owner,
            routeDurationLabel: routeDurationLabel,
            nextStopLabel: primaryActiveOrder.map(nextStopLabel(for:)) ?? "Waiting for route",
            onRefresh: {
                await coordinator.refreshAll()
                await refreshRoutePath()
            },
            routeSection: { route in
                routeSection(route)
            },
            ownerControls: {
                ownerControls
            },
            emptyState: {
                emptyStateCard
            }
        )
    }

    private func routeSection(_ route: DeliveryRoute) -> some View {
        let sortedStops = route.stops.sorted(by: { $0.stopIndex < $1.stopIndex })
        let currentStopID = sortedStops.first(where: { $0.completedAt == nil })?.id
        return VStack(spacing: 10) {
            ForEach(Array(sortedStops.enumerated()), id: \.element.id) { index, stop in
                let stopOrder = orderStore.orders.first(where: { $0.id == stop.orderID })
                RouteStopCard(
                    stop: stop,
                    route: route,
                    order: stopOrder,
                    canReorder: canReorder(route: route) && !isRouteActionInFlight,
                    canComplete: authStore.user?.role == .driver && !isRouteActionInFlight,
                    isCurrentStop: stop.id == currentStopID,
                    isLastStop: index == sortedStops.count - 1,
                    onMoveUp: {
                        Task {
                            await coordinator.reorderStop(routeID: route.id, stopID: stop.id, direction: .up)
                        }
                    },
                    onMoveDown: {
                        Task {
                            await coordinator.reorderStop(routeID: route.id, stopID: stop.id, direction: .down)
                        }
                    },
                    onDetails: {
                        if let stopOrder {
                            selectedStopOrder = stopOrder
                        }
                    },
                    onComplete: {
                        Task {
                            await coordinator.completeStop(routeID: route.id, stopID: stop.id)
                        }
                    }
                )
            }
        }
    }

    private func canReorder(route: DeliveryRoute) -> Bool {
        authStore.user?.role == .owner && route.status == .planned
    }

    private func routeStatusColor(_ status: RouteStatus) -> Color {
        switch status {
        case .planned:
            return AppTheme.warning
        case .inProgress:
            return AppTheme.accentBlue
        case .completed:
            return AppTheme.success
        case .cancelled:
            return AppTheme.danger
        }
    }

    private func buildOrOptimizeRoute() {
        guard !isRouteActionInFlight else { return }
        guard authStore.user?.role == .owner else {
            coordinator.present(.validation("Only owners can build or optimize routes."))
            return
        }
        guard !selectedDriverID.isEmpty else {
            coordinator.present(.validation("Select a driver before building a route."))
            return
        }
        isRouteActionInFlight = true
        Task {
            defer {
                Task { @MainActor in
                    isRouteActionInFlight = false
                }
            }
            guard let coordinate = await resolveStartCoordinate() else { return }
            await coordinator.buildRoute(
                start: GeoPoint(lat: coordinate.latitude, lng: coordinate.longitude),
                driverID: selectedDriverID
            )
            await refreshRoutePath()
        }
    }

    private var ownerControls: some View {
        DispatchRoutingControlsView(
            selectedDriverID: $selectedDriverID,
            startAddress: $startAddress,
            drivers: feedStore.drivers,
            isOffline: authStore.isOffline,
            isBusy: isRouteActionInFlight,
            onBuildRoute: {
                buildOrOptimizeRoute()
            }
        )
    }

    private var dispatchHeader: some View {
        let remainingStops = primaryRoute?.stops.filter { $0.completedAt == nil }.count ?? 0
        let statusLine: String = {
            if routeDurationLabel == "No active route" {
                return remainingStops == 0 ? "No active route" : "\(remainingStops) Stops Remaining"
            }
            return "\(remainingStops) stops • \(routeDurationLabel)"
        }()

        return HStack(alignment: .top, spacing: 12) {
            mapIconButton(
                systemName: "line.3.horizontal",
                identifier: "dispatch.map.refreshMenu",
                accessibilityLabel: "Refresh dispatch",
                accessibilityHint: "Refreshes dispatch data."
            ) {
                Task { await coordinator.refreshAll() }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Route Management")
                        .font(AppTheme.inter(21, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                }

                HStack(spacing: 8) {
                    if authStore.user?.role == .owner {
                        Text("OWNER")
                            .font(AppTheme.inter(10, weight: .bold, relativeTo: .caption2))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentBlue.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.accentBlue)
                    }

                    Text(statusLine)
                        .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                mapIconButton(
                    systemName: "scope",
                    identifier: "dispatch.map.recenter",
                    accessibilityLabel: "Recenter map",
                    accessibilityHint: "Centers the map on active route stops."
                ) {
                    syncMapCamera()
                }
                mapIconButton(
                    systemName: "gearshape.fill",
                    identifier: "dispatch.map.refreshSettings",
                    accessibilityLabel: "Dispatch settings",
                    accessibilityHint: "Refreshes dispatch controls."
                ) {
                    Task { await coordinator.refreshAll() }
                }
            }
        }
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            AppTheme.chromeBackground(glass: coordinator.featureFlags.glassChromeV2)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.5))
                .frame(height: 1)
        }
    }

    private var mapHero: some View {
        DispatchMapSectionView(
            mapPosition: $mapPosition,
            routePins: routePins(for: primaryRoute),
            activeStopOrderID: primaryActiveStop?.orderID,
            routePathCoordinates: routePathCoordinates,
            nextStopLabel: primaryActiveOrder.map(nextStopLabel(for:)) ?? "Waiting for route",
            isRoutePathLoading: isRoutePathLoading,
            isRouteActionInFlight: isRouteActionInFlight,
            optimizeDisabled: selectedDriverID.isEmpty || authStore.user?.role != .owner || authStore.isOffline || isRouteActionInFlight,
            canOpenMaps: canOpenMaps(for: primaryActiveOrder),
            onOptimize: {
                buildOrOptimizeRoute()
            },
            onOpenMaps: {
                openActiveStopInMaps()
            }
        )
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No Routes Yet", systemImage: "map")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Assign a driver and build the first route to start deliveries.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func mapIconButton(
        systemName: String,
        identifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppTheme.inter(15, weight: .bold, relativeTo: .body))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background(AppTheme.surface.opacity(0.94), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(identifier)
        .overlay(
            Circle()
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var routeDurationLabel: String {
        let pendingStops = dispatchStore.routes.first?.stops.filter { $0.completedAt == nil } ?? []
        guard !pendingStops.isEmpty else { return "No active route" }
        let fallbackMinutes = max(1, pendingStops.count) * 15
        let etaMinutes = pendingStops.compactMap(\.etaMinutes).max() ?? fallbackMinutes
        let hours = etaMinutes / 60
        let minutes = etaMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func nextStopLabel(for order: OrderRequest) -> String {
        let city = order.deliveryAddress.city.trimmingCharacters(in: .whitespacesAndNewlines)
        if city.isEmpty {
            return order.deliveryAddress.line1
        }
        return "\(order.deliveryAddress.line1) • \(city)"
    }

    private func syncMapCamera() {
        let pins = routePins(for: dispatchStore.routes.first)
        let coordinates = pins.compactMap { order -> CLLocationCoordinate2D? in
            guard let lat = order.lat, let lng = order.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let first = coordinates.first {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: first,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
            return
        }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLng = lngs.min(),
            let maxLng = lngs.max()
        else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let latDelta = max((maxLat - minLat) * 1.45, 0.08)
        let lngDelta = max((maxLng - minLng) * 1.45, 0.08)

        mapPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
            )
        )
    }

    private func routePins(for route: DeliveryRoute?) -> [OrderRequest] {
        guard let route else { return [] }
        let orderByID = Dictionary(uniqueKeysWithValues: orderStore.orders.map { ($0.id, $0) })
        return route.stops
            .sorted(by: { $0.stopIndex < $1.stopIndex })
            .compactMap { orderByID[$0.orderID] }
            .filter { $0.lat != nil && $0.lng != nil }
    }

    private var primaryRoute: DeliveryRoute? {
        dispatchStore.routes.first
    }

    private var primaryActiveStop: RouteStop? {
        primaryRoute?.stops
            .sorted(by: { $0.stopIndex < $1.stopIndex })
            .first(where: { $0.completedAt == nil })
    }

    private var primaryActiveOrder: OrderRequest? {
        guard let orderID = primaryActiveStop?.orderID else { return nil }
        return orderStore.orders.first(where: { $0.id == orderID })
    }

    private func syncDriverSelectionIfNeeded() {
        guard selectedDriverID.isEmpty else { return }
        if let routedDriver = primaryRoute?.driverID {
            selectedDriverID = routedDriver
            return
        }
        selectedDriverID = feedStore.drivers.first?.id ?? ""
    }

    @MainActor
    private func refreshRoutePath() async {
        let pins = routePins(for: primaryRoute)
        let coordinates = pins.compactMap { order -> CLLocationCoordinate2D? in
            guard let lat = order.lat, let lng = order.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        guard coordinates.count >= 2 else {
            routePathCoordinates = coordinates
            return
        }

        isRoutePathLoading = true
        defer { isRoutePathLoading = false }

        var merged: [CLLocationCoordinate2D] = []
        for idx in 0..<(coordinates.count - 1) {
            let start = coordinates[idx]
            let end = coordinates[idx + 1]
            let segment = await routeSegment(from: start, to: end)
            if merged.isEmpty {
                merged.append(contentsOf: segment)
            } else if let first = segment.first, isSameCoordinate(first, merged.last) {
                merged.append(contentsOf: segment.dropFirst())
            } else {
                merged.append(contentsOf: segment)
            }
        }

        routePathCoordinates = merged.isEmpty ? coordinates : merged
    }

    private func routeSegment(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            if let route = response.routes.first {
                let mapped = coordinates(from: route.polyline)
                if mapped.count >= 2 {
                    return mapped
                }
            }
        } catch {
            // Fallback keeps route drawing available when directions lookup fails.
        }

        return [start, end]
    }

    private func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }
        let points = polyline.points()
        return (0..<count).map { index in
            points[index].coordinate
        }
    }

    private func isSameCoordinate(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D?) -> Bool {
        guard let rhs else { return false }
        return abs(lhs.latitude - rhs.latitude) < 0.00001 && abs(lhs.longitude - rhs.longitude) < 0.00001
    }

    private func openActiveStopInMaps() {
        guard let activeOrder = primaryActiveOrder else {
            coordinator.present(.validation("No active stop selected yet."))
            return
        }

        if let lat = activeOrder.lat, let lng = activeOrder.lng {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = activeOrder.deliveryAddress.line1
            let opened = mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
            if !opened {
                coordinator.present(.validation("Unable to open Apple Maps for this stop."))
            }
            return
        }

        let address = mapsDestinationAddress(for: activeOrder)

        guard
            !address.isEmpty,
            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d")
        else {
            coordinator.present(.validation("Unable to open Apple Maps for this stop."))
            return
        }

        openInAppleMaps(url: url)
    }

    @MainActor
    private func resolveStartCoordinate() async -> CLLocationCoordinate2D? {
        let trimmedAddress = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAddress.isEmpty {
            do {
                let placemarks = try await CLGeocoder().geocodeAddressString(trimmedAddress)
                if let coordinate = placemarks.first?.location?.coordinate {
                    startLat = String(format: "%.6f", coordinate.latitude)
                    startLng = String(format: "%.6f", coordinate.longitude)
                    return coordinate
                }
                coordinator.present(.validation("Couldn't find that start address. Try adding city and state."))
                return nil
            } catch {
                coordinator.present(.validation("Couldn't geocode the start address. Check spelling and try again."))
                return nil
            }
        }

        guard let lat = Double(startLat), let lng = Double(startLng) else {
            coordinator.present(.validation("Enter a valid start address."))
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func canOpenMaps(for order: OrderRequest?) -> Bool {
        guard let order else { return false }
        if order.lat != nil, order.lng != nil {
            return true
        }
        let address = mapsDestinationAddress(for: order)
        guard
            !address.isEmpty,
            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d")
        else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    private func mapsDestinationAddress(for order: OrderRequest) -> String {
        [
            order.deliveryAddress.line1,
            order.deliveryAddress.city,
            order.deliveryAddress.state,
            order.deliveryAddress.postalCode,
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: ", ")
    }

    private func openInAppleMaps(url: URL) {
        guard UIApplication.shared.canOpenURL(url) else {
            coordinator.present(.validation("Apple Maps is unavailable on this device."))
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                coordinator.present(.validation("Unable to open Apple Maps for this stop."))
            }
        }
    }
}

private struct DispatchStopDetailsSheet: View {
    let order: OrderRequest

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    Text(order.deliveryAddress.line1)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(addressLine)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(order.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentBlue.opacity(0.18), in: Capsule())
                        .foregroundStyle(AppTheme.accentBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !order.quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(order.quoteNote)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 0)

                    if let mapURL = mapsURL {
                        Link(destination: mapURL) {
                            Label("Open in Apple Maps", systemImage: "map.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentBlue)
                        .accessibilityLabel("Open in Apple Maps")
                        .accessibilityHint("Launches turn-by-turn navigation for this stop.")
                        .accessibilityIdentifier("dispatch.stop.details.openMaps")
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.surfaceElevated)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Close stop details")
                    .accessibilityHint("Dismisses this stop details sheet.")
                    .accessibilityIdentifier("dispatch.stop.details.done")
                }
                .padding(AppTheme.cardPadding)
            }
            .navigationTitle("Stop Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(360)])
    }

    private var addressLine: String {
        [order.deliveryAddress.city, order.deliveryAddress.state, order.deliveryAddress.postalCode]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }

    private var mapsURL: URL? {
        if let lat = order.lat, let lng = order.lng {
            return URL(string: "https://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d")
        }
        let address = [
            order.deliveryAddress.line1,
            order.deliveryAddress.city,
            order.deliveryAddress.state,
            order.deliveryAddress.postalCode,
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: ", ")
        guard
            !address.isEmpty,
            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        return URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d")
    }
}
