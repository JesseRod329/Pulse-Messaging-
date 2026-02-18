import SwiftUI
import BoppyV2Core

struct OrderStatusPill: View {
    let status: OrderStatus

    var body: some View {
        Text(title)
            .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold, relativeTo: .caption2))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(foregroundColor.opacity(0.38), lineWidth: 1)
            )
    }

    private var title: String {
        switch status {
        case .requested:
            return "REQUESTED"
        case .quoted:
            return "QUOTED"
        case .accepted:
            return "ACCEPTED"
        case .assigned:
            return "ASSIGNED"
        case .outForDelivery:
            return "IN TRANSIT"
        case .delivered:
            return "DELIVERED"
        case .cancelled:
            return "CANCELLED"
        case .addressReview:
            return "REVIEW"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .requested, .addressReview:
            return AppTheme.warning
        case .quoted:
            return AppTheme.accentBlue
        case .accepted, .assigned:
            return AppTheme.success
        case .outForDelivery:
            return AppTheme.accentBlue
        case .delivered:
            return AppTheme.success
        case .cancelled:
            return AppTheme.danger
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.18)
    }
}
