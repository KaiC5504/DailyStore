import Foundation
import Security
import ValorantCore

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain error \(status)" }
}

/// The Riot session is as good as a password with 2FA already passed, so it only ever lives here.
struct KeychainSessionStore: SessionStore {
    private var base: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.kaichuan.dailystore.riot-session",
        kSecAttrAccount as String: "default",
    ] }

    func load() throws -> RiotSession? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(RiotSession.self, from: data)
    }

    func save(_ session: RiotSession) throws {
        let data = try JSONEncoder().encode(session)
        // AfterFirstUnlock so the widget and background refresh can read it while the phone is locked.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(base.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clear() throws {
        let status = SecItemDelete(base as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}
