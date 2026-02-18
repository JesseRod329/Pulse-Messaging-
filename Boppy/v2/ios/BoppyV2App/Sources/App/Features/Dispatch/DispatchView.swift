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
    @State private var selectedStopOrder: OrderRequest?
    @State private var isRouteActionInFlight = false
    @State private var isAddressSearching = false
    @State private var searchedAddressCoordinate: CLLocationCoordinate2D?
    @State private var isOwnerControlsExpanded = false
    @State private var isMapExpanded = true
    @State private var searchPreviewCoordinates: [CLLocationCoordinate2D] = []
    @State private var scrollProxy: ScrollViewProxy?
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.32, longitudeDelta: 0.32)
        )
    )

    var body: some View {
        NavigationStack {
            dispatchScreen
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    isOwnerControlsExpanded = dispatchStore.routes.isEmpty
                    syncDriverSelectionIfNeeded()
                    syncMapCamera()
                    Task {
                        await coordinator.refreshAll()
                        await refreshRoutePath()
                    }
                }
                .onChange(of: dispatchStore.routes) { _, _ in
                    syncDriverSelectionIfNeeded()
                    syncMapCamera()
                    searchPreviewCoordinates = []
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
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                dispatchHeader

                if isMapExpanded {
                    mapHero
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    collapsedMapStrip
                        .transition(.opacity)
                }

                routesContent
            }
            .animation(.easeInOut(duration: 0.25), value: isMapExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var routesContent: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollReader in
            ScrollView {
                VStack(spacing: 10) {
                    LazyVStack(spacing: 10) {
                        if authStore.user?.role == .owner {
                            ownerControlsCollapsible
                                .id("ownerControls")
                        }

                        if dispatchStore.routes.isEmpty {
                            emptyStateCard
                        } else {
                            RouteSummaryHeader(
                                route: primaryRoute,
                                isOwner: authStore.user?.role == .owner,
                                routeDurationLabel: routeDurationLabel,
                                nextStopLabel: primaryActiveOrder.map(nextStopLabel(for:)) ?? "No active stop"
                            )

                            ForEach(dispatchStore.routes) { route in
                                routeSection(route)
                            }
                        }
                    }

                    DispatchActionBar(
                        onRefresh: {
                            Task { await coordinator.refreshAll() }
                        },
                        onOptimizeRoute: buildOrOptimizeRoute,
                        optimizeDisabled: selectedDriverID.isEmpty || authStore.user?.role != .owner,
                        offline: authStore.isOffline,
                        isBusy: isRouteActionInFlight,
                        glass: coordinator.featureFlags.glassChromeV2
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, AppTheme.contentBottomPadding)
                .frame(
                    maxWidth: .infinity,
                    minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                    alignment: .top
                )
            }
            .refreshable {
                await coordinator.refreshAll()
                await refreshRoutePath()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.screenGradient)
            .onAppear { scrollProxy = scrollReader }
            }
        }
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
                    canReorder: canReorder(route: route),
                    canComplete: authStore.user?.role == .driver,
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
        searchPreviewCoordinates = []
        guard authStore.user?.role == .owner else {
            coordinator.present(.validation("Only owners can build or optimize routes."))
            return
        }
        guard !selectedDriverID.isEmpty else {
            coordinator.present(.validation("Select a driver before building a route."))
            return
        }
        Task {
            isRouteActionInFlight = true
            defer { isRouteActionInFlight = false }
            guard let coordinate = await resolveStartCoordinate() else { return }
            await coordinator.buildRoute(
                start: GeoPoint(lat: coordinate.latitude, lng: coordinate.longitude),
                driverID: selectedDriverID
            )
            await refreshRoutePath()
        }
    }

    private func searchAddress() {
        let trimmed = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            isAddressSearching = true
            defer { isAddressSearching = false }

            do {
                let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
                if let coordinate = placemarks.first?.location?.coordinate {
                    startLat = String(format: "%.6f", coordinate.latitude)
                    startLng = String(format: "%.6f", coordinate.longitude)
                    searchedAddressCoordinate = coordinate

                    // If route already has stops, preview the segment from searched address to first stop
                    if let firstStopOrder = routePins(for: primaryRoute).first,
                       let stopLat = firstStopOrder.lat,
                       let stopLng = firstStopOrder.lng {
                        let stopCoord = CLLocationCoordinate2D(latitude: stopLat, longitude: stopLng)
                        let previewSegment = await routeSegment(from: coordinate, to: stopCoord)
                        searchPreviewCoordinates = previewSegment

                        // Fit camera to show both search pin and first stop
                        var allCoords = previewSegment
                        allCoords.append(coordinate)
                        let lats = allCoords.map(\.latitude)
                        let lngs = allCoords.map(\.longitude)
                        if let minLat = lats.min(), let maxLat = lats.max(),
                           let minLng = lngs.min(), let maxLng = lngs.max() {
                            let center = CLLocationCoordinate2D(
                                latitude: (minLat + maxLat) / 2,
                                longitude: (minLng + maxLng) / 2
                            )
                            withAnimation {
                                mapPosition = .region(
                                    MKCoordinateRegion(
                                        center: center,
                                        span: MKCoordinateSpan(
                                            latitudeDelta: max((maxLat - minLat) * 1.6, 0.08),
                                            longitudeDelta: max((maxLng - minLng) * 1.6, 0.08)
                                        )
                                    )
                                )
                            }
                        }
                    } else {
                        searchPreviewCoordinates = []
                        withAnimation {
                            mapPosition = .region(
                                MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                                )
                            )
                        }
                    }
                } else {
                    coordinator.present(.validation("Couldn't find that address. Try adding city and state."))
                }
            } catch {
                coordinator.present(.validation("Couldn't geocode the address. Check spelling and try again."))
            }
        }
    }

    private func clearCurrentRoute() {
        Task {
            isRouteActionInFlight = true
            defer { isRouteActionInFlight = false }
            await coordinator.clearRoute()
            routePathCoordinates = []
            searchPreviewCoordinates = []
            searchedAddressCoordinate = nil
            selectedDriverID = ""
            withAnimation(.easeInOut(duration: 0.25)) {
                isOwnerControlsExpanded = true
            }
        }
    }

    private var ownerControlsCollapsible: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isOwnerControlsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Route Setup")
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: isOwnerControlsExpanded ? "chevron.up" : "chevron.down")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOwnerControlsExpanded ? "Collapse route setup" : "Expand route setup")
            .accessibilityHint("Toggles the route setup controls.")
            .accessibilityIdentifier("dispatch.toggleSetup")

            if isOwnerControlsExpanded {
                ownerControlsBody
                    .padding(.top, 10)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var ownerControlsBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Driver", selection: $selectedDriverID) {
                Text("Select driver").tag("")
                ForEach(feedStore.drivers) { driver in
                    Text(driver.displayName).tag(driver.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.textPrimary)
            .accessibilityLabel("Route driver")
            .accessibilityHint("Selects which driver receives this route.")

            if feedStore.drivers.isEmpty {
                Text("No drivers found for this channel. Add a driver in Admin Controls first.")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(AppTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                TextField("Start address (e.g. 123 Main St, Austin, TX)", text: $startAddress)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Start address")
                    .accessibilityHint("Starting address used for route optimization.")
                    .accessibilityIdentifier("dispatch.startAddress")
                    .onSubmit { searchAddress() }

                Button {
                    searchAddress()
                } label: {
                    Group {
                        if isAddressSearching {
                            ProgressView()
                                .tint(AppTheme.textPrimary)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accentBlue, in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAddressSearching || startAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Search address")
                .accessibilityHint("Geocodes the address and centers the map on the result.")
                .accessibilityIdentifier("dispatch.searchAddress")
            }

            Text("Tap search to verify the address on the map, then build your route.")
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(dispatchStore.routes.isEmpty ? "Build Route" : "Rebuild Route") {
                buildOrOptimizeRoute()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentBlue)
            .disabled(selectedDriverID.isEmpty || authStore.isOffline)
            .accessibilityLabel(dispatchStore.routes.isEmpty ? "Build route" : "Rebuild route")
            .accessibilityHint("Builds a delivery route for selected pending orders.")
            .accessibilityIdentifier("dispatch.buildRoute")
        }
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
            Menu {
                Button {
                    Task { await coordinator.refreshAll() }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }

                Button {
                    syncMapCamera()
                } label: {
                    Label("Recenter on Route", systemImage: "scope")
                }

                if authStore.user?.role == .owner, !dispatchStore.routes.isEmpty {
                    Divider()
                    Button(role: .destructive) {
                        clearCurrentRoute()
                    } label: {
                        Label("Clear Route", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surface.opacity(0.94), in: Circle())
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Dispatch menu")
            .accessibilityHint("Opens dispatch actions menu.")
            .accessibilityIdentifier("dispatch.map.menu")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Route Management")
                        .font(AppTheme.inter(AppTheme.typeTitle2, weight: .bold, relativeTo: .title3))
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
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
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
                    if !isMapExpanded {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isMapExpanded = true
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        syncMapCamera()
                    }
                }
                if authStore.user?.role == .owner {
                    mapIconButton(
                        systemName: isOwnerControlsExpanded ? "xmark" : "gearshape.fill",
                        identifier: "dispatch.map.toggleSetup",
                        accessibilityLabel: isOwnerControlsExpanded ? "Hide route setup" : "Show route setup",
                        accessibilityHint: "Toggles the route setup controls panel."
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isOwnerControlsExpanded.toggle()
                        }
                        if isOwnerControlsExpanded {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    scrollProxy?.scrollTo("ownerControls", anchor: .top)
                                }
                            }
                        }
                    }
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
        let activeRoute = primaryRoute
        let activeOrder = primaryActiveOrder

        return ZStack(alignment: .bottomLeading) {
            Map(position: $mapPosition) {
                UserAnnotation()

                if let searchCoord = searchedAddressCoordinate {
                    Marker("Start", coordinate: searchCoord)
                        .tint(.green)
                }

                ForEach(routePins(for: activeRoute), id: \.id) { order in
                    if let lat = order.lat, let lng = order.lng {
                        Marker(order.deliveryAddress.line1, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            .tint(order.id == primaryActiveStop?.orderID ? AppTheme.accentBlue : AppTheme.textMuted)
                    }
                }

                if routePathCoordinates.count >= 2 {
                    MapPolyline(coordinates: routePathCoordinates)
                        .stroke(
                            AppTheme.accentBlue.opacity(0.95),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                }

                if searchPreviewCoordinates.count >= 2 {
                    MapPolyline(coordinates: searchPreviewCoordinates)
                        .stroke(
                            AppTheme.success.opacity(0.8),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 6])
                        )
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .accessibilityLabel("Dispatch map")
            .accessibilityHint("Shows route stops and current route path.")
            .accessibilityIdentifier("dispatch.map")

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.34), Color.black.opacity(0.52)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT STOP")
                        .font(AppTheme.inter(10, weight: .bold, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.accentBlue)
                    Text(activeOrder.map(nextStopLabel(for:)) ?? "Waiting for route")
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
                )

                Spacer()

                Button {
                    openActiveStopInMaps()
                } label: {
                    Image(systemName: "location.north.fill")
                        .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accentBlue, in: Circle())
                }
                .disabled(!canOpenMaps(for: activeOrder))
                .opacity(canOpenMaps(for: activeOrder) ? 1.0 : 0.35)
                .accessibilityLabel("Open Apple Maps")
                .accessibilityHint("Opens driving directions to the next stop.")
                .accessibilityIdentifier("dispatch.openAppleMaps")
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
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
        .frame(height: max(260, UIScreen.main.bounds.height * 0.35))
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isMapExpanded = false
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(AppTheme.border.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 58)
            .padding(.trailing, AppTheme.screenHorizontalPadding)
            .accessibilityLabel("Collapse map")
            .accessibilityIdentifier("dispatch.map.collapse")
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var collapsedMapStrip: some View {
        let remainingStops = primaryRoute?.stops.filter { $0.completedAt == nil }.count ?? 0

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isMapExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBlue)

                if remainingStops > 0 {
                    Text("\(remainingStops) stops • \(routeDurationLabel)")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    Text("Show Map")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 14)
            .background(AppTheme.surfaceCard)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand map")
        .accessibilityIdentifier("dispatch.map.expand")
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No Routes Yet", systemImage: "map")
                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Assign a driver and build the first route to start deliveries.")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium, relativeTo: .subheadline))
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
                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
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
        if let routedDriver = primaryRoute?.driverID {
            selectedDriverID = routedDriver
            return
        }
        if selectedDriverID.isEmpty {
            selectedDriverID = feedStore.drivers.first?.id ?? ""
        }
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
        // If there's an active order with coordinates, open directions to it
        if let activeOrder = primaryActiveOrder {
            if let lat = activeOrder.lat, let lng = activeOrder.lng {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = activeOrder.deliveryAddress.line1
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
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
            UIApplication.shared.open(url)
            return
        }

        // No active order — fall back to opening Apple Maps at searched start location
        if let coord = searchedAddressCoordinate {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coord))
            mapItem.name = startAddress
            mapItem.openInMaps()
            return
        }

        coordinator.present(.validation("Build a route first, then tap to open directions."))
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
        if let order {
            if order.lat != nil, order.lng != nil { return true }
            let address = mapsDestinationAddress(for: order)
            if !address.isEmpty { return true }
        }
        // Allow opening maps to start address even without a route
        return searchedAddressCoordinate != nil
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
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(addressLine)
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(order.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentBlue.opacity(0.18), in: Capsule())
                        .foregroundStyle(AppTheme.accentBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !order.quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(order.quoteNote)
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 0)

                    if let mapURL = mapsURL {
                        Link(destination: mapURL) {
                            Label("Open in Apple Maps", systemImage: "map.fill")
                                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold, relativeTo: .subheadline))
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
