import SwiftUI
import PhotosUI
import BoppyV2Core

struct EditPostView: View {
    let post: ChannelPost
    let onSave: (_ caption: String, _ mediaPath: String?, _ heroSubtitle: String?, _ priceCents: Int?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var caption: String
    @State private var heroSubtitle: String
    @State private var priceLb: String
    @State private var priceHp: String
    @State private var priceQp: String
    @State private var mediaPath: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var isSaving = false

    init(post: ChannelPost, onSave: @escaping (_ caption: String, _ mediaPath: String?, _ heroSubtitle: String?, _ priceCents: Int?) -> Void) {
        self.post = post
        self.onSave = onSave
        _caption = State(initialValue: post.caption)
        // Parse heroSubtitle: strip out encoded hp/qp so we only show the user portion
        let (userSubtitle, hp, qp) = Self.parseHeroSubtitle(post.heroSubtitle)
        _heroSubtitle = State(initialValue: userSubtitle)
        _priceLb = State(initialValue: Self.centsToString(post.priceCents))
        _priceHp = State(initialValue: hp)
        _priceQp = State(initialValue: qp)
        _mediaPath = State(initialValue: post.mediaPath ?? "")
    }

    private static func centsToString(_ cents: Int?) -> String {
        guard let cents, cents > 0 else { return "" }
        let dollars = Double(cents) / 100.0
        return String(format: "%.2f", dollars)
    }

    /// Splits heroSubtitle into (userText, hpValue, qpValue).
    /// If it was encoded by the composer it looks like "UserText · hp: $X / qp: $Y"
    /// or just "hp: $X / qp: $Y" with no user text prefix.
    private static func parseHeroSubtitle(_ raw: String?) -> (userText: String, hp: String, qp: String) {
        guard let raw, !raw.isEmpty else { return ("", "", "") }
        // Split on " · " first to get user subtitle vs price part
        let midDot = " · "
        var userPart: String
        var pricePart: String
        if let range = raw.range(of: midDot) {
            userPart = String(raw[raw.startIndex..<range.lowerBound])
            pricePart = String(raw[range.upperBound...])
        } else {
            userPart = ""
            pricePart = raw
        }
        // Parse hp and qp out of pricePart
        var hp = ""
        var qp = ""
        let parts = pricePart.components(separatedBy: "/")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("hp:") {
                let val = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                // Strip leading "$" for the text field
                hp = val.hasPrefix("$") ? String(val.dropFirst()) : val
            } else if trimmed.hasPrefix("qp:") {
                let val = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                qp = val.hasPrefix("$") ? String(val.dropFirst()) : val
            }
        }
        // If nothing parsed, userPart might just be the whole original value
        if hp.isEmpty && qp.isEmpty && userPart.isEmpty {
            userPart = raw
        }
        return (userPart, hp, qp)
    }

    private var lbCents: Int? {
        guard let dollars = Double(priceLb), dollars > 0 else { return nil }
        return Int(round(dollars * 100))
    }

    private var builtHeroSubtitle: String? {
        var parts: [String] = []
        if let hpVal = Double(priceHp), hpVal > 0 {
            parts.append("hp: \(String(format: "$%.2f", hpVal))")
        }
        if let qpVal = Double(priceQp), qpVal > 0 {
            parts.append("qp: \(String(format: "$%.2f", qpVal))")
        }
        let priceStr = parts.isEmpty ? nil : parts.joined(separator: " / ")
        let userText = heroSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userText.isEmpty, let ps = priceStr {
            return "\(userText) · \(ps)"
        } else if !userText.isEmpty {
            return userText
        }
        return priceStr
    }

    private var canSave: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit Post")
                    .font(AppTheme.inter(AppTheme.typeTitle2, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(AppTheme.textPrimary)

                fieldCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(AppTheme.textSecondary)

                        TextField("Caption", text: $caption)
                            .feedInputFieldStyle()

                        Text("Subtitle")
                            .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(AppTheme.textSecondary)

                        TextField("Subtitle (optional)", text: $heroSubtitle)
                            .feedInputFieldStyle()

                        Text("Prices")
                            .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 8) {
                            ForEach([("lb", $priceLb), ("hp", $priceHp), ("qp", $priceQp)], id: \.0) { label, binding in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(label)
                                        .font(AppTheme.inter(11, weight: .bold, relativeTo: .caption2))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    HStack(spacing: 3) {
                                        Text("$")
                                            .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        TextField("0.00", text: binding)
                                            .keyboardType(.decimalPad)
                                    }
                                    .feedInputFieldStyle()
                                }
                            }
                        }
                    }
                }

                if post.postType != .text {
                    fieldCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Media")
                                .font(AppTheme.inter(12, weight: .semibold, relativeTo: .caption))
                                .foregroundStyle(AppTheme.textSecondary)

                            if !mediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                mediaPreview
                            }

                            HStack(spacing: 8) {
                                PhotosPicker(
                                    selection: $selectedPhotoItem,
                                    matching: post.postType == .video ? .videos : .any(of: [.images, .videos]),
                                    photoLibrary: .shared()
                                ) {
                                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    isFileImporterPresented = true
                                } label: {
                                    Label("Files", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)

                                if !mediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button("Clear") {
                                        mediaPath = ""
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .background(AppTheme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .foregroundStyle(AppTheme.textPrimary)

                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image, .movie]) { result in
            if case .success(let url) = result {
                mediaPath = url.absoluteString
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await importMedia(from: newValue) }
        }
    }

    // MARK: - Subviews

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var mediaPreview: some View {
        HStack(spacing: 10) {
            if let url = mediaPreviewURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(AppTheme.surfaceElevated)
                            .overlay(Image(systemName: "photo").foregroundStyle(AppTheme.textMuted))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
            }

            Text(mediaLabel)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(1)
            Spacer()
        }
    }

    private var mediaPreviewURL: URL? {
        let trimmed = mediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        if FileManager.default.fileExists(atPath: trimmed) { return URL(fileURLWithPath: trimmed) }
        return nil
    }

    private var mediaLabel: String {
        let trimmed = mediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed) {
            return url.lastPathComponent
        }
        return trimmed
    }

    // MARK: - Actions

    private func save() {
        isSaving = true
        let trimmedMedia = mediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            caption.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmedMedia.isEmpty ? nil : trimmedMedia,
            builtHeroSubtitle,
            lbCents
        )
    }

    private func importMedia(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(UUID().uuidString).jpg"
            let fileURL = tempDir.appendingPathComponent(filename)
            try? data.write(to: fileURL)
            await MainActor.run { mediaPath = fileURL.absoluteString }
        }
    }
}
