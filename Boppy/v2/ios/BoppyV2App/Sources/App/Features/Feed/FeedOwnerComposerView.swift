import SwiftUI
import PhotosUI
import BoppyV2Core

struct FeedOwnerComposerView: View {
    @Binding var newPostType: PostType
    @Binding var newCaption: String
    @Binding var newMediaPath: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isFileImporterPresented: Bool

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

            if newPostType != .text {
                TextField("Media URL or path", text: $newMediaPath)
                    .feedInputFieldStyle()
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack(spacing: 8) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: newPostType == .video ? .videos : .images,
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
                    Text("Selected: \(selectedMediaLabel)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
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
}

extension View {
    func feedInputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .tint(AppTheme.accentBlue)
    }
}
