import Foundation

struct SupabaseSessionStore {
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

    func save(accessToken: String, refreshToken: String?, userID: String, userPhone: String?) {
        defaults.set(accessToken, forKey: Keys.accessToken)
        defaults.set(refreshToken, forKey: Keys.refreshToken)
        defaults.set(userID, forKey: Keys.userID)
        defaults.set(userPhone, forKey: Keys.userPhone)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.userID)
        defaults.removeObject(forKey: Keys.userPhone)
    }
}
