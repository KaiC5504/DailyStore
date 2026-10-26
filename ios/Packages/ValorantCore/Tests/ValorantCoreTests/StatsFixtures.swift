import Foundation
@testable import ValorantCore

/// A hand-built 2v2 in Match's own shape, small enough to work every stat out by hand.
/// Blue (me, mate) attacks all four rounds.
enum StatsFixtures {
    static let me = "me", mate = "mate", e1 = "e1", e2 = "e2"
    static let jett = "add6443a-41bd-e414-f6ad-e58d267f4e95", sova = "320b2a48-4d9b-a075-30f1-1f93a9b638fa"
    static let ghost = "1baa85b4-4c70-1284-64bb-6481dfc3bb4e", vandal = "9c82e19d-4575-0200-1a81-3eacf00cf872"
    static let classic = "29a0cfab-485b-f5d5-779a-b59f85e204a8"
    static let ascent = "/Game/Maps/Ascent/Ascent", haven = "/Game/Maps/Triad/Triad"

    static func match(id: String = "stats-1", map: String = ascent, agent: String = jett, won: Bool = true,
                      queue: String = "competitive", isCustom: Bool = false, season: String = "act-5",
                      hits withHits: Bool = true, start: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> Match {
        func rp(_ id: String, _ loadout: Int, _ weapon: String, _ hits: [Match.Hit] = []) -> Match.RoundPlayer {
            Match.RoundPlayer(id: id, score: 0, loadout: loadout, spent: loadout, remaining: 0, weapon: weapon, armor: "",
                              hits: withHits ? hits : [])
        }
        func k(_ killer: String, _ victim: String, _ t: Int, _ item: String = vandal, _ kind: String = "Weapon") -> Match.Kill {
            Match.Kill(time: t, killer: killer, victim: victim, assistants: [], item: item, kind: kind)
        }
        func h(_ to: String, _ damage: Int, _ head: Int, _ body: Int, _ leg: Int) -> Match.Hit {
            Match.Hit(receiver: to, damage: damage, head: head, body: body, leg: leg)
        }
        let rounds = [
            Match.Round(number: 0, winner: "Blue", result: "Elimination", winnerRole: "Attacker", ceremony: "CeremonyFlawless",
                        planter: me, plantSite: "A", plantTime: 20000, defuser: nil, defuseTime: nil, firstBlood: me,
                        kills: [k(me, e1, 10000, ghost), k(me, e2, 15000, ghost)],
                        players: [rp(me, 800, ghost, [h(e1, 150, 1, 2, 0), h(e2, 150, 0, 3, 1)]), rp(mate, 800, classic),
                                  rp(e1, 800, classic), rp(e2, 800, classic)]),
            Match.Round(number: 1, winner: "Red", result: "Elimination", winnerRole: "Defender", ceremony: "CeremonyDefault",
                        planter: nil, plantSite: nil, plantTime: nil, defuser: nil, defuseTime: nil, firstBlood: e1,
                        kills: [k(e1, me, 5000), k(mate, e1, 11000), k(e2, mate, 20000)],
                        players: [rp(me, 1000, classic), rp(mate, 1000, classic, [h(e1, 150, 1, 1, 0)]),
                                  rp(e1, 3900, vandal, [h(me, 162, 1, 1, 0)]), rp(e2, 3900, vandal, [h(mate, 150, 1, 1, 0)])]),
            Match.Round(number: 2, winner: "Blue", result: "Elimination", winnerRole: "Attacker", ceremony: "CeremonyClutch",
                        planter: me, plantSite: "B", plantTime: 25000, defuser: nil, defuseTime: nil, firstBlood: e1,
                        kills: [k(e1, mate, 4000), k(me, e1, 9000), k(me, e2, 30000)],
                        players: [rp(me, 3900, vandal, [h(e1, 150, 2, 0, 0), h(e2, 150, 1, 1, 0)]), rp(mate, 3900, vandal),
                                  rp(e1, 2500, vandal, [h(mate, 150, 1, 1, 0)]), rp(e2, 2500, vandal)]),
            Match.Round(number: 3, winner: "Red", result: "Defuse", winnerRole: "Defender", ceremony: "CeremonyDefault",
                        planter: mate, plantSite: "A", plantTime: 40000, defuser: e2, defuseTime: 80000, firstBlood: me,
                        kills: [k(me, e1, 10000, "Ultimate", "Ability"), k(e2, me, 50000), k(e2, mate, 60000)],
                        players: [rp(me, 2400, vandal, [h(e1, 100, 0, 1, 0)]), rp(mate, 2400, vandal),
                                  rp(e1, 1500, classic), rp(e2, 1500, classic, [h(me, 150, 0, 2, 0), h(mate, 150, 1, 1, 0)])]),
        ]
        func p(_ id: String, _ team: String, _ agent: String, _ k: Int, _ d: Int, _ ps: Int) -> Match.Player {
            Match.Player(id: id, name: id, tag: "", team: team, agent: agent, tier: 18, party: "", score: 0,
                         kills: k, deaths: d, assists: 0, rounds: 4, performance: ps)
        }
        return Match(id: id, queue: queue, isCustom: isCustom, mapURL: map, mode: "", start: start, length: 1800, season: season,
                     isRanked: queue == "competitive", completion: "Completed", mvp: me,
                     teams: [Match.Team(id: "Blue", won: won, roundsWon: 2, points: 2),
                             Match.Team(id: "Red", won: !won, roundsWon: 2, points: 2)],
                     players: [p(me, "Blue", agent, 5, 2, 300), p(mate, "Blue", sova, 1, 3, 180),
                               p(e1, "Red", sova, 1, 4, 150), p(e2, "Red", jett, 3, 2, 260)],
                     rounds: rounds)
    }

    /// The same game as Riot sends it after a surrender, with the owner's own ultimate also killing them
    /// once round 3 is already won. Riot lists both; neither should change a stat.
    static func surrendered() -> Match {
        let base = match()
        var rounds = base.rounds
        let r = rounds[2]
        rounds[2] = Match.Round(number: r.number, winner: r.winner, result: r.result, winnerRole: r.winnerRole,
                                ceremony: r.ceremony, planter: r.planter, plantSite: r.plantSite, plantTime: r.plantTime,
                                defuser: nil, defuseTime: nil, firstBlood: r.firstBlood,
                                kills: r.kills + [Match.Kill(time: 70000, killer: me, victim: me, assistants: [],
                                                             item: "Ultimate", kind: "Ability")],
                                players: r.players)
        rounds.append(Match.Round(number: 4, winner: "Blue", result: "Surrendered", winnerRole: "Attacker", ceremony: "",
                                  planter: nil, plantSite: nil, plantTime: nil, defuser: nil, defuseTime: nil,
                                  firstBlood: nil, kills: [],
                                  players: [me, mate, e1, e2].map {
                                      Match.RoundPlayer(id: $0, score: 0, loadout: 0, spent: 0, remaining: 0, weapon: "",
                                                        armor: "", hits: [])
                                  }))
        return Match(id: base.id, queue: base.queue, isCustom: false, mapURL: base.mapURL, mode: "", start: base.start,
                     length: base.length, season: base.season, isRanked: true, completion: "Surrendered", mvp: me,
                     teams: base.teams, players: base.players, rounds: rounds)
    }

    static func deathmatch() -> Match {
        Match(id: "stats-dm", queue: "deathmatch", isCustom: false, mapURL: ascent, mode: "", start: Date(), length: 540,
              season: "act-5", isRanked: false, completion: "Completed", mvp: nil, teams: [],
              players: [Match.Player(id: me, name: me, tag: "", team: me, agent: jett, tier: 0, party: "", score: 3000,
                                     kills: 30, deaths: 10, assists: 0, rounds: 0)],
              rounds: [])
    }
}
