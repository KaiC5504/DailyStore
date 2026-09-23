import Foundation

public enum RiotError: Error, Equatable, LocalizedError {
    case notSignedIn
    case sessionExpired
    case http(step: String, status: Int)
    case unexpected(step: String)

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "Not signed in."
        case .sessionExpired: "Your Riot session expired. Sign in again."
        case let .http(step, status): "\(step) failed (HTTP \(status))."
        case let .unexpected(step): "\(step) returned something unexpected."
        }
    }
}

public struct AuthTokens: Sendable, Equatable {
    public let accessToken: String
    public let idToken: String
    public let expiresIn: Int
}

public enum RiotAuth {
    public static let redirectHost = "playvalorant.com"
    public static let redirectPath = "/opt_in"

    public static func authorizeURL(nonce: String = randomNonce()) -> URL {
        var components = URLComponents(string: "https://auth.riotgames.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: "https://\(redirectHost)\(redirectPath)"),
            URLQueryItem(name: "client_id", value: "play-valorant-web-prod"),
            URLQueryItem(name: "response_type", value: "token id_token"),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "scope", value: "account openid"),
        ]
        return components.url!
    }

    public static func randomNonce() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    public static func isRedirect(_ url: URL) -> Bool {
        url.host == redirectHost && url.path.hasPrefix(redirectPath)
    }

    public static func isLoginPage(_ url: URL) -> Bool {
        url.host == "authenticate.riotgames.com" || url.path.contains("/login")
    }

    public static func tokens(fromRedirect url: URL) -> AuthTokens? {
        guard isRedirect(url), let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            return nil
        }
        var parts = URLComponents()
        parts.query = fragment
        let items = parts.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let access = value("access_token"), let id = value("id_token") else { return nil }
        return AuthTokens(accessToken: access, idToken: id, expiresIn: Int(value("expires_in") ?? "") ?? 3600)
    }
}
