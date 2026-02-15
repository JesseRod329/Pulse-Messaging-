import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import BoppyV2Core

struct FeedView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

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
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            FeedHeaderStrip(
                                title: selectedChannelTitle,
                                subtitle: "Owner Channel"
                            )

                            if let user = coordinator.user, user.role == .follower {
                                inviteJoinCard
                            }

                            if coordinator.user?.role == .owner {
                                ownerChannelBuilder
                            }

                            channelPicker

                            if let user = coordinator.user, user.role == .owner {
                                ownerComposer
                            }

                            latestInviteCard

                            if coordinator.posts.isEmpty {
                                ContentUnavailableView(
                                    "No Posts",
                                    systemImage: "text.bubble",
                                    description: Text("Owner posts will appear here.")
                                )
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(coordinator.posts) { post in
                                        FeedPostCard(
                                            post: post,
                                            showsFollowerHint: coordinator.user?.role == .follower,
                                            selectedReaction: selectedReactionByPostID[post.id],
                                            onReactionSelected: { emoji in
                                                selectedReactionByPostID[post.id] = emoji
                                            },
                                            onQuickOrder: {
                                                quickOrderPost = post
                                            }
                                        )
                                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .onTapGesture {
                                                if coordinator.user?.role == .follower {
                                                    quickOrderPost = post
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.screenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, AppTheme.contentBottomPadding)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                            alignment: .top
                        )
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AppTheme.screenGradient)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("feed.refresh")
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
        .sheet(isPresented: $isChannelThreadSheetPresented) {
            channelThreadSheet
        }
        .sheet(item: $quickOrderPost) { post in
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
                coordinator.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                await importMediaFromPhotos(newValue)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appScreenBackground()
    }

    private var selectedChannelTitle: String {
        coordinator.selectedChannel?.title ?? "BeamBox Global"
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
                .accessibilityIdentifier("feed.openThreads")
            }

            if coordinator.channels.isEmpty {
                Text("No channels yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                Picker("Channel", selection: Binding(
                    get: { coordinator.selectedChannelID ?? "" },
                    set: { newValue in
                        guard !newValue.isEmpty else { return }
                        Task { await coordinator.selectChannel(newValue) }
                    }
                )) {
                    ForEach(coordinator.channels) { channel in
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

            TextField("Paste invite token", text: $coordinator.inviteTokenInput)
                .feedInputFieldStyle()
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Button("Join Channel") {
                Task { await coordinator.joinChannel() }
            }
            .buttonStyle(.borderedProminent)
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
            .disabled(newChannelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Owner Composer")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Create Invite") {
                    Task {
                        await coordinator.createInvite(expiresInHours: 72, maxUses: nil)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.selectedChannelID == nil)
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
                    .accessibilityIdentifier("feed.importPhotos")

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Files", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("feed.importFiles")

                    if !newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            newMediaPath = ""
                        }
                        .buttonStyle(.bordered)
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
                let media = newPostType == .text ? nil : newMediaPath
                Task {
                    await coordinator.createPost(type: newPostType, caption: newCaption, mediaPath: media)
                    newCaption = ""
                    newMediaPath = ""
                    selectedPhotoItem = nil
                    newPostType = .text
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                coordinator.selectedChannelID == nil
                || newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (newPostType != .text && newMediaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
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

    @ViewBuilder
    private var latestInviteCard: some View {
        if let invite = coordinator.latestInvite {
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
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coordinator.channels) { channel in
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
                        isChannelThreadSheetPresented = false
                    }
                    .accessibilityIdentifier("feed.closeThreads")
                }
            }
        }
    }

    @ViewBuilder
    private func channelThreadCard(for channel: Channel) -> some View {
        let isSelected = channel.id == coordinator.selectedChannelID

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

                if coordinator.posts.isEmpty {
                    Text("No posts yet in this thread.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(coordinator.posts.prefix(3))) { post in
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
            Task {
                await coordinator.selectChannel(channel.id)
            }
        }
        .accessibilityIdentifier("feed.thread.card")
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
            coordinator.errorMessage = error.localizedDescription
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
            coordinator.errorMessage = error.localizedDescription
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
                            .padding(12)
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

private extension View {
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
