import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import BoppyV2Core

struct FeedView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var feedStore: FeedStore

    @State private var newChannelTitle = ""
    @State private var newChannelDescription = ""

    @State private var newPostType: PostType = .text
    @State private var newCaption = ""
    @State private var newMediaPath = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var isChannelThreadSheetPresented = false
    @State private var quickOrderPost: ChannelPost?
    @State private var selectedReactionByPostID: [String: String] = [:]

    var body: some View {
        NavigationStack {
            FeedShellView(selectedChannelTitle: selectedChannelTitle) {
                await coordinator.refreshAll()
            } content: {
                if let user = authStore.user, user.role == .follower {
                    inviteJoinCard
                }

                if authStore.user?.role == .owner {
                    ownerChannelBuilder
                }

                channelPicker

                if authStore.user?.role == .owner {
                    ownerComposer
                }

                latestInviteCard

                FeedPostListView(
                    posts: feedStore.posts,
                    isFollower: authStore.user?.role == .follower,
                    selectedReactionByPostID: $selectedReactionByPostID
                ) { post in
                    quickOrderPost = post
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await coordinator.refreshAll()
                        }
                    } label: {
                        DesignIconView(icon: .refresh, size: 16, color: AppTheme.textSecondary)
                    }
                    .accessibilityLabel("Refresh feed")
                    .accessibilityHint("Loads the latest posts and channels.")
                    .accessibilityIdentifier("feed.refresh")
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
        .fullScreenCover(isPresented: $isChannelThreadSheetPresented) {
            channelThreadSheet
        }
        .fullScreenCover(item: $quickOrderPost) { post in
            QuickOrderMenuSheet(post: post) { option in
                openQuickOrderFlow(for: post, option: option)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .movie, .video]
        ) { result in
            switch result {
            case .success(let url):
                importMediaFile(from: url)
            case .failure(let error):
                coordinator.present(error)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                await importMediaFromPhotos(newValue)
            }
        }
        .appScreenBackground()
    }

    private var selectedChannelTitle: String {
        feedStore.channels.first(where: { $0.id == feedStore.selectedChannelID })?.title ?? "BeamBox Global"
    }

    private var channelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Channel")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Button {
                    isChannelThreadSheetPresented = true
                } label: {
                    Label("Threads", systemImage: "text.bubble")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open channel threads")
                .accessibilityHint("Shows all channels and recent thread activity.")
                .accessibilityIdentifier("feed.openThreads")
            }

            if feedStore.channels.isEmpty {
                Text("No channels yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                Picker("Channel", selection: Binding(
                    get: { feedStore.selectedChannelID ?? "" },
                    set: { newValue in
                        guard !newValue.isEmpty else { return }
                        Task { await coordinator.selectChannel(newValue) }
                    }
                )) {
                    ForEach(feedStore.channels) { channel in
                        Text(channel.title).tag(channel.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.textPrimary)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var inviteJoinCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Join by Invite")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Paste invite token", text: $authStore.inviteTokenInput)
                .feedInputFieldStyle()
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel("Invite token")
                .accessibilityHint("Paste your invite token to join a channel.")

            Button("Join Channel") {
                Task { await coordinator.joinChannel() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                authStore.isOffline
                || authStore.inviteTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .accessibilityLabel("Join channel")
            .accessibilityHint("Joins the selected channel using the invite token.")
            .accessibilityIdentifier("feed.joinChannel")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var ownerChannelBuilder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Channel")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Channel title", text: $newChannelTitle)
                .feedInputFieldStyle()

            TextField("Description", text: $newChannelDescription)
                .feedInputFieldStyle()

            Button("Create") {
                let title = newChannelTitle
                let description = newChannelDescription
                Task {
                    await coordinator.createChannel(title: title, description: description)
                    newChannelTitle = ""
                    newChannelDescription = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                authStore.isOffline
                || newChannelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .accessibilityLabel("Create channel")
            .accessibilityHint("Creates a new owner channel with the entered title and description.")
            .accessibilityIdentifier("feed.createChannel")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var ownerComposer: some View {
        FeedOwnerComposerView(
            newPostType: $newPostType,
            newCaption: $newCaption,
            newMediaPath: $newMediaPath,
            selectedPhotoItem: $selectedPhotoItem,
            isFileImporterPresented: $isFileImporterPresented,
            selectedChannelID: feedStore.selectedChannelID,
            isOffline: authStore.isOffline,
            selectedMediaLabel: selectedMediaLabel,
            onCreateInvite: {
                Task {
                    await coordinator.createInvite(expiresInHours: 72, maxUses: nil)
                }
            },
            onPublish: {
                let media = newPostType == .text ? nil : newMediaPath
                Task {
                    await coordinator.createPost(type: newPostType, caption: newCaption, mediaPath: media)
                    newCaption = ""
                    newMediaPath = ""
                    selectedPhotoItem = nil
                    newPostType = .text
                }
            }
        )
    }

    @ViewBuilder
    private var latestInviteCard: some View {
        if let invite = authStore.latestInvite {
            VStack(alignment: .leading, spacing: 6) {
                Text("Latest invite")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(invite.inviteURL)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.cardGradient,
                in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private var selectedMediaLabel: String {
        let trimmed = newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "None" }
        if let url = URL(string: trimmed) {
            return url.lastPathComponent.isEmpty ? trimmed : url.lastPathComponent
        }
        let plainURL = URL(fileURLWithPath: trimmed)
        return plainURL.lastPathComponent.isEmpty ? trimmed : plainURL.lastPathComponent
    }

    private var channelThreadSheet: some View {
        FeedChannelThreadSheetView(
            channels: feedStore.channels,
            selectedChannelID: feedStore.selectedChannelID,
            posts: feedStore.posts,
            onSelectChannel: { channelID in
                Task {
                    await coordinator.selectChannel(channelID)
                }
            },
            onClose: {
                isChannelThreadSheetPresented = false
            }
        )
    }

    @MainActor
    private func importMediaFromPhotos(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let pickedType = item.supportedContentTypes.first
            let ext = pickedType?.preferredFilenameExtension ?? defaultImportedExtension
            let targetURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("beambox-photo-\(UUID().uuidString)")
                .appendingPathExtension(ext)

            try data.write(to: targetURL, options: [.atomic])
            updatePostType(for: pickedType, fileExtension: ext)
            newMediaPath = targetURL.absoluteString
        } catch {
            coordinator.present(error)
        }
    }

    private func importMediaFile(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let ext = url.pathExtension.isEmpty ? defaultImportedExtension : url.pathExtension
            let targetURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("beambox-file-\(UUID().uuidString)")
                .appendingPathExtension(ext)

            try FileManager.default.copyItem(at: url, to: targetURL)
            let pickedType = UTType(filenameExtension: ext)
            updatePostType(for: pickedType, fileExtension: ext)
            newMediaPath = targetURL.absoluteString
        } catch {
            coordinator.present(error)
        }
    }

    private var defaultImportedExtension: String {
        newPostType == .video ? "mp4" : "jpg"
    }

    private func updatePostType(for type: UTType?, fileExtension: String) {
        if let type, (type.conforms(to: .movie) || type.conforms(to: .video)) {
            newPostType = .video
            return
        }

        if type?.conforms(to: .image) == true {
            newPostType = .image
            return
        }

        let lowered = fileExtension.lowercased()
        let videoExtensions = Set(["mov", "mp4", "m4v", "avi", "mkv", "webm"])
        newPostType = videoExtensions.contains(lowered) ? .video : .image
    }

    private func openQuickOrderFlow(for post: ChannelPost, option: QuickOrderOption) {
        quickOrderPost = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            coordinator.openOrderSheet(for: post, prefilledQuote: option.prefilledNote)
        }
    }
}

private struct QuickOrderOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let prefilledNote: String
}

private struct QuickOrderMenuSheet: View {
    let post: ChannelPost
    let onSelect: (QuickOrderOption) -> Void

    private let options: [QuickOrderOption] = [
        QuickOrderOption(
            id: "standard",
            title: "Standard Quote",
            subtitle: "Best regular-rate option",
            prefilledNote: "Standard quote request for this item."
        ),
        QuickOrderOption(
            id: "priority",
            title: "Priority Handling",
            subtitle: "Faster handling and delivery",
            prefilledNote: "Priority order request with faster handling."
        ),
        QuickOrderOption(
            id: "bulk",
            title: "Bulk Order",
            subtitle: "Multi-unit quote request",
            prefilledNote: "Bulk order request. Please provide tiered pricing."
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text(post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Quick order" : post.caption)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    ForEach(options) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.accentBlue)
                            }
                            .padding(AppTheme.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityHint("Starts a \(option.title.lowercased()) request for this post.")
                        .accessibilityIdentifier("feed.quickOrder.\(option.id)")
                    }

                    Text("Select an option to continue to the full order card.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(AppTheme.cardPadding)
            }
            .navigationTitle("Quick Order")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(330)])
        }
    }
}
