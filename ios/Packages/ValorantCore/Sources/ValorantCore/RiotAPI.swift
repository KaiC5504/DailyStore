import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RiotAPI: Sendable {
    /// Riot has blocked third-party apps by User-Agent before; if requests start failing
    /// with 403 this is the first thing to change.
    public static let userAgent = "RiotGamesApi/24.11.0.4602 rso-auth (Windows;10;;Professional, x64) riot_client/0"
    // Windows PC platform descriptor, base64 of a tab-indented JSON blob. Every client sends this exact value.
    static let clientPlatform = "ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIlVua25vd24iDQp9"
    // The geo service answers with a region; the store is served per shard.
    static let regionToShard = ["na": "na", "latam": "na", "br": "na", "pbe": "pbe", "eu": "eu", "ap": "ap", "kr": "kr"]

    let http: HTTPClient

    public init(http: HTTPClient) {
        self.http = http
    }

    public struct Context: Sendable {
        public let accessToken: String
        public let entitlements: String
        public let clientVersion: String
        public let puuid: String
        public let shard: String
    }

    public func reauth(_ cookies: RiotCookies) async throws -> (AuthTokens, RiotCookies) {
        var request = URLRequest(url: RiotAuth.authorizeURL())
        request.setValue(cookies.header, forHTTPHeaderField: "Cookie")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let response = try await http.send(request)
        guard let location = response.header("Location").flatMap(URL.init(string:)) else {
            throw RiotError.http(step: "Reauth", status: response.status)
        }
        if let tokens = RiotAuth.tokens(fromRedirect: location) {
            return (tokens, cookies.merging(setCookie: response.header("Set-Cookie")))
        }
        if RiotAuth.isLoginPage(location) { throw RiotError.sessionExpired }
        throw RiotError.unexpected(step: "Reauth")
    }

    public func clientVersion() async throws -> String {
        let body = try await json("Client version", URLRequest(url: URL(string: "https://valorant-api.com/v1/version")!))
        guard let version = (body["data"] as? [String: Any])?["riotClientVersion"] as? String else {
            throw RiotError.unexpected(step: "Client version")
        }
        return version
    }

    public func entitlements(accessToken: String) async throws -> String {
        var request = bearer("https://entitlements.auth.riotgames.com/api/token/v1", accessToken, method: "POST")
        request.httpBody = Data("{}".utf8)
        guard let token = try await json("Entitlements", request)["entitlements_token"] as? String else {
            throw RiotError.unexpected(step: "Entitlements")
        }
        return token
    }

    public func puuid(accessToken: String) async throws -> String {
        let request = bearer("https://auth.riotgames.com/userinfo", accessToken)
        guard let sub = try await json("User info", request)["sub"] as? String else {
            throw RiotError.unexpected(step: "User info")
        }
        return sub
    }

    public func shard(tokens: AuthTokens) async throws -> String {
        var request = bearer("https://riot-geo.pas.si.riotgames.com/pas/v1/product/valorant", tokens.accessToken, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["id_token": tokens.idToken])
        let body = try await json("Region", request)
        guard let region = (body["affinities"] as? [String: Any])?["live"] as? String else {
            throw RiotError.unexpected(step: "Region")
        }
        return Self.regionToShard[region] ?? region
    }

    public func storefront(_ ctx: Context) async throws -> Storefront {
        // v2 GET was retired in September 2024; v3 is POST and 400s without a JSON body.
        var request = game("https://pd.\(ctx.shard).a.pvp.net/store/v3/storefront/\(ctx.puuid)", ctx, method: "POST")
        request.httpBody = Data("{}".utf8)
        return try Storefront(json: try await data("Storefront", request))
    }

    public func wallet(_ ctx: Context) async throws -> Wallet {
        try Wallet(json: try await data("Wallet", game("https://pd.\(ctx.shard).a.pvp.net/store/v1/wallet/\(ctx.puuid)", ctx)))
    }

    /// Every skin level the account owns, lowercased. Owning a skin includes its first level,
    /// which is the ID the catalog and wishlist use.
    public func ownedSkinLevels(_ ctx: Context) async throws -> Set<String> {
        let url = "https://pd.\(ctx.shard).a.pvp.net/store/v1/entitlements/\(ctx.puuid)/\(ItemKind.skinTypeID)"
        let raw = try JSONDecoder().decode(RawOwned.self, from: try await data("Owned skins", game(url, ctx)))
        return Set((raw.Entitlements ?? []).map { $0.ItemID.lowercased() })
    }

    private struct RawOwned: Decodable {
        struct Entitlement: Decodable { let ItemID: String }
        let Entitlements: [Entitlement]?
    }

    private func bearer(_ url: String, _ token: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func game(_ url: String, _ ctx: Context, method: String = "GET") -> URLRequest {
        var request = bearer(url, ctx.accessToken, method: method)
        request.setValue(ctx.entitlements, forHTTPHeaderField: "X-Riot-Entitlements-JWT")
        request.setValue(Self.clientPlatform, forHTTPHeaderField: "X-Riot-ClientPlatform")
        request.setValue(ctx.clientVersion, forHTTPHeaderField: "X-Riot-ClientVersion")
        return request
    }

    private func data(_ step: String, _ request: URLRequest) async throws -> Data {
        let response = try await http.send(request)
        guard response.isSuccess else { throw RiotError.http(step: step, status: response.status) }
        return response.body
    }

    private func json(_ step: String, _ request: URLRequest) async throws -> [String: Any] {
        let body = try await data(step, request)
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw RiotError.unexpected(step: step)
        }
        return object
    }
}
