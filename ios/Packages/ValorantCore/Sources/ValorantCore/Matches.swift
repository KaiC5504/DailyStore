import Foundation

/// One finished game, trimmed from Riot's match-details response. A competitive match is
/// over 600 KB raw (mostly player positions on every kill), so the archive keeps this instead.
public struct Match: Codable, Equatable, Sendable, Identifiable {
    /// Bumped when the stored shape changes, so old archive entries can be refetched while Riot still has them.
    public static let currentSchema = 1

    public struct Team: Codable, Equatable, Sendable {
        public let id: String
        public let won: Bool
        public let roundsWon: Int
        public let points: Int

        public init(id: String, won: Bool, roundsWon: Int, points: Int) {
            self.id = id
            self.won = won
            self.roundsWon = roundsWon
            self.points = points
        }
    }

    public struct Player: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public internal(set) var name: String
        public internal(set) var tag: String
        public let team: String
        public let agent: String
        public let tier: Int
        public let party: String
        public let score: Int
        public let kills: Int
        public let deaths: Int
        public let assists: Int
        public let rounds: Int

        public init(id: String, name: String, tag: String, team: String, agent: String, tier: Int, party: String,
                    score: Int, kills: Int, deaths: Int, assists: Int, rounds: Int) {
            self.id = id
            self.name = name
            self.tag = tag
            self.team = team
            self.agent = agent
            self.tier = tier
            self.party = party
            self.score = score
            self.kills = kills
            self.deaths = deaths
            self.assists = assists
            self.rounds = rounds
        }

        public var displayName: String { tag.isEmpty ? name : "\(name)#\(tag)" }
    }

    public struct Kill: Codable, Equatable, Sendable {
        /// Milliseconds into the round.
        public let time: Int
        public let killer: String
        public let victim: String
        public let assistants: [String]
        /// Weapon uuid (lowercased), or Riot's slot name for abilities ("Ultimate", "Ability1", ...), or "".
        public let item: String
        /// "Weapon", "Ability", "Bomb", "Fall", "Melee"...
        public let kind: String

        public init(time: Int, killer: String, victim: String, assistants: [String], item: String, kind: String) {
            self.time = time
            self.killer = killer
            self.victim = victim
            self.assistants = assistants
            self.item = item
            self.kind = kind
        }

        enum CodingKeys: String, CodingKey {
            case time = "t", killer = "k", victim = "v", assistants = "a", item = "i", kind = "d"
        }
    }

    public struct Hit: Codable, Equatable, Sendable {
        public let receiver: String
        public let damage: Int
        public let head: Int
        public let body: Int
        public let leg: Int

        public init(receiver: String, damage: Int, head: Int, body: Int, leg: Int) {
            self.receiver = receiver
            self.damage = damage
            self.head = head
            self.body = body
            self.leg = leg
        }

        enum CodingKeys: String, CodingKey { case receiver = "r", damage = "d", head = "h", body = "b", leg = "l" }
    }

    public struct RoundPlayer: Codable, Equatable, Sendable {
        public let id: String
        public let score: Int
        public let loadout: Int
        public let spent: Int
        public let remaining: Int
        public let weapon: String
        public let armor: String
        public let hits: [Hit]

        public init(id: String, score: Int, loadout: Int, spent: Int, remaining: Int, weapon: String, armor: String,
                    hits: [Hit]) {
            self.id = id
            self.score = score
            self.loadout = loadout
            self.spent = spent
            self.remaining = remaining
            self.weapon = weapon
            self.armor = armor
            self.hits = hits
        }

        enum CodingKeys: String, CodingKey {
            case id = "p", score = "s", loadout = "l", spent = "x", remaining = "m", weapon = "w", armor = "a", hits = "h"
        }
    }

    public struct Round: Codable, Equatable, Sendable, Identifiable {
        public let number: Int
        public let winner: String
        /// "Elimination", "Detonate", "Defuse", "Surrendered" or "" (time ran out, or a mode without a spike).
        public let result: String
        /// "Attacker" or "Defender" when Riot says.
        public let winnerRole: String?
        public let ceremony: String
        public let planter: String?
        public let plantSite: String?
        public let plantTime: Int?
        public let defuser: String?
        public let defuseTime: Int?
        public let firstBlood: String?
        public let kills: [Kill]
        public let players: [RoundPlayer]

        public init(number: Int, winner: String, result: String, winnerRole: String?, ceremony: String,
                    planter: String?, plantSite: String?, plantTime: Int?, defuser: String?, defuseTime: Int?,
                    firstBlood: String?, kills: [Kill], players: [RoundPlayer]) {
            self.number = number
            self.winner = winner
            self.result = result
            self.winnerRole = winnerRole
            self.ceremony = ceremony
            self.planter = planter
            self.plantSite = plantSite
            self.plantTime = plantTime
            self.defuser = defuser
            self.defuseTime = defuseTime
            self.firstBlood = firstBlood
            self.kills = kills
            self.players = players
        }

        public var id: Int { number }
    }

    public var schema: Int
    public let id: String
    /// Riot's queue ID; "" for custom games.
    public let queue: String
    public let isCustom: Bool
    public let mapURL: String
    public let mode: String
    public let start: Date
    public let length: TimeInterval
    public let season: String
    public let isRanked: Bool
    public let completion: String
    public let mvp: String?
    public let teams: [Team]
    public internal(set) var players: [Player]
    public let rounds: [Round]

    public init(schema: Int = Match.currentSchema, id: String, queue: String, isCustom: Bool, mapURL: String, mode: String,
                start: Date, length: TimeInterval, season: String, isRanked: Bool, completion: String, mvp: String?,
                teams: [Team], players: [Player], rounds: [Round]) {
        self.schema = schema
        self.id = id
        self.queue = queue
        self.isCustom = isCustom
        self.mapURL = mapURL
        self.mode = mode
        self.start = start
        self.length = length
        self.season = season
        self.isRanked = isRanked
        self.completion = completion
        self.mvp = mvp
        self.teams = teams
        self.players = players
        self.rounds = rounds
    }
}

extension Match {
    public static func parse(_ data: Data) throws -> Match {
        let raw = try JSONDecoder().decode(RawMatch.self, from: data)
        let info = raw.matchInfo
        let rounds = (raw.roundResults ?? []).map { round -> Round in
            let stats = round.playerStats ?? []
            // Competitive and Swiftplay carry a separate economy list; other modes only fill the per-player one.
            let economies = Dictionary((round.playerEconomies ?? []).map { (($0.subject ?? "").lowercased(), $0) }) { a, _ in a }
            let players = stats.map { stat -> RoundPlayer in
                let id = stat.subject.lowercased()
                let economy = economies[id] ?? stat.economy
                return RoundPlayer(
                    id: id,
                    score: stat.score ?? 0,
                    loadout: economy?.loadoutValue ?? 0,
                    spent: economy?.spent ?? 0,
                    remaining: economy?.remaining ?? 0,
                    weapon: (economy?.weapon ?? "").lowercased(),
                    armor: (economy?.armor ?? "").lowercased(),
                    hits: (stat.damage ?? []).map {
                        Hit(receiver: $0.receiver.lowercased(), damage: $0.damage ?? 0,
                            head: $0.headshots ?? 0, body: $0.bodyshots ?? 0, leg: $0.legshots ?? 0)
                    }
                )
            }
            let kills = stats.flatMap { $0.kills ?? [] }.map(Kill.init(raw:)).sorted { $0.time < $1.time }
            return Round(
                number: round.roundNum,
                winner: round.winningTeam ?? "",
                result: round.roundResultCode ?? "",
                winnerRole: round.winningTeamRole?.nilIfEmpty,
                ceremony: round.roundCeremony ?? "",
                planter: round.bombPlanter?.nilIfEmpty?.lowercased(),
                plantSite: round.plantSite?.nilIfEmpty,
                plantTime: round.bombPlanter?.nilIfEmpty == nil ? nil : round.plantRoundTime,
                defuser: round.bombDefuser?.nilIfEmpty?.lowercased(),
                defuseTime: round.bombDefuser?.nilIfEmpty == nil ? nil : round.defuseRoundTime,
                firstBlood: round.firstBloodPlayer?.nilIfEmpty?.lowercased() ?? kills.first?.killer,
                kills: kills,
                players: players
            )
        }
        return Match(
            id: info.matchId.lowercased(),
            queue: info.queueID ?? "",
            isCustom: info.provisioningFlowID == "CustomGame",
            mapURL: info.mapId,
            mode: info.gameMode ?? "",
            start: Date(timeIntervalSince1970: TimeInterval(info.gameStartMillis ?? 0) / 1000),
            length: TimeInterval(info.gameLengthMillis ?? 0) / 1000,
            season: (info.seasonId ?? "").lowercased(),
            isRanked: info.isRanked ?? false,
            completion: info.completionState ?? "",
            mvp: raw.matchMvp?.nilIfEmpty?.lowercased(),
            teams: (raw.teams ?? []).map {
                Team(id: $0.teamId, won: $0.won ?? false, roundsWon: $0.roundsWon ?? 0, points: $0.numPoints ?? 0)
            },
            players: raw.players.filter { !($0.isObserver ?? false) }.map {
                Player(
                    id: $0.subject.lowercased(),
                    name: $0.gameName ?? "",
                    tag: $0.tagLine ?? "",
                    team: $0.teamId ?? "",
                    agent: ($0.characterId ?? "").lowercased(),
                    tier: $0.competitiveTier ?? 0,
                    party: $0.partyId ?? "",
                    score: $0.stats?.score ?? 0,
                    kills: $0.stats?.kills ?? 0,
                    deaths: $0.stats?.deaths ?? 0,
                    assists: $0.stats?.assists ?? 0,
                    rounds: $0.stats?.roundsPlayed ?? 0
                )
            },
            rounds: rounds.sorted { $0.number < $1.number }
        )
    }
}

public enum MatchOutcome: Codable, Hashable, Sendable {
    case win, loss, draw
    /// Free-for-all modes, 1 = first.
    case placement(Int)

    public var isWin: Bool {
        switch self {
        case .win: true
        case let .placement(place): place == 1
        default: false
        }
    }
}

extension Match {
    /// Riot blanks `gameName`/`tagLine` in match details, so names come from name-service instead.
    public var unnamed: [String] { players.filter { $0.name.isEmpty }.map(\.id) }

    public func naming(_ names: [String: PlayerName]) -> Match {
        var copy = self
        for i in copy.players.indices {
            guard let found = names[copy.players[i].id], !found.name.isEmpty else { continue }
            copy.players[i].name = found.name
            copy.players[i].tag = found.tag
        }
        return copy
    }

    public func player(_ id: String) -> Player? {
        let id = id.lowercased()
        return players.first { $0.id == id }
    }

    /// Two sides playing rounds. Deathmatch and the like give every player their own team.
    public var hasSides: Bool { teams.count == 2 }

    public var hasRounds: Bool { hasSides && !rounds.isEmpty }

    public func team(_ id: String) -> Team? { teams.first { $0.id == id } }

    public func outcome(for puuid: String) -> MatchOutcome {
        guard let me = player(puuid) else { return .draw }
        if hasSides {
            guard let mine = team(me.team), let other = teams.first(where: { $0.id != me.team }) else { return .draw }
            if mine.won { return .win }
            if other.won { return .loss }
            return .draw
        }
        let ranking = players.sorted { ($0.kills, $0.score) > ($1.kills, $1.score) }
        return .placement((ranking.firstIndex { $0.id == me.id } ?? 0) + 1)
    }

    /// Rounds (or points) won by the player's side first.
    public func score(for puuid: String) -> (mine: Int, theirs: Int)? {
        guard hasSides, let me = player(puuid), let mine = team(me.team),
              let other = teams.first(where: { $0.id != me.team }) else { return nil }
        return (mine.roundsWon, other.roundsWon)
    }

    public func acs(_ player: Player) -> Int {
        player.rounds > 0 ? Int((Double(player.score) / Double(player.rounds)).rounded()) : 0
    }

    public func hits(by id: String) -> [Hit] {
        rounds.flatMap { round in round.players.filter { $0.id == id }.flatMap(\.hits) }
    }

    /// Nil when Riot sent no per-shot data for this mode.
    public func headshotPercent(_ player: Player) -> Int? {
        let hits = hits(by: player.id)
        let shots = hits.reduce(0) { $0 + $1.head + $1.body + $1.leg }
        guard shots > 0 else { return nil }
        return Int((Double(hits.reduce(0) { $0 + $1.head }) / Double(shots) * 100).rounded())
    }

    public func adr(_ player: Player) -> Int? {
        let hits = hits(by: player.id)
        guard !hits.isEmpty, player.rounds > 0 else { return nil }
        return Int((Double(hits.reduce(0) { $0 + $1.damage }) / Double(player.rounds)).rounded())
    }

    public func firstBloods(_ player: Player) -> Int {
        rounds.filter { $0.firstBlood == player.id }.count
    }

    /// Share of rounds with a kill, assist, survival or a death traded within five seconds.
    public func kast(_ player: Player) -> Int? {
        guard hasRounds else { return nil }
        let played = rounds.filter { round in round.players.contains { $0.id == player.id } }
        guard !played.isEmpty else { return nil }
        let team = player.team
        let counted = played.filter { round in
            if round.kills.contains(where: { $0.killer == player.id || $0.assistants.contains(player.id) }) { return true }
            guard let death = round.kills.first(where: { $0.victim == player.id }) else { return true }
            return round.kills.contains { kill in
                kill.victim == death.killer && kill.time >= death.time && kill.time - death.time <= 5000
                    && self.player(kill.killer)?.team == team
            }
        }
        return Int((Double(counted.count) / Double(played.count) * 100).rounded())
    }

    /// Kills on and deaths to each opponent, most kills first.
    public func duels(_ player: Player) -> [(opponent: Player, kills: Int, deaths: Int)] {
        let all = rounds.flatMap(\.kills)
        return players.filter { $0.id != player.id && (!hasSides || $0.team != player.team) }
            .map { other in
                (other,
                 all.filter { $0.killer == player.id && $0.victim == other.id }.count,
                 all.filter { $0.killer == other.id && $0.victim == player.id }.count)
            }
            .sorted { ($0.1, -$0.2) > ($1.1, -$1.2) }
    }
}

extension Match.Kill {
    init(raw: RawMatch.Kill) {
        let item = raw.finishingDamage?.damageItem ?? ""
        self.init(
            time: raw.roundTime ?? 0,
            killer: (raw.killer ?? "").lowercased(),
            victim: (raw.victim ?? "").lowercased(),
            assistants: (raw.assistants ?? []).map { $0.lowercased() },
            item: item.count == 36 ? item.lowercased() : item,
            kind: raw.finishingDamage?.damageType ?? ""
        )
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct RawMatch: Decodable {
    struct Info: Decodable {
        let matchId: String
        let mapId: String
        let gameMode: String?
        let queueID: String?
        let provisioningFlowID: String?
        let gameStartMillis: Int?
        let gameLengthMillis: Int?
        let seasonId: String?
        let isRanked: Bool?
        let completionState: String?
    }

    struct Stats: Decodable {
        let score: Int?
        let roundsPlayed: Int?
        let kills: Int?
        let deaths: Int?
        let assists: Int?
    }

    struct Player: Decodable {
        let subject: String
        let gameName: String?
        let tagLine: String?
        let teamId: String?
        let partyId: String?
        let characterId: String?
        let competitiveTier: Int?
        let isObserver: Bool?
        let stats: Stats?
    }

    struct Team: Decodable {
        let teamId: String
        let won: Bool?
        let roundsWon: Int?
        let numPoints: Int?
    }

    struct Damage: Decodable {
        let receiver: String
        let damage: Int?
        let headshots: Int?
        let bodyshots: Int?
        let legshots: Int?
    }

    struct Kill: Decodable {
        struct Finishing: Decodable {
            let damageType: String?
            let damageItem: String?
        }

        let roundTime: Int?
        let killer: String?
        let victim: String?
        let assistants: [String]?
        let finishingDamage: Finishing?
    }

    struct Economy: Decodable {
        let subject: String?
        let loadoutValue: Int?
        let weapon: String?
        let armor: String?
        let remaining: Int?
        let spent: Int?
    }

    struct PlayerStat: Decodable {
        let subject: String
        let kills: [Kill]?
        let damage: [Damage]?
        let score: Int?
        let economy: Economy?
    }

    struct Round: Decodable {
        let roundNum: Int
        let roundResultCode: String?
        let roundCeremony: String?
        let winningTeam: String?
        let winningTeamRole: String?
        let bombPlanter: String?
        let bombDefuser: String?
        let plantRoundTime: Int?
        let plantSite: String?
        let defuseRoundTime: Int?
        let firstBloodPlayer: String?
        let playerStats: [PlayerStat]?
        let playerEconomies: [Economy]?
    }

    let matchInfo: Info
    let players: [Player]
    let teams: [Team]?
    let roundResults: [Round]?
    let matchMvp: String?
}
