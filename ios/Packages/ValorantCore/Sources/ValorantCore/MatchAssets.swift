import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Names and art for what match details only refers to by ID, from valorant-api.com.
public struct MatchAssets: Codable, Sendable {
    public struct MapInfo: Codable, Hashable, Sendable {
        public let name: String
        public let splash: URL?
        /// Wide banner for list rows.
        public let banner: URL?
    }

    public struct AgentInfo: Codable, Hashable, Sendable {
        public let name: String
        public let icon: URL?
        public let portrait: URL?
        public let killfeed: URL?
        public let role: String?
        /// RRGGBBAA hex, darkest first as valorant-api.com lists them.
        public let colors: [String]
        /// Ability icons keyed by Riot's damage item names ("Ability1", "Ability2", "GrenadeAbility", "Ultimate").
        public let abilities: [String: URL]
    }

    public struct RankTier: Codable, Hashable, Sendable {
        public let tier: Int
        public let name: String
        public let color: String
        public let icon: URL?
    }

    public struct WeaponInfo: Codable, Hashable, Sendable {
        public let name: String
        public let icon: URL?
    }

    public let clientVersion: String
    public let maps: [String: MapInfo]
    public let agents: [String: AgentInfo]
    public let tiers: [String: RankTier]
    public let weapons: [String: WeaponInfo]
    public let gear: [String: String]
    public let queues: [String: String]

    public init(clientVersion: String, maps: [String: MapInfo], agents: [String: AgentInfo], tiers: [String: RankTier],
                weapons: [String: WeaponInfo], gear: [String: String], queues: [String: String]) {
        self.clientVersion = clientVersion
        self.maps = maps
        self.agents = agents
        self.tiers = tiers
        self.weapons = weapons
        self.gear = gear
        self.queues = queues
    }

    public func map(_ mapURL: String) -> MapInfo? { maps[mapURL.lowercased()] }
    public func agent(_ id: String) -> AgentInfo? { agents[id.lowercased()] }
    public func tier(_ tier: Int) -> RankTier? { tiers[String(tier)] }
    public func weapon(_ id: String) -> WeaponInfo? { weapons[id.lowercased()] }
    public func armor(_ id: String) -> String? { gear[id.lowercased()] }

    public func queueName(_ queue: String, isCustom: Bool = false) -> String {
        if isCustom || queue.isEmpty { return "Custom" }
        return queues[queue] ?? Self.displayFallback(queue)
    }

    /// Riot adds modes before valorant-api.com lists them.
    public static func displayFallback(_ queue: String) -> String {
        queue.prefix(1).uppercased() + queue.dropFirst()
    }

    public static func fetch(http: HTTPClient, clientVersion: String) async throws -> MatchAssets {
        let base = "https://valorant-api.com/v1/"
        async let maps = get(http, base + "maps?language=en-US")
        async let agents = get(http, base + "agents?isPlayableCharacter=true&language=en-US")
        async let tiers = get(http, base + "competitivetiers?language=en-US")
        async let weapons = get(http, base + "weapons?language=en-US")
        async let gear = get(http, base + "gear?language=en-US")
        async let queues = get(http, base + "gamemodes/queues?language=en-US")
        return try parse(clientVersion: clientVersion, maps: await maps, agents: await agents, tiers: await tiers,
                         weapons: await weapons, gear: await gear, queues: await queues)
    }

    static func parse(clientVersion: String, maps: Data, agents: Data, tiers: Data,
                      weapons: Data, gear: Data, queues: Data) throws -> MatchAssets {
        let decoder = JSONDecoder()
        var mapInfo: [String: MapInfo] = [:]
        for map in try decoder.decode(Envelope<[RawMap]>.self, from: maps).data {
            guard let url = map.mapUrl, !url.isEmpty else { continue }
            // The Range is listed twice; the first entry is the playable one.
            let key = url.lowercased()
            if mapInfo[key] == nil {
                mapInfo[key] = MapInfo(name: map.displayName, splash: map.splash, banner: map.listViewIcon)
            }
        }
        let agentInfo = try decoder.decode(Envelope<[RawAgent]>.self, from: agents).data.reduce(into: [String: AgentInfo]()) { result, agent in
            var abilities: [String: URL] = [:]
            for ability in agent.abilities ?? [] {
                guard let icon = ability.displayIcon, let slot = ability.slot else { continue }
                abilities[slot == "Grenade" ? "GrenadeAbility" : slot] = icon
            }
            result[agent.uuid.lowercased()] = AgentInfo(
                name: agent.displayName, icon: agent.displayIcon, portrait: agent.fullPortrait,
                killfeed: agent.killfeedPortrait, role: agent.role?.displayName,
                colors: agent.backgroundGradientColors ?? [], abilities: abilities
            )
        }
        // Every episode has its own tier set; the last one is current.
        let tierSet = try decoder.decode(Envelope<[RawTierSet]>.self, from: tiers).data.last?.tiers ?? []
        let tierInfo = tierSet.reduce(into: [String: RankTier]()) {
            $0[String($1.tier)] = RankTier(tier: $1.tier, name: $1.tierName.capitalized, color: $1.color ?? "ffffffff",
                                            icon: $1.largeIcon ?? $1.smallIcon)
        }
        let weaponInfo = try decoder.decode(Envelope<[RawWeapon]>.self, from: weapons).data.reduce(into: [String: WeaponInfo]()) {
            $0[$1.uuid.lowercased()] = WeaponInfo(name: $1.displayName, icon: $1.killStreamIcon ?? $1.displayIcon)
        }
        let gearInfo = try decoder.decode(Envelope<[RawNamed]>.self, from: gear).data.reduce(into: [String: String]()) {
            $0[$1.uuid.lowercased()] = $1.displayName
        }
        let queueNames = try decoder.decode(Envelope<[RawQueue]>.self, from: queues).data.reduce(into: [String: String]()) {
            $0[$1.queueId] = $1.displayName
        }
        return MatchAssets(clientVersion: clientVersion, maps: mapInfo, agents: agentInfo, tiers: tierInfo,
                           weapons: weaponInfo, gear: gearInfo, queues: queueNames)
    }

    private static func get(_ http: HTTPClient, _ url: String) async throws -> Data {
        let response = try await http.send(URLRequest(url: URL(string: url)!))
        guard response.isSuccess else { throw RiotError.http(step: "Match assets", status: response.status) }
        return response.body
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let data: T
}

private struct RawMap: Decodable {
    let displayName: String
    let mapUrl: String?
    let splash: URL?
    let listViewIcon: URL?
}

private struct RawAgent: Decodable {
    struct Role: Decodable { let displayName: String }
    struct Ability: Decodable {
        let slot: String?
        let displayIcon: URL?
    }

    let uuid: String
    let displayName: String
    let displayIcon: URL?
    let fullPortrait: URL?
    let killfeedPortrait: URL?
    let backgroundGradientColors: [String]?
    let role: Role?
    let abilities: [Ability]?
}

private struct RawTierSet: Decodable {
    struct Tier: Decodable {
        let tier: Int
        let tierName: String
        let color: String?
        let smallIcon: URL?
        let largeIcon: URL?
    }

    let tiers: [Tier]
}

private struct RawWeapon: Decodable {
    let uuid: String
    let displayName: String
    let displayIcon: URL?
    let killStreamIcon: URL?
}

private struct RawNamed: Decodable {
    let uuid: String
    let displayName: String
}

private struct RawQueue: Decodable {
    let queueId: String
    let displayName: String
}
