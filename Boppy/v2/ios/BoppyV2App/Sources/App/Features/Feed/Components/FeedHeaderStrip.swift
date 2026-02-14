import SwiftUI

struct FeedHeaderStrip: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color(red: 60 / 255, green: 131 / 255, blue: 246 / 255))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .bold))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            InviteOnlyBadge()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
