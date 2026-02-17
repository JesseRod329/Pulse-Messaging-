import Foundation
import Security

protocol KeychainAccessing {
    func readData(service: String, account: String) -> Data?
    func saveData(_ data: Data, service: String, account: String)
    func deleteData(service: String, account: String)
}

struct SystemKeychainAccess: KeychainAccessing {
    func readData(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    func saveData(_ data: Data, service: String, account: String) {
        deleteData(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func deleteData(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

final class KeychainSessionStore: SessionTokenStore {
    private enum Constants {
        static let service = "com.boppy.v2.auth"
        static let account = "session.tokens"
    }

    private let keychain: KeychainAccessing

    init(keychain: KeychainAccessing = SystemKeychainAccess()) {
        self.keychain = keychain
    }

    func readTokens() -> SessionTokens? {
        guard let data = keychain.readData(service: Constants.service, account: Constants.account) else {
            return nil
        }

        return try? JSONDecoder().decode(SessionTokens.self, from: data)
    }

    func saveTokens(_ tokens: SessionTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else {
            return
        }
        keychain.saveData(data, service: Constants.service, account: Constants.account)
    }

    func clearTokens() {
        keychain.deleteData(service: Constants.service, account: Constants.account)
    }

    func migrateFromLegacyStoreIfNeeded() {}
}
