import Foundation
@testable import ValorantCore

/// Made-up matches in the shape the probe saw on a real account (2026-09-23). The repo is
/// public, so no real match JSON with other players' names goes in here.
enum MatchFixtures {
    static let me = Fixtures.puuid
    static let mate = "aaaaaaaa-0000-0000-0000-000000000001"
    static let enemy1 = "bbbbbbbb-0000-0000-0000-000000000002"
    static let enemy2 = "cccccccc-0000-0000-0000-000000000003"
    static let jett = "ADD6443A-41BD-E414-F6AD-E58D267F4E95"
    static let sova = "320B2A48-4D9B-A075-30F1-1F93A9B638FA"
    static let vandal = "9C82E19D-4575-0200-1A81-3EACF00CF872"
    static let heavyArmor = "822BCAB2-40A2-324E-C137-E09195AD7692"

    static func player(_ id: String, team: String, agent: String, score: Int, k: Int, d: Int, a: Int, observer: Bool = false) -> String {
        """
        {"subject": "\(id.uppercased())", "gameName": "Player\(id.prefix(2))", "tagLine": "\(id.prefix(3))", "teamId": "\(team)",
         "partyId": "party-\(team)", "characterId": "\(agent)", "competitiveTier": 18, "isObserver": \(observer), "accountLevel": 100,
         "stats": {"score": \(score), "roundsPlayed": 3, "kills": \(k), "deaths": \(d), "assists": \(a), "playtimeMillis": 1, "TempValueA": 9},
         "roundDamage": null, "scores": {"TempValueA": 1.5}}
        """
    }

    static func kill(_ killer: String, _ victim: String, at time: Int, item: String = vandal, type: String = "Weapon", assists: [String] = []) -> String {
        """
        {"gameTime": \(time), "roundTime": \(time), "killer": "\(killer)", "victim": "\(victim)", "victimLocation": {"x": 1, "y": 2},
         "assistants": [\(assists.map { "\"\($0)\"" }.joined(separator: ","))], "playerLocations": [{"subject": "\(killer)", "viewRadians": 1.0, "location": {"x": 1, "y": 2}}],
         "finishingDamage": {"damageType": "\(type)", "damageItem": "\(item)", "isSecondaryFireMode": false}}
        """
    }

    static func stat(_ id: String, kills: [String] = [], damage: String = "[]", economy: String = "null") -> String {
        """
        {"subject": "\(id)", "kills": [\(kills.joined(separator: ","))], "damage": \(damage), "score": 100, "economy": \(economy),
         "ability": {"grenadeEffects": null}, "wasAfk": false, "wasPenalized": false, "stayedInSpawn": false}
        """
    }

    static func economy(_ id: String, loadout: Int) -> String {
        #"{"subject": "\#(id)", "loadoutValue": \#(loadout), "weapon": "\#(vandal)", "armor": "\#(heavyArmor)", "remaining": 200, "spent": \#(loadout)}"#
    }

    static let myDamage = """
    [{"receiver": "\(enemy1)", "damage": 150, "legshots": 0, "bodyshots": 2, "headshots": 1},
     {"receiver": "\(enemy2)", "damage": 150, "legshots": 1, "bodyshots": 3, "headshots": 0}]
    """

    static let competitive = """
    {
      "matchInfo": {"matchId": "MATCH-COMP-1", "mapId": "/Game/Maps/Ascent/Ascent", "gameMode": "/Game/GameModes/Bomb/BombGameMode.BombGameMode_C",
        "queueID": "competitive", "provisioningFlowID": "Matchmaking", "gameStartMillis": 1790000000000, "gameLengthMillis": 2280000,
        "seasonId": "8102CD81-43A0-D0D7-BD59-47B8FE9BED1B", "isRanked": true, "isCompleted": true, "completionState": "Completed", "premierMatchInfo": {}},
      "players": [
        \(player(me, team: "Blue", agent: jett, score: 600, k: 3, d: 1, a: 1)),
        \(player(mate, team: "Blue", agent: sova, score: 300, k: 1, d: 2, a: 1)),
        \(player(enemy1, team: "Red", agent: sova, score: 400, k: 1, d: 3, a: 0)),
        \(player(enemy2, team: "Red", agent: jett, score: 200, k: 2, d: 1, a: 0)),
        \(player("dddddddd-0000-0000-0000-000000000004", team: "Neutral", agent: jett, score: 0, k: 0, d: 0, a: 0, observer: true))
      ],
      "bots": [], "coaches": [],
      "teams": [{"teamId": "Blue", "won": true, "roundsPlayed": 3, "roundsWon": 2, "numPoints": 2, "mvp": "", "tempR": 0},
                {"teamId": "Red", "won": false, "roundsPlayed": 3, "roundsWon": 1, "numPoints": 1, "mvp": "", "tempR": 0}],
      "roundResults": [
        {"roundNum": 0, "roundResult": "Eliminated", "roundResultCode": "Elimination", "roundCeremony": "CeremonyDefault",
         "winningTeam": "Blue", "winningTeamRole": "Defender", "firstBloodPlayer": "\(me)", "plantSite": "", "plantRoundTime": 0, "defuseRoundTime": 0,
         "playerStats": [
           \(stat(me, kills: [kill(me, enemy1, at: 10000), kill(me, enemy2, at: 20000)], damage: myDamage)),
           \(stat(mate)), \(stat(enemy1)), \(stat(enemy2))
         ],
         "playerEconomies": [\(economy(me, loadout: 3900)), \(economy(mate, loadout: 3100)), \(economy(enemy1, loadout: 800)), \(economy(enemy2, loadout: 900))],
         "playerScores": null},
        {"roundNum": 1, "roundResult": "Bomb detonated", "roundResultCode": "Detonate", "roundCeremony": "CeremonyDefault",
         "winningTeam": "Red", "winningTeamRole": "Attacker", "firstBloodPlayer": "\(enemy1)", "bombPlanter": "\(enemy1)", "plantSite": "A", "plantRoundTime": 60000,
         "defuseRoundTime": 0,
         "playerStats": [
           \(stat(me)), \(stat(mate, kills: [kill(mate, enemy1, at: 8000)])),
           \(stat(enemy1, kills: [kill(enemy1, me, at: 5000)])), \(stat(enemy2, kills: [kill(enemy2, mate, at: 30000)]))
         ],
         "playerEconomies": null},
        {"roundNum": 2, "roundResult": "Bomb defused", "roundResultCode": "Defuse", "roundCeremony": "CeremonyCloser",
         "winningTeam": "Blue", "bombDefuser": "\(me)", "defuseRoundTime": 90000, "plantSite": "B", "bombPlanter": "\(enemy2)", "plantRoundTime": 45000,
         "playerStats": [
           \(stat(me, kills: [kill(me, enemy1, at: 1000, item: "Ultimate", type: "Ability", assists: [mate])])), \(stat(mate)),
           \(stat(enemy1)), \(stat(enemy2, kills: [kill(enemy2, mate, at: 2000)]))
         ]}
      ],
      "kills": [],
      "matchMvp": "\(me)",
      "hasTempValues": true
    }
    """

    static let custom = """
    {
      "matchInfo": {"matchId": "match-custom-1", "mapId": "/Game/Maps/Skirmish/Skirmish_A", "gameMode": "/Game/GameModes/Skirmish/SkirmishGameMode.SkirmishGameMode_C",
        "queueID": "", "provisioningFlowID": "CustomGame", "gameStartMillis": 1789000000000, "gameLengthMillis": 180000,
        "seasonId": "", "isRanked": false, "completionState": "Completed"},
      "players": [\(player(me, team: "Blue", agent: jett, score: 300, k: 1, d: 0, a: 0)), \(player(enemy1, team: "Red", agent: sova, score: 0, k: 0, d: 1, a: 0))],
      "teams": [{"teamId": "Blue", "won": true, "roundsWon": 1, "numPoints": 1}, {"teamId": "Red", "won": false, "roundsWon": 0, "numPoints": 0}],
      "roundResults": [
        {"roundNum": 0, "roundResultCode": "Elimination", "winningTeam": "Blue", "firstBloodPlayer": "\(me)", "playerEconomies": null, "playerScores": null,
         "playerStats": [
           \(stat(me, kills: [kill(me, enemy1, at: 3000, item: "5F0AAF7A-4289-3998-D5FF-EB9A5CF7EF5C")],
                  economy: #"{"loadoutValue": 0, "weapon": "", "armor": "", "remaining": 0, "spent": 0}"#)),
           \(stat(enemy1, economy: #"{"loadoutValue": 0, "weapon": "", "armor": "", "remaining": 0, "spent": 0}"#))
         ]}
      ],
      "matchMvp": ""
    }
    """

    static let deathmatch = """
    {
      "matchInfo": {"matchId": "match-dm-1", "mapId": "/Game/Maps/Ascent/Ascent", "queueID": "deathmatch", "provisioningFlowID": "Matchmaking",
        "gameStartMillis": 1789500000000, "gameLengthMillis": 540000, "isRanked": false, "completionState": "Completed"},
      "players": [\(player(me, team: me, agent: jett, score: 2000, k: 25, d: 20, a: 0)),
                  \(player(enemy1, team: enemy1, agent: sova, score: 2600, k: 40, d: 12, a: 0)),
                  \(player(enemy2, team: enemy2, agent: jett, score: 900, k: 10, d: 30, a: 0))],
      "teams": null,
      "roundResults": null,
      "kills": null
    }
    """

    static func history(_ ids: [String], start: Int = 0, total: Int) -> String {
        let entries = ids.enumerated().map { index, id in
            #"{"MatchID": "\#(id)", "GameStartTime": \#(1790000000000 - index * 3_600_000), "QueueID": "competitive"}"#
        }
        return #"{"Subject": "x", "BeginIndex": \#(start), "EndIndex": \#(start + 20), "Total": \#(total), "History": [\#(entries.joined(separator: ","))]}"#
    }

    /// Specific enough not to catch the RR route, which uses the same index parameters.
    static func historyRoute(_ start: Int) -> String {
        "/v1/history/\(me)?startIndex=\(start)&"
    }

    static func details(id: String, start: Int = 1790000000000) -> String {
        competitive
            .replacingOccurrences(of: "MATCH-COMP-1", with: id)
            .replacingOccurrences(of: "\"gameStartMillis\": 1790000000000", with: "\"gameStartMillis\": \(start)")
    }

    static let updates = """
    {"Version": 1, "Subject": "x", "Matches": [
      {"MatchID": "MATCH-COMP-1", "MapID": "/Game/Maps/Ascent/Ascent", "SeasonID": "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b", "MatchStartTime": 1790000000000,
       "TierAfterUpdate": 18, "TierBeforeUpdate": 17, "RankedRatingAfterUpdate": 12, "RankedRatingBeforeUpdate": 88, "RankedRatingEarned": 24,
       "RankedRatingPerformanceBonus": 0, "CompetitiveMovement": "MOVEMENT_UNKNOWN", "AFKPenalty": 0, "IsPlacementMatch": false, "RRPenalty": 0.0, "QueueID": "competitive"}
    ]}
    """

    static let mmr = """
    {"Version": 1, "Subject": "x", "NewPlayerExperienceFinished": true,
     "QueueSkills": {
       "competitive": {"TotalGamesNeededForRating": 5, "SeasonalInfoBySeasonID": {
         "8102CD81-43A0-D0D7-BD59-47B8FE9BED1B": {"SeasonID": "8102cd81-43a0-d0d7-bd59-47b8fe9bed1b", "NumberOfWins": 14, "NumberOfGames": 25,
           "CompetitiveTier": 18, "RankedRating": 12, "WinsByTier": {"17": 3}, "Prestige": {"GOLD": {"Delta": 0, "Total": 1}}},
         "old-act": {"SeasonID": "old-act", "NumberOfWins": 2, "NumberOfGames": 3, "CompetitiveTier": 9, "RankedRating": 40, "WinsByTier": null}}},
       "deathmatch": {"SeasonalInfoBySeasonID": null}},
     "LatestCompetitiveUpdate": {"MatchID": "MATCH-COMP-1", "TierAfterUpdate": 18, "RankedRatingAfterUpdate": 12},
     "LifetimePrestige": {"GOLD": {"Count": 1}}}
    """

    static let content = """
    {"DisabledIDs": [], "Events": [], "Seasons": [
      {"ID": "ep-26", "Name": "V26", "Type": "episode", "StartTime": "2026-06-01T00:00:00Z", "EndTime": "2026-12-01T00:00:00Z", "IsActive": true},
      {"ID": "old-act", "Name": "ACT IV", "Type": "act", "IsActive": false},
      {"ID": "8102CD81-43A0-D0D7-BD59-47B8FE9BED1B", "Name": "ACT V", "Type": "act", "IsActive": true}
    ]}
    """

    /// A Riot mock that signs in and answers every match endpoint with the fixtures above.
    static func riot() -> MockHTTP {
        let http = MockHTTP()
        http.on("auth.riotgames.com/authorize") { _ in
            HTTPResponse(status: 303, headers: ["Location": Fixtures.successLocation])
        }
        http.on("valorant-api.com/v1/version", json: #"{"data": {"riotClientVersion": "release-13.05-shipping-11-5350494"}}"#)
        http.on("entitlements.auth.riotgames.com", json: #"{"entitlements_token": "ENT"}"#)
        // The mock picks the last matching route, and the mmr path is a prefix of the updates path.
        http.on("/mmr/v1/players/\(Fixtures.puuid)", json: mmr)
        http.on("/competitiveupdates", json: updates)
        http.on("/content-service/v3/content", json: content)
        return http
    }

    static let session = RiotSession(cookies: RiotCookies(["ssid": "S"]), puuid: Fixtures.puuid, shard: "ap")
}
