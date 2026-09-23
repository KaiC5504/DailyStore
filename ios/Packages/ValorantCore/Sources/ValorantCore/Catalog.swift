import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SkinChroma: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let render: URL?
    public let swatch: URL?
    public let video: URL?
}

public struct SkinLevel: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// e.g. "VFX", "Animation"; nil for the base level.
    public let upgrade: String?
    public let video: URL?
}

public struct SkinInfo: Codable, Hashable, Sendable {
    public let levelID: String
    public let skinID: String
    public let name: String
    public let icon: URL?
    public let tierID: String?
    public let video: URL?
    public let chromas: [SkinChroma]
    public let levels: [SkinLevel]
}

public struct ContentTier: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let rank: Int
    /// RRGGBBAA hex as valorant-api.com sends it.
    public let color: String
    public let icon: URL?
}

public enum ItemKind: String, Codable, Sendable {
    case skin, buddy, spray, card, title, flex, other

    public static let skinTypeID = "e7c63390-eda7-46e0-bb7a-a6abdacd2433"

    /// Riot's ItemTypeID values as they appear in storefront rewards.
    public init(typeID: String) {
        switch typeID.lowercased() {
        case Self.skinTypeID: self = .skin
        case "dd3bf334-87f3-40bd-b043-682a57a8dc3a": self = .buddy
        case "d5f120f8-ff8c-4aac-92ea-f2b5acbe9475": self = .spray
        case "3f296c07-64c3-494c-923b-fe692a4fa1bd": self = .card
        case "de7caa6b-adf7-4588-bbd1-143831e786c6": self = .title
        case "03a572de-4234-31ed-d344-ababa488f981": self = .flex
        default: self = .other
        }
    }
}

/// Anything that is not a weapon skin: buddies, sprays, cards, titles.
public struct ItemInfo: Codable, Hashable, Sendable {
    public let id: String
    public let kind: ItemKind
    public let name: String
    public let icon: URL?
}

public struct BundleInfo: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String?
    public let art: URL?
    public let verticalArt: URL?
}

/// Names, art and tiers from valorant-api.com, keyed the way the storefront refers to them.
public struct Catalog: Codable, Sendable {
    public let clientVersion: String
    public let skins: [String: SkinInfo]
    public let tiers: [String: ContentTier]
    public let items: [String: ItemInfo]
    public let bundles: [String: BundleInfo]

    public init(clientVersion: String, skins: [String: SkinInfo], tiers: [String: ContentTier],
                items: [String: ItemInfo] = [:], bundles: [String: BundleInfo] = [:]) {
        self.clientVersion = clientVersion
        self.skins = skins
        self.tiers = tiers
        self.items = items
        self.bundles = bundles
    }

    public func skin(_ levelID: String) -> SkinInfo? { skins[levelID.lowercased()] }
    public func tier(for skin: SkinInfo) -> ContentTier? { skin.tierID.flatMap { tiers[$0] } }
    public func item(_ id: String) -> ItemInfo? { items[id.lowercased()] }
    public func bundle(_ dataAssetID: String) -> BundleInfo? { bundles[dataAssetID.lowercased()] }

    public static func fetch(http: HTTPClient, clientVersion: String) async throws -> Catalog {
        let base = "https://valorant-api.com/v1/"
        async let skins = get(http, base + "weapons/skins?language=en-US")
        async let tiers = get(http, base + "contenttiers")
        async let bundles = get(http, base + "bundles?language=en-US")
        async let buddies = get(http, base + "buddies/levels?language=en-US")
        async let sprays = get(http, base + "sprays?language=en-US")
        async let cards = get(http, base + "playercards?language=en-US")
        async let titles = get(http, base + "playertitles?language=en-US")

        var items: [String: ItemInfo] = [:]
        for (kind, data) in [(ItemKind.buddy, try await buddies), (.spray, try await sprays),
                             (.card, try await cards), (.title, try await titles)] {
            items.merge(try parseItems(data, kind: kind)) { $1 }
        }
        return Catalog(
            clientVersion: clientVersion,
            skins: try parseSkins(await skins),
            tiers: try parseTiers(await tiers),
            items: items,
            bundles: try parseBundles(await bundles)
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
                video: video,
                chromas: skin.chromas.map {
                    SkinChroma(id: $0.uuid.lowercased(), name: cleanChromaName($0.displayName, skin: skin.displayName),
                               render: $0.fullRender ?? $0.displayIcon, swatch: $0.swatch, video: $0.streamedVideo)
                },
                levels: skin.levels.enumerated().map { index, level in
                    SkinLevel(id: level.uuid.lowercased(), name: "Level \(index + 1)",
                              upgrade: level.levelItem.map(cleanLevelItem), video: level.streamedVideo)
                }
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

    static func parseItems(_ data: Data, kind: ItemKind) throws -> [String: ItemInfo] {
        let raw = try JSONDecoder().decode(Envelope<[RawItem]>.self, from: data).data
        var out: [String: ItemInfo] = [:]
        for item in raw {
            let icon = item.largeArt ?? item.fullTransparentIcon ?? item.displayIcon
            out[item.uuid.lowercased()] = ItemInfo(id: item.uuid.lowercased(), kind: kind,
                                                   name: item.titleText ?? item.displayName ?? "Unknown", icon: icon)
        }
        return out
    }

    static func parseBundles(_ data: Data) throws -> [String: BundleInfo] {
        let raw = try JSONDecoder().decode(Envelope<[RawBundleInfo]>.self, from: data).data
        return Dictionary(raw.map {
            ($0.uuid.lowercased(), BundleInfo(id: $0.uuid.lowercased(), name: $0.displayName,
                                              subtitle: $0.displayNameSubText, art: $0.displayIcon,
                                              verticalArt: $0.verticalPromoImage))
        }) { first, _ in first }
    }

    /// "Reaver Vandal Level 4\r\n(Variant 1 Red)" -> "Red"; the base chroma becomes "Standard".
    static func cleanChromaName(_ name: String, skin: String) -> String {
        if let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), open < close {
            let inner = name[name.index(after: open)..<close]
            let parts = inner.split(separator: " ")
            if parts.first == "Variant", parts.count > 2 { return parts.dropFirst(2).joined(separator: " ") }
            return String(inner)
        }
        return name == skin ? "Standard" : name
    }

    static func cleanLevelItem(_ raw: String) -> String {
        let name = raw.components(separatedBy: "::").last ?? raw
        switch name {
        case "VFX": return "VFX"
        case "SoundEffects": return "Sound"
        case "KillBanner": return "Kill Banner"
        case "KillCounter": return "Kill Counter"
        case "KillEffect": return "Kill Effect"
        case "TopFrame": return "Top Frame"
        case "InspectAndKill": return "Inspect & Kill"
        case "Randomizer": return "Randomizer"
        case "Transformation": return "Transformation"
        case "Finisher": return "Finisher"
        case "Animation": return "Animation"
        case "AttackerDefenderSwap": return "Side Swap"
        default: return name
        }
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
        let levelItem: String?
        let displayIcon: URL?
        let streamedVideo: URL?
    }

    struct Chroma: Decodable {
        let uuid: String
        let displayName: String
        let displayIcon: URL?
        let fullRender: URL?
        let swatch: URL?
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

private struct RawItem: Decodable {
    let uuid: String
    let displayName: String?
    let titleText: String?
    let displayIcon: URL?
    let fullTransparentIcon: URL?
    let largeArt: URL?
}

private struct RawBundleInfo: Decodable {
    let uuid: String
    let displayName: String
    let displayNameSubText: String?
    let displayIcon: URL?
    let verticalPromoImage: URL?
}
