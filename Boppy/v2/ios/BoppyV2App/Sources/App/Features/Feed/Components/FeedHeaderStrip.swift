import SwiftUI

struct FeedHeaderStrip: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(AppTheme.accentBlue)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: AppTheme.brandSymbolName)
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.system(size: 16, weight: .bold))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 6, height: 6)
                    Text(subtitle.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.success)
                }
            }

            Spacer()

            InviteOnlyBadge()
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
