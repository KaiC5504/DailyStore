import Foundation

/// One row of the match list: what the list and the stats need, without loading the full match.
public struct MatchSummary: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let queue: String
    public let isCustom: Bool
    public let mapURL: String
    public let start: Date
    public let length: TimeInterval
    public let agent: String
    public let kills: Int
    public let deaths: Int
    public let assists: Int
    public let acs: Int
    public let outcome: MatchOutcome
    public let mine: Int?
    public let theirs: Int?
    public var rrEarned: Int?
    public var tierAfter: Int?

    public init(match: Match, puuid: String, update: CompetitiveUpdate? = nil) {
        let me = match.player(puuid)
        let score = match.score(for: puuid)
        id = match.id
        queue = match.queue
        isCustom = match.isCustom
        mapURL = match.mapURL
        start = match.start
        length = match.length
        agent = me?.agent ?? ""
        kills = me?.kills ?? 0
        deaths = me?.deaths ?? 0
        assists = me?.assists ?? 0
        acs = me.map(match.acs) ?? 0
        outcome = match.outcome(for: puuid)
        mine = score?.mine
        theirs = score?.theirs
        rrEarned = update?.rrEarned
        tierAfter = update?.tierAfter
    }

    public var kd: Double { Double(kills) / Double(max(deaths, 1)) }
}

public struct CompetitiveUpdate: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let mapURL: String
    public let season: String
    public let start: Date
    public let tierBefore: Int
    public let tierAfter: Int
    public let rrBefore: Int
    public let rrAfter: Int
    public let rrEarned: Int
    public let isPlacement: Bool

    public init(id: String, mapURL: String, season: String, start: Date, tierBefore: Int, tierAfter: Int,
                rrBefore: Int, rrAfter: Int, rrEarned: Int, isPlacement: Bool) {
        self.id = id
        self.mapURL = mapURL
        self.season = season
        self.start = start
        self.tierBefore = tierBefore
        self.tierAfter = tierAfter
        self.rrBefore = rrBefore
        self.rrAfter = rrAfter
        self.rrEarned = rrEarned
        self.isPlacement = isPlacement
    }

    /// Tier and RR as one climbing number, for the trend graph.
    public var ladder: Int { tierAfter * 100 + rrAfter }

    public static func parse(_ data: Data) throws -> [CompetitiveUpdate] {
        try JSONDecoder().decode(RawUpdates.self, from: data).Matches?.map(CompetitiveUpdate.init(raw:)) ?? []
    }

    init(raw: RawUpdate) {
        self.init(
            id: raw.MatchID.lowercased(),
            mapURL: raw.MapID ?? "",
            season: (raw.SeasonID ?? "").lowercased(),
            start: Date(timeIntervalSince1970: TimeInterval(raw.MatchStartTime ?? 0) / 1000),
            tierBefore: raw.TierBeforeUpdate ?? 0,
            tierAfter: raw.TierAfterUpdate ?? 0,
            rrBefore: raw.RankedRatingBeforeUpdate ?? 0,
            rrAfter: raw.RankedRatingAfterUpdate ?? 0,
            rrEarned: raw.RankedRatingEarned ?? 0,
            isPlacement: raw.IsPlacementMatch ?? false
        )
    }
}

public struct RankStatus: Codable, Equatable, Sendable {
    public let tier: Int
    public let rr: Int
    /// e.g. "V26 · ACT V".
    public let act: String?
    public let wins: Int
    public let games: Int
    public let fetchedAt: Date

    public init(tier: Int, rr: Int, act: String?, wins: Int, games: Int, fetchedAt: Date) {
        self.tier = tier
        self.rr = rr
        self.act = act
        self.wins = wins
        self.games = games
        self.fetchedAt = fetchedAt
    }

    public var isRanked: Bool { tier >= 3 }

    /// Rank for the active act. Riot has no entry for an act you haven't played ranked in yet,
    /// which is what "unranked" means here.
    public static func parse(mmr: Data, act: CurrentAct?, now: Date = Date()) throws -> RankStatus {
        let raw = try JSONDecoder().decode(RawMMR.self, from: mmr)
        let seasons = raw.QueueSkills?["competitive"]?.SeasonalInfoBySeasonID ?? [:]
        if let act, let info = seasons.first(where: { $0.key.lowercased() == act.id })?.value {
            return RankStatus(tier: info.CompetitiveTier ?? 0, rr: info.RankedRating ?? 0, act: act.name,
                              wins: info.NumberOfWins ?? 0, games: info.NumberOfGames ?? 0, fetchedAt: now)
        }
        if act == nil, let latest = raw.LatestCompetitiveUpdate, latest.MatchID.isEmpty == false {
            return RankStatus(tier: latest.TierAfterUpdate ?? 0, rr: latest.RankedRatingAfterUpdate ?? 0, act: nil,
                              wins: 0, games: 0, fetchedAt: now)
        }
        return RankStatus(tier: 0, rr: 0, act: act?.name, wins: 0, games: 0, fetchedAt: now)
    }
}

public struct CurrentAct: Equatable, Sendable {
    public let id: String
    public let name: String

    /// The active act from content-service, named with its episode when there is one.
    public static func parse(content: Data) throws -> CurrentAct? {
        let seasons = try JSONDecoder().decode(RawContent.self, from: content).Seasons ?? []
        guard let act = seasons.first(where: { $0.IsActive == true && $0.Type == "act" }) else { return nil }
        let episode = seasons.first { $0.IsActive == true && $0.Type == "episode" }
        let name = [episode?.Name, act.Name].compactMap { $0 }.joined(separator: " · ")
        return CurrentAct(id: act.ID.lowercased(), name: name)
    }
}

/// Top agents and maps, recent form. Custom games don't count.
public struct MatchStats: Equatable, Sendable {
    public struct Line: Equatable, Sendable, Identifiable {
        public let key: String
        public let games: Int
        public let wins: Int
        public let kills: Int
        public let deaths: Int

        public var id: String { key }
        public var winRate: Int { games > 0 ? Int((Double(wins) / Double(games) * 100).rounded()) : 0 }
        public var kd: Double { Double(kills) / Double(max(deaths, 1)) }
    }

    public let agents: [Line]
    public let maps: [Line]
    /// Newest first.
    public let form: [MatchOutcome]
    public let recent: Line

    public init(_ summaries: [MatchSummary], top: Int = 3, formLength: Int = 10) {
        let counted = summaries.filter { !$0.isCustom }.sorted { $0.start > $1.start }
        agents = Self.lines(counted, by: \.agent, top: top)
        maps = Self.lines(counted, by: \.mapURL, top: top)
        form = counted.prefix(formLength).map(\.outcome)
        recent = Self.line("recent", Array(counted.prefix(20)))
    }

    private static func lines(_ summaries: [MatchSummary], by key: KeyPath<MatchSummary, String>, top: Int) -> [Line] {
        Dictionary(grouping: summaries.filter { !$0[keyPath: key].isEmpty }) { $0[keyPath: key] }
            .map { line($0.key, $0.value) }
            .sorted { ($0.games, $0.winRate, $0.key) > ($1.games, $1.winRate, $1.key) }
            .prefix(top)
            .map { $0 }
    }

    private static func line(_ key: String, _ games: [MatchSummary]) -> Line {
        Line(key: key, games: games.count, wins: games.filter { $0.outcome.isWin }.count,
             kills: games.reduce(0) { $0 + $1.kills }, deaths: games.reduce(0) { $0 + $1.deaths })
    }
}

struct RawUpdate: Decodable {
    let MatchID: String
    let MapID: String?
    let SeasonID: String?
    let MatchStartTime: Int?
    let TierBeforeUpdate: Int?
    let TierAfterUpdate: Int?
    let RankedRatingBeforeUpdate: Int?
    let RankedRatingAfterUpdate: Int?
    let RankedRatingEarned: Int?
    let IsPlacementMatch: Bool?
}

private struct RawUpdates: Decodable {
    let Matches: [RawUpdate]?
}

private struct RawMMR: Decodable {
    struct Seasonal: Decodable {
        let CompetitiveTier: Int?
        let RankedRating: Int?
        let NumberOfWins: Int?
        let NumberOfGames: Int?
    }

    struct Queue: Decodable {
        let SeasonalInfoBySeasonID: [String: Seasonal]?
    }

    let QueueSkills: [String: Queue]?
    let LatestCompetitiveUpdate: RawUpdate?
}

private struct RawContent: Decodable {
    struct Season: Decodable {
        let ID: String
        let Name: String?
        let `Type`: String?
        let IsActive: Bool?
    }

    let Seasons: [Season]?
}
