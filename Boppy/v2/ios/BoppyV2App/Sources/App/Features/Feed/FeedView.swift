import SwiftUI
import BoppyV2Core

struct FeedView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var newChannelTitle = ""
    @State private var newChannelDescription = ""

    @State private var newPostType: PostType = .text
    @State private var newCaption = ""
    @State private var newMediaPath = ""

    var body: some View {
        NavigationStack {
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

                    if coordinator.posts.isEmpty {
                        ContentUnavailableView(
                            "No Posts",
                            systemImage: "text.bubble",
                            description: Text("Owner posts will appear here.")
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(coordinator.posts) { post in
                                FeedPostCard(post: post, showsFollowerHint: coordinator.user?.role == .follower)
                                    .onLongPressGesture {
                                        coordinator.openOrderSheet(for: post)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .navigationTitle("Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await coordinator.refreshAll()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                Task { await coordinator.refreshAll() }
            }
            .safeAreaInset(edge: .bottom) {
                if let invite = coordinator.latestInvite {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest invite")
                            .font(.caption.bold())
                        Text(invite.inviteURL)
                            .font(.caption2)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                }
            }
        }
    }

    private var selectedChannelTitle: String {
        coordinator.selectedChannel?.title ?? "BeamBox V2"
    }

    private var channelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Channel")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.channels.isEmpty {
                Text("No channels yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            }
        }
    }

    private var inviteJoinCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Join by Invite")
                .font(.headline)

            TextField("Paste invite token", text: $coordinator.inviteTokenInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Button("Join Channel") {
                Task { await coordinator.joinChannel() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var ownerChannelBuilder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Channel")
                .font(.headline)

            TextField("Channel title", text: $newChannelTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $newChannelDescription)
                .textFieldStyle(.roundedBorder)

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
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var ownerComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Owner Composer")
                    .font(.headline)
                Spacer()
                Button("Create Invite") {
                    Task {
                        await coordinator.createInvite(expiresInHours: 72, maxUses: nil)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.selectedChannelID == nil)
            }

            Picker("Post Type", selection: $newPostType) {
                ForEach(PostType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("Caption", text: $newCaption)
                .textFieldStyle(.roundedBorder)

            if newPostType != .text {
                TextField("Media URL or path", text: $newMediaPath)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            Button("Publish") {
                let media = newPostType == .text ? nil : newMediaPath
                Task {
                    await coordinator.createPost(type: newPostType, caption: newCaption, mediaPath: media)
                    newCaption = ""
                    newMediaPath = ""
                    newPostType = .text
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.selectedChannelID == nil || newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
