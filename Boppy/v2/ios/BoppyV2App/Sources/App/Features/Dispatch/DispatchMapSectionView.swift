import SwiftUI
import MapKit
import UIKit
import BoppyV2Core

struct DispatchMapSectionView: View {
    @Binding var mapPosition: MapCameraPosition

    let routePins: [OrderRequest]
    let activeStopOrderID: String?
    let routePathCoordinates: [CLLocationCoordinate2D]
    let nextStopLabel: String

    let isRoutePathLoading: Bool
    let isRouteActionInFlight: Bool
    let optimizeDisabled: Bool
    let canOpenMaps: Bool

    let onOptimize: () -> Void
    let onOpenMaps: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $mapPosition) {
                UserAnnotation()

                ForEach(routePins, id: \.id) { order in
                    if let lat = order.lat, let lng = order.lng {
                        Marker(order.deliveryAddress.line1, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            .tint(order.id == activeStopOrderID ? AppTheme.accentBlue : AppTheme.textMuted)
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
                    Text(nextStopLabel)
                        .font(AppTheme.inter(16, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
                )

                Button {
                    onOptimize()
                } label: {
                    Label(isRouteActionInFlight ? "Optimizing..." : "Optimize", systemImage: "sparkles")
                        .font(AppTheme.inter(12, weight: .bold, relativeTo: .caption))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
                )
                .disabled(optimizeDisabled)
                .accessibilityLabel("Optimize route")
                .accessibilityHint("Re-optimizes stop order and ETA.")
                .accessibilityIdentifier("dispatch.optimizeInline")

                Button {
                    onOpenMaps()
                } label: {
                    Image(systemName: "location.north.fill")
                        .font(AppTheme.inter(18, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accentBlue, in: Circle())
                }
                .disabled(!canOpenMaps)
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.75))
                .frame(height: 1)
        }
    }
}
