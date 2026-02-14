import SwiftUI
import BoppyV2Core

struct RouteSummaryHeader: View {
    let route: DeliveryRoute?
    let isOwner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Route Management")
                    .font(.headline.weight(.bold))
                if isOwner {
                    Text("Owner")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255).opacity(0.14), in: Capsule())
                        .foregroundStyle(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255))
                }
                Spacer()
            }

            if let route {
                Text("\(remainingStops(route)) stops remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No active route yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func remainingStops(_ route: DeliveryRoute) -> Int {
        route.stops.filter { $0.completedAt == nil }.count
    }
}
