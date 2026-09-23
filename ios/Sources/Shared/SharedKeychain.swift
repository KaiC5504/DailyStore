import Foundation
import Security
import ValorantCore

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain error \(status)" }
}

/// The app and the widget have no shared container (App Groups need portal setup this project
/// avoids), so everything both sides read lives in one shared keychain access group instead.
struct SharedKeychain: Sendable {
    static let shared = SharedKeychain()

    private static let service = "com.kaichuan.dailystore"

    /// "$(AppIdentifierPrefix)com.kaichuan.dailystore.shared", expanded into Info.plist at build time.
    private let accessGroup: String? = {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String,
              !group.hasPrefix("."), !group.isEmpty else { return nil }
        return group
    }()

    private func query(_ account: String, group: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        if let group { query[kSecAttrAccessGroup as String] = group }
        return query
    }

    func data(_ account: String) throws -> Data? {
        var query = query(account, group: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return data
    }

    func set(_ data: Data, for account: String) throws {
        var status = write(data, account: account, group: accessGroup)
        // Simulator builds without a team cannot claim the group.
        if status == errSecMissingEntitlement { status = write(data, account: account, group: nil) }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private func write(_ data: Data, account: String, group: String?) -> OSStatus {
        // AfterFirstUnlock so the widget and background refresh can read it while the phone is locked.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let base = query(account, group: group)
        var status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(base.merging(attributes) { $1 } as CFDictionary, nil)
        }
        return status
    }

    func remove(_ account: String) throws {
        let status = SecItemDelete(query(account, group: nil) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    func value<T: Decodable>(_ type: T.Type, _ account: String) -> T? {
        guard let data = try? data(account) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setValue<T: Encodable>(_ value: T, _ account: String) throws {
        try set(try JSONEncoder().encode(value), for: account)
    }

    /// Build 3 stored the session in the app's private group under the old service name.
    /// Move it once so the widget can see it.
    func migrateLegacySession() {
        let legacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kaichuan.dailystore.riot-session",
            kSecAttrAccount as String: "default",
        ]
        var query = legacy
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return }
        if (try? self.data(Account.session)) == nil {
            try? set(data, for: Account.session)
        }
        _ = SecItemDelete(legacy as CFDictionary)
    }
}

enum Account {
    static let session = "riot-session"
    static let snapshot = "store-snapshot"
    static let wishlist = "wishlist"
    static let compactCatalog = "compact-catalog"
    static let alerts = "alert-state"
    static let history = "store-history"
}

/// The Riot session is as good as a password with 2FA already passed, so it only ever lives here.
struct KeychainSessionStore: SessionStore {
    func load() throws -> RiotSession? {
        guard let data = try SharedKeychain.shared.data(Account.session) else { return nil }
        return try JSONDecoder().decode(RiotSession.self, from: data)
    }

    func save(_ session: RiotSession) throws {
        try SharedKeychain.shared.setValue(session, Account.session)
    }

    func clear() throws {
        try SharedKeychain.shared.remove(Account.session)
    }
}

/// Everything besides the session that the app, the widget and background refresh share.
enum SharedState {
    private static var keychain: SharedKeychain { .shared }

    static var snapshot: StoreSnapshot? { keychain.value(StoreSnapshot.self, Account.snapshot) }

    /// Keeps whichever copy is newer, since the widget and the app both fetch.
    static func save(_ snapshot: StoreSnapshot) {
        if let current = self.snapshot, current.fetchedAt > snapshot.fetchedAt { return }
        try? keychain.setValue(snapshot, Account.snapshot)
    }

    static func clearSnapshot() { try? keychain.remove(Account.snapshot) }

    /// Written by whoever fetches, so a day the app isn't opened still gets recorded by the widget.
    /// Survives sign-out on purpose: it holds no account data beyond what the store offered.
    static var history: StoreHistory { keychain.value(StoreHistory.self, Account.history) ?? StoreHistory() }

    static func recordHistory(_ snapshot: StoreSnapshot) {
        var history = self.history
        guard history.record(snapshot) else { return }
        try? keychain.setValue(history, Account.history)
    }

    static var wishlist: Set<String> {
        get { keychain.value(Set<String>.self, Account.wishlist) ?? [] }
        set { try? keychain.setValue(newValue, Account.wishlist) }
    }

    static var compactCatalog: CompactCatalog? { keychain.value(CompactCatalog.self, Account.compactCatalog) }

    static func save(_ compact: CompactCatalog) {
        guard compactCatalog?.clientVersion != compact.clientVersion else { return }
        try? keychain.setValue(compact, Account.compactCatalog)
    }

    struct Alerts: Codable {
        /// The reset the last wishlist alert was sent for, so the widget and the app don't both send one.
        var wishlistAlertedFor: Date?
        /// Lives here rather than in UserDefaults because the widget sends the alert too.
        var wishlistEnabled = true
    }

    static var alerts: Alerts {
        get { keychain.value(Alerts.self, Account.alerts) ?? Alerts() }
        set { try? keychain.setValue(newValue, Account.alerts) }
    }
}
