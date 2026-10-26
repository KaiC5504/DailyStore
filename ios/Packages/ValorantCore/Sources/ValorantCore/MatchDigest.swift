import Foundation

/// Rounds or games played and won.
public struct Tally: Codable, Equatable, Sendable {
    public var played: Int
    public var won: Int

    public init(played: Int = 0, won: Int = 0) {
        self.played = played
        self.won = won
    }

    /// Percent won, nil when nothing was played.
    public var rate: Int? {
        played > 0 ? Int((Double(won) / Double(played) * 100).rounded()) : nil
    }

    public mutating func add(_ won: Bool) {
        played += 1
        if won { self.won += 1 }
    }

    public static func + (a: Tally, b: Tally) -> Tally {
        Tally(played: a.played + b.played, won: a.won + b.won)
    }
}

/// Where shots that hit landed.
public struct Shots: Codable, Equatable, Sendable {
    public var head: Int
    public var body: Int
    public var leg: Int

    public init(head: Int = 0, body: Int = 0, leg: Int = 0) {
        self.head = head
        self.body = body
        self.leg = leg
    }

    public var total: Int { head + body + leg }

    /// Nil when Riot sent no per-shot data.
    public func percent(_ part: KeyPath<Shots, Int>) -> Double? {
        total > 0 ? Double(self[keyPath: part]) / Double(total) * 100 : nil
    }

    mutating func add(_ hit: Match.Hit) {
        head += hit.head
        body += hit.body
        leg += hit.leg
    }

    public static func + (a: Shots, b: Shots) -> Shots {
        Shots(head: a.head + b.head, body: a.body + b.body, leg: a.leg + b.leg)
    }
}

/// The owner's numbers from one match, small enough to load for every archived game at once.
public struct MatchDigest: Codable, Equatable, Sendable, Identifiable {
    /// Bumped when the numbers are worked out differently; the archive rebuilds older digests
    /// from the match details it already has, without asking Riot.
    public static let version = 1

    public struct Gun: Codable, Equatable, Sendable {
        public var kills = 0
        /// Hits in rounds this was the gun bought; Riot doesn't say which gun each hit came from.
        public var shots = Shots()
    }

    public struct Site: Codable, Equatable, Sendable {
        /// Rounds your team planted here.
        public var postPlant = Tally()
        /// Rounds the enemy planted here.
        public var retake = Tally()
    }

    public var version = MatchDigest.version
    public let id: String
    public let start: Date
    public let length: TimeInterval
    public let queue: String
    public let isCustom: Bool
    public let season: String
    public let mapURL: String
    public let agent: String
    public let outcome: MatchOutcome
    /// Two sides playing rounds. Without them only the fields above `rounds` are filled in.
    public let hasRounds: Bool
    public let kills: Int
    public let deaths: Int
    public let assists: Int
    public let performance: Int?
    public let rounds: Int
    public private(set) var damage = 0
    public private(set) var damageTaken = 0
    public private(set) var shots = Shots()
    public private(set) var firstKills = 0
    public private(set) var firstDeaths = 0
    /// Rounds that count toward KAST.
    public private(set) var kast = 0
    /// Rounds with 2, 3, 4 and 5 or more kills.
    public private(set) var multiKills = [0, 0, 0, 0]
    /// 1v1 through 1v5.
    public private(set) var clutches = Array(repeating: Tally(), count: 5)
    public private(set) var plants = 0
    public private(set) var defuses = 0
    public private(set) var flawless = 0
    public private(set) var attack = Tally()
    public private(set) var defense = Tally()
    public private(set) var pistol = Tally()
    public private(set) var eco = Tally()
    public private(set) var force = Tally()
    public private(set) var full = Tally()
    public private(set) var withFirstKill = Tally()
    public private(set) var withFirstDeath = Tally()
    public private(set) var spent = 0
    /// Keyed by weapon uuid; every ability kill goes under "ability".
    public private(set) var guns: [String: Gun] = [:]
    public private(set) var sites: [String: Site] = [:]
    public private(set) var startSide: Side?
    /// 1 is the best rating on your team.
    public private(set) var teamPlace: Int?
    public private(set) var isMVP = false

    public var adr: Int? {
        shots.total > 0 && rounds > 0 ? Int((Double(damage) / Double(rounds)).rounded()) : nil
    }

    public init(match: Match, puuid: String) {
        let me = match.player(puuid)
        id = match.id
        start = match.start
        length = match.length
        queue = match.queue
        isCustom = match.isCustom
        season = match.season
        mapURL = match.mapURL
        agent = me?.agent ?? ""
        outcome = match.outcome(for: puuid)
        hasRounds = match.hasRounds && me != nil
        kills = me?.kills ?? 0
        deaths = me?.deaths ?? 0
        assists = me?.assists ?? 0
        performance = me?.performance
        rounds = me?.rounds ?? 0
        guard hasRounds, let me else { return }

        let team = me.team
        isMVP = match.mvp == me.id
        teamPlace = match.players.filter { $0.team == team }
            .sorted { match.rating($0) > match.rating($1) }
            .firstIndex { $0.id == me.id }
            .map { $0 + 1 }
        damageTaken = match.damageTaken(me)
        firstKills = match.firstBloods(me)
        firstDeaths = match.firstDeaths(me)
        kast = match.kastRounds(me)?.counted ?? 0
        startSide = match.playedRounds.first.flatMap { match.side(of: team, in: $0) }

        for round in match.playedRounds {
            guard let mine = round.players.first(where: { $0.id == me.id }) else { continue }
            let won = round.winner == team
            spent += mine.spent
            for hit in mine.hits {
                damage += hit.damage
                shots.add(hit)
                if !mine.weapon.isEmpty { guns[mine.weapon, default: Gun()].shots.add(hit) }
            }
            for kill in match.enemyKills(by: me.id, in: round) {
                let gun = kill.kind == "Ability" ? "ability" : kill.item
                if !gun.isEmpty { guns[gun, default: Gun()].kills += 1 }
            }

            let roundKills = match.kills(by: me.id, in: round)
            if roundKills >= 2 { multiKills[min(roundKills, 5) - 2] += 1 }
            if let enemies = match.clutch(for: me.id, in: round), enemies <= clutches.count {
                clutches[enemies - 1].add(won)
            }
            if round.planter == me.id { plants += 1 }
            if round.defuser == me.id { defuses += 1 }
            if won, !round.kills.contains(where: { match.player($0.victim)?.team == team }) { flawless += 1 }
            if round.firstBlood == me.id { withFirstKill.add(won) }
            if round.kills.first?.victim == me.id { withFirstDeath.add(won) }

            switch match.side(of: team, in: round) {
            case .attack: attack.add(won)
            case .defense: defense.add(won)
            case nil: break
            }
            switch match.buy(of: team, in: round) {
            case .pistol: pistol.add(won)
            case .eco: eco.add(won)
            case .force: force.add(won)
            case .full: full.add(won)
            case nil: break
            }
            if let site = round.plantSite, let planter = round.planter.flatMap(match.player) {
                if planter.team == team {
                    sites[site, default: Site()].postPlant.add(won)
                } else {
                    sites[site, default: Site()].retake.add(won)
                }
            }
        }
    }
}
