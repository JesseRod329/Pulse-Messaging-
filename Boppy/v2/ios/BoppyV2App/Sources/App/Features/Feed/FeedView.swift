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
    @State private var isOwnerActionsSheetPresented = false
    @State private var quickOrderPost: ChannelPost?
    @State private var selectedReactionByPostID: [String: String] = [:]
    @State private var newPriceLb = ""
    @State private var newPriceHp = ""
    @State private var newPriceQp = ""
    @State private var newHeroSubtitle = ""
    @State private var editingPost: ChannelPost?
    @State private var postToDelete: ChannelPost?

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

                            if let user = authStore.user, user.role == .follower {
                                inviteJoinCard
                            }

                            channelPicker

                            if feedStore.posts.isEmpty {
                                AppEmptyStateView(
                                    icon: "text.bubble",
                                    title: "No Posts",
                                    subtitle: "Owner posts will appear here."
                                )
                            } else {
                                postListSection
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
                    .refreshable {
                        await coordinator.refreshAll()
                    }
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
                    HStack(spacing: 12) {
                        if authStore.user?.role == .owner {
                            Button {
                                isOwnerActionsSheetPresented = true
                            } label: {
                                DesignIconView(icon: .add, size: 16, color: AppTheme.textSecondary)
                            }
                            .accessibilityLabel("Owner tools")
                            .accessibilityHint("Opens channel management and post creation.")
                            .accessibilityIdentifier("feed.ownerActions")
                        }

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
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
        }
        .sheet(isPresented: $isOwnerActionsSheetPresented) {
            ownerActionsSheet
        }
        .fullScreenCover(isPresented: $isChannelThreadSheetPresented) {
            channelThreadSheet
        }
        .fullScreenCover(item: $quickOrderPost) { post in
            QuickOrderMenuSheet(post: post) { option in
                openQuickOrderFlow(for: post, option: option)
            }
        }
        .fullScreenCover(item: $editingPost) { post in
            NavigationStack {
                EditPostView(post: post) { caption, mediaPath, heroSubtitle, priceCents in
                    Task {
                        await coordinator.updatePost(
                            postID: post.id,
                            caption: caption,
                            mediaPath: mediaPath,
                            heroSubtitle: heroSubtitle,
                            priceCents: priceCents
                        )
                        editingPost = nil
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert(
            "Delete Post",
            isPresented: Binding(
                get: { postToDelete != nil },
                set: { if !$0 { postToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { postToDelete = nil }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task { await coordinator.deletePost(postID: post.id) }
                    postToDelete = nil
                }
            }
        } message: {
            Text("This post will be permanently removed from the feed.")
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
        feedStore.channels.first(where: { $0.id == feedStore.selectedChannelID })?.title ?? "Beamly"
    }

    @ViewBuilder
    private var postListSection: some View {
        let isOwner = authStore.user?.role == .owner
        List {
            ForEach(feedStore.posts) { post in
                FeedPostCard(
                    post: post,
                    channelTitle: selectedChannelTitle,
                    showsFollowerHint: !isOwner,
                    selectedReaction: selectedReactionByPostID[post.id],
                    onReactionSelected: { emoji in
                        selectedReactionByPostID[post.id] = emoji
                    },
                    onQuickOrder: {
                        quickOrderPost = post
                    }
                )
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                .onTapGesture {
                    if isOwner {
                        editingPost = post
                    } else {
                        quickOrderPost = post
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if isOwner {
                        Button(role: .destructive) {
                            postToDelete = post
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            editingPost = post
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppTheme.accentBlue)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var channelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Channel")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Button {
                    isChannelThreadSheetPresented = true
                } label: {
                    Label("Threads", systemImage: "text.bubble")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open channel threads")
                .accessibilityHint("Shows all channels and recent thread activity.")
                .accessibilityIdentifier("feed.openThreads")
            }

            if feedStore.channels.isEmpty {
                VStack(spacing: 4) {
                    Text("No channels yet")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                    if authStore.user?.role == .follower {
                        Text("Use an invite link from your supplier to join a channel.")
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .regular))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
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
                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
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
                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("New Post")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Create Invite") {
                    Task {
                        await coordinator.createInvite(expiresInHours: 72, maxUses: nil)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(feedStore.selectedChannelID == nil || authStore.isOffline)
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

            HStack(spacing: 8) {
                ForEach([("lb", $newPriceLb), ("hp", $newPriceHp), ("qp", $newPriceQp)], id: \.0) { label, binding in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(label)
                            .font(AppTheme.inter(11, weight: .bold, relativeTo: .caption2))
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack(spacing: 3) {
                            Text("$")
                                .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .body))
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("0.00", text: binding)
                                .keyboardType(.decimalPad)
                        }
                        .feedInputFieldStyle()
                    }
                }
            }

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

                // Media preview thumbnail
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
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedMediaLabel)
                                .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium, relativeTo: .caption2))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                            Text(newPostType.rawValue.capitalized)
                                .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold, relativeTo: .caption2))
                                .foregroundStyle(AppTheme.accentBlue)
                        }
                        Spacer()
                    }
                }
            }

            Button {
                let media = newPostType == .text ? nil : newMediaPath
                let lbCents = Self.parsePriceCents(newPriceLb)
                let hpCents = Self.parsePriceCents(newPriceHp)
                let qpCents = Self.parsePriceCents(newPriceQp)
                // Pack hp and qp into heroSubtitle as "hp:$X.XX / qp:$X.XX"
                let priceSubtitle = Self.buildPriceSubtitle(hp: hpCents, qp: qpCents)
                // Prefer explicit subtitle; append price breakdown if no subtitle entered
                let userSubtitle = newHeroSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalSubtitle: String?
                if !userSubtitle.isEmpty, let ps = priceSubtitle {
                    finalSubtitle = "\(userSubtitle) · \(ps)"
                } else if !userSubtitle.isEmpty {
                    finalSubtitle = userSubtitle
                } else {
                    finalSubtitle = priceSubtitle
                }
                Task {
                    await coordinator.createPost(
                        type: newPostType,
                        caption: newCaption,
                        mediaPath: media,
                        heroSubtitle: finalSubtitle,
                        priceCents: lbCents
                    )
                    newCaption = ""
                    newMediaPath = ""
                    newPriceLb = ""
                    newPriceHp = ""
                    newPriceQp = ""
                    newHeroSubtitle = ""
                    selectedPhotoItem = nil
                    newPostType = .text
                }
            } label: {
                if feedStore.isPublishing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Uploading...")
                    }
                } else {
                    Text("Publish")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                authStore.isOffline
                || feedStore.isPublishing
                || feedStore.selectedChannelID == nil
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

    @State private var inviteCopied = false

    @ViewBuilder
    private var latestInviteCard: some View {
        if let invite = authStore.latestInvite {
            VStack(alignment: .leading, spacing: 8) {
                Text("Latest invite")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(invite.inviteURL)
                    .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    ShareLink(item: invite.inviteURL) {
                        Label("Share Invite", systemImage: "square.and.arrow.up")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentBlue)
                    .accessibilityLabel("Share invite link")
                    .accessibilityHint("Opens the share sheet with the invite link.")
                    .accessibilityIdentifier("feed.shareInvite")

                    Button {
                        UIPasteboard.general.string = invite.inviteURL
                        inviteCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            inviteCopied = false
                        }
                    } label: {
                        Label(inviteCopied ? "Copied!" : "Copy", systemImage: inviteCopied ? "checkmark" : "doc.on.doc")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy invite link")
                    .accessibilityHint("Copies the invite link to your clipboard.")
                    .accessibilityIdentifier("feed.copyInvite")
                }
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

    private var ownerActionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ownerChannelBuilder
                    ownerComposer
                    latestInviteCard
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, AppTheme.space8)
                .padding(.bottom, AppTheme.space24)
            }
            .background(AppTheme.screenGradient)
            .navigationTitle("Owner Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isOwnerActionsSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                        ForEach(feedStore.channels) { channel in
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
                    .accessibilityLabel("Close threads")
                    .accessibilityHint("Dismisses the channel threads sheet.")
                    .accessibilityIdentifier("feed.closeThreads")
                }
            }
        }
    }

    @ViewBuilder
    private func channelThreadCard(for channel: Channel) -> some View {
        let isSelected = channel.id == feedStore.selectedChannelID

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isSelected ? AppTheme.accentBlue : AppTheme.surfaceElevated)
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.title)
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(channel.description)
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                    Text(isSelected ? "Current thread" : "Tap to open thread")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(isSelected ? AppTheme.accentBlue : AppTheme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(AppTheme.textMuted)
            }

            if isSelected {
                Divider()
                    .overlay(AppTheme.border)

                if feedStore.posts.isEmpty {
                    Text("No posts yet in this thread.")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(feedStore.posts.prefix(3))) { post in
                            HStack(alignment: .top, spacing: 8) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(AppTheme.border)
                                    .frame(width: 2, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled post" : post.caption)
                                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold, relativeTo: .caption))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(post.postType.rawValue.capitalized)
                                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium, relativeTo: .caption2))
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(channel.title)
        .accessibilityHint(isSelected ? "Current thread." : "Opens this channel thread.")
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

    private static func parsePriceCents(_ raw: String) -> Int? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let dollars = Double(cleaned), dollars > 0 else { return nil }
        return Int(round(dollars * 100))
    }

    private static func buildPriceSubtitle(hp: Int?, qp: Int?) -> String? {
        var parts: [String] = []
        if let hp { parts.append("hp: \(formatCents(hp))") }
        if let qp { parts.append("qp: \(formatCents(qp))") }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private static func formatCents(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
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
                        .font(AppTheme.inter(AppTheme.typeBody, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    ForEach(options) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold, relativeTo: .subheadline))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(option.subtitle)
                                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.right")
                                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(AppTheme.accentBlue)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                    .fill(AppTheme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityHint("Starts a \(option.title.lowercased()) request for this post.")
                        .accessibilityIdentifier("feed.quickOrder.\(option.id)")
                    }

                    Text("Select an option to continue to the full order card.")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium, relativeTo: .caption))
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

