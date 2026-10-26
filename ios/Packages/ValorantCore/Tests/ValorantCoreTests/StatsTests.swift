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
