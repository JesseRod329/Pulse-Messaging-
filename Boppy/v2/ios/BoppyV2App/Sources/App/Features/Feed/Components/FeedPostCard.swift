import SwiftUI
import UIKit
import BoppyV2Core

struct FeedPostCard: View {
    let post: ChannelPost
    let channelTitle: String
    let showsFollowerHint: Bool
    let selectedReaction: String?
    let onReactionSelected: ((String) -> Void)?
    let onQuickOrder: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var headerAvatarSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var heroAvatarSize: CGFloat = 28

    init(
        post: ChannelPost,
        channelTitle: String = "boppyv1 Supply",
        showsFollowerHint: Bool,
        selectedReaction: String? = nil,
        onReactionSelected: ((String) -> Void)? = nil,
        onQuickOrder: (() -> Void)? = nil
    ) {
        self.post = post
        self.channelTitle = channelTitle
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
                    .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                if let heroSubtitle {
                    Text(heroSubtitle)
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                priceRow
            }

            if showsFollowerHint {
                followerActions
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .accessibilityIdentifier("feed.post.card.\(post.id)")
    }

    private var avatarInitials: String {
        let words = channelTitle.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(channelTitle.prefix(2)).uppercased()
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.accentBlue.opacity(0.22))
                .frame(width: headerAvatarSize, height: headerAvatarSize)
                .overlay(
                    Text(avatarInitials)
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(channelTitle)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(dateLabel)
                    .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
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
        ZStack(alignment: .topLeading) {
            if let mediaPath = post.mediaPath,
               let url = mediaURL(from: mediaPath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        failedHero
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

            if let remaining = post.slotRemaining, remaining > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(remaining)")
                        .font(AppTheme.inter(10, weight: .bold))
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 180)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
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
                    .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(AppTheme.textMuted)
                Text("Media pending")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private var failedHero: some View {
        LinearGradient(
            colors: [AppTheme.surfaceElevated, AppTheme.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(AppTheme.warning)
                Text("Image failed to load")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
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
                            .font(AppTheme.inter(AppTheme.typeBody, weight: .regular, relativeTo: .callout))
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
                if let priceCents = post.priceCents, priceCents > 0 {
                    Label("lb \(Self.formatPrice(priceCents))", systemImage: "tag.fill")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold))
                        .foregroundStyle(AppTheme.success)
                } else {
                    Label(etaLabel, systemImage: "clock")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onQuickOrder?()
                } label: {
                    HStack(spacing: 4) {
                        Text("Request Quote")
                        DesignIconView(icon: .chevronRight, size: 11, color: AppTheme.textPrimary)
                    }
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
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

    /// Displays lb / hp / qp prices. lb comes from priceCents; hp and qp are encoded
    /// in heroSubtitle as "hp: $X.XX / qp: $X.XX" by the post composer.
    @ViewBuilder
    private var priceRow: some View {
        let lbPrice = post.priceCents.flatMap { $0 > 0 ? Self.formatPrice($0) : nil }
        // Parse hp/qp from heroSubtitle if it contains our encoded format
        let (hpPrice, qpPrice) = Self.parsePriceSubtitle(post.heroSubtitle)
        let hasPrices = lbPrice != nil || hpPrice != nil || qpPrice != nil
        if hasPrices {
            HStack(spacing: 12) {
                if let lb = lbPrice {
                    priceChip(label: "lb", value: lb)
                }
                if let hp = hpPrice {
                    priceChip(label: "hp", value: hp)
                }
                if let qp = qpPrice {
                    priceChip(label: "qp", value: qp)
                }
            }
        }
    }

    private func priceChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(AppTheme.inter(9, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.success)
        }
    }

    /// Parses "hp: $X.XX / qp: $X.XX" (or partial) from heroSubtitle.
    private static func parsePriceSubtitle(_ subtitle: String?) -> (hp: String?, qp: String?) {
        guard let subtitle else { return (nil, nil) }
        var hp: String?
        var qp: String?
        let parts = subtitle.components(separatedBy: "/")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("hp:") {
                hp = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("qp:") {
                qp = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }
        return (hp, qp)
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
        case .text:
            return "UPDATE"
        default:
            return "AVAILABLE"
        }
    }

    private var etaLabel: String {
        switch post.postType {
        case .text:
            return "Update available"
        default:
            return "Details in post"
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

    private static func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
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
