import Foundation
import BoppyV2Core

@MainActor
final class FeedStore: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var selectedChannelID: String?
    @Published var posts: [ChannelPost] = []
    @Published var drivers: [DriverProfile] = []

    func refresh(
        userID: String,
        channelFeedService: ChannelFeedServiceProtocol
    ) async throws {
        let fetchedChannels = try await channelFeedService.fetchChannels(userID: userID)
        channels = fetchedChannels

        if selectedChannelID == nil || !channels.contains(where: { $0.id == selectedChannelID }) {
            selectedChannelID = channels.first?.id
        }

        if let selectedChannelID {
            async let fetchedPosts = channelFeedService.fetchPosts(channelID: selectedChannelID)
            async let fetchedDrivers = channelFeedService.fetchDrivers(channelID: selectedChannelID)
            posts = try await fetchedPosts
            drivers = try await fetchedDrivers
        } else {
            posts = []
            drivers = []
        }
    }

    func selectChannel(_ channelID: String) {
        selectedChannelID = channelID
    }

    @discardableResult
    func createChannel(
        ownerID: String,
        title: String,
        description: String,
        channelFeedService: ChannelFeedServiceProtocol
    ) async throws -> Channel {
        let channel = try await channelFeedService.createChannel(
            ownerID: ownerID,
            title: title,
            description: description
        )
        selectedChannelID = channel.id
        return channel
    }

    func joinChannel(
        token: String,
        userID: String,
        channelFeedService: ChannelFeedServiceProtocol
    ) async throws {
        _ = try await channelFeedService.joinChannel(token: token, userID: userID)
    }

    @discardableResult
    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?,
        channelFeedService: ChannelFeedServiceProtocol
    ) async throws -> ChannelInvite {
        try await channelFeedService.createInvite(
            channelID: channelID,
            ownerID: ownerID,
            expiresInHours: expiresInHours,
            maxUses: maxUses
        )
    }

    func createPost(
        channelID: String,
        authorID: String,
        type: PostType,
        caption: String,
        mediaPath: String?,
        channelFeedService: ChannelFeedServiceProtocol
    ) async throws {
        _ = try await channelFeedService.createPost(
            channelID: channelID,
            authorID: authorID,
            postType: type,
            caption: caption,
            mediaPath: mediaPath
        )
    }

    func clear() {
        channels = []
        selectedChannelID = nil
        posts = []
        drivers = []
    }
}
