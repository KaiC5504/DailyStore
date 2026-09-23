import Foundation

public struct RiotSession: Codable, Equatable, Sendable {
    public var cookies: RiotCookies
    /// The jar from before the last rotation, tried once if the current one is rejected.
    public var fallback: RiotCookies?
    public var puuid: String?
    public var shard: String?

    public init(cookies: RiotCookies, fallback: RiotCookies? = nil, puuid: String? = nil, shard: String? = nil) {
        self.cookies = cookies
        self.fallback = fallback
        self.puuid = puuid
        self.shard = shard
    }
}

public protocol SessionStore: Sendable {
    func load() throws -> RiotSession?
    func save(_ session: RiotSession) throws
    func clear() throws
}

public struct StoreSnapshot: Codable, Sendable {
    public let storefront: Storefront
    public let wallet: Wallet
    public let clientVersion: String
    public let fetchedAt: Date
    /// Owned skin level IDs, lowercased. Nil when that call failed or the snapshot predates it.
    public var owned: Set<String>?

    public init(storefront: Storefront, wallet: Wallet, clientVersion: String, fetchedAt: Date, owned: Set<String>? = nil) {
        self.storefront = storefront
        self.wallet = wallet
        self.clientVersion = clientVersion
        self.fetchedAt = fetchedAt
        self.owned = owned
    }
}

public actor StoreService {
    let api: RiotAPI
    private let sessions: SessionStore
    let log: @Sendable (String) -> Void
    private var cached: (context: RiotAPI.Context, expires: Date)?

    /// `retryBase` is the back-off in seconds when Riot rate-limits a match call; tests pass 0.
    public init(http: HTTPClient, sessions: SessionStore, retryBase: Double = 10,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.api = RiotAPI(http: http, retryBase: retryBase)
        self.sessions = sessions
        self.log = log
    }

    public var isSignedIn: Bool { (try? sessions.load())?.cookies.hasSession ?? false }

    public var puuid: String? { (try? sessions.load())?.puuid?.lowercased() }

    /// Starts a fresh session from cookies harvested by the login webview.
    public func signIn(cookies: RiotCookies) async throws -> StoreSnapshot {
        guard cookies.hasSession else {
            log("Sign-in: no ssid cookie came back from the login page")
            throw RiotError.notSignedIn
        }
        try sessions.save(RiotSession(cookies: cookies))
        cached = nil
        log("Sign-in: saved \(cookies.values.keys.sorted().joined(separator: ", "))")
        return try await fetch()
    }

    public func signOut() throws {
        try sessions.clear()
        cached = nil
        log("Signed out")
    }

    public func fetch() async throws -> StoreSnapshot {
        // The store always reauths: that is what keeps the cookies sliding forward.
        let ctx = try await context(fresh: true)
        async let storefront = api.storefront(ctx)
        async let wallet = api.wallet(ctx)
        async let owned = ownedSkins(ctx)
        let snapshot = StoreSnapshot(
            storefront: try await storefront,
            wallet: try await wallet,
            clientVersion: ctx.clientVersion,
            fetchedAt: Date(),
            owned: await owned
        )
        log("Store OK: \(snapshot.storefront.daily.count) daily offers, night market \(snapshot.storefront.nightMarket == nil ? "off" : "on"), \(snapshot.owned.map { "\($0.count) owned skins" } ?? "owned skins unavailable")")
        return snapshot
    }

    /// Tokens for game calls. Access tokens last an hour, so match paging reuses them for 45 minutes.
    public func context(fresh: Bool = false) async throws -> RiotAPI.Context {
        if !fresh, let cached, cached.expires > Date() { return cached.context }
        guard var session = try sessions.load(), session.cookies.hasSession else { throw RiotError.notSignedIn }

        let tokens = try await reauth(&session)
        async let version = api.clientVersion()
        async let entitlements = api.entitlements(accessToken: tokens.accessToken)
        if session.puuid == nil { session.puuid = try await api.puuid(accessToken: tokens.accessToken) }
        if session.shard == nil { session.shard = try await api.shard(tokens: tokens) }
        try sessions.save(session)

        let ctx = RiotAPI.Context(
            accessToken: tokens.accessToken,
            entitlements: try await entitlements,
            clientVersion: try await version,
            puuid: session.puuid!,
            shard: session.shard!
        )
        log("Tokens OK, shard \(ctx.shard), client \(ctx.clientVersion)")
        cached = (ctx, Date().addingTimeInterval(45 * 60))
        return ctx
    }

    /// Only the wishlist uses this, so a failure here shouldn't cost the whole store.
    private func ownedSkins(_ ctx: RiotAPI.Context) async -> Set<String>? {
        do {
            return try await api.ownedSkinLevels(ctx)
        } catch {
            log("Owned skins: \(error.localizedDescription)")
            return nil
        }
    }

    private func reauth(_ session: inout RiotSession) async throws -> AuthTokens {
        do {
            let (tokens, rotated) = try await api.reauth(session.cookies)
            session.fallback = session.cookies
            session.cookies = rotated
            try sessions.save(session)
            log("Reauth OK")
            return tokens
        } catch RiotError.sessionExpired {
            guard let fallback = session.fallback else {
                log("Reauth: session expired")
                throw RiotError.sessionExpired
            }
            log("Reauth: current cookies rejected, trying previous set")
            do {
                let (tokens, rotated) = try await api.reauth(fallback)
                session.cookies = rotated
                session.fallback = nil
                try sessions.save(session)
                log("Reauth OK with previous cookies")
                return tokens
            } catch RiotError.sessionExpired {
                log("Reauth: session expired")
                throw RiotError.sessionExpired
            }
        }
    }
}
