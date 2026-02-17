import SwiftUI
import BoppyV2Core

struct FeedPostListView: View {
    let posts: [ChannelPost]
    let isFollower: Bool
    @Binding var selectedReactionByPostID: [String: String]
    let onQuickOrder: (ChannelPost) -> Void

    var body: some View {
        if posts.isEmpty {
            ContentUnavailableView(
                "No Posts",
                systemImage: "text.bubble",
                description: Text("Owner posts will appear here.")
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(posts) { post in
                    FeedPostCard(
                        post: post,
                        showsFollowerHint: isFollower,
                        selectedReaction: selectedReactionByPostID[post.id],
                        onReactionSelected: { emoji in
                            selectedReactionByPostID[post.id] = emoji
                        },
                        onQuickOrder: {
                            onQuickOrder(post)
                        }
                    )
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                    .onTapGesture {
                        if isFollower {
                            onQuickOrder(post)
                        }
                    }
                }
            }
        }
    }
}

