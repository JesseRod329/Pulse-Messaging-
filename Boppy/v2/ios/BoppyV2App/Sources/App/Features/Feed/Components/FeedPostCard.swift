import SwiftUI
import BoppyV2Core

struct FeedPostCard: View {
    let post: ChannelPost
    let showsFollowerHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(post.postType.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(post.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if post.postType != .text {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 170)
                    .overlay(alignment: .topTrailing) {
                        if post.postType == .image || post.postType == .video {
                            Text(post.postType == .video ? "Video" : "Image")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(8)
                        }
                    }
            }

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.body)
            }

            if let mediaPath = post.mediaPath, !mediaPath.isEmpty {
                Text(mediaPath)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }

            if showsFollowerHint {
                Text("Long press to request an order")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
