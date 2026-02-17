import SwiftUI
import UIKit
import BoppyV2Core

struct FeedPostCard: View {
    let post: ChannelPost
    let showsFollowerHint: Bool
    let selectedReaction: String?
    let onReactionSelected: ((String) -> Void)?
    let onQuickOrder: (() -> Void)?

    @State private var hasAppeared = false
    @ScaledMetric(relativeTo: .body) private var headerAvatarSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var heroAvatarSize: CGFloat = 28

    init(
        post: ChannelPost,
        showsFollowerHint: Bool,
        selectedReaction: String? = nil,
        onReactionSelected: ((String) -> Void)? = nil,
        onQuickOrder: (() -> Void)? = nil
    ) {
        self.post = post
        self.showsFollowerHint = showsFollowerHint
        self.selectedReaction = selectedReaction
        self.onReactionSelected = onReactionSelected
        self.onQuickOrder = onQuickOrder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            hero

            VStack(alignment: .leading, spacing: 6) {
                Text(headlineCaption)
                    .font(AppTheme.inter(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                if let heroSubtitle {
                    Text(heroSubtitle)
                        .font(AppTheme.inter(14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            if showsFollowerHint {
                followerActions
            }
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .opacity(hasAppeared ? 1 : 0.4)
        .offset(y: hasAppeared ? 0 : 10)
        .animation(.easeOut(duration: 0.25), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
        .accessibilityIdentifier("feed.post.card.\(post.id)")
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.accentBlue.opacity(0.22))
                .frame(width: headerAvatarSize, height: headerAvatarSize)
                .overlay(
                    Text("BB")
                        .font(AppTheme.inter(11, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("BeamBox Supply")
                    .font(AppTheme.inter(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(dateLabel)
                    .font(AppTheme.inter(11, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer(minLength: 8)

            Text(slotBadge)
                .font(AppTheme.inter(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.accentBlue.opacity(0.92), in: Capsule())
        }
    }

    private var hero: some View {
        let ratio = post.heroAspectRatio ?? (16.0 / 9.0)

        return ZStack(alignment: .topLeading) {
            if let mediaPath = post.mediaPath,
               let url = mediaURL(from: mediaPath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderHero
                    }
                }
            } else {
                placeholderHero
            }

            Text(slotBadge)
                .font(AppTheme.inter(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)

            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.surface.opacity(0.9))
                        .frame(width: heroAvatarSize, height: heroAvatarSize)
                        .overlay(Circle().stroke(AppTheme.navBar, lineWidth: 2))
                        .overlay(
                            Text(String(index + 1))
                                .font(AppTheme.inter(10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                        )
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .aspectRatio(ratio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderHero: some View {
        LinearGradient(
            colors: [AppTheme.surfaceElevated, AppTheme.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
                Text("Media pending")
                    .font(AppTheme.inter(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private var followerActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(reactionOptions.enumerated()), id: \.offset) { index, emoji in
                    Button {
                        onReactionSelected?(emoji)
                    } label: {
                        Text(emoji)
                            .font(.callout)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedReaction == emoji ? AppTheme.accentBlue.opacity(0.24) : AppTheme.surface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedReaction == emoji ? AppTheme.accentBlue : AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("React \(emoji)")
                    .accessibilityHint("Adds a \(emoji) reaction to this post.")
                    .accessibilityValue(selectedReaction == emoji ? "Selected" : "Not selected")
                    .accessibilityIdentifier("feed.post.reaction.\(index)")
                }
            }

            HStack {
                Label(etaLabel, systemImage: "clock")
                    .font(AppTheme.inter(11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onQuickOrder?()
                } label: {
                    HStack(spacing: 4) {
                        Text("Request Quote")
                        DesignIconView(icon: .chevronRight, size: 11, color: AppTheme.textPrimary)
                    }
                    .font(AppTheme.inter(13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.accentBlue)
                    )
                    .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .shadow(color: AppTheme.accentBlue.opacity(0.3), radius: 8, y: 4)
                .accessibilityLabel("Request quote")
                .accessibilityHint("Starts an order request for this post.")
                .accessibilityIdentifier("feed.post.quickOrder")
            }
        }
    }

    private var slotBadge: String {
        if let label = post.slotLabel, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label.uppercased()
        }
        if let slotRemaining = post.slotRemaining {
            return "\(slotRemaining) SLOTS LEFT"
        }
        return availabilityBadge
    }

    private var heroSubtitle: String? {
        if let subtitle = post.heroSubtitle,
           !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        return secondaryCaption
    }

    private var availabilityBadge: String {
        switch post.postType {
        case .image:
            return "72 SLOTS LEFT"
        case .video:
            return "CONSOLIDATED SHIP"
        case .text:
            return "POLICY UPDATE"
        }
    }

    private var etaLabel: String {
        switch post.postType {
        case .image:
            return "ETA 2 Days"
        case .video:
            return "ETA 4 Days"
        case .text:
            return "Update Available"
        }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        if Calendar.current.isDateInToday(post.createdAt) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if Calendar.current.isDateInYesterday(post.createdAt) {
            formatter.dateFormat = "'Yesterday,' h:mm a"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        return formatter.string(from: post.createdAt)
    }

    private var headlineCaption: String {
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return post.postType == .text ? "Channel update" : "New shipment update" }
        let segments = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
        let first = String(segments.first ?? "")
        return first.isEmpty ? trimmed : first
    }

    private var secondaryCaption: String? {
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let segments = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
        guard segments.count > 1 else { return nil }
        let tail = String(segments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return tail.isEmpty ? nil : tail
    }

    private var reactionOptions: [String] {
        ["🔥", "👍", "❤️", "👏", "📦"]
    }

    private func mediaURL(from mediaPath: String) -> URL? {
        if let url = URL(string: mediaPath), url.scheme != nil {
            return url
        }
        if FileManager.default.fileExists(atPath: mediaPath) {
            return URL(fileURLWithPath: mediaPath)
        }
        return nil
    }
}
