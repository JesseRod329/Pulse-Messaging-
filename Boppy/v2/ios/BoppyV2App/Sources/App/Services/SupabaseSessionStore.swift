import Foundation

struct SupabaseSessionStore: SessionTokenStore {
    private enum Keys {
        static let accessToken = "v2.auth.accessToken"
        static let refreshToken = "v2.auth.refreshToken"
        static let userID = "v2.auth.userID"
        static let userPhone = "v2.auth.userPhone"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var accessToken: String? {
        defaults.string(forKey: Keys.accessToken)
    }

    var refreshToken: String? {
        defaults.string(forKey: Keys.refreshToken)
    }

    var userID: String? {
        defaults.string(forKey: Keys.userID)
    }

    var userPhone: String? {
        defaults.string(forKey: Keys.userPhone)
    }

    func readTokens() -> SessionTokens? {
        guard let accessToken, let userID else {
            return nil
        }

        return SessionTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            userPhone: userPhone
        )
    }

    func saveTokens(_ tokens: SessionTokens) {
        defaults.set(tokens.accessToken, forKey: Keys.accessToken)
        defaults.set(tokens.refreshToken, forKey: Keys.refreshToken)
        defaults.set(tokens.userID, forKey: Keys.userID)
        defaults.set(tokens.userPhone, forKey: Keys.userPhone)
    }

    func clearTokens() {
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.userID)
        defaults.removeObject(forKey: Keys.userPhone)
    }

    func migrateFromLegacyStoreIfNeeded() {}

    func save(accessToken: String, refreshToken: String?, userID: String, userPhone: String?) {
        saveTokens(
            SessionTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userID: userID,
                userPhone: userPhone
            )
        )
    }

    func clear() {
        clearTokens()
    }
}
