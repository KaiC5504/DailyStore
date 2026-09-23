import Foundation

/// The auth.riotgames.com cookies that keep a remember-me session alive.
public struct RiotCookies: Codable, Equatable, Sendable {
    public static let names = ["ssid", "clid", "csid", "tdid", "asid"]

    public private(set) var values: [String: String]

    public init(_ values: [String: String]) {
        self.values = values.filter { Self.names.contains($0.key) && !$0.value.isEmpty }
    }

    public var hasSession: Bool { values["ssid"] != nil }

    public var header: String {
        Self.names.compactMap { name in values[name].map { "\(name)=\($0)" } }.joined(separator: "; ")
    }

    /// Riot rotates ssid/clid/csid on every reauth with a fresh 30-day Max-Age, so the
    /// rotated values must replace the old ones or the session stops sliding.
    public func merging(setCookie header: String?) -> RiotCookies {
        guard let header else { return self }
        var merged = values
        for (name, value) in Self.parseSetCookie(header) where Self.names.contains(name) {
            merged[name] = value.isEmpty ? nil : value
        }
        return RiotCookies(merged)
    }

    /// Parses one Set-Cookie header, or several joined with commas the way Foundation
    /// flattens repeated headers. Commas inside `Expires=Fri, 23 Oct ...` are not separators.
    static func parseSetCookie(_ header: String) -> [(String, String)] {
        var cookies: [String] = []
        for part in header.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let eq = trimmed.firstIndex(of: "="),
               !trimmed[..<eq].contains(where: { $0 == " " || $0 == ";" }),
               !trimmed[..<eq].isEmpty {
                cookies.append(trimmed)
            } else if !cookies.isEmpty {
                cookies[cookies.count - 1] += "," + part
            }
        }
        return cookies.compactMap { cookie in
            let pair = cookie.split(separator: ";", maxSplits: 1).first.map(String.init) ?? cookie
            guard let eq = pair.firstIndex(of: "=") else { return nil }
            return (String(pair[..<eq]).trimmingCharacters(in: .whitespaces),
                    String(pair[pair.index(after: eq)...]).trimmingCharacters(in: .whitespaces))
        }
    }
}
