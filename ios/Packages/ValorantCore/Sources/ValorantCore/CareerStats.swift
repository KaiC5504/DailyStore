import Foundation

/// Which games the stats pages count, picked from the Matches header.
public struct StatsScope: Codable, Hashable, Sendable {
    public enum Act: String, Codable, Sendable {
        case current, all
    }

    public var act: Act
    /// Riot's queue ID; nil is every queue, "custom" is custom games only.
    public var queue: String?

    public init(act: Act = .current, queue: String? = "competitive") {
        self.act = act
        self.queue = queue
    }

    public func includes(_ digest: MatchDigest, currentAct: String?) -> Bool {
        includes(queue: digest.queue, isCustom: digest.isCustom, season: digest.season, currentAct: currentAct)
    }

    /// Without a known current act there is nothing to narrow to, so every act counts. A game whose
    /// season isn't known yet only shows under "All time".
    public func includes(queue: String, isCustom: Bool, season: String?, currentAct: String?) -> Bool {
        if act == .current, let currentAct, season != currentAct { return false }
        switch self.queue {
        case nil: return true
        case "custom": return isCustom
        case let wanted?: return !isCustom && queue == wanted
        }
    }
}

/// Six axes from 0 to 1, each on a fixed scale rather than compared with other players.
public struct Playstyle: Equatable, Sendable {
    public var aim: Double
    public var entry: Double
    public var damage: Double
    public var consistency: Double
    public var clutch: Double
    public var economy: Double

    public static let zero = Playstyle(aim: 0, entry: 0, damage: 0, consistency: 0, clutch: 0, economy: 0)
}

/// Totals over a set of games: the whole scope, one agent or one map. Custom games and modes
/// without two sides never count.
public struct CareerStats: Equatable, Sendable {
    public struct Line: Equatable, Sendable, Identifiable {
        public let key: String
        public let games: Int
        public let wins: Int
        public let kills: Int
        public let deaths: Int
        public let performance: Int?
        public let attack: Tally
        public let defense: Tally

        public var id: String { key }
        public var winRate: Int { games > 0 ? Int((Double(wins) / Double(games) * 100).rounded()) : 0 }
        public var kd: Double { Double(kills) / Double(max(deaths, 1)) }
    }

    public struct GunLine: Equatable, Sendable, Identifiable {
        /// Weapon uuid, or "ability".
        public let key: String
        public let kills: Int
        public let shots: Shots

        public var id: String { key }
    }

    public let games: Int
    public let wins: Int
    public let losses: Int
    public let rounds: Int
    public let kills: Int
    public let deaths: Int
    public let assists: Int
    public let performance: Int?
    public let shots: Shots
    public let adr: Int?
    public let kast: Int?
    public let ddDelta: Int?
    public let econRating: Int?
    public let playtime: TimeInterval
    /// Rounds with 2, 3, 4 and 5 or more kills.
    public let multiKills: [Int]
    /// 1v1 through 1v5.
    public let clutches: [Tally]
    public let clutch: Tally
    public let plants: Int
    public let defuses: Int
    public let flawless: Int
    public let firstKills: Int
    public let firstDeaths: Int
    public let attack: Tally
    public let defense: Tally
    public let pistol: Tally
    public let eco: Tally
    public let force: Tally
    public let full: Tally
    public let withFirstKill: Tally
    public let withFirstDeath: Tally
    /// Games by the side they started on.
    public let startAttack: Tally
    public let startDefense: Tally
    /// Most played first.
    public let agents: [Line]
    public let maps: [Line]
    /// Most kills first.
    public let guns: [GunLine]
    public let sites: [String: MatchDigest.Site]

    public init(_ digests: [MatchDigest]) {
        let counted = digests.filter { $0.hasRounds && !$0.isCustom }
        // Older matches and some modes carry no per-shot data; averaging them in would drag ADR toward zero.
        let withHits = counted.filter { $0.shots.total > 0 }
        games = counted.count
        wins = counted.filter { $0.outcome.isWin }.count
        losses = counted.filter { $0.outcome == .loss }.count
        rounds = Self.sum(counted, \.rounds)
        kills = Self.sum(counted, \.kills)
        deaths = Self.sum(counted, \.deaths)
        assists = Self.sum(counted, \.assists)
        performance = Self.average(counted.compactMap(\.performance))
        shots = withHits.reduce(Shots()) { $0 + $1.shots }

        let hitRounds = Self.sum(withHits, \.rounds)
        let damage = Self.sum(withHits, \.damage)
        let spent = Self.sum(withHits, \.spent)
        adr = hitRounds > 0 ? Int((Double(damage) / Double(hitRounds)).rounded()) : nil
        ddDelta = hitRounds > 0
            ? Int((Double(damage - Self.sum(withHits, \.damageTaken)) / Double(hitRounds)).rounded()) : nil
        econRating = spent > 0 ? Int((Double(damage) * 1000 / Double(spent)).rounded()) : nil
        let kastRounds = Self.sum(counted, \.kastRounds)
        kast = kastRounds > 0 ? Int((Double(Self.sum(counted, \.kast)) / Double(kastRounds) * 100).rounded()) : nil
        playtime = counted.reduce(0) { $0 + $1.length }

        multiKills = (0..<4).map { index in counted.reduce(0) { $0 + $1.multiKills[index] } }
        clutches = (0..<5).map { index in counted.reduce(Tally()) { $0 + $1.clutches[index] } }
        clutch = clutches.reduce(Tally(), +)
        plants = Self.sum(counted, \.plants)
        defuses = Self.sum(counted, \.defuses)
        flawless = Self.sum(counted, \.flawless)
        firstKills = Self.sum(counted, \.firstKills)
        firstDeaths = Self.sum(counted, \.firstDeaths)
        attack = Self.tally(counted, \.attack)
        defense = Self.tally(counted, \.defense)
        pistol = Self.tally(counted, \.pistol)
        eco = Self.tally(counted, \.eco)
        force = Self.tally(counted, \.force)
        full = Self.tally(counted, \.full)
        withFirstKill = Self.tally(counted, \.withFirstKill)
        withFirstDeath = Self.tally(counted, \.withFirstDeath)
        startAttack = Self.games(counted.filter { $0.startSide == .attack })
        startDefense = Self.games(counted.filter { $0.startSide == .defense })

        agents = Self.lines(counted, by: \.agent)
        maps = Self.lines(counted, by: \.mapURL)
        var guns: [String: MatchDigest.Gun] = [:]
        var sites: [String: MatchDigest.Site] = [:]
        for digest in counted {
            for (key, gun) in digest.guns {
                var total = guns[key] ?? MatchDigest.Gun()
                total.kills += gun.kills
                total.shots = total.shots + gun.shots
                guns[key] = total
            }
            for (key, site) in digest.sites {
                var total = sites[key] ?? MatchDigest.Site()
                total.postPlant = total.postPlant + site.postPlant
                total.retake = total.retake + site.retake
                sites[key] = total
            }
        }
        self.guns = guns.map { GunLine(key: $0.key, kills: $0.value.kills, shots: $0.value.shots) }
            .sorted { ($0.kills, $0.key) > ($1.kills, $1.key) }
        self.sites = sites
    }

    public var winRate: Int? {
        games > 0 ? Int((Double(wins) / Double(games) * 100).rounded()) : nil
    }

    public var kd: Double { Double(kills) / Double(max(deaths, 1)) }

    /// First kills per first death; a player who never died first counts as dying once.
    public var entryRatio: Double { Double(firstKills) / Double(max(firstDeaths, 1)) }

    public var playstyle: Playstyle {
        func scale(_ value: Double?, _ low: Double, _ high: Double) -> Double {
            guard let value else { return 0 }
            return min(max((value - low) / (high - low), 0), 1)
        }
        return Playstyle(
            aim: scale(shots.percent(\.head), 0, 40),
            entry: scale(games > 0 ? entryRatio : nil, 0, 2),
            damage: scale(adr.map(Double.init), 0, 220),
            consistency: scale(kast.map(Double.init), 40, 90),
            clutch: scale(clutch.rate.map(Double.init), 0, 60),
            economy: scale(econRating.map(Double.init), 0, 120)
        )
    }

    private static func sum(_ digests: [MatchDigest], _ key: KeyPath<MatchDigest, Int>) -> Int {
        digests.reduce(0) { $0 + $1[keyPath: key] }
    }

    private static func tally(_ digests: [MatchDigest], _ key: KeyPath<MatchDigest, Tally>) -> Tally {
        digests.reduce(Tally()) { $0 + $1[keyPath: key] }
    }

    private static func games(_ digests: [MatchDigest]) -> Tally {
        Tally(played: digests.count, won: digests.filter { $0.outcome.isWin }.count)
    }

    private static func average(_ values: [Int]) -> Int? {
        values.isEmpty ? nil : Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func lines(_ digests: [MatchDigest], by key: KeyPath<MatchDigest, String>) -> [Line] {
        Dictionary(grouping: digests.filter { !$0[keyPath: key].isEmpty }) { $0[keyPath: key] }
            .map { key, games in
                Line(key: key, games: games.count, wins: games.filter { $0.outcome.isWin }.count,
                     kills: sum(games, \.kills), deaths: sum(games, \.deaths),
                     performance: average(games.compactMap(\.performance)),
                     attack: tally(games, \.attack), defense: tally(games, \.defense))
            }
            .sorted { a, b in
                (a.games, a.winRate) != (b.games, b.winRate) ? (a.games, a.winRate) > (b.games, b.winRate) : a.key < b.key
            }
    }
}
