import SwiftUI
import BoppyV2Core

struct FeedChannelThreadSheetView: View {
    let channels: [Channel]
    let selectedChannelID: String?
    let posts: [ChannelPost]
    let onSelectChannel: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(channels) { channel in
                            channelThreadCard(for: channel)
                        }
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .navigationTitle("Channel Threads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                    .accessibilityLabel("Close threads")
                    .accessibilityHint("Dismisses the channel threads sheet.")
                    .accessibilityIdentifier("feed.closeThreads")
                }
            }
        }
    }

    @ViewBuilder
    private func channelThreadCard(for channel: Channel) -> some View {
        let isSelected = channel.id == selectedChannelID

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isSelected ? AppTheme.accentBlue : AppTheme.surfaceElevated)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(channel.description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                    Text(isSelected ? "Current thread" : "Tap to open thread")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? AppTheme.accentBlue : AppTheme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textMuted)
            }

            if isSelected {
                Divider()
                    .overlay(AppTheme.border)

                if posts.isEmpty {
                    Text("No posts yet in this thread.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(posts.prefix(3))) { post in
                            HStack(alignment: .top, spacing: 8) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(AppTheme.border)
                                    .frame(width: 2, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled post" : post.caption)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(post.postType.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(isSelected ? AppTheme.accentBlue.opacity(0.75) : AppTheme.border, lineWidth: 1)
        )
        .onTapGesture {
            onSelectChannel(channel.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(channel.title)
        .accessibilityHint(isSelected ? "Current thread." : "Opens this channel thread.")
        .accessibilityIdentifier("feed.thread.card")
    }
}
