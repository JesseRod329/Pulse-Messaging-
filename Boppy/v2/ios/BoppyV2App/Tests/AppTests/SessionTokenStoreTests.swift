import XCTest
@testable import Boppy_V2

final class SessionTokenStoreTests: XCTestCase {
    func testMigrationMovesLegacyTokensToPrimaryAndClearsLegacy() {
        let legacyTokens = SessionTokens(
            accessToken: "legacy-access",
            refreshToken: "legacy-refresh",
            userID: "legacy-user",
            userPhone: "+15550000001"
        )
        let primary = InMemoryTokenStore(tokens: nil)
        let legacy = InMemoryTokenStore(tokens: legacyTokens)
        let store = MigratingSessionTokenStore(primary: primary, legacy: legacy)

        store.migrateFromLegacyStoreIfNeeded()

        XCTAssertEqual(primary.readTokens(), legacyTokens)
        XCTAssertNil(legacy.readTokens())
        XCTAssertEqual(primary.saveCount, 1)
        XCTAssertEqual(legacy.clearCount, 1)
    }

    func testMigrationRunsOnlyOnce() {
        let primary = InMemoryTokenStore(tokens: nil)
        let legacy = InMemoryTokenStore(
            tokens: SessionTokens(
                accessToken: "legacy-access",
                refreshToken: "legacy-refresh",
                userID: "legacy-user",
                userPhone: nil
            )
        )
        let store = MigratingSessionTokenStore(primary: primary, legacy: legacy)

        _ = store.readTokens()
        _ = store.readTokens()

        XCTAssertEqual(primary.saveCount, 1)
        XCTAssertEqual(legacy.clearCount, 1)
    }

    func testClearTokensClearsPrimaryAndLegacy() {
        let primary = InMemoryTokenStore(
            tokens: SessionTokens(
                accessToken: "primary-access",
                refreshToken: "primary-refresh",
                userID: "primary-user",
                userPhone: nil
            )
        )
        let legacy = InMemoryTokenStore(
            tokens: SessionTokens(
                accessToken: "legacy-access",
                refreshToken: "legacy-refresh",
                userID: "legacy-user",
                userPhone: nil
            )
        )
        let store = MigratingSessionTokenStore(primary: primary, legacy: legacy)

        store.clearTokens()

        XCTAssertNil(primary.readTokens())
        XCTAssertNil(legacy.readTokens())
        XCTAssertEqual(primary.clearCount, 1)
        XCTAssertEqual(legacy.clearCount, 1)
    }
}

private final class InMemoryTokenStore: SessionTokenStore {
    private var tokens: SessionTokens?
    private(set) var saveCount = 0
    private(set) var clearCount = 0

    init(tokens: SessionTokens?) {
        self.tokens = tokens
    }

    func readTokens() -> SessionTokens? {
        tokens
    }

    func saveTokens(_ tokens: SessionTokens) {
        self.tokens = tokens
        saveCount += 1
    }

    func clearTokens() {
        tokens = nil
        clearCount += 1
    }

    func migrateFromLegacyStoreIfNeeded() {}
}
