import Foundation
import Testing
@testable import ValorantCore

@Suite struct MatchAnalysisTests {
    typealias F = StatsFixtures
    let match = F.match()
    var me: Match.Player { match.player(F.me)! }

    @Test func sidesComeFromTheWinnerRole() {
        #expect(match.rounds.map { match.side(of: "Blue", in: $0) } == [.attack, .attack, .attack, .attack])
        #expect(match.side(of: "Red", in: match.rounds[0]) == .defense)
    }

    @Test func roundWithoutRoleOrPlantHasNoSide() {
        let r = match.rounds[1]
        let blind = Match.Round(number: 1, winner: r.winner, result: "", winnerRole: nil, ceremony: "", planter: nil,
                                plantSite: nil, plantTime: nil, defuser: nil, defuseTime: nil, firstBlood: nil,
                                kills: r.kills, players: r.players)
        #expect(match.side(of: "Blue", in: blind) == nil)
    }

    @Test func pistolsAreTheFirstRoundOfEachHalfOnly() {
        #expect(match.halftime == 12)
        #expect(match.rounds.map(match.isPistol) == [true, false, false, false])
        #expect(F.match(queue: "swiftplay").halftime == 4)
    }

    @Test func buysFollowTheTeamAverageLoadout() {
        #expect(match.rounds.map { match.buy(of: "Blue", in: $0) } == [.pistol, .eco, .full, .force])
        #expect(match.teamLoadout("Red", in: match.rounds[2]) == 2500)
    }

    @Test func clutchStartsWhenTheTeamIsDownToYou() {
        #expect(match.rounds.map { match.clutch(for: F.me, in: $0) } == [nil, nil, 2, nil])
    }

    @Test func perPlayerReads() {
        #expect(match.firstDeaths(me) == 1)
        #expect(match.damageTaken(me) == 312)
        #expect(match.ddDelta(me) == 97)
        #expect(match.multiKillRounds(me) == 2)
        #expect(match.econRating(me) == 86)
        let kast = match.kastRounds(me)
        #expect(kast?.counted == 3 && kast?.played == 4)
        #expect(match.kast(me) == 75)
    }

    @Test func momentsListClutchesAndBigRounds() {
        #expect(match.moments(for: F.me) == [Moment(round: 2, kind: .clutch(2))])
    }
}

@Suite struct MatchDigestTests {
    typealias F = StatsFixtures
    let digest = MatchDigest(match: F.match(), puuid: F.me)

    @Test func totalsForTheOwner() {
        #expect(digest.kills == 5 && digest.deaths == 2 && digest.rounds == 4 && digest.performance == 300)
        #expect(digest.damage == 700 && digest.damageTaken == 312 && digest.adr == 175)
        #expect(digest.shots == Shots(head: 4, body: 7, leg: 1))
        #expect(digest.firstKills == 2 && digest.firstDeaths == 1 && digest.kast == 3)
        #expect(digest.multiKills == [2, 0, 0, 0])
        #expect(digest.clutches == [Tally(), Tally(played: 1, won: 1), Tally(), Tally(), Tally()])
        #expect(digest.plants == 2 && digest.defuses == 0 && digest.flawless == 1)
        #expect(digest.spent == 8100)
        #expect(digest.teamPlace == 1 && digest.isMVP && digest.startSide == .attack)
    }

    @Test func roundRecords() {
        #expect(digest.attack == Tally(played: 4, won: 2) && digest.defense == Tally())
        #expect(digest.pistol == Tally(played: 1, won: 1))
        #expect(digest.eco == Tally(played: 1, won: 0) && digest.force == Tally(played: 1, won: 0)
                && digest.full == Tally(played: 1, won: 1))
        #expect(digest.withFirstKill == Tally(played: 2, won: 1) && digest.withFirstDeath == Tally(played: 1, won: 0))
    }

    @Test func gunsAndSites() {
        #expect(digest.guns[F.ghost]?.kills == 2 && digest.guns[F.ghost]?.shots == Shots(head: 1, body: 5, leg: 1))
        #expect(digest.guns[F.vandal]?.kills == 2 && digest.guns[F.vandal]?.shots == Shots(head: 3, body: 2, leg: 0))
        #expect(digest.guns["ability"]?.kills == 1)
        #expect(digest.guns[F.classic] == nil)
        #expect(digest.sites["A"]?.postPlant == Tally(played: 2, won: 1) && digest.sites["B"]?.postPlant == Tally(played: 1, won: 1))
        #expect(digest.sites.values.allSatisfy { $0.retake == Tally() })
    }

    @Test func deathmatchKeepsOnlyTheBasics() {
        let dm = MatchDigest(match: F.deathmatch(), puuid: F.me)
        #expect(!dm.hasRounds && dm.kills == 30 && dm.rounds == 0 && dm.adr == nil && dm.teamPlace == nil)
    }

    @Test func digestsRoundTrip() throws {
        let data = try JSONEncoder().encode(digest)
        #expect(try JSONDecoder().decode(MatchDigest.self, from: data) == digest)
    }
}

@Suite struct CareerStatsTests {
    typealias F = StatsFixtures
    func d(_ m: Match) -> MatchDigest { MatchDigest(match: m, puuid: F.me) }

    @Test func totalsFromOneGame() {
        let c = CareerStats([d(F.match())])
        #expect(c.games == 1 && c.wins == 1 && c.winRate == 100 && c.kd == 2.5)
        #expect(c.adr == 175 && c.kast == 75 && c.ddDelta == 97 && c.econRating == 86 && c.performance == 300)
        #expect(c.clutch == Tally(played: 1, won: 1) && c.flawless == 1 && c.plants == 2)
        #expect(c.startAttack == Tally(played: 1, won: 1) && c.playtime == 1800)
    }

    @Test func careerOfNothingHasNoNumbers() {
        let c = CareerStats([d(F.match(isCustom: true)), d(F.deathmatch())])
        #expect(c.games == 0 && c.winRate == nil && c.adr == nil && c.kast == nil && c.performance == nil)
        #expect(c.shots.percent(\.head) == nil && c.playstyle == .zero && c.agents.isEmpty)
    }

    @Test func gamesWithoutHitsLeaveHeadshotsAndAdrBlank() {
        let c = CareerStats([d(F.match(hits: false))])
        #expect(c.games == 1 && c.adr == nil && c.shots.percent(\.head) == nil && c.ddDelta == nil)
        let mixed = CareerStats([d(F.match(hits: false)), d(F.match(id: "stats-2"))])
        #expect(mixed.adr == 175)
    }

    @Test func agentsMapsAndGunsAreGroupedAndSorted() {
        let c = CareerStats([d(F.match()), d(F.match(id: "s2", map: F.haven, won: false)),
                             d(F.match(id: "s3", agent: F.sova))])
        #expect(c.agents.map(\.key) == [F.jett, F.sova] && c.agents[0].games == 2 && c.agents[0].wins == 1)
        #expect(c.maps.map(\.key) == [F.ascent, F.haven] && c.maps[0].winRate == 100)
        #expect(c.guns.map(\.kills) == [6, 6, 3] && c.guns.last?.key == "ability")
    }

    @Test func playstyleUsesFixedScales() {
        let p = CareerStats([d(F.match())]).playstyle
        #expect(abs(p.aim - 33.333 / 40) < 0.001 && p.entry == 1 && abs(p.damage - 175.0 / 220) < 0.001)
        #expect(abs(p.consistency - 0.7) < 0.001 && p.clutch == 1 && abs(p.economy - 86.0 / 120) < 0.001)
    }

    @Test func scopeFiltersActAndQueue() {
        let comp = d(F.match())
        #expect(StatsScope().includes(comp, currentAct: "act-5"))
        #expect(!StatsScope().includes(comp, currentAct: "act-6"))
        #expect(StatsScope().includes(comp, currentAct: nil))
        #expect(StatsScope(act: .all, queue: "competitive").includes(comp, currentAct: "act-6"))
        #expect(!StatsScope(act: .all, queue: "unrated").includes(comp, currentAct: nil))
        #expect(StatsScope(act: .all, queue: "custom").includes(d(F.match(queue: "", isCustom: true)), currentAct: nil))
        #expect(!StatsScope(act: .all, queue: "custom").includes(comp, currentAct: nil))
    }
}
