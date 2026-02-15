import SwiftUI
import MapKit
import BoppyV2Core

struct DispatchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var selectedDriverID: String = ""
    @State private var startLat = "30.2672"
    @State private var startLng = "-97.7431"
    @State private var routePathCoordinates: [CLLocationCoordinate2D] = []
    @State private var isRoutePathLoading = false
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
                .onChange(of: coordinator.routes) { _, _ in
                    syncMapCamera()
                    Task { await refreshRoutePath() }
                }
                .onChange(of: coordinator.orders) { _, _ in
                    syncMapCamera()
                    Task { await refreshRoutePath() }
                }
                .onChange(of: coordinator.drivers) { _, _ in
                    syncDriverSelectionIfNeeded()
                }
        }
        .appScreenBackground()
        .sheet(item: $selectedStopOrder) { order in
            DispatchStopDetailsSheet(order: order)
        }
    }

    private var dispatchScreen: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                mapHero
                routesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DispatchActionBar(
                onRefresh: {
                    Task { await coordinator.refreshAll() }
                },
                onOptimizeRoute: buildOrOptimizeRoute,
                onSaveRouteChanges: {
                    Task { await coordinator.refreshAll() }
                },
                optimizeDisabled: selectedDriverID.isEmpty || coordinator.user?.role != .owner
            )
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var routesContent: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    RouteSummaryHeader(
                        route: primaryRoute,
                        isOwner: coordinator.user?.role == .owner,
                        routeDurationLabel: routeDurationLabel,
                        nextStopLabel: primaryActiveOrder.map(nextStopLabel(for:)) ?? "Waiting for route"
                    )

                    if coordinator.routes.isEmpty {
                        emptyStateCard

                        if coordinator.user?.role == .owner {
                            ownerControls
                        }
                    } else {
                        ForEach(coordinator.routes) { route in
                            routeSection(route)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .frame(
                    maxWidth: .infinity,
                    minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                    alignment: .top
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.screenGradient)
        }
    }

    private func routeSection(_ route: DeliveryRoute) -> some View {
        let sortedStops = route.stops.sorted(by: { $0.stopIndex < $1.stopIndex })
        let currentStopID = sortedStops.first(where: { $0.completedAt == nil })?.id
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(route.id.prefix(8).uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface.opacity(0.90), in: Capsule())
                    .foregroundStyle(AppTheme.textSecondary)

                Text(route.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(routeStatusColor(route.status).opacity(0.18), in: Capsule())
                    .foregroundStyle(routeStatusColor(route.status))

                Spacer()

                Text("Driver \(route.driverID.suffix(4))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 4)

            ForEach(Array(sortedStops.enumerated()), id: \.element.id) { index, stop in
                let stopOrder = coordinator.orders.first(where: { $0.id == stop.orderID })
                RouteStopCard(
                    stop: stop,
                    route: route,
                    order: stopOrder,
                    canReorder: canReorder(route: route),
                    canComplete: coordinator.user?.role == .driver || coordinator.user?.role == .owner,
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
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func canReorder(route: DeliveryRoute) -> Bool {
        coordinator.user?.role == .owner && route.status == .planned
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
        guard let lat = Double(startLat), let lng = Double(startLng), !selectedDriverID.isEmpty else {
            return
        }
        Task {
            await coordinator.buildRoute(start: GeoPoint(lat: lat, lng: lng), driverID: selectedDriverID)
            await refreshRoutePath()
        }
    }

    private var ownerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Setup")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Picker("Driver", selection: $selectedDriverID) {
                Text("Select driver").tag("")
                ForEach(coordinator.drivers) { driver in
                    Text(driver.displayName).tag(driver.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.textPrimary)

            HStack {
                TextField("Start lat", text: $startLat)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .accessibilityIdentifier("dispatch.startLat")

                TextField("Start lng", text: $startLng)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .accessibilityIdentifier("dispatch.startLng")
            }

            Button("Build Route") {
                buildOrOptimizeRoute()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentBlue)
            .disabled(selectedDriverID.isEmpty)
            .accessibilityIdentifier("dispatch.buildRoute")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var mapHero: some View {
        let activeRoute = primaryRoute
        let remainingStops = activeRoute?.stops.filter { $0.completedAt == nil }.count ?? 0
        let activeStop = primaryActiveStop
        let activeOrder = primaryActiveOrder

        return ZStack(alignment: .topLeading) {
            Map(position: $mapPosition) {
                UserAnnotation()

                ForEach(routePins(for: activeRoute), id: \.id) { order in
                    if let lat = order.lat, let lng = order.lng {
                        Marker(order.deliveryAddress.line1, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            .tint(order.id == activeStop?.orderID ? AppTheme.accentBlue : AppTheme.textMuted)
                    }
                }

                if routePathCoordinates.count >= 2 {
                    MapPolyline(coordinates: routePathCoordinates)
                        .stroke(
                            AppTheme.accentBlue.opacity(0.95),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .accessibilityIdentifier("dispatch.map")

            LinearGradient(
                colors: [Color.black.opacity(0.42), Color.clear, Color.black.opacity(0.50)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 10) {
                        mapIconButton(systemName: "line.3.horizontal", identifier: "dispatch.map.refreshMenu") {
                            Task { await coordinator.refreshAll() }
                        }
                        Text("Route Management")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        mapIconButton(systemName: "scope", identifier: "dispatch.map.recenter") {
                            syncMapCamera()
                        }
                        mapIconButton(systemName: "gearshape.fill", identifier: "dispatch.map.refreshSettings") {
                            Task { await coordinator.refreshAll() }
                        }
                    }
                }

                HStack(spacing: 8) {
                    if coordinator.user?.role == .owner {
                        Text("OWNER")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentBlue.opacity(0.22), in: Capsule())
                            .foregroundStyle(AppTheme.accentBlue)
                    }
                    Text("\(remainingStops) Stops Remaining • \(routeDurationLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT STOP")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accentBlue)
                        Text(activeOrder.map(nextStopLabel(for:)) ?? "Waiting for route")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        buildOrOptimizeRoute()
                    } label: {
                        Label("Optimize", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.surface.opacity(0.96))
                    .disabled(selectedDriverID.isEmpty || coordinator.user?.role != .owner)
                    .accessibilityIdentifier("dispatch.optimizeInline")

                    Button {
                        syncMapCamera()
                    } label: {
                        Image(systemName: "location.north.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.accentBlue, in: Circle())
                    }
                    .accessibilityIdentifier("dispatch.recenterInline")

                    Button {
                        openActiveStopInMaps()
                    } label: {
                        Image(systemName: "car.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.surface.opacity(0.90), in: Circle())
                    }
                    .disabled(activeOrder?.lat == nil || activeOrder?.lng == nil)
                    .accessibilityIdentifier("dispatch.openAppleMaps")
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)

            if isRoutePathLoading {
                ProgressView("Routing")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(AppTheme.surface.opacity(0.9), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.top, 58)
                    .padding(.leading, AppTheme.screenHorizontalPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 270)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.75))
                .frame(height: 1)
        }
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

    private func mapIconButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface.opacity(0.90), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .overlay(
            Circle()
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var routeDurationLabel: String {
        let pendingStops = coordinator.routes.first?.stops.filter { $0.completedAt == nil } ?? []
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
        let pins = routePins(for: coordinator.routes.first)
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
        let orderByID = Dictionary(uniqueKeysWithValues: coordinator.orders.map { ($0.id, $0) })
        return route.stops
            .sorted(by: { $0.stopIndex < $1.stopIndex })
            .compactMap { orderByID[$0.orderID] }
            .filter { $0.lat != nil && $0.lng != nil }
    }

    private var primaryRoute: DeliveryRoute? {
        coordinator.routes.first
    }

    private var primaryActiveStop: RouteStop? {
        primaryRoute?.stops
            .sorted(by: { $0.stopIndex < $1.stopIndex })
            .first(where: { $0.completedAt == nil })
    }

    private var primaryActiveOrder: OrderRequest? {
        guard let orderID = primaryActiveStop?.orderID else { return nil }
        return coordinator.orders.first(where: { $0.id == orderID })
    }

    private func syncDriverSelectionIfNeeded() {
        guard selectedDriverID.isEmpty else { return }
        selectedDriverID = coordinator.drivers.first?.id ?? ""
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
        guard
            let activeOrder = primaryActiveOrder,
            let lat = activeOrder.lat,
            let lng = activeOrder.lng
        else { return }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = activeOrder.deliveryAddress.line1
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
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
                        .accessibilityIdentifier("dispatch.stop.details.openMaps")
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.surfaceElevated)
                    .frame(maxWidth: .infinity)
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
        guard let lat = order.lat, let lng = order.lng else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d")
    }
}
