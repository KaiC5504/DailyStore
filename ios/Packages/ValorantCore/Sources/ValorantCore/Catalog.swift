import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SkinInfo: Codable, Hashable, Sendable {
    public let levelID: String
    public let skinID: String
    public let name: String
    public let icon: URL?
    public let tierID: String?
    public let video: URL?
}

public struct ContentTier: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let rank: Int
    /// RRGGBBAA hex as valorant-api.com sends it.
    public let color: String
    public let icon: URL?
}

/// Names, art and tiers from valorant-api.com, keyed the way the storefront refers to them.
public struct Catalog: Codable, Sendable {
    public let clientVersion: String
    public let skins: [String: SkinInfo]
    public let tiers: [String: ContentTier]

    public init(clientVersion: String, skins: [String: SkinInfo], tiers: [String: ContentTier]) {
        self.clientVersion = clientVersion
        self.skins = skins
        self.tiers = tiers
    }

    public func skin(_ levelID: String) -> SkinInfo? { skins[levelID.lowercased()] }
    public func tier(for skin: SkinInfo) -> ContentTier? { skin.tierID.flatMap { tiers[$0] } }

    public static func fetch(http: HTTPClient, clientVersion: String) async throws -> Catalog {
        async let skins = get(http, "https://valorant-api.com/v1/weapons/skins?language=en-US")
        async let tiers = get(http, "https://valorant-api.com/v1/contenttiers")
        return Catalog(
            clientVersion: clientVersion,
            skins: try parseSkins(await skins),
            tiers: try parseTiers(await tiers)
        )
    }

    static func parseSkins(_ data: Data) throws -> [String: SkinInfo] {
        let skins = try JSONDecoder().decode(Envelope<[RawSkin]>.self, from: data).data
        var byLevel: [String: SkinInfo] = [:]
        for skin in skins {
            guard let first = skin.levels.first else { continue }
            // Some first levels ship without art; the base chroma render always exists.
            let icon = first.displayIcon ?? skin.chromas.first?.fullRender ?? skin.displayIcon
            let video = skin.levels.lazy.compactMap(\.streamedVideo).first
                ?? skin.chromas.lazy.compactMap(\.streamedVideo).first
            byLevel[first.uuid.lowercased()] = SkinInfo(
                levelID: first.uuid.lowercased(),
                skinID: skin.uuid.lowercased(),
                name: skin.displayName,
                icon: icon,
                tierID: skin.contentTierUuid?.lowercased(),
                video: video
            )
        }
        return byLevel
    }

    static func parseTiers(_ data: Data) throws -> [String: ContentTier] {
        let tiers = try JSONDecoder().decode(Envelope<[RawTier]>.self, from: data).data
        return Dictionary(uniqueKeysWithValues: tiers.map {
            ($0.uuid.lowercased(), ContentTier(id: $0.uuid.lowercased(), name: $0.devName, rank: $0.rank,
                                              color: $0.highlightColor, icon: $0.displayIcon))
        })
    }

    private static func get(_ http: HTTPClient, _ url: String) async throws -> Data {
        let response = try await http.send(URLRequest(url: URL(string: url)!))
        guard response.isSuccess else { throw RiotError.http(step: "Catalog", status: response.status) }
        return response.body
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let data: T
}

private struct RawSkin: Decodable {
    struct Level: Decodable {
        let uuid: String
        let displayIcon: URL?
        let streamedVideo: URL?
    }

    struct Chroma: Decodable {
        let fullRender: URL?
        let streamedVideo: URL?
    }

    let uuid: String
    let displayName: String
    let contentTierUuid: String?
    let displayIcon: URL?
    let chromas: [Chroma]
    let levels: [Level]
}

private struct RawTier: Decodable {
    let uuid: String
    let devName: String
    let rank: Int
    let highlightColor: String
    let displayIcon: URL?
}
