//
//  EmojiPickerView.swift
//  Pulse
//
//  Emoji picker for message reactions.
//

import SwiftUI

struct EmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss

    // Common emoji reactions
    let commonEmojis = [
        "👍", "❤️", "😂", "😮", "😢", "🔥",
        "👌", "💯", "😍", "🤔", "👀", "🎉",
        "💪", "🚀", "✨", "😎", "🙏", "👏"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Reaction")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))

            Divider()

            // Emoji Grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                    spacing: 12
                ) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button(action: {
                            onEmojiSelected(emoji)
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxHeight: 350)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    EmojiPickerView(onEmojiSelected: { _ in })
}
