import Foundation
import BoppyV2Core

@MainActor
final class AdminStore: ObservableObject {
    @Published var adminAuditEvents: [AdminAuditEvent] = []

    func refreshAuditEvents(
        channelID: String,
        actorID: String,
        adminService: AdminServiceProtocol
    ) async throws {
        adminAuditEvents = try await adminService.fetchAdminAuditEvents(
            channelID: channelID,
            action: nil,
            limit: 25,
            actorID: actorID
        )
    }

    func archiveChannel(
        channelID: String,
        actorID: String,
        adminService: AdminServiceProtocol
    ) async throws {
        try await adminService.archiveChannel(
            channelID: channelID,
            reason: "Archived from iOS owner admin controls",
            actorID: actorID
        )
    }

    func clear() {
        adminAuditEvents = []
    }
}
