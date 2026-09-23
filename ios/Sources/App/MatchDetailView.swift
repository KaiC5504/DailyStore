import SwiftUI
import ValorantCore

struct MatchDetailView: View {
    @Environment(MatchesModel.self) private var matches
    let id: String
    @State private var match: Match?
    @State private var loaded = false
    @State private var round: Match.Round?
    @State private var player: Match.Player?

    private var me: String { matches.puuid ?? "" }

    var body: some View {
        ScrollView {
            if let match {
                VStack(alignment: .leading, spacing: 16) {
                    MatchHeader(match: match, me: me, rr: matches.summaries.first { $0.id == match.id }?.rrEarned)
                    if let mine = match.player(me) {
                        PerformanceCard(match: match, player: mine, title: "Your game")
                            .padding(.horizontal, Theme.gutter)
                    }
                    if match.hasRounds {
                        RoundsStrip(match: match, me: me) { round = $0 }
                    }
                    Scoreboard(match: match, me: me) { player = $0 }
                        .padding(.horizontal, Theme.gutter)
                }
                .padding(.bottom, 40)
            } else if loaded {
                ContentUnavailableView("Match not saved", systemImage: "externaldrive.badge.xmark",
                                       description: Text("Pull to refresh the match list and try again."))
                    .padding(.top, 120)
            } else {
                ProgressView().tint(.white).padding(.top, 160)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AmbientBackground(tint: match.map { $0.outcome(for: me).color } ?? Theme.accent, secondary: Theme.violet))
        .sheet(item: $round) { round in
            if let match { RoundSheet(match: match, round: round, me: me) }
        }
        .sheet(item: $player) { player in
            if let match { PlayerMatchSheet(match: match, player: player, me: me) }
        }
        .task {
            match = await matches.match(id)
            loaded = true
            #if DEBUG
            let defaults = UserDefaults.standard
            if let match, match.rounds.indices.contains(defaults.integer(forKey: "DemoRound") - 1) {
                round = match.rounds[defaults.integer(forKey: "DemoRound") - 1]
            }
            if let match, match.players.indices.contains(defaults.integer(forKey: "DemoPlayer") - 1) {
                player = Scoreboard.ordered(match, me: me).flatMap(\.players)[defaults.integer(forKey: "DemoPlayer") - 1]
            }
            #endif
        }
    }
}

private struct MatchHeader: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let me: String
    let rr: Int?

    var body: some View {
        let outcome = match.outcome(for: me)
        let map = matches.assets?.map(match.mapURL)
        ZStack(alignment: .bottomLeading) {
            FillImage(url: map?.splash)
                .frame(height: 300)
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.6), Theme.ink], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(matches.queueName(match.isCustom ? MatchesModel.customFilter : match.queue)) · \(map?.name ?? "Unknown map")".uppercased())
                    .font(Theme.label(11)).tracking(2)
                    .foregroundStyle(Theme.textDim)
                Text(outcome.label)
                    .font(Theme.display(64))
                    .foregroundStyle(outcome.color)
                    .shadow(color: outcome.color.opacity(0.5), radius: 20)
                HStack(alignment: .center, spacing: 12) {
                    if let score = match.score(for: me) {
                        Text("\(score.mine) : \(score.theirs)")
                            .font(Theme.display(40))
                            .monospacedDigit()
                    }
                    if let rr { RRChip(earned: rr) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(match.start.formatted(date: .abbreviated, time: .shortened))
                        Text("\(Int(match.length / 60)) min")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 4)
        }
    }
}

struct PerformanceCard: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let player: Match.Player
    let title: String

    var body: some View {
        let agent = matches.assets?.agent(player.agent)
        HStack(alignment: .bottom, spacing: 0) {
            FillImage(url: agent?.portrait ?? agent?.icon, alignment: .top)
                .frame(width: 96, height: 150)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 10) {
                Text(title.uppercased())
                    .font(Theme.label(10)).tracking(1.6)
                    .foregroundStyle(Theme.textDim)
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow {
                        StatCell(label: match.hasRounds ? "ACS" : "SCORE", value: "\(match.hasRounds ? match.acs(player) : player.score)")
                        StatCell(label: "K / D / A", value: "\(player.kills)/\(player.deaths)/\(player.assists)")
                        StatCell(label: "HS", value: match.headshotPercent(player).map { "\($0)%" } ?? "–")
                    }
                    GridRow {
                        StatCell(label: "ADR", value: match.adr(player).map(String.init) ?? "–")
                        StatCell(label: "FIRST BL.", value: match.hasRounds ? "\(match.firstBloods(player))" : "–")
                        StatCell(label: "KAST", value: match.kast(player).map { "\($0)%" } ?? "–")
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
        .background {
            RadialGradient(colors: [(agent?.tint ?? Theme.violet).opacity(0.5), .clear], center: .bottomLeading,
                           startRadius: 5, endRadius: 220)
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius))
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(Theme.label(8)).tracking(1).foregroundStyle(Theme.textFaint)
            Text(value).font(Theme.display(24)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

private struct RoundsStrip: View {
    let match: Match
    let me: String
    let select: (Match.Round) -> Void

    /// Where sides swap; Riot doesn't say, so it follows each mode's rules.
    private var halftime: Int {
        switch match.queue {
        case "swiftplay": 4
        case "spikerush": 3
        default: 12
        }
    }

    var body: some View {
        let team = match.player(me)?.team
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Rounds · tap one for its kill feed")
                .padding(.horizontal, Theme.gutter)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(match.rounds) { round in
                        if round.number == halftime {
                            Capsule().fill(.white.opacity(0.25)).frame(width: 2, height: 40).padding(.horizontal, 4)
                        }
                        Button { select(round) } label: {
                            RoundChip(round: round, won: round.winner == team)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct RoundChip: View {
    let round: Match.Round
    let won: Bool

    var body: some View {
        let color = won ? Theme.win : Theme.loss
        VStack(spacing: 5) {
            Text("\(round.number + 1)")
                .font(.system(size: 11, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.textDim)
            Image(systemName: round.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 54)
        .glassEffect(.regular.tint(color.opacity(won ? 0.25 : 0.12)).interactive(), in: .rect(cornerRadius: 10))
    }
}

struct Scoreboard: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let me: String
    let select: (Match.Player) -> Void

    struct Block {
        let title: String
        let score: Int?
        let color: Color
        let players: [Match.Player]
    }

    /// The owner's side first, each sorted by ACS; free-for-all modes are one list by kills.
    static func ordered(_ match: Match, me: String) -> [Block] {
        guard match.hasSides, let mine = match.player(me)?.team else {
            return [Block(title: "Players", score: nil, color: .white,
                          players: match.players.sorted { ($0.kills, $0.score) > ($1.kills, $1.score) })]
        }
        return match.teams.sorted { ($0.id == mine ? 0 : 1) < ($1.id == mine ? 0 : 1) }.map { team in
            Block(title: team.id == mine ? "Your team" : "Enemy team", score: team.roundsWon,
                  color: team.id == mine ? Theme.win : Theme.loss,
                  players: match.players.filter { $0.team == team.id }.sorted { match.acs($0) > match.acs($1) })
        }
    }

    var body: some View {
        let party = match.player(me)?.party
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Self.ordered(match, me: me), id: \.title) { block in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SectionLabel(block.title)
                        Spacer()
                        Text(match.hasRounds ? "ACS" : "SCORE").frame(width: 50, alignment: .trailing)
                        Text("K / D / A").frame(width: 76, alignment: .trailing)
                    }
                    .font(Theme.label(8)).tracking(1)
                    .foregroundStyle(Theme.textFaint)
                    ForEach(Array(block.players.enumerated()), id: \.element.id) { index, player in
                        Button { select(player) } label: {
                            row(player, place: match.hasSides ? nil : index + 1, color: block.color,
                                isMe: player.id == me, partied: player.id != me && !player.party.isEmpty && player.party == party)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func row(_ player: Match.Player, place: Int?, color: Color, isMe: Bool, partied: Bool) -> some View {
        let agent = matches.assets?.agent(player.agent)
        let tier = matches.assets?.tier(player.tier)
        return HStack(spacing: 10) {
            if let place {
                Text("\(place)").font(Theme.display(18)).frame(width: 22)
            }
            RemoteImage(url: agent?.icon)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.18), in: .rect(cornerRadius: 9))
                .clipShape(.rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(player.name.isEmpty ? (agent?.name ?? "Player") : player.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    if match.mvp == player.id {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.newItem)
                    }
                    if partied {
                        Image(systemName: "person.2.fill").font(.system(size: 9)).foregroundStyle(Theme.textDim)
                    }
                }
                HStack(spacing: 4) {
                    if player.tier >= 3 {
                        RemoteImage(url: tier?.icon).frame(width: 14, height: 14)
                    }
                    Text(player.tag.isEmpty ? (agent?.name ?? "") : "#\(player.tag)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text("\(match.hasRounds ? match.acs(player) : player.score)")
                .frame(width: 50, alignment: .trailing)
            Text("\(player.kills)/\(player.deaths)/\(player.assists)")
                .frame(width: 76, alignment: .trailing)
        }
        .font(.system(size: 14, weight: .heavy).monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(isMe ? .regular.tint(color.opacity(0.3)) : .regular, in: .rect(cornerRadius: Theme.chipRadius))
    }
}

struct RoundSheet: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let round: Match.Round
    let me: String

    private enum Event: Identifiable {
        case kill(Match.Kill, Int)
        case plant(String?, String?, Int)
        case defuse(String?, Int)

        var id: String {
            switch self {
            case let .kill(_, index): "k\(index)"
            case .plant: "plant"
            case .defuse: "defuse"
            }
        }

        var time: Int {
            switch self {
            case let .kill(kill, _): kill.time
            case let .plant(_, _, time), let .defuse(_, time): time
            }
        }
    }

    private var events: [Event] {
        var events = round.kills.enumerated().map { Event.kill($1, $0) }
        if let time = round.plantTime { events.append(.plant(round.planter, round.plantSite, time)) }
        if let time = round.defuseTime { events.append(.defuse(round.defuser, time)) }
        return events.sorted { $0.time < $1.time }
    }

    private var myTeam: String? { match.player(me)?.team }

    var body: some View {
        let won = round.winner == myTeam
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUND \(round.number + 1)")
                        .font(Theme.display(40))
                    Text("\(won ? "Won" : "Lost") · \(round.resultText)")
                        .font(Theme.label(11)).tracking(1.2)
                        .foregroundStyle(won ? Theme.win : Theme.loss)
                }
                SectionLabel("Kill feed")
                if events.isEmpty {
                    Text("No kills recorded this round.").font(.footnote).foregroundStyle(Theme.textDim)
                }
                ForEach(events) { event in
                    switch event {
                    case let .kill(kill, _): killRow(kill)
                    case let .plant(planter, site, time):
                        objectiveRow(time: time, symbol: "flame.fill", text: "\(name(planter)) planted\(site.map { " on \($0)" } ?? "")")
                    case let .defuse(defuser, time):
                        objectiveRow(time: time, symbol: "wrench.adjustable.fill", text: "\(name(defuser)) defused")
                    }
                }
                if round.players.contains(where: { $0.loadout > 0 }) {
                    SectionLabel("Loadouts")
                    ForEach(loadoutOrder, id: \.id) { economy in economyRow(economy) }
                }
            }
            .padding(Theme.gutter)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var loadoutOrder: [Match.RoundPlayer] {
        round.players.sorted { a, b in
            let teamA = match.player(a.id)?.team == myTeam
            let teamB = match.player(b.id)?.team == myTeam
            return teamA != teamB ? teamA : a.loadout > b.loadout
        }
    }

    private func name(_ id: String?) -> String {
        guard let id, let player = match.player(id) else { return "Someone" }
        return player.name.isEmpty ? (matches.assets?.agent(player.agent)?.name ?? "Player") : player.name
    }

    private func color(_ id: String) -> Color {
        match.player(id)?.team == myTeam ? Theme.win : Theme.loss
    }

    private func killRow(_ kill: Match.Kill) -> some View {
        let killer = match.player(kill.killer)
        let victim = match.player(kill.victim)
        return HStack(spacing: 8) {
            Text(clock(kill.time))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.textFaint)
                .frame(width: 34, alignment: .leading)
            PlayerTag(player: killer, name: name(kill.killer), color: color(kill.killer), isMe: kill.killer == me)
            Spacer(minLength: 4)
            KillWeapon(kill: kill, killerAgent: killer?.agent)
            Spacer(minLength: 4)
            PlayerTag(player: victim, name: name(kill.victim), color: color(kill.victim), isMe: kill.victim == me, trailing: true)
                .opacity(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func objectiveRow(time: Int, symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(clock(time))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.textFaint)
                .frame(width: 34, alignment: .leading)
            Image(systemName: symbol).foregroundStyle(Theme.newItem)
            Text(text).font(.footnote.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(Theme.newItem.opacity(0.12)), in: .rect(cornerRadius: 12))
    }

    private func economyRow(_ economy: Match.RoundPlayer) -> some View {
        let player = match.player(economy.id)
        let weapon = matches.assets?.weapon(economy.weapon)
        return HStack(spacing: 10) {
            RemoteImage(url: player.flatMap { matches.assets?.agent($0.agent)?.icon })
                .frame(width: 26, height: 26)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(name(economy.id)).font(.caption.weight(.bold)).foregroundStyle(color(economy.id)).lineLimit(1)
                Text([weapon?.name, matches.assets?.armor(economy.armor)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            Spacer()
            RemoteImage(url: weapon?.icon).frame(width: 54, height: 18)
            VStack(alignment: .trailing, spacing: 1) {
                Text(economy.loadout, format: .number).font(.caption.weight(.heavy).monospacedDigit())
                Text("spent \(economy.spent)").font(.caption2.monospacedDigit()).foregroundStyle(Theme.textFaint)
            }
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func clock(_ ms: Int) -> String {
        String(format: "%d:%02d", ms / 60000, (ms / 1000) % 60)
    }
}

private struct PlayerTag: View {
    @Environment(MatchesModel.self) private var matches
    let player: Match.Player?
    let name: String
    let color: Color
    let isMe: Bool
    var trailing = false

    var body: some View {
        HStack(spacing: 5) {
            if trailing { label }
            RemoteImage(url: player.flatMap { matches.assets?.agent($0.agent)?.icon })
                .frame(width: 24, height: 24)
                .background(color.opacity(0.25), in: .rect(cornerRadius: 6))
                .clipShape(.rect(cornerRadius: 6))
            if !trailing { label }
        }
    }

    private var label: some View {
        Text(name)
            .font(.caption.weight(isMe ? .heavy : .semibold))
            .foregroundStyle(isMe ? .white : color)
            .lineLimit(1)
            .frame(maxWidth: 92, alignment: trailing ? .trailing : .leading)
    }
}

/// Weapon art for gun kills, the killer's ability icon for ability kills, a symbol for the rest.
private struct KillWeapon: View {
    @Environment(MatchesModel.self) private var matches
    let kill: Match.Kill
    let killerAgent: String?

    var body: some View {
        if let weapon = matches.assets?.weapon(kill.item), let icon = weapon.icon {
            RemoteImage(url: icon).frame(width: 58, height: 20)
        } else if let agent = killerAgent, let icon = matches.assets?.agent(agent)?.abilities[kill.item] {
            RemoteImage(url: icon).frame(width: 22, height: 22)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textDim)
                .frame(width: 22, height: 20)
        }
    }

    private var symbol: String {
        switch kill.kind {
        case "Bomb": "flame.fill"
        case "Fall": "arrow.down.to.line"
        case "Melee": "hand.raised.fill"
        case "Ability": "sparkles"
        default: "scope"
        }
    }
}

struct PlayerMatchSheet: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let player: Match.Player
    let me: String

    var body: some View {
        let agent = matches.assets?.agent(player.agent)
        let tier = matches.assets?.tier(player.tier)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((agent?.name ?? "Agent").uppercased())
                            .font(Theme.label(10)).tracking(1.6)
                            .foregroundStyle(agent?.tint ?? Theme.accent)
                        Text(player.name.isEmpty ? "Player" : player.name)
                            .font(Theme.display(34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if !player.tag.isEmpty {
                            Text("#\(player.tag)").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textDim)
                        }
                    }
                    Spacer()
                    if player.tier >= 3 {
                        VStack(spacing: 2) {
                            RemoteImage(url: tier?.icon).frame(width: 44, height: 44)
                            Text(tier?.name.uppercased() ?? "").font(Theme.label(8)).tracking(1)
                                .foregroundStyle(tier.map { Color(rgbaHex: $0.color) } ?? Theme.textDim)
                        }
                    }
                }
                PerformanceCard(match: match, player: player, title: player.id == me ? "Your game" : "This match")
                let duels = match.duels(player).filter { $0.kills + $0.deaths > 0 }
                if !duels.isEmpty {
                    SectionLabel("Kills · deaths against")
                    ForEach(duels, id: \.opponent.id) { duel in
                        HStack(spacing: 10) {
                            RemoteImage(url: matches.assets?.agent(duel.opponent.agent)?.icon)
                                .frame(width: 30, height: 30)
                                .clipShape(.rect(cornerRadius: 8))
                            Text(duel.opponent.name.isEmpty ? (matches.assets?.agent(duel.opponent.agent)?.name ?? "Player") : duel.opponent.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(duel.kills)").foregroundStyle(Theme.win)
                            Text("–").foregroundStyle(Theme.textFaint)
                            Text("\(duel.deaths)").foregroundStyle(Theme.loss)
                        }
                        .font(.system(size: 16, weight: .heavy).monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect(cornerRadius: Theme.chipRadius))
                    }
                }
            }
            .padding(Theme.gutter)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

extension Match.Round {
    var symbol: String {
        switch result {
        case "Elimination": "xmark"
        case "Detonate": "flame.fill"
        case "Defuse": "wrench.adjustable.fill"
        case "Surrendered": "flag.fill"
        default: "clock.fill"
        }
    }

    var resultText: String {
        switch result {
        case "Elimination": "Elimination"
        case "Detonate": "Spike detonated"
        case "Defuse": "Spike defused"
        case "Surrendered": "Surrender"
        default: "Time ran out"
        }
    }
}
