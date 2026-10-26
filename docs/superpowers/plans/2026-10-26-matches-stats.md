# Matches Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tracker-style stats for your own games: overview, agents, maps, guns and rounds, plus agent, map and tabbed match-detail pages. All of it lives inside the Matches tab.

**Architecture:** ValorantCore gains a small per-match `MatchDigest` (the owner's numbers from one archived `Match`), stored in `digests.json` next to the archive index. It is built when a match is saved and backfilled once from the details already on disk. `CareerStats` aggregates any slice of digests: the current scope, one agent, or one map. Riot is never asked for anything new. The app's Matches tab becomes a header with a scope menu, a pill strip of six sections and a paged body, with each page one file.

**Tech Stack:** Swift 6.4 tools / Swift 5 language mode, SwiftUI with Liquid Glass, Swift Charts, Swift Testing, XcodeGen, xtool (`tools/check-app.sh`), GitHub Actions.

**Spec:** the approved mockup https://claude.ai/artifact/NkCwME9xijvSRcsEd8T4ME (boards History, Overview, Agents, Maps, Guns, Rounds, Agent, Map and Match detail). The rules below come from the owner's comments on it.

## Global Constraints

- Everything stays in the Matches tab. Sub-tabs, in order: `History · Overview · Agents · Maps · Guns · Rounds`. No new app tabs.
- Every page fits in one or two iPhone screens. Longer content goes behind small tabs or "See all", never a long scroll.
- Labels are a word or two. No explanation lines, no sentence legends, no "last 10" comparisons. Plain numbers only.
- Hit figure: head, body and legs are three separate shapes with gaps and no neck. Whichever part has the highest % is `Theme.win` (teal) with a 30 pt label. The other two are greys with 22 pt dim labels.
- Colours and fonts come only from `ios/Sources/Shared/Theme.swift`. New tokens are added there (Task 5).
- No new network calls, no third-party dependencies, no analytics.
- Custom games and modes without two sides (Deathmatch) never count toward stats. History still shows them.
- Comments: why, not what. Match each file's density.
- Every new screen gets a `#if DEBUG` demo path and a screenshot line in `.github/workflows/ios-compile.yml`.
- The app icon is not changed.
- Docs updated in the same commit as the behaviour change: `docs/architecture.md` (files, `digests.json`), `docs/ui-design.md` (Matches section), and `docs/development.md` (demo flags, screenshot list, test count).

## Review Focus

1. **Empty scope** (a new act with no Competitive games yet, or a fresh install mid-backfill). Every page shows one "No games" state and the scope chip still works. No NaN, no "0%" that means "nothing". Test: `careerOfNothingHasNoNumbers` (Task 3).
2. **Games without per-shot data** (older matches, odd modes). HS%, ADR and gun HS show "–", not 0%. ADR averages only over games that have hits. Test: `gamesWithoutHitsLeaveHeadshotsAndAdrBlank` (Task 3).
3. **A big archive on first launch after the update.** The backfill reads every details file once, and later launches read only `digests.json`. Test: `backfillRunsOnce` (Task 4).
4. **Rounds whose side Riot doesn't say** (no `winnerRole`, no plant). They are left out of attack and defense, not counted as defense. Test: `roundWithoutRoleOrPlantHasNoSide` (Task 1).
5. **History scoped to "This act" at the bottom of the list.** Older games belong to older acts, so the list must not page Riot forever. `loadMore` asks Riot only when the act scope is "All time". Manual check in Task 7, step 4.

## File Structure

Core (`ios/Packages/ValorantCore/Sources/ValorantCore/`):
- Create `MatchAnalysis.swift`: per-round reads on `Match` (side, buy, clutch, multi-kills, first deaths, damage taken, moments).
- Create `MatchDigest.swift`: `MatchDigest`, `Tally`, `Side`, `Buy`.
- Create `CareerStats.swift`: `CareerStats`, `Playstyle`, `StatsScope`.
- Modify `MatchArchive.swift`: `digests(puuid:)`, `digest(_:)`, digest written in `save`.
- Modify `MatchSummary.swift`: `RankStatus.actID`. `MatchStats` is deleted in Task 5.
- Modify `Matches.swift`: `kast` rebuilt on `kastRounds`.

Core tests (`ios/Packages/ValorantCore/Tests/ValorantCoreTests/`):
- Create `StatsFixtures.swift`: one hand-built 4-round 2v2 match plus a deathmatch.
- Create `StatsTests.swift`.
- Modify `MatchTests.swift`: `actID` assertion; drop `statsSkipCustomGames` with `MatchStats`.

App (`ios/Sources/App/`):
- Modify `MatchesModel.swift`: scope, digests, career.
- Modify `MatchesView.swift`: shell only (header, scope menu, section strip, paging, routes).
- Create `HistoryPage.swift`: rank card, day groups and match cards, moved out of `MatchesView.swift`.
- Create `OverviewPage.swift`, `AgentsPage.swift`, `MapsPage.swift`, `GunsPage.swift` (+ `HitFigure`), `RoundsPage.swift`.
- Create `AgentPage.swift`, `MapPage.swift`.
- Create `StatsComponents.swift`: `PillTabs`, `StatCell`, `StatTileSmall`, `WinLossBar`, `KillBars`, `EmptyScope`.
- Modify `MatchDetailView.swift`: tabs, with the Summary tab inline.
- Create `MatchDetailTabs.swift`: Scoreboard, Duels and Economy tabs.
- Modify `DemoData.swift`: sides, buy variety, digests, `actID`.
- Modify `ios/Sources/Shared/Theme.swift`: tokens.
- Modify `.github/workflows/ios-compile.yml`: screenshots.

## Verification commands

- Core tests: `cd ios/Packages/ValorantCore && swift test 2>&1 | grep -E "✘|Test run with"`. Passing looks like `Test run with N tests passed`, with no `✘`.
- App compile: `bash tools/check-app.sh`. Passing ends with `OK`.
- CI, once per phase:
  1. Push `main`, then `gh run list --branch main --limit 1` and `gh run watch <id> --exit-status`.
  2. `gh run download <id> -n simulator-screenshots -D <scratchpad>/shots-<phase>`.
  3. Open every listed PNG and compare it with the matching mockup board.

---

## Phase 1: Stats engine (ValorantCore, fully tested on Windows)

### Task 1: Per-round analysis on `Match`

**Files:**
- Create: `ios/Packages/ValorantCore/Sources/ValorantCore/MatchAnalysis.swift`
- Create: `ios/Packages/ValorantCore/Tests/ValorantCoreTests/StatsFixtures.swift`
- Create: `ios/Packages/ValorantCore/Tests/ValorantCoreTests/StatsTests.swift`
- Modify: `ios/Packages/ValorantCore/Sources/ValorantCore/Matches.swift:386-401` (`kast`)
- Modify: `ios/Sources/App/MatchDetailView.swift:168-175` (`RoundsStrip.halftime` → `match.halftime`)

**Interfaces:**
- Produces, all `public` in `MatchAnalysis.swift`:
  - `enum Side: String, Codable, Sendable { case attack, defense }`
  - `enum Buy: String, Codable, Sendable, CaseIterable { case pistol, eco, force, full }`
  - `struct Moment: Equatable, Sendable { enum Kind: Equatable, Sendable { case ace, quad, triple, clutch(Int), ecoWin, defuse }; let round: Int; let kind: Kind }`, where `round` is the 0-based `Round.number`.
  - `extension Match`:
    - `var halftime: Int`: swiftplay 4, spikerush 3, otherwise 12.
    - `func isPistol(_ round: Round) -> Bool`: `round.number == 0 || round.number == halftime`.
    - `func side(of team: String, in round: Round) -> Side?`
    - `func buy(of team: String, in round: Round) -> Buy?`
    - `func teamLoadout(_ team: String, in round: Round) -> Int?`: average `loadout` of that team's `RoundPlayer`s, nil when all are 0.
    - `func clutch(for id: String, in round: Round) -> Int?`
    - `func kills(by id: String, in round: Round) -> Int`
    - `func firstDeaths(_ player: Player) -> Int`
    - `func damageTaken(_ player: Player) -> Int`
    - `func ddDelta(_ player: Player) -> Int?`
    - `func multiKillRounds(_ player: Player) -> Int`: rounds with 2 or more kills.
    - `func econRating(_ player: Player) -> Int?`: damage per 1,000 credits spent, rounded. Nil when nothing was spent or there are no hits.
    - `func kastRounds(_ player: Player) -> (counted: Int, played: Int)?`
    - `func moments(for id: String) -> [Moment]`

Rules the signatures don't settle:

- **`side`:** with `winnerRole`, the winner holds that role and the loser the other. Without it, use the planter's team, which is attack. With neither, return nil.
- **`buy`:** pistol when `isPistol`. Otherwise use `teamLoadout`: under 2000 is eco, 2000–3899 is force, and 3900 and up is full. Nil when there is no loadout data.
- **`clutch`:** start with every `round.players` id split by `self.player(id)?.team`, then walk `round.kills` in time order, removing each victim. The first time `id`'s team is down to exactly `{id}` with enemies still alive, return the number of enemies alive. Return nil if that never happens, or if the team started with fewer than 2 players.
- **`ddDelta`:** `(dealt - taken) / rounds`, rounded. Nil when the player has no hits.
- **`moments`:** per round, in order:
  - kills ≥5 gives `.ace`, 4 gives `.quad`, 3 gives `.triple`;
  - a clutch won gives `.clutch(n)`;
  - your team's buy was `.eco` and it won gives `.ecoWin`;
  - you defused gives `.defuse`.
- **`kast`** becomes `kastRounds(player).map { Int((Double($0.counted) / Double($0.played) * 100).rounded()) }`. Its behaviour doesn't change.

- [ ] **Step 1: Write `StatsFixtures.swift`.** The values are fixed because every later test asserts on them.

```swift
import Foundation
@testable import ValorantCore

/// A hand-built 2v2 in Match's own shape. Blue (me, mate) attacks all four rounds.
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

    static func deathmatch() -> Match {
        Match(id: "stats-dm", queue: "deathmatch", isCustom: false, mapURL: ascent, mode: "", start: Date(), length: 540,
              season: "act-5", isRanked: false, completion: "Completed", mvp: nil, teams: [],
              players: [Match.Player(id: me, name: me, tag: "", team: me, agent: jett, tier: 0, party: "", score: 3000,
                                     kills: 30, deaths: 10, assists: 0, rounds: 0)],
              rounds: [])
    }
}
```

- [ ] **Step 2: Write the failing tests in `StatsTests.swift`**

```swift
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
        #expect(match.kastRounds(me)! == (counted: 3, played: 4))
        #expect(match.kast(me) == 75)
    }

    @Test func momentsListClutchesAndBigRounds() {
        #expect(match.moments(for: F.me) == [Moment(round: 2, kind: .clutch(2))])
    }
}
```

- [ ] **Step 3: Run the tests.** Expected: FAIL to compile with `cannot find 'Side' in scope` or `value of type 'Match' has no member 'halftime'`.

- [ ] **Step 4: Implement `MatchAnalysis.swift`, and rebuild `kast` on `kastRounds`.** Point `RoundsStrip` at `match.halftime` and delete its private copy.

- [ ] **Step 5: Run the core tests and `bash tools/check-app.sh`.** Expected: every test passes, including the existing KAST test, and the app check prints `OK`.

- [ ] **Step 6: Commit** with `git commit -m "Read sides, buys, clutches and moments from a match's rounds"`. No push yet.

### Task 2: `MatchDigest`

**Files:**
- Create: `ios/Packages/ValorantCore/Sources/ValorantCore/MatchDigest.swift`
- Test: `ios/Packages/ValorantCore/Tests/ValorantCoreTests/StatsTests.swift`

**Interfaces:**
- Consumes everything from Task 1.
- Produces, all `public`:
  - `struct Tally: Codable, Equatable, Sendable`:
    - `var played = 0`, `var won = 0`;
    - `var rate: Int?`: percent, nil when `played == 0`;
    - `mutating func add(_ won: Bool)`;
    - `static func + (a, b) -> Tally`.
  - `struct Shots: Codable, Equatable, Sendable`:
    - `var head = 0, body = 0, leg = 0`;
    - `var total: Int`;
    - `func percent(_ part: KeyPath<Shots, Int>) -> Double?`: nil when `total == 0`;
    - `static func +`.
  - `struct MatchDigest: Codable, Equatable, Sendable, Identifiable`:
    - `static let version = 1` and `var version: Int`.
    - Game: `id`, `start: Date`, `length: TimeInterval`, `queue`, `isCustom`, `season`, `mapURL`, `agent`, `outcome: MatchOutcome`, `hasRounds: Bool`.
    - Totals: `kills`, `deaths`, `assists`, `rounds`, `performance: Int?`, `damage`, `damageTaken`, `shots: Shots`.
    - Entries and KAST: `firstKills`, `firstDeaths`, `kast` (counted rounds).
    - Big rounds: `multiKills: [Int]` (index 0 = 2K … 3 = 5K), `clutches: [Tally]` (index 0 = 1v1 … 4 = 1v5).
    - Objectives: `plants`, `defuses`, `flawless`.
    - Round records (all `Tally`): `attack`, `defense`, `pistol`, `eco`, `force`, `full`, `withFirstKill`, `withFirstDeath`.
    - Economy and guns: `spent`, `guns: [String: Gun]`, where `Gun` is `{ var kills = 0; var shots = Shots() }` and the key is a weapon uuid or `"ability"`.
    - Sites: `sites: [String: Site]`, where `Site` is `{ var postPlant = Tally(); var retake = Tally() }`.
    - Match facts: `startSide: Side?`, `teamPlace: Int?` (1 is the best rating on your team, nil without sides), `isMVP: Bool`.
    - `init(match: Match, puuid: String)`.
    - `var adr: Int?`: damage / rounds, nil when `shots.total == 0`.

Rules:

- **Without sides** (`!match.hasSides`) only the game fields, `kills`, `deaths`, `assists` and `performance` are set. Everything else stays zero, and `hasRounds` is false.
- **`rounds`** is `Player.rounds`.
- **Gun shots:** each round's hits by you are credited to that round's `RoundPlayer.weapon`. A gun with no kills and no shots gets no entry.
- **Gun kills:** credited by `Kill.item`. A kill whose `kind == "Ability"` goes to `"ability"`.
- **Flawless:** your team won and none of its players appears as a victim that round.
- **Sites:**
  - When your team planted (`side == .attack` and the planter is on your team), `postPlant` at that site, won by your team's result.
  - When the enemy planted, `retake` at that site.

- [ ] **Step 1: Write the failing tests** (append to `StatsTests.swift`)

```swift
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
```

- [ ] **Step 2: Run the tests.** Expected: FAIL to compile with `cannot find 'MatchDigest' in scope`.
- [ ] **Step 3: Implement `MatchDigest.swift`.** Use Task 1's reads; don't re-derive them.
- [ ] **Step 4: Run the core tests.** Expected: all pass.
- [ ] **Step 5: Commit** with `git commit -m "Digest each match into the owner's numbers"`.

### Task 3: `CareerStats`, `Playstyle`, `StatsScope`

**Files:**
- Create: `ios/Packages/ValorantCore/Sources/ValorantCore/CareerStats.swift`
- Test: `ios/Packages/ValorantCore/Tests/ValorantCoreTests/StatsTests.swift`

**Interfaces:**
- Consumes `MatchDigest`, `Tally` and `Shots` (Task 2).
- Produces, all `public`:
  - `struct StatsScope: Codable, Hashable, Sendable`:
    - `enum Act: String, Codable, Sendable { case current, all }`;
    - `var act: Act`, `var queue: String?`, where nil means every queue (custom included) and `"custom"` means custom games only;
    - `public init(act: Act = .current, queue: String? = "competitive")`;
    - `func includes(_ digest: MatchDigest, currentAct: String?) -> Bool`. When `currentAct` is nil, `.current` behaves like `.all`.
  - `struct Playstyle: Equatable, Sendable`:
    - `var aim, entry, damage, consistency, clutch, economy: Double`, each 0…1;
    - `static let zero`.
  - `struct CareerStats: Equatable, Sendable`:
    - `struct Line: Equatable, Sendable, Identifiable`:
      - `key`, `games`, `wins`, `kills`, `deaths`, `performance: Int?` (average), `attack: Tally`, `defense: Tally`;
      - `id`, `winRate: Int`, `kd: Double`.
    - `struct GunLine: Equatable, Sendable, Identifiable { key, kills, shots: Shots; id }`
    - `init(_ digests: [MatchDigest])`. It counts only `hasRounds && !isCustom`.
    - Games and totals:
      - `games`, `wins`, `losses`, `winRate: Int?`, `kills`, `deaths`, `assists`, `kd: Double`;
      - `performance: Int?`, `shots: Shots`, `adr: Int?`, `kast: Int?`, `ddDelta: Int?`, `playtime: TimeInterval`.
    - Big rounds:
      - `multiKills: [Int]` (2K…5K), `clutches: [Tally]` (1v1…1v5), `clutch: Tally` (all sizes);
      - `plants`, `defuses`, `flawless`, `firstKills`, `firstDeaths`.
    - Round and game records (all `Tally`):
      - `attack`, `defense`, `pistol`, `eco`, `force`, `full`, `withFirstKill`, `withFirstDeath`;
      - `startAttack`, `startDefense`: games by the side the game started on.
    - Lines:
      - `econRating: Int?`;
      - `agents: [Line]`: games desc, then win rate desc, then key;
      - `maps: [Line]`: same order;
      - `guns: [GunLine]`: kills desc, then key desc;
      - `sites: [String: MatchDigest.Site]`: the UI sorts by site letter.
    - `var playstyle: Playstyle`.

Rules:

- **`adr`:** total damage over total rounds, counting only games with `shots.total > 0`. Nil when there are none.
- **`ddDelta`:** worked out the same way.
- **`kast`:** counted rounds over rounds played.
- **`econRating`:** total damage × 1000 / total spent.
- **Playstyle:** each axis is clamped to 0…1, and a nil input gives 0. ADR, KAST and econ rating use the rounded `Int` values above; head % uses `shots.percent(\.head)`. The scales are fixed and not compared with anyone else:

| Axis | Input | Range |
| --- | --- | --- |
| Aim | head % | 0–40 |
| Entry | FK/FD | 0–2 (FD 0 counts as 1) |
| Damage | ADR | 0–220 |
| Consistency | KAST % | 40–90 |
| Clutch | clutch win % | 0–60 |
| Economy | econ rating | 0–120 |

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run the tests.** Expected: FAIL to compile with `cannot find 'CareerStats' in scope`.
- [ ] **Step 3: Implement `CareerStats.swift`.**
- [ ] **Step 4: Run the core tests.** Expected: all pass.
- [ ] **Step 5: Commit** with `git commit -m "Aggregate digests into career stats, playstyle and a scope"`.

### Task 4: Archive digests and the current act's id

**Files:**
- Modify: `ios/Packages/ValorantCore/Sources/ValorantCore/MatchArchive.swift`
- Modify: `ios/Packages/ValorantCore/Sources/ValorantCore/MatchSummary.swift:100-135` (`RankStatus`)
- Test: `StatsTests.swift`, and `MatchTests.swift:124-128`

**Interfaces:**
- Consumes `MatchDigest` (Task 2).
- Produces:
  - `MatchArchive.digests(puuid: String) -> [MatchDigest]`. Newest first. On first call it reads `digests.json`, builds a digest for every index id that is missing or has `version != MatchDigest.version` from `details/<id>.json`, skips ids whose details are missing, and writes `digests.json` once if anything was added.
  - `MatchArchive.digest(_ id: String) -> MatchDigest?`
  - `save(_:puuid:)` also stores the match's digest.
  - `RankStatus.actID: String?`. It is a new stored property, last in the memberwise init with a default of `nil`, and set by `parse` from `act?.id`. Old `rank.json` files decode with it as nil.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct DigestArchiveTests {
    typealias F = StatsFixtures
    func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("digests-\(UUID().uuidString)")
    }

    @Test func savingAMatchStoresItsDigest() async {
        let dir = directory()
        await MatchArchive(directory: dir).save(F.match(), puuid: F.me)
        #expect(await MatchArchive(directory: dir).digests(puuid: F.me).map(\.id) == ["stats-1"])
    }

    @Test func missingDigestsAreBuiltFromDetails() async throws {
        let dir = directory()
        await MatchArchive(directory: dir).save(F.match(), puuid: F.me)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("digests.json"))
        #expect(await MatchArchive(directory: dir).digests(puuid: F.me).first?.kills == 5)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("digests.json").path))
    }

    @Test func backfillRunsOnce() async throws {
        let dir = directory()
        await MatchArchive(directory: dir).save(F.match(), puuid: F.me)
        _ = await MatchArchive(directory: dir).digests(puuid: F.me)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("details"))
        #expect(await MatchArchive(directory: dir).digests(puuid: F.me).count == 1)
    }

    @Test func outdatedDigestsAreRebuilt() async throws {
        let dir = directory()
        await MatchArchive(directory: dir).save(F.match(), puuid: F.me)
        var old = MatchDigest(match: F.match(), puuid: F.me)
        old.version = 0
        try JSONEncoder().encode([old]).write(to: dir.appendingPathComponent("digests.json"))
        #expect(await MatchArchive(directory: dir).digests(puuid: F.me).first?.version == MatchDigest.version)
    }
}
```

  In `rankComesFromTheActiveAct`, add `#expect(rank.actID == "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b")`.

- [ ] **Step 2: Run the tests.** Expected: FAIL to compile with `value of type 'MatchArchive' has no member 'digests'`.
- [ ] **Step 3: Implement both changes.** Keep the archive's lazy-cache style (`private var digestCache: [MatchDigest]?`).
- [ ] **Step 4: Run the core tests and `bash tools/check-app.sh`.** Expected: all tests pass and the app check prints `OK`.
- [ ] **Step 5: Commit and push Phase 1.**
  1. Update `docs/architecture.md`: the file list (`MatchAnalysis`, `MatchDigest`, `CareerStats`) and `digests.json` in the archive paragraph.
  2. Update the test count in `docs/development.md`.
  3. Run `git commit -m "Keep a digest per archived match; remember the act id"`, then push.
  4. Wait for CI to go green. The app is unchanged, so the screenshots only need a glance.

---

## Phase 2: Matches shell, History and Overview

### Task 5: Model, tokens and demo data

**Files:**
- Modify: `ios/Sources/App/MatchesModel.swift`, `ios/Sources/Shared/Theme.swift`, `ios/Sources/App/DemoData.swift`
- Modify: `ios/Packages/ValorantCore/Sources/ValorantCore/MatchSummary.swift:151-191`. Delete `MatchStats` and `MatchTests.statsSkipCustomGames`.

**Interfaces:**
- Consumes `StatsScope`, `CareerStats`, `MatchDigest` and `MatchArchive.digests/digest` (Tasks 3 and 4).
- Produces on `MatchesModel`:
  - `private(set) var digests: [String: MatchDigest]` and `private(set) var digestsReady: Bool`;
  - `var scope: StatsScope`, persisted as JSON in `UserDefaults` key `MatchesScope`. Setting it recomputes everything;
  - `var currentAct: String?`: `rank?.actID ?? newest digest's season`;
  - `var actLabel: String`: the part of `rank.act` after the last " · ", capitalised ("Act V"), or "This act";
  - `var scopeLabel: String`: e.g. "Act V · Comp" or "All time · All". `competitive` is shown as "Comp", other queues use `queueName`;
  - `private(set) var scoped: [MatchDigest]`: newest first, every digest `scope.includes`. `CareerStats` drops custom and side-less games by itself;
  - `private(set) var career: CareerStats`: built from `scoped`;
  - `func career(where keep: (MatchDigest) -> Bool) -> CareerStats`: `CareerStats(scoped.filter(keep))`;
  - `var filtered: [MatchSummary]`: History's list. A summary is kept when its digest is in scope. A summary with no digest is kept only when `scope.act == .all`.
- Removes `filter`, `select(_:)` and `stats`. `queues` stays for the scope menu.
- On `Theme`:
  - `attack` (#ff8a5c), `defense` (#5cb8ff), `ability` (#c79bf2), `gold` (#f2c14e);
  - `hitMid` (#6b6480), `hitLow` (#3e3850).

Rules:

- `handle(.saved)` becomes `async` and fetches `archive.digest(summary.id)`, so streamed cards get HS and ADR straight away.
- `reload` loads digests with `archive.digests(puuid:)` and sets `digestsReady`.
- `loadMore` pages Riot only when `scope.act == .all` (Review Focus 5).
- Demo:
  - `DemoData.rank` gets `actID: "demo"`, and the demo matches already use season "demo".
  - Demo rounds set `winnerRole`: Blue attacks the first half and swaps at `halftime`.
  - After two lost rounds in a row the losing side buys eco (loadout 900–1500), and on every fifth round it buys force (2400).
  - The owner defuses one Defuse round in three.
  - `DemoData.digests` is `matches.map { MatchDigest(match: $0, puuid: me) }`.

- [ ] **Step 1: Make the changes, keeping the History screen working.** `MatchesView` still compiles: delete `FormStrip`, `StatsSection` and `FilterChips`, which Task 6 replaces.
- [ ] **Step 2: Run the core tests and `bash tools/check-app.sh`.** Expected: all tests pass and the app check prints `OK`.
- [ ] **Step 3: Commit** with `git commit -m "Scope match stats by act and queue; theme tokens; richer demo rounds"`.

### Task 6: Matches shell

**Files:**
- Modify: `ios/Sources/App/MatchesView.swift`. It keeps only the shell; the history views move out in Task 7.
- Create: `ios/Sources/App/StatsComponents.swift`

**Interfaces:**
- Produces:
  - `enum MatchesSection: String, CaseIterable, Identifiable { case history, overview, agents, maps, guns, rounds }`, with `title` "History"…"Rounds".
  - `struct AgentRoute: Hashable { let id: String }`, `struct MapRoute: Hashable { let url: String }`, with `MatchRoute` kept.
  - `struct PillTabs<T: Hashable>: View`: `init(_ items: [(T, String)], selection: Binding<T>, scrolls: Bool = false)`. The selected pill is white with ink text and moves with `matchedGeometryEffect`. The others are glass.
  - `StatCell(label:value:)`: kicker plus big number. Move the private one out of `MatchDetailView`.
  - `StatTileSmall(label:value:tint:)`
  - `EmptyScope()`: one glass card that says "No games". It is shown by every stats page when `career.games == 0`, or a spinner while `!digestsReady`.

Layout, from the mockup's History board header:

- Kicker "YOUR GAMES".
- Title "MATCHES", with the scope chip on the right. The chip is a glass capsule showing `scopeLabel` and a chevron. It opens a `Menu` with two sections:
  - Act: "This act" / "All time";
  - Queue: "All" and each `matches.queues` entry.
- `PillTabs(MatchesSection…, scrolls: true)`. Picking a section also scrolls the strip so the pill is visible.
- The body is a horizontal paging `ScrollView` (`.scrollTargetBehavior(.paging)`, `.scrollPosition(id:)` bound to the section). Swiping changes the section. Each page is its own vertical `ScrollView` with `.refreshable { await matches.refresh() }`.
- `.navigationDestination` entries for `MatchRoute`, `AgentRoute` and `MapRoute`. The agent and map destinations are placeholders until Phase 4.
- Sections not built yet render `ContentUnavailableView("Soon", systemImage: "chart.bar")`. Phase 3 removes it.
- Demo: `-DemoSection <rawValue>` picks the start section.

- [ ] **Step 1: Build the shell and components.**
- [ ] **Step 2: Run `bash tools/check-app.sh`.** Expected: `OK`.
- [ ] **Step 3: Commit** with `git commit -m "Matches tab: scope menu, section strip and paged sections"`.

### Task 7: History page

**Files:**
- Create: `ios/Sources/App/HistoryPage.swift`. Move `RankCard`, `RRBar`, `RRTrend`, `MatchCard`, `PendingMatchCard`, `RRChip` and the footer here from `MatchesView.swift`.

Layout (mockup History board):

1. **Rank card, compact, one row.** The tier emblem is 56 pt with its glow. Next to it: kicker "V26 · ACT V · 14W 11L", then the tier name, then the RR bar with "62 RR". `RRTrend` sits on the right as a sparkline about 110 pt wide.
2. **Day groups.** Each header reads "Today", "Yesterday", or `Date.FormatStyle` ".weekday(.abbreviated) .day .month(.abbreviated)", followed by "3W" (teal) "1L" (red) "· +38 RR · 1.58 K/D". The RR part is left out when no game that day has RR.
3. **Match card.** Keep the banner, outcome edge and 3D deal-in.
   - Line 1: the result ("Victory" or "Defeat"), the score "13 : 9", and the RR chip on the right.
   - Line 2: "Ascent · Jett · 8:23 AM".
   - Badge: "Match MVP" in gold when `isMVP`; "Team MVP" in gold when `teamPlace == 1`; otherwise the ordinal of `teamPlace` in dim; the placement label for free-for-all.
   - Bottom row: `K / D / A`, `PS` (or `ACS`), `HS`, `ADR` from the digest, "–" when nil.
4. Keep the pending skeleton cards and the end-of-list footer.

- [ ] **Step 1: Build it.**
- [ ] **Step 2: Run `bash tools/check-app.sh`.** Expected: `OK`.
- [ ] **Step 3: Commit** with `git commit -m "History: compact rank card, games grouped by day, richer match cards"`.
- [ ] **Step 4: Manual check of Review Focus 5.** In code, confirm that `loadMore` returns without calling `olderMatches` when `scope.act == .current`.

### Task 8: Overview page

**Files:**
- Create: `ios/Sources/App/OverviewPage.swift`

Layout (mockup Overview board), from `matches.career`:

1. **Hero card.**
   - Win donut: teal for the win share, red for losses. "56%" in the middle and "14W 11L" under it. It draws its arc on appear.
   - On the right, a 2×2 grid of `StatCell`s: "K/D" `1.38`, "Avg PS" `287` ("Avg ACS" when no game has PS), "HS%" `27.4%`, "ADR" `168`.
2. **Strip card,** four cells: "KAST" `74%`; "DDΔ" `+32`, teal when ≥0 and red when below; "Games" `25`; "Played" `16h 14m`.
3. **"Playstyle" card.** A hexagon radar drawn with `Path`:
   - Three rings at 1/3, 2/3 and 1, plus spokes.
   - Axes clockwise from the top: AIM, ENTRY, DAMAGE, CONSISTENCY, CLUTCH, ECONOMY.
   - Each axis has a kicker label and a value line: "27.4% HS", "1.61 FK/FD", "168 ADR", "74% KAST", "29% won", "71 rating".
   - The polygon is teal at 28% fill with a 2 pt stroke, and grows from the centre on appear.
4. **Tiles row of four:** "Aces" (gold), "4K · 3K", "Clutch" `won/played`, "Flawless".

- [ ] **Step 1: Build it.**
- [ ] **Step 2: Add screenshots to `ios-compile.yml`:** `shoot 16-overview 14 -DemoTab matches -DemoSection overview`.
- [ ] **Step 3: Run `bash tools/check-app.sh`.** Expected: `OK`.
- [ ] **Step 4: Push Phase 2 and check the screenshots.**
  1. Update `docs/ui-design.md` (Matches section rewritten for the shell, History and Overview) and `docs/development.md` (`-DemoSection`, screenshot `16-overview`).
  2. Commit, push and wait for CI.
  3. Look at `11-matches` against the History board and `16-overview` against the Overview board, and at `12-match-detail`, which must not have regressed.
  4. Fix and push again until both match.

---

## Phase 3: Agents, Maps, Guns and Rounds

All four pages use `EmptyScope` and come from `matches.career`. Agent names, roles and art come from `matches.assets`. An unknown id falls back to "Agent", "Map" or "Gun".

### Task 9: Agents page

**Files:** Create `ios/Sources/App/AgentsPage.swift`, and add `WinLossBar` to `StatsComponents.swift`.

1. **"Roles" card.** One segmented bar with one segment per role, width proportional to games, in role colours from the agents' tints. Labels under it read "Duelist 12 · 58%", "Init 6 · 50%", "Sent 5 · 60%" and "Ctrl 2". Short names: Duelist, Init, Sent, Ctrl. The % shows only when a role has at least 3 games.
2. **"Main" card** for the agent with the most games. It shows the portrait, kicker "MAIN", the name, the win % and "1.72 K/D · 318 PS". Tapping it pushes `AgentRoute`.
3. **"All agents" list** with a sort chip ("Games" ▾ / "Win %" / "K/D").
   - Each row shows the icon, the name, then a `WinLossBar` (teal wins plus red losses, total length = games / max games), the win %, and the K/D.
   - The first 8 rows show, then a "See all N" button expands the rest in place.
   - Tapping a row pushes `AgentRoute`.
- Screenshot: `shoot 17-agents 14 -DemoTab matches -DemoSection agents`.
- Steps: build, `bash tools/check-app.sh` OK, then commit `"Agents: roles, main and every agent"`.

### Task 10: Maps page

**Files:** Create `ios/Sources/App/MapsPage.swift`.

1. **"Rounds won" card.** A mirrored bar with "Atk 51%" on the left in `Theme.attack` and "57% Def" on the right in `Theme.defense`, built from `career.attack` and `career.defense`.
2. **Two-column grid of map tiles.** Each tile shows the map banner behind a gradient, the name, a win % chip (teal at 50% or more, otherwise red), "5W 1L", and atk/def mini bars. Tapping a tile pushes `MapRoute`.
3. **"Not played" tile.** It lists the maps that appear in any archived Competitive digest (any act) but not in this scope, joined with " · ". It is hidden when there are none.
- Screenshot: `shoot 18-maps 14 -DemoTab matches -DemoSection maps`.
- Steps: build, `bash tools/check-app.sh` OK, then commit `"Maps: attack and defense, map tiles"`.

### Task 11: Guns page and hit figure

**Files:** Create `ios/Sources/App/GunsPage.swift`, and add `KillBars` to `StatsComponents.swift`.

1. **"Hits" card.**
   - On the left, `HitFigure(head:body:legs:)` at 70×160 in the viewBox `10 2 80 182`.
   - On the right, Head / Body / Legs with their %. The top one is teal at 30 pt; the others are `textDim` at 22 pt.
   - The fills follow the hit order: highest `Theme.win`, middle `Theme.hitMid`, lowest `Theme.hitLow`.
   - Build the shapes with a minimal absolute M/L/C/Z SVG path parser in `GunsPage.swift`. Cut the leg gap by drawing the body path stroked 5 wide with `.blendMode(.destinationOut)` inside `.compositingGroup()`. The head-to-body gap is already in the shapes.
   - The paths are copied exactly from the approved mockup:

```
legs: M38 84 C35.8 94 34.6 103 34.5 111 C34 124 33 135 32.6 144 C32 154 31.6 163 31.3 170 L27.5 179 C27 181 27.6 182 29.4 182 L41 182 C42.2 182 42.6 181 42.3 179.5 L41.2 170 C41.8 163 42.8 154 43.6 144 C44.4 135 46.2 122 50 112 C53.8 122 55.6 135 56.4 144 C57.2 154 58.2 163 58.8 170 L57.7 179.5 C57.4 181 57.8 182 59 182 L70.6 182 C72.4 182 73 181 72.5 179 L68.7 170 C68.4 163 68 154 67.4 144 C67 135 66 124 65.5 111 C65.4 103 64.2 94 62 84 Z
body: M44.5 30 C39 31.5 32 33.5 27.5 36.5 C23 39 21.5 43 21 48 C20 58 18 68 16.5 77 C15 88 13.5 98 12.8 106 C12.3 111 13.8 115.5 17.2 115.8 C20.6 116 22.2 113 22 109 C22.6 99 24 89 25.6 80 C27.2 68 29.2 58 31.2 50 C33.5 61 38 76 39.2 88 C41.5 94 46.5 100 50 103.5 C53.5 100 58.5 94 60.8 88 C62 76 66.5 61 68.8 50 C70.8 58 72.8 68 74.4 80 C76 89 77.4 99 78 109 C77.8 113 79.4 116 82.8 115.8 C86.2 115.5 87.7 111 87.2 106 C86.5 98 85 88 83.5 77 C82 68 80 58 79 48 C78.5 43 77 39 72.5 36.5 C68 33.5 61 31.5 55.5 30 Z
head: M50 3 C56.2 3 59.6 7.6 59.6 13.6 C59.6 20 55.6 26.6 50 26.6 C44.4 26.6 40.4 20 40.4 13.6 C40.4 7.6 43.8 3 50 3 Z
```

2. **"Kills by gun" card.**
   - Column heads "Kills" and "HS".
   - Each row shows the gun name, a bar (teal, or `Theme.ability` for "Abilities"; length = kills / max), the kills, and the gun's head %, with "—" for abilities or no shots.
   - The first 8 rows show, then "See all N".
- Screenshot: `shoot 19-guns 14 -DemoTab matches -DemoSection guns`.
- Steps: build, `bash tools/check-app.sh` OK, then commit `"Guns: hit figure and kills by gun"`.

### Task 12: Rounds page

**Files:** Create `ios/Sources/App/RoundsPage.swift`.

1. **"Round win %" card.** Two big numbers: `withFirstKill.rate` labelled "You get first kill", and `withFirstDeath.rate` labelled "You die first".
2. **"Win % by buy" columns:** Pistol, Eco, Force and Full. Column height is proportional to the rate, with the rate above it. The column is teal at 50% or more and faded teal below. Columns grow on appear.
3. **"Clutches" card.** The header total is "9/31". There is one row each for 1v1 to 1v5. Each row has its label, dots (won is teal, lost is faint, at most 12) and "5/8".
4. **Tiles:** "Plants", "Defuses", "Flawless".
- Screenshot: `shoot 20-rounds 14 -DemoTab matches -DemoSection rounds`.
- Steps:
  1. Build, run `bash tools/check-app.sh` until OK, and remove the "Soon" placeholder.
  2. Commit `"Rounds: first-kill impact, buys and clutches"`.
- **Push Phase 3.**
  1. Update `ui-design.md` and `development.md` (screenshots 17–20).
  2. Run CI.
  3. Compare screenshots 17–20 with their boards, and fix until they match.
  4. **Proposed TestFlight build here,** since this is the first build with stats on your real archive. It ships only with your OK.

---

## Phase 4: Agent and map pages

### Task 13: Agent page

**Files:** Create `ios/Sources/App/AgentPage.swift`, and wire it to `AgentRoute`.

**Data:** `matches.career { $0.agent == id }`.

- **Hero card.** The portrait sits over the agent's tint, with kicker "Duelist · 10 games", the name, and "7W" (teal) "3L" (red) "· 70%".
- **`PillTabs`:** Stats / Maps / Guns.
  - **Stats:** a 3×2 `StatCell` grid of "K/D", "Avg PS", "HS%", "ADR", "KAST" and "FK · FD" (`41·26`), then tiles "3K", "4K", "Ace" and "Clutch" (won/played).
  - **Maps:** one row per map, with name, "4W 1L", win % and K/D. Tapping a row pushes `MapRoute`.
  - **Guns:** `KillBars` for this agent.
- **Demo:** `-DemoAgent N` opens the Nth row of the agents list.
- **Screenshot:** `shoot 21-agent 14 -DemoTab matches -DemoSection agents -DemoAgent 1`.
- **Steps:** build, `bash tools/check-app.sh` OK, then commit `"Agent page: stats, maps and guns"`.

### Task 14: Map page

**Files:** Create `ios/Sources/App/MapPage.swift`, and wire it to `MapRoute`.

**Data:** `matches.career { $0.mapURL == url }`.

- **Hero card.** The map splash sits behind a gradient, with kicker "6 games", the name, and "5W 1L · 83%".
- **`PillTabs`:** Rounds / Sites / Agents.
  - **Rounds:** "Attack 58%" with "35 of 60" under it, and "Defense 64%" with "39 of 61" under it. Then tiles: "Pistols" `9/12`, "Start atk" `4W 0L`, "Start def" `1W 1L`.
  - **Sites:** an "Attack · after plant" list with one row per site (site letter, plants, win %), then a "Defense · retakes" list laid out the same way.
  - **Agents:** one row per agent on this map: icon, name, "5 games", win %, K/D.
- **Demo:** `-DemoMap N` opens the Nth map tile.
- **Screenshot:** `shoot 22-map 14 -DemoTab matches -DemoSection maps -DemoMap 1`.
- **Steps:**
  1. Build, run `bash tools/check-app.sh` until OK, and commit `"Map page: sides, sites and agents"`.
  2. Push Phase 4 with docs, run CI, and check screenshots 21 and 22.

---

## Phase 5: Tabbed match detail

### Task 15: Summary, Scoreboard, Duels and Economy

**Files:** Modify `ios/Sources/App/MatchDetailView.swift`, and create `ios/Sources/App/MatchDetailTabs.swift`.

The header stays. Under it, `PillTabs` shows Summary / Scoreboard / Duels / Economy. Economy is hidden when `!match.hasRounds`.

- **Summary.**
  - `PerformanceCard`, with "FIRST BL." renamed to "First kills".
  - A moments chip row from `match.moments(for: me)`:
    - Text: "R2 Eco win", "R6 4K", "R9 Clutch 1v2", "R16 3K", "R19 Defuse", plus "Ace".
    - Colours: Ace, 4K and Eco win are gold; Clutch is teal; 3K is white; Defuse is `Theme.defense`.
  - The existing rounds strip, with the section label shortened to "Rounds".
- **Scoreboard.** A horizontally scrolling table with the Player column pinned.
  - Column heads: Player | PS (`ratingLabel`) | K/D/A | ADR | DDΔ | HS | KAST | FK | FD | MK.
  - Rows are grouped as "Your team" and "Enemy team", using the existing `Scoreboard.ordered`.
  - Your row is teal at 16%. DDΔ is coloured by sign.
  - Tapping a row opens `PlayerMatchSheet`.
- **Duels.** A "Kills · Deaths" header, then one row per opponent from `match.duels(mine)`. Kill bars grow left in teal and death bars grow right in red from a centre line, with the numbers at the ends.
- **Economy.**
  - A Swift Charts bar chart of `teamLoadout` per round, with your team and the enemy side by side and a W/L tick under each round.
  - A small "Your team · Them" key.
  - Tiles: "You spent" (sum of your `spent`, formatted "71.4K"), "Econ rating" (`econRating`), and "Eco + force" ("3 of 5": rounds won where your team's buy was eco or force, out of those rounds).
- **Demo:** `-DemoMatchTab summary|scoreboard|duels|economy`.
- **Screenshots:** `23-match-scoreboard`, `24-match-duels` and `25-match-economy`, each with `-DemoMatch 1`. The existing `13-round`, `14-player` and `15-deathmatch` must still work.

- [ ] **Step 1: Build it.**
- [ ] **Step 2: Run `bash tools/check-app.sh`.** Expected: `OK`.
- [ ] **Step 3: Commit** with `git commit -m "Match detail: summary, scoreboard, duels and economy tabs"`.
- [ ] **Step 4: Push Phase 5.**
  1. Update docs.
  2. Run CI and check screenshots 12–15 and 23–25.
  3. Have one fresh reviewer go over the whole diff since the plan commit.
  4. **Proposed TestFlight build,** only with your OK.
