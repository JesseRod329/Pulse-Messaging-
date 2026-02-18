import Foundation
import UIKit
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
        let query = "posts?select=id,channel_id,author_id,post_type,caption,media_path,slot_remaining,slot_label,hero_subtitle,hero_aspect_ratio,price_cents,created_at&channel_id=eq.\(escape(channelID))&archived_at=is.null&order=created_at.desc"
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
        mediaPath: String?,
        heroSubtitle: String?,
        priceCents: Int?
    ) async throws -> ChannelPost {
        let accessToken = try requireAccessToken()

        // Upload media to Supabase Storage if this is an image/video post
        var resolvedMediaPath = mediaPath
        if let localPath = mediaPath,
           !localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           postType != .text {
            // Only upload local file:// URLs; leave existing HTTPS URLs as-is
            if let fileURL = URL(string: localPath), fileURL.isFileURL {
                let (uploadData, mimeType) = try compressImageIfNeeded(at: fileURL)

                let fileExtension: String
                if mimeType == "image/jpeg" { fileExtension = "jpg" }
                else if mimeType == "image/png" { fileExtension = "png" }
                else if mimeType.hasPrefix("video/") {
                    fileExtension = fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension
                } else {
                    fileExtension = fileURL.pathExtension.isEmpty ? "bin" : fileURL.pathExtension
                }

                let storagePath = "\(channelID)/\(UUID().uuidString).\(fileExtension)"
                resolvedMediaPath = try await client.storageUpload(
                    bucket: "posts",
                    path: storagePath,
                    data: uploadData,
                    contentType: mimeType,
                    accessToken: accessToken
                )

                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        let body: [String: Any?] = [
            "channel_id": channelID,
            "author_id": authorID,
            "post_type": postType.rawValue,
            "caption": caption,
            "media_path": resolvedMediaPath,
            "hero_subtitle": heroSubtitle,
            "price_cents": priceCents,
        ]

        let payload = sanitizeDictionary(body)
        let data = try await client.restPost(
            pathAndQuery: "posts?select=id,channel_id,author_id,post_type,caption,media_path,slot_remaining,slot_label,hero_subtitle,hero_aspect_ratio,price_cents,created_at",
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

    // MARK: - Update / Delete Posts

    func updatePost(
        postID: String,
        caption: String,
        mediaPath: String?,
        heroSubtitle: String?,
        priceCents: Int?,
        actorID: String
    ) async throws -> ChannelPost {
        let accessToken = try requireAccessToken()

        // Upload new local media if provided
        var resolvedMediaPath = mediaPath
        if let localPath = mediaPath,
           !localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let fileURL = URL(string: localPath), fileURL.isFileURL {
                let (uploadData, mimeType) = try compressImageIfNeeded(at: fileURL)

                let fileExtension: String
                if mimeType == "image/jpeg" { fileExtension = "jpg" }
                else if mimeType == "image/png" { fileExtension = "png" }
                else if mimeType.hasPrefix("video/") {
                    fileExtension = fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension
                } else {
                    fileExtension = fileURL.pathExtension.isEmpty ? "bin" : fileURL.pathExtension
                }

                let storagePath = "updates/\(UUID().uuidString).\(fileExtension)"
                resolvedMediaPath = try await client.storageUpload(
                    bucket: "posts",
                    path: storagePath,
                    data: uploadData,
                    contentType: mimeType,
                    accessToken: accessToken
                )

                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        let body: [String: Any?] = [
            "caption": caption,
            "media_path": resolvedMediaPath,
            "hero_subtitle": heroSubtitle,
            "price_cents": priceCents,
        ]

        let selectFields = "id,channel_id,author_id,post_type,caption,media_path,slot_remaining,slot_label,hero_subtitle,hero_aspect_ratio,price_cents,created_at"
        let data = try await client.restPatch(
            pathAndQuery: "posts?id=eq.\(escape(postID))&select=\(selectFields)",
            body: sanitizeDictionary(body),
            accessToken: accessToken,
            prefer: "return=representation"
        )

        let rows = try decode([PostRow].self, from: data)
        guard let first = rows.first, let post = mapPost(first) else {
            throw SupabaseClientError.invalidResponse
        }
        return post
    }

    func deletePost(postID: String, actorID: String) async throws {
        let accessToken = try requireAccessToken()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())

        _ = try await client.restPatch(
            pathAndQuery: "posts?id=eq.\(escape(postID))",
            body: ["archived_at": now],
            accessToken: accessToken
        )
    }

    // MARK: - Storage Helpers

    private func compressImageIfNeeded(at fileURL: URL, maxBytes: Int = 1_000_000) throws -> (Data, String) {
        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.lowercased()

        // Video files: return as-is
        let videoExtensions = ["mp4", "mov", "m4v", "avi"]
        if videoExtensions.contains(ext) {
            let mimeType = ext == "mov" ? "video/quicktime" : "video/mp4"
            return (data, mimeType)
        }

        // Try to decode as UIImage for compression
        guard let uiImage = UIImage(data: data) else {
            return (data, "application/octet-stream")
        }

        // Small enough already — return original
        if data.count <= maxBytes {
            let mimeType = ext == "png" ? "image/png" : "image/jpeg"
            return (data, mimeType)
        }

        // Compress as JPEG with decreasing quality
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let compressed = uiImage.jpegData(compressionQuality: quality),
               compressed.count <= maxBytes {
                return (compressed, "image/jpeg")
            }
        }

        // Last resort: lowest quality
        let fallback = uiImage.jpegData(compressionQuality: 0.3) ?? data
        return (fallback, "image/jpeg")
    }
}
