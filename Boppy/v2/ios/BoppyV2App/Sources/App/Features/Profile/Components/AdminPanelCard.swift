import SwiftUI

struct AdminPanelCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(AppTheme.textMuted)
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

    private var iconColor: Color {
        if icon.contains("shield") {
            return AppTheme.warning
        }
        return AppTheme.accentBlue
    }
}
