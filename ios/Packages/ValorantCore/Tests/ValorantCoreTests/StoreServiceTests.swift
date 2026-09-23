import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ValorantCore

@Suite struct StoreServiceTests {
    private func riot(reauth: @escaping (URLRequest) -> HTTPResponse) -> MockHTTP {
        let http = MockHTTP()
        http.on("auth.riotgames.com/authorize", reauth)
        http.on("valorant-api.com/v1/version", json: #"{"data": {"riotClientVersion": "release-13.05-shipping-11-5350494"}}"#)
        http.on("entitlements.auth.riotgames.com", json: #"{"entitlements_token": "ENT"}"#)
        http.on("auth.riotgames.com/userinfo", json: #"{"sub": "\#(Fixtures.puuid)"}"#)
        http.on("riot-geo.pas.si.riotgames.com", json: #"{"token": "t", "affinities": {"pbe": "na", "live": "ap"}}"#)
        http.on("/store/v3/storefront/", json: Fixtures.storefront)
        http.on("/store/v1/wallet/", json: Fixtures.wallet)
        return http
    }

    private static let success: (URLRequest) -> HTTPResponse = { _ in
        HTTPResponse(status: 303, headers: ["Location": Fixtures.successLocation, "Set-Cookie": Fixtures.rotatedSetCookie])
    }

    private static let expired: (URLRequest) -> HTTPResponse = { _ in
        HTTPResponse(status: 303, headers: ["Location": Fixtures.expiredLocation])
    }

    @Test func fetchRotatesCookiesAndLoadsTheStore() async throws {
        let http = riot(reauth: Self.success)
        let original = RiotCookies(["ssid": "OLD", "tdid": "DEVICE"])
        let sessions = MemorySessions(RiotSession(cookies: original))

        let snapshot = try await StoreService(http: http, sessions: sessions).fetch()

        #expect(snapshot.storefront.daily.count == 4)
        #expect(snapshot.wallet.vp == 4909)
        #expect(snapshot.clientVersion == "release-13.05-shipping-11-5350494")
        #expect(sessions.session?.cookies.values == ["ssid": "NEW_SSID", "clid": "NEW_CLID", "tdid": "DEVICE"])
        #expect(sessions.session?.fallback == original)
        #expect(sessions.session?.puuid == Fixtures.puuid)
        #expect(sessions.session?.shard == "ap")
        #expect(http.requests(to: "authorize").first?.value(forHTTPHeaderField: "Cookie") == "ssid=OLD; tdid=DEVICE")
    }

    @Test func storefrontIsAV3PostWithGameHeaders() async throws {
        let http = riot(reauth: Self.success)
        _ = try await StoreService(http: http, sessions: MemorySessions(RiotSession(cookies: RiotCookies(["ssid": "S"])))).fetch()

        let request = try #require(http.requests(to: "/store/v3/storefront/").first)
        #expect(request.url?.absoluteString == "https://pd.ap.a.pvp.net/store/v3/storefront/\(Fixtures.puuid)")
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == Data("{}".utf8))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ACCESS.TOKEN.X")
        #expect(request.value(forHTTPHeaderField: "X-Riot-Entitlements-JWT") == "ENT")
        #expect(request.value(forHTTPHeaderField: "X-Riot-ClientVersion") == "release-13.05-shipping-11-5350494")
        #expect(request.value(forHTTPHeaderField: "X-Riot-ClientPlatform") == RiotAPI.clientPlatform)
    }

    @Test func cachedPuuidAndShardSkipLookups() async throws {
        let http = riot(reauth: Self.success)
        let sessions = MemorySessions(RiotSession(cookies: RiotCookies(["ssid": "S"]), puuid: Fixtures.puuid, shard: "ap"))
        _ = try await StoreService(http: http, sessions: sessions).fetch()
        #expect(http.requests(to: "userinfo").isEmpty)
        #expect(http.requests(to: "riot-geo").isEmpty)
    }

    @Test func expiredCookiesFallBackToThePreviousSet() async throws {
        let http = riot { request in
            request.value(forHTTPHeaderField: "Cookie") == "ssid=PREVIOUS" ? Self.success(request) : Self.expired(request)
        }
        let sessions = MemorySessions(RiotSession(cookies: RiotCookies(["ssid": "CURRENT"]), fallback: RiotCookies(["ssid": "PREVIOUS"])))

        _ = try await StoreService(http: http, sessions: sessions).fetch()

        #expect(http.requests(to: "authorize").count == 2)
        #expect(sessions.session?.cookies.values["ssid"] == "NEW_SSID")
        #expect(sessions.session?.fallback == nil)
    }

    @Test func expiredWithNoFallbackThrowsSessionExpired() async throws {
        let http = riot(reauth: Self.expired)
        let sessions = MemorySessions(RiotSession(cookies: RiotCookies(["ssid": "S"])))
        await #expect(throws: RiotError.sessionExpired) {
            try await StoreService(http: http, sessions: sessions).fetch()
        }
        #expect(sessions.session?.cookies.values["ssid"] == "S")
    }

    @Test func noSessionThrowsNotSignedIn() async {
        await #expect(throws: RiotError.notSignedIn) {
            try await StoreService(http: MockHTTP(), sessions: MemorySessions()).fetch()
        }
    }

    @Test func failingStepIsNamedInTheError() async {
        let http = riot(reauth: Self.success)
        http.on("/store/v3/storefront/", status: 404, json: #"{"errorCode": "RESOURCE_NOT_FOUND"}"#)
        await #expect(throws: RiotError.http(step: "Storefront", status: 404)) {
            try await StoreService(http: http, sessions: MemorySessions(RiotSession(cookies: RiotCookies(["ssid": "S"])))).fetch()
        }
    }

    @Test func signInWithoutSsidIsRejected() async {
        let sessions = MemorySessions()
        await #expect(throws: RiotError.notSignedIn) {
            try await StoreService(http: MockHTTP(), sessions: sessions).signIn(cookies: RiotCookies(["tdid": "T"]))
        }
        #expect(sessions.session == nil)
    }
}
