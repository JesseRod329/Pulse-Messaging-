import Foundation

struct SessionTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let userID: String
    let userPhone: String?
}

protocol SessionTokenStore {
    func readTokens() -> SessionTokens?
    func saveTokens(_ tokens: SessionTokens)
    func clearTokens()
    func migrateFromLegacyStoreIfNeeded()
}

final class MigratingSessionTokenStore: SessionTokenStore {
    private let primary: SessionTokenStore
    private let legacy: SessionTokenStore
    private let migrationLock = NSLock()
    private var didMigrate = false

    init(
        primary: SessionTokenStore = KeychainSessionStore(),
        legacy: SessionTokenStore = SupabaseSessionStore()
    ) {
        self.primary = primary
        self.legacy = legacy
    }

    func readTokens() -> SessionTokens? {
        migrateFromLegacyStoreIfNeeded()
        return primary.readTokens()
    }

    func saveTokens(_ tokens: SessionTokens) {
        primary.saveTokens(tokens)
        legacy.clearTokens()
    }

    func clearTokens() {
        primary.clearTokens()
        legacy.clearTokens()
    }

    func migrateFromLegacyStoreIfNeeded() {
        migrationLock.lock()
        if didMigrate {
            migrationLock.unlock()
            return
        }
        didMigrate = true
        migrationLock.unlock()

        if primary.readTokens() == nil, let legacyTokens = legacy.readTokens() {
            primary.saveTokens(legacyTokens)
        }

        legacy.clearTokens()
    }
}
