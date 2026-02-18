import SwiftUI

extension View {
    func feedInputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .tint(AppTheme.accentBlue)
    }
}
