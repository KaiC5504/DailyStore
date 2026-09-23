#if DEBUG
import Foundation
import ValorantCore

/// Real item IDs so the CI simulator screenshots show real art. Launch with `-DemoData YES`.
enum DemoData {
    private static let skinType = "e7c63390-eda7-46e0-bb7a-a6abdacd2433"

    static let snapshot = StoreSnapshot(
        storefront: Storefront(
            daily: [
                StoreOffer(offerID: "d1", itemID: "d58e1881-4126-9c75-347d-67bab6b98fb2", cost: 2175),
                StoreOffer(offerID: "d2", itemID: "1590d353-4b81-4207-b79a-5493231cbee7", cost: 1775),
                StoreOffer(offerID: "d3", itemID: "722a1311-43e1-7c18-ce90-acac33e9c2ad", cost: 2975),
                StoreOffer(offerID: "d4", itemID: "68564c51-4f7e-67d1-fd0d-4e9d216356e8", cost: 875),
            ],
            dailyRemainingSeconds: 5 * 3600 + 23 * 60,
            nightMarket: [
                night("n1", "ba42fe63-457a-78ce-4499-47950a698129", 1775, 37),
                night("n2", "c00e786e-4e6f-0ef7-0ce3-32ba9918ba41", 1775, 22),
                night("n3", "4b74b3ee-4a63-7339-a28f-8b8be010ca5a", 2175, 41),
                night("n4", "4e435234-49a2-1444-4640-908692c855b8", 2175, 18),
                night("n5", "636c1f83-44f7-6bc4-0b24-88a1beb66c2d", 2175, 29),
                night("n6", "2b555f97-46bb-5949-3531-979f5bc817f0", 1775, 45),
            ],
            nightMarketRemainingSeconds: 9 * 86400,
            bundles: [
                FeaturedBundle(
                    id: "b1", dataAssetID: "69d9b2be-4439-0785-780b-ba8951053683",
                    items: [
                        BundleItem(itemTypeID: skinType, itemID: "636c1f83-44f7-6bc4-0b24-88a1beb66c2d", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "0c989088-43ef-22ad-cc43-81a27bde2377", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "72b3bacc-48ac-85f7-ec38-5ab629654486", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "99b0edce-48db-b898-1d6f-0fa89795226d", basePrice: 4350, discountedPrice: 3262),
                        BundleItem(itemTypeID: "3f296c07-64c3-494c-923b-fe692a4fa1bd", itemID: "1a127cbf-4131-3581-da59-529b7e0d9495", basePrice: 375, discountedPrice: 0),
                        BundleItem(itemTypeID: "d5f120f8-ff8c-4aac-92ea-f2b5acbe9475", itemID: "515a130a-4a2e-e0a4-9a73-c784f8f16e2a", basePrice: 325, discountedPrice: 0),
                    ],
                    baseCost: 10_875, discountedCost: 8_700, remainingSeconds: 6 * 86400 + 3600
                ),
                FeaturedBundle(
                    id: "b2", dataAssetID: "2116a38e-4b71-f169-0d16-ce9289af4bfa",
                    items: [], baseCost: 7_100, discountedCost: 7_100, remainingSeconds: 2 * 86400
                ),
            ]
        ),
        wallet: Wallet(vp: 4909, radianite: 0, kingdomCredits: 10000),
        clientVersion: "demo",
        fetchedAt: Date(),
        // Kuronami Phantom and Sheriff (in the demo bundle), Reaver Phantom, Sheriff and Odin.
        owned: ["0c989088-43ef-22ad-cc43-81a27bde2377", "72b3bacc-48ac-85f7-ec38-5ab629654486",
                "4c18d802-409d-ec20-f630-d3abfcaa37c7", "4e4ebb8d-41d0-c326-595a-1f9b257e91fa",
                "f5ce6297-4cd4-4b09-3931-5f8b20a4317d"]
    )

    static let wishlist: Set<String> = ["722a1311-43e1-7c18-ce90-acac33e9c2ad", "636c1f83-44f7-6bc4-0b24-88a1beb66c2d",
                                        "0c989088-43ef-22ad-cc43-81a27bde2377"]

    static let historyDays: [String] = (0..<12).reversed().map {
        StoreHistory.dayKey(Date().addingTimeInterval(TimeInterval(-$0 * 86_400)))
    }

    private static func night(_ id: String, _ item: String, _ cost: Int, _ percent: Int) -> NightMarketOffer {
        NightMarketOffer(offer: StoreOffer(offerID: id, itemID: item, cost: cost),
                         discountedCost: cost * (100 - percent) / 100, discountPercent: percent, isSeen: false)
    }
}
/// Twelve made-up matches for the Matches screenshots. Names are invented; map, agent and
/// weapon IDs are real so valorant-api.com art loads.
extension DemoData {
    static let me = "00000000-dead-beef-0000-000000000001"

    private struct Spec {
        let queue: String
        let map: String
        let mine: Int
        let theirs: Int
        var teamSize = 5
        var custom = false
    }

    private static let specs: [Spec] = [
        Spec(queue: "competitive", map: "/Game/Maps/Ascent/Ascent", mine: 13, theirs: 9),
        Spec(queue: "competitive", map: "/Game/Maps/Jam/Jam", mine: 11, theirs: 13),
        Spec(queue: "unrated", map: "/Game/Maps/Triad/Triad", mine: 13, theirs: 7),
        Spec(queue: "competitive", map: "/Game/Maps/Duality/Duality", mine: 13, theirs: 11),
        Spec(queue: "swiftplay", map: "/Game/Maps/Juliett/Juliett", mine: 5, theirs: 3),
        Spec(queue: "deathmatch", map: "/Game/Maps/Port/Port", mine: 0, theirs: 0),
        Spec(queue: "competitive", map: "/Game/Maps/Bonsai/Bonsai", mine: 8, theirs: 13),
        Spec(queue: "competitive", map: "/Game/Maps/Infinity/Infinity", mine: 13, theirs: 10),
        Spec(queue: "skirmish2v2", map: "/Game/Maps/Duel/Duel_1/Skirmish_A", mine: 10, theirs: 8, teamSize: 2),
        Spec(queue: "competitive", map: "/Game/Maps/Pitt/Pitt", mine: 12, theirs: 14),
        Spec(queue: "", map: "/Game/Maps/Foxtrot/Foxtrot", mine: 13, theirs: 5, custom: true),
        Spec(queue: "competitive", map: "/Game/Maps/Rook/Rook", mine: 13, theirs: 8),
    ]

    private static let agents = [
        "add6443a-41bd-e414-f6ad-e58d267f4e95", "8e253930-4c05-31dd-1b6c-968525494517", "320b2a48-4d9b-a075-30f1-1f93a9b638fa",
        "1e58de9c-4950-5125-93e9-a0aee9f98746", "569fdd95-4d10-43ab-ca70-79becc718b46", "a3bfb853-43b2-7238-a4f1-ad90e9e46bcc",
        "9f0d8ba9-4140-b941-57d3-a7ad57c6b417", "117ed9e3-49f3-6512-3ccf-0cada7e3823b", "f94c3b30-42be-e959-889c-5aa313dba261",
        "eb93336a-449b-9c1b-0a54-a891f7921d69", "bb2a4828-46eb-8cd1-e765-15848195d751", "6f2a04ca-43e0-be17-7f36-b3908627744d",
    ]
    private static let names = ["DailyStore", "Nebula", "Kestrel", "Ashfall", "Tidewater", "Vortex", "Sable", "Monolith",
                                "Quill", "Ember", "Lantern", "Rook"]
    private static let rifles = ["9c82e19d-4575-0200-1a81-3eacf00cf872", "ee8e8d15-496b-07ac-e5f6-8fae5d4c7b1a",
                                 "9c82e19d-4575-0200-1a81-3eacf00cf872", "a03b24d3-4319-996d-0f8c-94bbfba1dfc7",
                                 "462080d1-4035-2937-7c09-27aa2a5c27a7"]
    private static let pistols = ["1baa85b4-4c70-1284-64bb-6481dfc3bb4e", "e336c6b8-418d-9340-d77f-7a9e4cfe0702",
                                  "29a0cfab-485b-f5d5-779a-b59f85e204a8"]
    private static let heavyArmor = "822bcab2-40a2-324e-c137-e09195ad7692"
    private static let lightArmor = "4dec83d5-4902-9ab3-bed6-a7a390761157"

    static let matches: [Match] = specs.indices.map { makeMatch($0, specs[$0]) }

    static let updates: [CompetitiveUpdate] = {
        var rng = Rng(seed: 99)
        var ladder = 18 * 100 + 62
        var result: [CompetitiveUpdate] = []
        let ranked = matches.filter { $0.queue == "competitive" }
        for index in 0..<20 {
            let match = index < ranked.count ? ranked[index] : nil
            let won = match.map { $0.outcome(for: me).isWin } ?? (rng.next(100) < 55)
            let earned = won ? 16 + rng.next(10) : -(13 + rng.next(8))
            let before = ladder - earned
            result.append(CompetitiveUpdate(
                id: match?.id ?? "demo-old-\(index)", mapURL: match?.mapURL ?? "", season: "demo",
                start: match?.start ?? Date().addingTimeInterval(TimeInterval(-86_400 * (index + 2))),
                tierBefore: before / 100, tierAfter: ladder / 100, rrBefore: before % 100, rrAfter: ladder % 100,
                rrEarned: earned, isPlacement: false
            ))
            ladder = before
        }
        return result
    }()

    static let summaries: [MatchSummary] = matches.map { match in
        MatchSummary(match: match, puuid: me, update: updates.first { $0.id == match.id })
    }

    static let rank = RankStatus(tier: 18, rr: 62, act: "V26 · ACT V", wins: 14, games: 25, fetchedAt: Date())

    fileprivate struct Rng: RandomNumberGenerator {
        var state: UInt64

        init(seed: UInt64) { state = seed &* 2_654_435_761 &+ 1 }

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }

        mutating func next(_ bound: Int) -> Int {
            Int((next() >> 33) % UInt64(bound))
        }
    }

    private static func playerID(_ slot: Int) -> String {
        slot == 0 ? me : String(format: "00000000-dead-beef-0000-%012d", slot + 1)
    }

    private static func makeMatch(_ index: Int, _ spec: Spec) -> Match {
        var rng = Rng(seed: UInt64(index + 7))
        let start = Date().addingTimeInterval(TimeInterval(-(index * 5 + 1) * 3600))
        let id = "demo-match-\(index)"
        if spec.queue == "deathmatch" {
            let players = (0..<12).map { slot -> Match.Player in
                let kills = slot == 0 ? 31 : 8 + rng.next(30)
                return Match.Player(id: playerID(slot), name: names[slot], tag: "DEMO", team: playerID(slot),
                                    agent: agents[slot], tier: 0, party: "", score: kills * 100, kills: kills,
                                    deaths: 10 + rng.next(20), assists: 0, rounds: 0)
            }
            return Match(id: id, queue: spec.queue, isCustom: false, mapURL: spec.map, mode: "", start: start, length: 540,
                         season: "demo", isRanked: false, completion: "Completed", mvp: nil, teams: [], players: players, rounds: [])
        }

        let size = spec.teamSize
        let blue = (0..<size).map(playerID)
        let red = (size..<size * 2).map(playerID)
        let didWin = spec.mine > spec.theirs
        var order = Array(repeating: true, count: spec.mine - (didWin ? 1 : 0))
            + Array(repeating: false, count: spec.theirs - (didWin ? 0 : 1))
        order.shuffle(using: &rng)
        order.append(didWin)
        let half = spec.queue == "swiftplay" ? 4 : 12

        var kills: [String: Int] = [:]
        var deaths: [String: Int] = [:]
        var assists: [String: Int] = [:]
        var score: [String: Int] = [:]
        var rounds: [Match.Round] = []
        for (number, blueWon) in order.enumerated() {
            let winners = blueWon ? blue : red
            let losers = blueWon ? red : blue
            let pistolRound = number == 0 || number == half
            var alive = Set(blue + red)
            var roundKills: [Match.Kill] = []
            var hits: [String: [Match.Hit]] = [:]
            var time = 6000 + rng.next(8000)
            let winnerDeaths = rng.next(min(3, size))
            var victims = losers + Array(winners.shuffled(using: &rng).prefix(winnerDeaths))
            victims.shuffle(using: &rng)
            for victim in victims where alive.contains(victim) {
                let side = blue.contains(victim) ? red : blue
                var shooters = side.filter { alive.contains($0) }
                if shooters.contains(me) { shooters += [me, me] }
                guard !shooters.isEmpty else { continue }
                let killer = shooters[rng.next(shooters.count)]
                let ability = rng.next(100) < 6
                let guns = pistolRound ? pistols : rifles
                let item = ability ? "Ultimate" : guns[rng.next(guns.count)]
                let helpers = side.filter { $0 != killer && alive.contains($0) }
                let assist = !helpers.isEmpty && rng.next(100) < 35 ? [helpers[rng.next(helpers.count)]] : []
                roundKills.append(Match.Kill(time: time, killer: killer, victim: victim, assistants: assist, item: item,
                                             kind: ability ? "Ability" : "Weapon"))
                hits[killer, default: []].append(Match.Hit(receiver: victim, damage: 140 + rng.next(30), head: rng.next(3),
                                                           body: 1 + rng.next(3), leg: rng.next(2)))
                alive.remove(victim)
                kills[killer, default: 0] += 1
                deaths[victim, default: 0] += 1
                for helper in assist { assists[helper, default: 0] += 1 }
                time += 3000 + rng.next(9000)
            }
            let roll = rng.next(100)
            let result = roll < 60 ? "Elimination" : roll < 80 ? "Detonate" : roll < 95 ? "Defuse" : ""
            let planted = result == "Detonate" || result == "Defuse"
            let planter = planted ? (result == "Detonate" ? winners : losers)[rng.next(size)] : nil
            let players = (blue + red).map { player -> Match.RoundPlayer in
                let guns = pistolRound ? pistols : rifles
                let loadout = pistolRound ? 800 : 3900 + rng.next(9) * 100
                let damage = hits[player] ?? []
                score[player, default: 0] += damage.reduce(0) { $0 + $1.damage } + damage.count * 70
                return Match.RoundPlayer(id: player, score: 0, loadout: loadout, spent: pistolRound ? 800 : loadout - 400,
                                         remaining: 200 + rng.next(30) * 100, weapon: guns[rng.next(guns.count)],
                                         armor: pistolRound ? lightArmor : heavyArmor, hits: damage)
            }
            rounds.append(Match.Round(
                number: number, winner: blueWon ? "Blue" : "Red", result: result, winnerRole: nil,
                ceremony: "CeremonyDefault", planter: planter, plantSite: planted ? ["A", "B"][rng.next(2)] : nil,
                plantTime: planted ? 40000 + rng.next(30000) : nil,
                defuser: result == "Defuse" ? winners[rng.next(size)] : nil,
                defuseTime: result == "Defuse" ? 90000 + rng.next(10000) : nil,
                firstBlood: roundKills.first?.killer, kills: roundKills, players: players
            ))
        }
        let count = order.count
        let players = (blue + red).enumerated().map { slot, id in
            Match.Player(id: id, name: names[slot], tag: slot == 0 ? "DEMO" : "\(1000 + slot * 37)",
                         team: blue.contains(id) ? "Blue" : "Red", agent: agents[slot],
                         tier: spec.queue == "competitive" ? 16 + rng.next(4) : 0,
                         party: slot == 0 || slot == 2 ? "demo-party" : "p\(slot)",
                         score: score[id, default: 0], kills: kills[id, default: 0], deaths: deaths[id, default: 0],
                         assists: assists[id, default: 0], rounds: count)
        }
        return Match(
            id: id, queue: spec.queue, isCustom: spec.custom, mapURL: spec.map, mode: "", start: start,
            length: TimeInterval(count * 105), season: "demo", isRanked: spec.queue == "competitive",
            completion: "Completed", mvp: players.max { $0.score < $1.score }?.id,
            teams: [Match.Team(id: "Blue", won: didWin, roundsWon: spec.mine, points: spec.mine),
                    Match.Team(id: "Red", won: !didWin, roundsWon: spec.theirs, points: spec.theirs)],
            players: players, rounds: rounds
        )
    }
}
#endif
