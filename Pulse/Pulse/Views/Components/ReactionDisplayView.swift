//
//  ReactionDisplayView.swift
//  Pulse
//
//  Display and manage emoji reactions on messages.
//

import SwiftUI

struct ReactionDisplayView: View {
    let reactions: [Reaction]
    let onAddReaction: () -> Void
    let onRemoveReaction: (String) -> Void
    let currentUserId: String

    var groupedReactions: [(emoji: String, count: Int, hasUserReacted: Bool)] {
        let grouped = Dictionary(grouping: reactions, by: { $0.emoji })
        return grouped.map { emoji, reactionsWithEmoji in
            let hasUserReacted = reactionsWithEmoji.contains { $0.userId == currentUserId }
            return (emoji, reactionsWithEmoji.count, hasUserReacted)
        }
        .sorted { $0.emoji < $1.emoji }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Existing reactions
            ForEach(groupedReactions, id: \.emoji) { emoji, count, hasUserReacted in
                ReactionPill(
                    emoji: emoji,
                    count: count,
                    isSelected: hasUserReacted,
                    onTap: {
                        if hasUserReacted {
                            onRemoveReaction(emoji)
                        } else {
                            // Would need to re-add with new user reaction
                            onAddReaction()
                        }
                    }
                )
            }

            // Add reaction button
            Button(action: onAddReaction) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding(.top, 6)
    }
}

struct ReactionPill: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 14))

                if count > 1 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 28)
            .paddingHorizontal(8)
            .background(
                isSelected ?
                Color.blue.opacity(0.2) :
                Color(.secondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
        }
    }
}

extension View {
    func paddingHorizontal(_ padding: CGFloat) -> some View {
        self.padding(.horizontal, padding)
    }
}

#Preview {
    VStack(spacing: 16) {
        ReactionDisplayView(
            reactions: [
                Reaction(emoji: "👍", userId: "user1"),
                Reaction(emoji: "👍", userId: "user2"),
                Reaction(emoji: "❤️", userId: "me"),
                Reaction(emoji: "😂", userId: "user1")
            ],
            onAddReaction: {},
            onRemoveReaction: { _ in },
            currentUserId: "me"
        )

        ReactionDisplayView(
            reactions: [],
            onAddReaction: {},
            onRemoveReaction: { _ in },
            currentUserId: "me"
        )
    }
    .padding()
}
