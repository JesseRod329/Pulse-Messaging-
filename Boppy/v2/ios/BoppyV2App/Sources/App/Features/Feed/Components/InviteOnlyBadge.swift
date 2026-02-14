import SwiftUI

struct InviteOnlyBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Invite Only")
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255).opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255).opacity(0.35), lineWidth: 1)
        )
    }
}
