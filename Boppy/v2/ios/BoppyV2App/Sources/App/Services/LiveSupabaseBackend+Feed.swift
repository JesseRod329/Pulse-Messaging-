import Foundation
import BoppyV2Core

extension LiveSupabaseBackend {
    // MARK: - Channels

    func createChannel(ownerID: String, title: String, description: String) async throws -> Channel {
        let accessToken = try requireAccessToken()
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw SupabaseClientError.server(status: 400, message: "Channel title is required.")
        }

        let body: [String: Any] = [
            "owner_id": ownerID,
            "title": normalizedTitle,
            "description": description,
            "is_active": true,
        ]

        let data = try await client.restPost(
            pathAndQuery: "channels?select=id,title,description,is_active",
            body: body,
            accessToken: accessToken,
            prefer: "return=representation"
        )

        let rows = try decode([ChannelRow].self, from: data)
        guard let channel = rows.first else {
            throw SupabaseClientError.invalidResponse
        }

        _ = try await client.restPost(
            pathAndQuery: "channel_memberships?select=channel_id,user_id",
            body: [
                "channel_id": channel.id,
                "user_id": ownerID,
                "role": "owner",
            ],
            accessToken: accessToken,
            prefer: "return=representation"
        )

        return Channel(id: channel.id, title: channel.title, description: channel.description, isActive: channel.isActive)
    }

    func fetchChannels(userID: String) async throws -> [Channel] {
        let accessToken = try requireAccessToken()
        let memberships = try await fetchMemberships(userID: userID, accessToken: accessToken)
        let ids = memberships.map(\.channelID)
        guard !ids.isEmpty else { return [] }

        let query = "channels?select=id,title,description,is_active&id=in.\(inFilter(ids))&is_active=eq.true&order=created_at.desc"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([ChannelRow].self, from: data)

        return rows.map { row in
            Channel(id: row.id, title: row.title, description: row.description, isActive: row.isActive)
        }
    }

    func fetchPosts(channelID: String) async throws -> [ChannelPost] {
        let accessToken = try requireAccessToken()
        let query = "posts?select=id,channel_id,author_id,post_type,caption,media_path,slot_remaining,slot_label,hero_subtitle,hero_aspect_ratio,created_at&channel_id=eq.\(escape(channelID))&archived_at=is.null&order=created_at.desc"
        let data = try await client.restGet(pathAndQuery: query, accessToken: accessToken)
        let rows = try decode([PostRow].self, from: data)

        return rows.compactMap(mapPost)
    }

    func fetchDrivers(channelID: String) async throws -> [DriverProfile] {
        let accessToken = try requireAccessToken()
        let membershipQuery = "channel_memberships?select=user_id&channel_id=eq.\(escape(channelID))&role=eq.driver"
        let membershipData = try await client.restGet(pathAndQuery: membershipQuery, accessToken: accessToken)
        let membershipRows = try decode([[String: String]].self, from: membershipData)
        let userIDs = membershipRows.compactMap { $0["user_id"] }

        guard !userIDs.isEmpty else { return [] }

        let profilesQuery = "profiles?select=id,display_name,avatar_url,driver_availability,driver_rating,driver_trip_count,last_lat,last_lng&id=in.\(inFilter(userIDs))"
        let profilesData = try await client.restGet(pathAndQuery: profilesQuery, accessToken: accessToken)
        let profileRows = try decode([DriverProfileRow].self, from: profilesData)

        return profileRows
            .map {
                DriverProfile(
                    id: $0.id,
                    displayName: $0.displayName ?? "Driver",
                    avatarURL: $0.avatarURL,
                    availability: $0.availability,
                    rating: $0.rating,
                    tripCount: $0.tripCount,
                    lastLat: $0.lastLat,
                    lastLng: $0.lastLng
                )
            }
            .sorted(by: { $0.displayName < $1.displayName })
    }

    func createPost(
        channelID: String,
        authorID: String,
        postType: PostType,
        caption: String,
        mediaPath: String?
    ) async throws -> ChannelPost {
        let accessToken = try requireAccessToken()
        let body: [String: Any?] = [
            "channel_id": channelID,
            "author_id": authorID,
            "post_type": postType.rawValue,
            "caption": caption,
            "media_path": mediaPath,
        ]

        let payload = sanitizeDictionary(body)
        let data = try await client.restPost(
            pathAndQuery: "posts?select=id,channel_id,author_id,post_type,caption,media_path,slot_remaining,slot_label,hero_subtitle,hero_aspect_ratio,created_at",
            body: payload,
            accessToken: accessToken,
            prefer: "return=representation"
        )

        let rows = try decode([PostRow].self, from: data)
        guard let first = rows.first, let post = mapPost(first) else {
            throw SupabaseClientError.invalidResponse
        }

        return post
    }

    func createInvite(
        channelID: String,
        ownerID: String,
        expiresInHours: Int,
        maxUses: Int?
    ) async throws -> ChannelInvite {
        let accessToken = try requireAccessToken()
        _ = ownerID

        let data: CreateInviteResponse = try await client.edgeCall(
            functionName: "create-invite",
            accessToken: accessToken,
            body: [
                "channel_id": channelID,
                "expires_in_hours": expiresInHours,
                "max_uses": maxUses as Any
            ]
        )

        return ChannelInvite(
            id: data.id,
            channelID: data.channel_id,
            token: data.token,
            inviteURL: data.invite_url,
            expiresAt: data.expires_at,
            maxUses: data.max_uses
        )
    }

    func joinChannel(token: String, userID: String) async throws -> Channel {
        let accessToken = try requireAccessToken()
        _ = userID

        let data: JoinChannelResponse = try await client.edgeCall(
            functionName: "join-channel",
            accessToken: accessToken,
            body: ["token": token]
        )

        return try await fetchChannelByID(data.channel_id, accessToken: accessToken)
    }


}
