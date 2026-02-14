import SwiftUI
import BoppyV2Core

struct DispatchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var selectedDriverID: String = ""
    @State private var startLat = "30.2672"
    @State private var startLng = "-97.7431"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                RouteSummaryHeader(
                    route: coordinator.routes.first,
                    isOwner: coordinator.user?.role == .owner
                )

                if coordinator.user?.role == .owner {
                    ownerControls
                }

                if coordinator.routes.isEmpty {
                    ContentUnavailableView(
                        "No Routes",
                        systemImage: "map",
                        description: Text("Build or receive a route to begin delivery.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(coordinator.routes) { route in
                                HStack {
                                    Text("Route \(route.id)")
                                        .font(.subheadline.weight(.bold))
                                    if route.approximate {
                                        Text("Approximate")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    Spacer()
                                }
                                .padding(.top, 4)

                                ForEach(route.stops.sorted(by: { $0.stopIndex < $1.stopIndex })) { stop in
                                    RouteStopCard(
                                        stop: stop,
                                        route: route,
                                        canReorder: canReorder(route: route),
                                        canComplete: coordinator.user?.role == .driver || coordinator.user?.role == .owner,
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
                                        onComplete: {
                                            Task {
                                                await coordinator.completeStop(routeID: route.id, stopID: stop.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                DispatchActionBar(
                    onRefresh: {
                        Task { await coordinator.refreshAll() }
                    },
                    onBuildOrOptimize: {
                        guard let lat = Double(startLat), let lng = Double(startLng), !selectedDriverID.isEmpty else {
                            return
                        }
                        Task {
                            await coordinator.buildRoute(start: GeoPoint(lat: lat, lng: lng), driverID: selectedDriverID)
                        }
                    },
                    buildButtonLabel: "Optimize / Build Route",
                    isBuildDisabled: selectedDriverID.isEmpty || coordinator.user?.role != .owner
                )
            }
            .padding(.horizontal, 16)
            .navigationTitle("Dispatch")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await coordinator.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
    }

    private func canReorder(route: DeliveryRoute) -> Bool {
        coordinator.user?.role == .owner && route.status == .planned
    }

    private var ownerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build Driver Route")
                .font(.headline)

            Picker("Driver", selection: $selectedDriverID) {
                Text("Select driver").tag("")
                ForEach(coordinator.drivers) { driver in
                    Text(driver.displayName).tag(driver.id)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("Start lat", text: $startLat)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                TextField("Start lng", text: $startLng)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }

            Button("Build Route") {
                guard let lat = Double(startLat), let lng = Double(startLng), !selectedDriverID.isEmpty else {
                    return
                }
                Task {
                    await coordinator.buildRoute(start: GeoPoint(lat: lat, lng: lng), driverID: selectedDriverID)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDriverID.isEmpty)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
