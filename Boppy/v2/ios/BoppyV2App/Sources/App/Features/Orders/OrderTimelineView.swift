import SwiftUI
import MapKit
import BoppyV2Core

struct OrderTimelineView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var orderStore: OrderStore
    @Environment(\.dismiss) private var dismiss

    let order: OrderRequest

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard
                    mapCard
                    timelineCard
                    actionRow
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, 12)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle(order.externalRef ?? "Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .accessibilityLabel("Close timeline")
                        .accessibilityHint("Returns to the orders list.")
                        .accessibilityIdentifier("orders.timeline.close")
                }
                if authStore.user?.role == .owner {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Status") {
                            ForEach(OrderStatus.allCases, id: \.self) { status in
                                Button(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) {
                                    Task {
                                        await coordinator.updateOrderStatus(orderID: order.id, status: status, quoteNote: order.quoteNote)
                                    }
                                }
                            }
                        }
                        .accessibilityLabel("Update order status")
                        .accessibilityHint("Opens the list of available status transitions.")
                        .accessibilityIdentifier("orders.timeline.statusMenu")
                    }
                }
            }
            .task {
                await coordinator.loadLedger(for: order.id)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let imageURL = order.summaryImageURL,
                   let url = URL(string: imageURL),
                   !imageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            ShimmerBlock(cornerRadius: 12)
                        }
                    }
                } else {
                    ShimmerBlock(cornerRadius: 12)
                }

                if let total = order.summaryTotalCents {
                    Text(currency(total))
                        .font(AppTheme.inter(13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentBlue.opacity(0.92), in: Capsule())
                        .padding(10)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(order.summaryTitle ?? "Order Summary")
                .font(AppTheme.inter(18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack {
                OrderStatusPill(status: order.status)
                Spacer()
                Text(order.externalRef ?? order.id)
                    .font(AppTheme.interMonospaced(12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(AppTheme.textMuted)
            }

            HStack(spacing: 8) {
                if order.status == .outForDelivery {
                    PulseDot(color: AppTheme.success, size: 8)
                }
                Text(order.summaryEtaText ?? "ETA pending")
                    .font(AppTheme.inter(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Order summary")
        .accessibilityHint("Shows status, reference, total, and ETA.")
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Driver Location")
                .font(AppTheme.inter(13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            OrderMapPreview(order: order)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Immutable Ledger")
                .font(AppTheme.inter(13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            LedgerTimelineView(
                events: orderStore.ledgerByOrderID[order.id] ?? [],
                isLoading: orderStore.loadingLedgerOrderIDs.contains(order.id)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
            } label: {
                Label("View Invoice", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("View invoice")
            .accessibilityHint("Opens invoice details for this order.")

            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Share order")
            .accessibilityHint("Shares this order timeline.")
        }
    }

    private func currency(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let value = NSDecimalNumber(value: cents).dividing(by: 100)
        return formatter.string(from: value) ?? "$\(Double(cents) / 100)"
    }
}

struct OrderMapPreview: View {
    let order: OrderRequest

    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    )

    var body: some View {
        Group {
            if let lat = order.lat, let lng = order.lng {
                let point = MapPoint(
                    id: order.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                )

                Map(position: $mapPosition) {
                    Annotation("Order location", coordinate: point.coordinate) {
                        ZStack {
                            if order.status == .outForDelivery {
                                Circle()
                                    .fill(AppTheme.accentBlue.opacity(0.22))
                                    .frame(width: 28, height: 28)
                            }
                            Circle()
                                .fill(AppTheme.accentBlue)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(AppTheme.textPrimary, lineWidth: 2))
                        }
                    }
                }
                .onAppear {
                    mapPosition = .region(
                        MKCoordinateRegion(
                            center: point.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                        )
                    )
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
                    .overlay {
                        Text("Location unavailable")
                            .font(AppTheme.inter(12, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private struct MapPoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}
