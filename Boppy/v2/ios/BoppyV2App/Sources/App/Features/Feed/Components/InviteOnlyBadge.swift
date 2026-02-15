import SwiftUI

struct InviteOnlyBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
            Text("INVITE ONLY")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(AppTheme.accentBlue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
