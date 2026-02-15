import SwiftUI
import BoppyV2Core

struct FeedPostCard: View {
    let post: ChannelPost
    let showsFollowerHint: Bool
    let selectedReaction: String?
    let onReactionSelected: ((String) -> Void)?
    let onQuickOrder: (() -> Void)?

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
            HStack {
                Text("\(laneLabel) • \(dateLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer(minLength: 8)
                Text(availabilityBadge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface, in: Capsule())
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if post.postType != .text {
                Group {
                    if
                        let mediaPath = post.mediaPath,
                        let url = mediaURL(from: mediaPath)
                    {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.surfaceElevated)
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.surfaceElevated)
                    }
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if post.postType == .image || post.postType == .video {
                        Text(post.postType == .video ? "VIDEO" : "IMAGE")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.surface, in: Capsule())
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(8)
                    }
                }
            }

            if !headlineCaption.isEmpty {
                Text(headlineCaption)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
            }

            if let secondaryCaption {
                Text(secondaryCaption)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
            }

            if let mediaPath = post.mediaPath, !mediaPath.isEmpty {
                Text(mediaPath)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accentBlue)
                    .lineLimit(1)
            }

            if showsFollowerHint {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(reactionOptions, id: \.self) { emoji in
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
                            .accessibilityIdentifier("feed.post.reaction")
                        }
                    }

                    HStack {
                        Label(etaLabel, systemImage: "clock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textMuted)
                        Spacer()
                        Button {
                            onQuickOrder?()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Order")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentBlue, in: Capsule())
                            .foregroundStyle(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("feed.post.quickOrder")
                    }
                    HStack(spacing: 4) {
                        Text("Quick order card")
                        Image(systemName: "chevron.up")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var laneLabel: String {
        let lanes = ["Dubai Hub", "Paris Office", "West Yard", "Main Gallery"]
        let scalarSum = post.id.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        return lanes[scalarSum % lanes.count]
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
