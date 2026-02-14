import SwiftUI
import BoppyV2Core

struct OrderStatusPill: View {
    let status: OrderStatus

    var body: some View {
        Text(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(foregroundColor.opacity(0.35), lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch status {
        case .requested, .addressReview:
            return .orange
        case .quoted:
            return Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255)
        case .accepted, .assigned:
            return .green
        case .outForDelivery:
            return .indigo
        case .delivered:
            return .mint
        case .cancelled:
            return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.14)
    }
}
