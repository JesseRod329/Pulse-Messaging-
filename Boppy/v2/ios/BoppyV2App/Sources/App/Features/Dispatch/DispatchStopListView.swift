import SwiftUI
import BoppyV2Core

struct DispatchStopListView<RouteSection: View, OwnerControls: View, EmptyState: View>: View {
    let routes: [DeliveryRoute]
    let primaryRoute: DeliveryRoute?
    let isOwner: Bool
    let routeDurationLabel: String
    let nextStopLabel: String

    let onRefresh: () async -> Void
    let routeSection: (DeliveryRoute) -> RouteSection
    @ViewBuilder let ownerControls: () -> OwnerControls
    @ViewBuilder let emptyState: () -> EmptyState

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if routes.isEmpty {
                        RouteSummaryHeader(
                            route: primaryRoute,
                            isOwner: isOwner,
                            routeDurationLabel: routeDurationLabel,
                            nextStopLabel: nextStopLabel
                        )

                        emptyState()

                        if isOwner {
                            ownerControls()
                        }
                    } else {
                        ForEach(routes) { route in
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
            .refreshable {
                await onRefresh()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.screenGradient)
        }
    }
}
