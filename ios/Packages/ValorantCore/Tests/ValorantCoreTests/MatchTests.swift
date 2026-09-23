import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ValorantCore

@Suite struct MatchParsingTests {
    typealias F = MatchFixtures

    private func competitive() throws -> Match { try Match.parse(Data(F.competitive.utf8)) }

    @Test func competitiveMatchIsTrimmedAndLowercased() throws {
        let match = try competitive()
        #expect(match.id == "match-comp-1")
        #expect(match.queue == "competitive")
        #expect(!match.isCustom)
        #expect(match.season == "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b")
        #expect(match.length == 2280)
        #expect(match.players.count == 4)
        #expect(match.player(F.me)?.agent == F.jett.lowercased())
        #expect(match.player(F.me)?.displayName == "Player11#111")
        #expect(match.mvp == F.me)
        #expect(match.rounds.map(\.result) == ["Elimination", "Detonate", "Defuse"])
    }

    @Test func roundsKeepPlantsDefusesAndEconomy() throws {
        let rounds = try competitive().rounds
        #expect(rounds[0].plantSite == nil && rounds[0].plantTime == nil)
        #expect(rounds[1].planter == F.enemy1 && rounds[1].plantSite == "A" && rounds[1].plantTime == 60000)
        #expect(rounds[1].winnerRole == "Attacker")
        #expect(rounds[2].defuser == F.me && rounds[2].defuseTime == 90000)
        let mine = try #require(rounds[0].players.first { $0.id == F.me })
        #expect(mine.loadout == 3900 && mine.weapon == F.vandal.lowercased() && mine.armor == F.heavyArmor.lowercased())
        #expect(rounds[2].kills.first?.item == "Ultimate")
        #expect(rounds[0].kills.first?.item == F.vandal.lowercased())
        #expect(rounds[1].kills.map(\.time) == [5000, 8000, 30000])
    }

    @Test func derivedStatsForTheOwner() throws {
        let match = try competitive()
        let me = try #require(match.player(F.me))
        #expect(match.outcome(for: F.me) == .win)
        #expect(match.score(for: F.me)! == (2, 1))
        #expect(match.acs(me) == 200)
        #expect(match.headshotPercent(me) == 14)
        #expect(match.adr(me) == 100)
        #expect(match.firstBloods(me) == 2)
        #expect(match.kast(me) == 100)
        let duels = match.duels(me)
        #expect(duels.map(\.opponent.id) == [F.enemy1, F.enemy2])
        #expect(duels[0].kills == 2 && duels[0].deaths == 1)
    }

    @Test func kastCountsTradesButNotUntradedDeaths() throws {
        let match = try competitive()
        #expect(match.kast(match.player(F.enemy2)!) == 67)
        #expect(match.kast(match.player(F.enemy1)!) == 33)
        #expect(match.outcome(for: F.enemy1) == .loss)
        #expect(match.headshotPercent(match.player(F.enemy1)!) == nil)
    }

    @Test func customGameUsesThePerPlayerEconomy() throws {
        let match = try Match.parse(Data(F.custom.utf8))
        #expect(match.isCustom && match.queue.isEmpty)
        #expect(match.rounds[0].players.first?.weapon == "")
        #expect(match.rounds[0].kills.first?.item == "5f0aaf7a-4289-3998-d5ff-eb9a5cf7ef5c")
        #expect(match.mvp == nil)
    }

    @Test func deathmatchIsRankedByKills() throws {
        let match = try Match.parse(Data(F.deathmatch.utf8))
        #expect(!match.hasSides && !match.hasRounds)
        #expect(match.outcome(for: F.me) == .placement(2))
        #expect(match.outcome(for: F.enemy1).isWin)
        #expect(match.score(for: F.me) == nil)
        #expect(match.kast(match.player(F.me)!) == nil)
        #expect(match.duels(match.player(F.me)!).count == 2)
    }

    @Test func archivedMatchesRoundTrip() throws {
        let match = try competitive()
        let decoded = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(match))
        #expect(decoded == match)
    }

    @Test func statsSkipCustomGames() throws {
        let summaries = try [F.competitive, F.custom, F.deathmatch].map {
            MatchSummary(match: try Match.parse(Data($0.utf8)), puuid: F.me)
        }
        let stats = MatchStats(summaries)
        #expect(stats.form == [.win, .placement(2)])
        #expect(stats.agents.first?.key == F.jett.lowercased())
        #expect(stats.agents.first?.games == 2 && stats.agents.first?.winRate == 50)
        #expect(stats.maps.map(\.key) == ["/Game/Maps/Ascent/Ascent"])
        #expect(stats.recent.kills == 28)
    }
}

@Suite struct RankParsingTests {
    typealias F = MatchFixtures

    @Test func currentActIsNamedWithItsEpisode() throws {
        let act = try #require(try CurrentAct.parse(content: Data(F.content.utf8)))
        #expect(act == CurrentAct(id: "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b", name: "V26 · ACT V"))
    }

    @Test func rankComesFromTheActiveAct() throws {
        let act = CurrentAct(id: "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b", name: "ACT V")
        let rank = try RankStatus.parse(mmr: Data(F.mmr.utf8), act: act)
        #expect(rank.tier == 18 && rank.rr == 12 && rank.wins == 14 && rank.games == 25 && rank.act == "ACT V")
    }

    @Test func noGamesThisActIsUnranked() throws {
        let rank = try RankStatus.parse(mmr: Data(F.mmr.utf8), act: CurrentAct(id: "new-act", name: "ACT VI"))
        #expect(rank.tier == 0 && !rank.isRanked && rank.act == "ACT VI")
    }

    @Test func unknownActFallsBackToTheLatestUpdate() throws {
        let rank = try RankStatus.parse(mmr: Data(F.mmr.utf8), act: nil)
        #expect(rank.tier == 18 && rank.rr == 12)
    }

    @Test func competitiveUpdatesParse() throws {
        let update = try #require(try CompetitiveUpdate.parse(Data(F.updates.utf8)).first)
        #expect(update.id == "match-comp-1" && update.rrEarned == 24 && update.ladder == 1812)
    }
}

@Suite struct MatchArchiveTests {
    typealias F = MatchFixtures

    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString)")
    }

    @Test func savesNewestFirstWithoutDuplicates() async throws {
        let archive = MatchArchive(directory: directory())
        let older = try Match.parse(Data(F.deathmatch.utf8))
        let newer = try Match.parse(Data(F.competitive.utf8))
        await archive.save(older, puuid: F.me)
        await archive.save(newer, puuid: F.me)
        await archive.save(newer, puuid: F.me)
        #expect(await archive.summaries().map(\.id) == ["match-comp-1", "match-dm-1"])
        #expect(await archive.contains("MATCH-COMP-1"))
        #expect(await archive.match("match-comp-1") == newer)
    }

    @Test func rrFillsInExistingRowsAndPersists() async throws {
        let url = directory()
        let archive = MatchArchive(directory: url)
        await archive.save(try Match.parse(Data(F.competitive.utf8)), puuid: F.me)
        #expect(await archive.summaries().first?.rrEarned == nil)

        #expect(await archive.merge(try CompetitiveUpdate.parse(Data(F.updates.utf8))))
        #expect(await archive.merge(try CompetitiveUpdate.parse(Data(F.updates.utf8))) == false)
        await archive.save(rank: RankStatus(tier: 18, rr: 12, act: nil, wins: 1, games: 2, fetchedAt: Date(timeIntervalSince1970: 0)))

        let reopened = MatchArchive(directory: url)
        #expect(await reopened.summaries().first?.rrEarned == 24)
        #expect(await reopened.summaries().first?.tierAfter == 18)
        #expect(await reopened.rrUpdates().count == 1)
        #expect(await reopened.rank()?.tier == 18)
    }
}

@Suite struct MatchSyncTests {
    typealias F = MatchFixtures

    private func service(_ http: MockHTTP) -> StoreService {
        StoreService(http: http, sessions: MemorySessions(F.session), retryBase: 0)
    }

    private func archive() -> MatchArchive {
        MatchArchive(directory: FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)"))
    }

    @Test func firstSyncDownloadsEachListedMatch() async throws {
        let http = F.riot()
        http.on(F.historyRoute(0), json: F.history(["MATCH-COMP-1", "gone", "match-b"], total: 45))
        http.on("/match-details/v1/matches/match-comp-1", json: F.details(id: "match-comp-1"))
        http.on("/match-details/v1/matches/gone", status: 404, json: "{}")
        http.on("/match-details/v1/matches/match-b", json: F.details(id: "match-b", start: 1789000000000))
        let archive = archive()
        let events = EventLog()

        let result = try await service(http).syncMatches(into: archive) { await events.add($0) }

        #expect(result.added == 2 && result.failed == 0 && result.next == 20)
        #expect(result.rank?.tier == 18 && result.rank?.act == "V26 · ACT V")
        #expect(await archive.summaries().map(\.id) == ["match-comp-1", "match-b"])
        #expect(await archive.summaries().first?.rrEarned == 24)
        #expect(await events.pending == ["match-comp-1", "gone", "match-b"])
        #expect(await events.unavailable == ["gone"])
        #expect(http.requests(to: "/match-history/").first?.value(forHTTPHeaderField: "X-Riot-Entitlements-JWT") == "ENT")
    }

    @Test func secondSyncOnlyFetchesNewMatches() async throws {
        let http = F.riot()
        http.on(F.historyRoute(0), json: F.history(["match-comp-1"], total: 1))
        http.on("/match-details/", json: F.details(id: "match-comp-1"))
        let archive = archive()
        let service = service(http)
        _ = try await service.syncMatches(into: archive) { _ in }
        let second = try await service.syncMatches(into: archive) { _ in }

        #expect(second.added == 0 && second.next == nil)
        #expect(http.requests(to: "/match-details/").count == 1)
        #expect(http.requests(to: "auth.riotgames.com/authorize").count == 1)
    }

    @Test func rateLimitIsRetriedAndOneBadMatchDoesNotStopTheRest() async throws {
        let http = F.riot()
        http.on(F.historyRoute(0), json: F.history(["m-limited", "m-broken", "m-fine"], total: 3))
        let limited = Counter()
        http.on("/match-details/v1/matches/m-limited") { _ in
            limited.next() == 1 ? HTTPResponse(status: 429) : HTTPResponse(status: 200, body: Data(F.details(id: "m-limited").utf8))
        }
        http.on("/match-details/v1/matches/m-broken", status: 500, json: "{}")
        http.on("/match-details/v1/matches/m-fine", json: F.details(id: "m-fine", start: 1789000000000))

        let result = try await service(http).syncMatches(into: archive()) { _ in }

        #expect(result.added == 2 && result.failed == 1)
        #expect(http.requests(to: "m-limited").count == 2)
        #expect(http.requests(to: "m-broken").count == 3)
    }

    @Test func olderMatchesSkipPagesAlreadyArchived() async throws {
        let http = F.riot()
        http.on(F.historyRoute(20), json: F.history(["match-comp-1"], start: 20, total: 45))
        http.on(F.historyRoute(40), json: F.history(["match-old"], start: 40, total: 45))
        http.on("/match-details/v1/matches/match-old", json: F.details(id: "match-old", start: 1780000000000))
        let archive = archive()
        await archive.save(try Match.parse(Data(F.competitive.utf8)), puuid: F.me)

        let result = try await service(http).olderMatches(from: 20, into: archive) { _ in }

        #expect(result.added == 1 && result.next == nil)
        #expect(await archive.summaries().map(\.id) == ["match-comp-1", "match-old"])
        #expect(http.requests(to: "/match-details/").count == 1)
    }

    @Test func historyPagesStopAtRiotsTotal() {
        #expect(HistoryPage(entries: [], start: 0, total: 45).next == 20)
        #expect(HistoryPage(entries: [], start: 40, total: 45).next == nil)
        #expect(HistoryPage(entries: [], start: 0, total: 20).next == nil)
    }
}

@Suite struct MatchAssetsTests {
    @Test func assetsAreKeyedTheWayMatchesReferToThem() throws {
        let maps = #"{"data": [{"displayName": "Ascent", "mapUrl": "/Game/Maps/Ascent/Ascent", "splash": "https://x/s.png", "listViewIcon": "https://x/l.png"},{"displayName": "The Range", "mapUrl": null}]}"#
        let agents = #"{"data": [{"uuid": "ADD6443A-41BD-E414-F6AD-E58D267F4E95", "displayName": "Jett", "displayIcon": "https://x/j.png", "fullPortrait": null, "killfeedPortrait": null, "backgroundGradientColors": ["aabbccff"], "role": {"displayName": "Duelist"}, "abilities": [{"slot": "Grenade", "displayIcon": "https://x/g.png"}, {"slot": "Ultimate", "displayIcon": "https://x/u.png"}, {"slot": "Passive", "displayIcon": null}]}]}"#
        let tiers = #"{"data": [{"tiers": [{"tier": 18, "tierName": "OLD", "color": null}]}, {"tiers": [{"tier": 18, "tierName": "DIAMOND 1", "color": "b489c4ff", "smallIcon": "https://x/s.png", "largeIcon": "https://x/l.png"}]}]}"#
        let weapons = #"{"data": [{"uuid": "9C82E19D-4575-0200-1A81-3EACF00CF872", "displayName": "Vandal", "displayIcon": "https://x/v.png", "killStreamIcon": "https://x/k.png"}]}"#
        let gear = #"{"data": [{"uuid": "822bcab2-40a2-324e-c137-e09195ad7692", "displayName": "Heavy Armor"}]}"#
        let queues = #"{"data": [{"queueId": "competitive", "displayName": "Competitive"}, {"queueId": "hurm", "displayName": "Team Deathmatch"}]}"#

        let assets = try MatchAssets.parse(clientVersion: "v", maps: Data(maps.utf8), agents: Data(agents.utf8), tiers: Data(tiers.utf8),
                                           weapons: Data(weapons.utf8), gear: Data(gear.utf8), queues: Data(queues.utf8))

        #expect(assets.map("/Game/Maps/Ascent/Ascent")?.name == "Ascent")
        #expect(assets.agent("add6443a-41bd-e414-f6ad-e58d267f4e95")?.abilities["GrenadeAbility"]?.absoluteString == "https://x/g.png")
        #expect(assets.agent(MatchFixtures.jett)?.role == "Duelist")
        #expect(assets.tier(18)?.name == "Diamond 1")
        #expect(assets.weapon(MatchFixtures.vandal)?.icon?.absoluteString == "https://x/k.png")
        #expect(assets.armor(MatchFixtures.heavyArmor) == "Heavy Armor")
        #expect(assets.queueName("hurm") == "Team Deathmatch")
        #expect(assets.queueName("brandnew") == "Brandnew")
        #expect(assets.queueName("", isCustom: true) == "Custom")
    }
}

actor EventLog {
    private(set) var pending: [String] = []
    private(set) var unavailable: [String] = []

    func add(_ event: MatchSyncEvent) {
        switch event {
        case let .pending(entries): pending += entries.map(\.id)
        case let .unavailable(id): unavailable.append(id)
        case .saved: break
        }
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
