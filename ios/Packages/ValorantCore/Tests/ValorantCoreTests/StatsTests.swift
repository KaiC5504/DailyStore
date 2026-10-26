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
