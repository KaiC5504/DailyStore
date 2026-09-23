import Foundation
import Testing
@testable import ValorantCore

@Suite struct AuthTests {
    @Test func authorizeURLCarriesTheWebClientParameters() throws {
        let url = RiotAuth.authorizeURL(nonce: "n0")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "auth.riotgames.com")
        #expect(query["client_id"] == "play-valorant-web-prod")
        #expect(query["redirect_uri"] == "https://playvalorant.com/opt_in")
        #expect(query["response_type"] == "token id_token")
        #expect(query["scope"] == "account openid")
        #expect(query["nonce"] == "n0")
    }

    @Test func tokensComeOutOfTheRedirectFragment() throws {
        let tokens = try #require(RiotAuth.tokens(fromRedirect: URL(string: Fixtures.successLocation)!))
        #expect(tokens == AuthTokens(accessToken: "ACCESS.TOKEN.X", idToken: "ID.TOKEN.Y", expiresIn: 3600))
    }

    @Test func loginPageIsNotARedirect() {
        let url = URL(string: Fixtures.expiredLocation)!
        #expect(!RiotAuth.isRedirect(url))
        #expect(RiotAuth.isLoginPage(url))
        #expect(RiotAuth.tokens(fromRedirect: url) == nil)
    }

    @Test func randomNonceIsHex() {
        let nonce = RiotAuth.randomNonce()
        #expect(nonce.count == 32)
        #expect(nonce.allSatisfy { $0.isHexDigit })
    }
}

@Suite struct CookieTests {
    @Test func headerKeepsKnownCookiesInStableOrder() {
        let jar = RiotCookies(["tdid": "T", "ssid": "S", "junk": "x", "clid": ""])
        #expect(jar.header == "ssid=S; tdid=T")
        #expect(jar.hasSession)
    }

    @Test func joinedSetCookieSplitsOnlyBetweenCookies() {
        let parsed = RiotCookies.parseSetCookie(Fixtures.rotatedSetCookie)
        #expect(parsed.map(\.0) == ["ssid", "clid", "__cf_bm"])
        #expect(parsed.map(\.1) == ["NEW_SSID", "NEW_CLID", "junk"])
    }

    @Test func mergeReplacesRotatedCookiesAndKeepsTheRest() {
        let jar = RiotCookies(["ssid": "OLD", "clid": "OLD_C", "tdid": "DEVICE"])
        let merged = jar.merging(setCookie: Fixtures.rotatedSetCookie)
        #expect(merged.values == ["ssid": "NEW_SSID", "clid": "NEW_CLID", "tdid": "DEVICE"])
    }

    @Test func emptyValueDeletesACookie() {
        let jar = RiotCookies(["ssid": "S", "asid": "A"])
        let merged = jar.merging(setCookie: "asid=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT")
        #expect(merged.values == ["ssid": "S"])
    }

    @Test func missingHeaderLeavesJarAlone() {
        let jar = RiotCookies(["ssid": "S"])
        #expect(jar.merging(setCookie: nil) == jar)
    }
}
