import SwiftUI
import PhotosUI
import BoppyV2Core

struct FeedOwnerComposerView: View {
    @Binding var newPostType: PostType
    @Binding var newCaption: String
    @Binding var newMediaPath: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isFileImporterPresented: Bool
    @Binding var newPrice: String
    @Binding var newHeroSubtitle: String

    let selectedChannelID: String?
    let isOffline: Bool
    let selectedMediaLabel: String

    let onCreateInvite: () -> Void
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Owner Composer")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Create Invite") {
                    onCreateInvite()
                }
                .buttonStyle(.bordered)
                .disabled(selectedChannelID == nil || isOffline)
                .accessibilityLabel("Create invite")
                .accessibilityHint("Generates a new invite link for the active channel.")
                .accessibilityIdentifier("feed.createInvite")
            }

            Picker("Post Type", selection: $newPostType) {
                ForEach(PostType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("Caption", text: $newCaption)
                .feedInputFieldStyle()

            TextField("Subtitle (optional)", text: $newHeroSubtitle)
                .feedInputFieldStyle()

            HStack(spacing: 4) {
                Text("$")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Price", text: $newPrice)
                    .keyboardType(.decimalPad)
            }
            .feedInputFieldStyle()

            if newPostType != .text {
                HStack(spacing: 8) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: newPostType == .video ? .videos : .any(of: [.images, .videos]),
                        photoLibrary: .shared()
                    ) {
                        Label("Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Import from photos")
                    .accessibilityHint("Select media from your photo library.")
                    .accessibilityIdentifier("feed.importPhotos")

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Files", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Import from files")
                    .accessibilityHint("Select media from files.")
                    .accessibilityIdentifier("feed.importFiles")

                    if !newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            newMediaPath = ""
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Clear selected media")
                        .accessibilityHint("Removes the currently selected media attachment.")
                        .accessibilityIdentifier("feed.clearMedia")
                    }
                }

                if !newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

                        Text(selectedMediaLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            Button("Publish") {
                onPublish()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isOffline
                || selectedChannelID == nil
                || newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (newPostType != .text && newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .accessibilityLabel("Publish post")
            .accessibilityHint("Posts this update to the active channel.")
            .accessibilityIdentifier("feed.publishPost")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var mediaPreviewURL: URL? {
        let trimmed = newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        if FileManager.default.fileExists(atPath: trimmed) {
            return URL(fileURLWithPath: trimmed)
        }
        return nil
    }
}
