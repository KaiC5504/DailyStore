import Foundation

public enum Side: String, Codable, Sendable {
    case attack, defense
}

public enum Buy: String, Codable, Sendable, CaseIterable {
    case pistol, eco, force, full
}

/// A round worth calling out on the match page.
public struct Moment: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case ace, quad, triple, ecoWin, defuse
        /// Won while last alive against this many.
        case clutch(Int)
    }

    /// `Round.number`, so 0 is the first round.
    public let round: Int
    public let kind: Kind

    public init(round: Int, kind: Kind) {
        self.round = round
        self.kind = kind
    }
}

extension Match {
    /// Where sides swap; Riot doesn't say, so it follows each mode's rules.
    public var halftime: Int {
        switch queue {
        case "swiftplay": 4
        case "spikerush": 3
        default: 12
        }
    }

    /// Overtime rounds start on full money, so only the first round of each half counts.
    public func isPistol(_ round: Round) -> Bool {
        round.number == 0 || round.number == halftime
    }

    /// Riot names the winners' role; without it, whoever planted was attacking.
    public func side(of team: String, in round: Round) -> Side? {
        if let role = round.winnerRole {
            return (round.winner == team) == (role == "Attacker") ? .attack : .defense
        }
        guard let planter = round.planter, let planting = player(planter)?.team else { return nil }
        return planting == team ? .attack : .defense
    }

    /// Average loadout value of the team at the start of the round; nil in modes without an economy.
    public func teamLoadout(_ team: String, in round: Round) -> Int? {
        let loadouts = round.players.filter { player($0.id)?.team == team }.map(\.loadout)
        guard loadouts.contains(where: { $0 > 0 }) else { return nil }
        return loadouts.reduce(0, +) / loadouts.count
    }

    /// Nil in modes without buying, Spike Rush included, so their rounds never count as pistols.
    public func buy(of team: String, in round: Round) -> Buy? {
        guard let loadout = teamLoadout(team, in: round) else { return nil }
        if isPistol(round) { return .pistol }
        return loadout < 2000 ? .eco : loadout < 3900 ? .force : .full
    }

    /// Enemies still alive when `id` became the last one standing on their team, nil if that never happened.
    public func clutch(for id: String, in round: Round) -> Int? {
        guard let team = player(id)?.team else { return nil }
        let everyone = round.players.map(\.id)
        var mine = Set(everyone.filter { player($0)?.team == team })
        var theirs = Set(everyone).subtracting(mine)
        guard mine.count >= 2, mine.contains(id) else { return nil }
        for kill in round.kills {
            mine.remove(kill.victim)
            theirs.remove(kill.victim)
            guard mine.contains(id) else { return nil }
            if mine.count == 1, !theirs.isEmpty { return theirs.count }
        }
        return nil
    }

    /// Riot also lists you as the killer when your own ultimate or the spike kills you or a teammate.
    public func enemyKills(by id: String, in round: Round) -> [Kill] {
        let team = player(id)?.team
        return round.kills.filter { $0.killer == id && $0.victim != id && player($0.victim)?.team != team }
    }

    public func kills(by id: String, in round: Round) -> Int {
        enemyKills(by: id, in: round).count
    }

    /// The round's opening duel. Riot's own first blood also names teamkills and falls.
    public func firstKill(in round: Round) -> Kill? {
        round.kills.first { kill in
            guard kill.killer != kill.victim, let killer = player(kill.killer) else { return false }
            return killer.team != player(kill.victim)?.team
        }
    }

    public func firstDeaths(_ player: Player) -> Int {
        playedRounds.filter { firstKill(in: $0)?.victim == player.id }.count
    }

    public func damageTaken(_ player: Player) -> Int {
        rounds.flatMap(\.players).filter { $0.id != player.id }.flatMap(\.hits)
            .filter { $0.receiver == player.id }
            .reduce(0) { $0 + $1.damage }
    }

    /// Damage dealt minus damage taken, per round.
    public func ddDelta(_ player: Player) -> Int? {
        let hits = hits(by: player.id)
        guard !hits.isEmpty, player.rounds > 0 else { return nil }
        let delta = hits.reduce(0) { $0 + $1.damage } - damageTaken(player)
        return Int((Double(delta) / Double(player.rounds)).rounded())
    }

    /// Rounds with two kills or more.
    public func multiKillRounds(_ player: Player) -> Int {
        playedRounds.filter { kills(by: player.id, in: $0) >= 2 }.count
    }

    /// Damage per 1,000 credits spent.
    public func econRating(_ player: Player) -> Int? {
        let hits = hits(by: player.id)
        let spent = rounds.flatMap(\.players).filter { $0.id == player.id }.reduce(0) { $0 + $1.spent }
        guard !hits.isEmpty, spent > 0 else { return nil }
        return Int((Double(hits.reduce(0) { $0 + $1.damage }) * 1000 / Double(spent)).rounded())
    }

    public func moments(for id: String) -> [Moment] {
        guard hasRounds, let team = player(id)?.team else { return [] }
        return playedRounds.flatMap { round -> [Moment] in
            var kinds: [Moment.Kind] = []
            switch kills(by: id, in: round) {
            case 5...: kinds.append(.ace)
            case 4: kinds.append(.quad)
            case 3: kinds.append(.triple)
            default: break
            }
            if round.winner == team {
                if let enemies = clutch(for: id, in: round) { kinds.append(.clutch(enemies)) }
                if buy(of: team, in: round) == .eco { kinds.append(.ecoWin) }
            }
            if round.defuser == id { kinds.append(.defuse) }
            return kinds.map { Moment(round: round.number, kind: $0) }
        }
    }
}
