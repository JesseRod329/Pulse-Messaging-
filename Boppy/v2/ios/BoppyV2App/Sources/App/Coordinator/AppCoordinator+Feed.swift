import Foundation
import BoppyV2Core

extension AppCoordinator {
    func selectChannel(_ channelID: String) async {
        feedStore.selectChannel(channelID)
        await refreshAll()
    }

    func createChannel(title: String, description: String) async {
        guard let user = authStore.user, user.role == .owner else { return }
        guard ensureOnline() else { return }

        do {
            _ = try await feedStore.createChannel(
                ownerID: user.id,
                title: title,
                description: description,
                channelFeedService: environment.channelFeedService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func joinChannel(using token: String? = nil) async {
        guard let user = authStore.user else { return }
        guard ensureOnline() else { return }

        let inviteToken = token ?? authStore.inviteTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inviteToken.isEmpty else { return }

        do {
            try await feedStore.joinChannel(
                token: inviteToken,
                userID: user.id,
                channelFeedService: environment.channelFeedService
            )
            authStore.inviteTokenInput = ""
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func createInvite(expiresInHours: Int = 72, maxUses: Int? = nil) async {
        guard let user = authStore.user, user.role == .owner, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            authStore.latestInvite = try await feedStore.createInvite(
                channelID: channelID,
                ownerID: user.id,
                expiresInHours: expiresInHours,
                maxUses: maxUses,
                channelFeedService: environment.channelFeedService
            )
        } catch {
            handleError(error)
        }
    }

    func createPost(type: PostType, caption: String, mediaPath: String?, heroSubtitle: String? = nil, priceCents: Int? = nil) async {
        guard let user = authStore.user, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        feedStore.isPublishing = true
        defer { feedStore.isPublishing = false }

        do {
            try await feedStore.createPost(
                channelID: channelID,
                authorID: user.id,
                type: type,
                caption: caption,
                mediaPath: mediaPath,
                heroSubtitle: heroSubtitle,
                priceCents: priceCents,
                channelFeedService: environment.channelFeedService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func updatePost(postID: String, caption: String, mediaPath: String?, heroSubtitle: String?, priceCents: Int?) async {
        guard let user = authStore.user, user.role == .owner else { return }
        guard ensureOnline() else { return }

        do {
            try await feedStore.updatePost(
                postID: postID,
                caption: caption,
                mediaPath: mediaPath,
                heroSubtitle: heroSubtitle,
                priceCents: priceCents,
                actorID: user.id,
                channelFeedService: environment.channelFeedService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }

    func deletePost(postID: String) async {
        guard let user = authStore.user, user.role == .owner else { return }
        guard ensureOnline() else { return }

        do {
            try await feedStore.deletePost(
                postID: postID,
                actorID: user.id,
                channelFeedService: environment.channelFeedService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }
}
