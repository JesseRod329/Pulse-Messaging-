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

    func createPost(type: PostType, caption: String, mediaPath: String?) async {
        guard let user = authStore.user, let channelID = feedStore.selectedChannelID else { return }
        guard ensureOnline() else { return }

        do {
            try await feedStore.createPost(
                channelID: channelID,
                authorID: user.id,
                type: type,
                caption: caption,
                mediaPath: mediaPath,
                channelFeedService: environment.channelFeedService
            )
            await refreshAll()
        } catch {
            handleError(error)
        }
    }


}
