import SwiftUI

struct FeedHeaderStrip: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(AppTheme.accentBlue)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: AppTheme.brandSymbolName)
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.system(size: 15, weight: .bold))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 6, height: 6)
                    Text(subtitle.uppercased().replacingOccurrences(of: "CHANNEL", with: "CHANNEL"))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(AppTheme.success)
                }
            }

            Spacer()

            InviteOnlyBadge()
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
