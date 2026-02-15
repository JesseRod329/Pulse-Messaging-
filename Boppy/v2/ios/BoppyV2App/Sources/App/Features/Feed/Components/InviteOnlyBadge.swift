import SwiftUI

struct InviteOnlyBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("INVITE ONLY")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(AppTheme.accentBlue)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(AppTheme.accentBlue.opacity(0.14))
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.accentBlue.opacity(0.40), lineWidth: 1)
        )
    }
}
