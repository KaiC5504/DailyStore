import Charts
import SwiftUI
import ValorantCore

enum MatchTab: String, CaseIterable {
    case summary = "Summary", scoreboard = "Scoreboard", duels = "Duels", economy = "Economy"
}

/// Rounds worth a second look, as chips in round order.
struct MomentsRow: View {
    let moments: [Moment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Moments")
                .padding(.horizontal, Theme.gutter)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(moments.indices, id: \.self) { index in
                        chip(moments[index])
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(_ moment: Moment) -> some View {
        let (text, color): (String, Color) = switch moment.kind {
        case .ace: ("Ace", Theme.gold)
        case .quad: ("4K", Theme.gold)
        case .triple: ("3K", .white)
        case let .clutch(enemies): ("Clutch 1v\(enemies)", Theme.win)
        case .ecoWin: ("Eco win", Theme.gold)
        case .defuse: ("Defuse", Theme.defense)
        }
        return HStack(spacing: 5) {
            Text("R\(moment.round + 1)").font(Theme.label(9)).foregroundStyle(Theme.textDim)
            Text(text.uppercased()).font(Theme.label(10)).tracking(0.6).foregroundStyle(color)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.16), in: .capsule)
    }
}

/// Every player's numbers in one table: names stay put while the columns scroll sideways.
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

    /// The owner's side first, each sorted by rating; free-for-all modes are one list by kills.
    static func ordered(_ match: Match, me: String) -> [Block] {
        guard match.hasSides, let mine = match.player(me)?.team else {
            return [Block(title: "Players", score: nil, color: .white,
                          players: match.players.sorted { ($0.kills, $0.score) > ($1.kills, $1.score) })]
        }
        return match.teams.sorted { ($0.id == mine ? 0 : 1) < ($1.id == mine ? 0 : 1) }.map { team in
            Block(title: team.id == mine ? "Your team" : "Enemy team", score: team.roundsWon,
                  color: team.id == mine ? Theme.win : Theme.loss,
                  players: match.players.filter { $0.team == team.id }.sorted { match.rating($0) > match.rating($1) })
        }
    }

    private static let rowHeight: CGFloat = 46
    private static let labelHeight: CGFloat = 28

    private var columns: [(title: String, width: CGFloat)] {
        [(match.ratingLabel, 46), ("K/D/A", 72), ("ADR", 44), ("DDΔ", 46), ("HS", 44), ("KAST", 48), ("FK", 32), ("FD", 32), ("MK", 32)]
    }

    var body: some View {
        let blocks = Self.ordered(match, me: me)
        let party = match.player(me)?.party
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("PLAYER").font(Theme.label(8)).tracking(1).foregroundStyle(Theme.textFaint)
                    .frame(height: 22, alignment: .leading)
                ForEach(blocks, id: \.title) { block in
                    blockLabel(block)
                    ForEach(Array(block.players.enumerated()), id: \.element.id) { index, player in
                        Button { select(player) } label: {
                            nameCell(player, place: match.hasSides ? nil : index + 1, color: block.color,
                                     partied: player.id != me && !player.party.isEmpty && player.party == party)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 138)
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns.indices, id: \.self) { index in
                            Text(columns[index].title).frame(width: columns[index].width, alignment: .trailing)
                        }
                    }
                    .font(Theme.label(8)).tracking(1)
                    .foregroundStyle(Theme.textFaint)
                    .frame(height: 22)
                    ForEach(blocks, id: \.title) { block in
                        Color.clear.frame(height: Self.labelHeight)
                        ForEach(block.players) { player in
                            Button { select(player) } label: { valueRow(player) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            .scrollIndicators(.hidden)
        }
        .statCard(padding: 10)
    }

    private func blockLabel(_ block: Block) -> some View {
        HStack(spacing: 6) {
            Text(block.title.uppercased()).font(Theme.label(9)).tracking(1.2).foregroundStyle(block.color)
            if let score = block.score {
                Text("\(score)").font(.system(size: 12, weight: .heavy).monospacedDigit())
            }
        }
        .frame(height: Self.labelHeight, alignment: .bottomLeading)
    }

    private func nameCell(_ player: Match.Player, place: Int?, color: Color, partied: Bool) -> some View {
        let agent = matches.assets?.agent(player.agent)
        let tier = matches.assets?.tier(player.tier)
        return HStack(spacing: 7) {
            if let place {
                Text("\(place)").font(Theme.display(16)).frame(width: 18)
            }
            RemoteImage(url: agent?.icon)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.18), in: .rect(cornerRadius: 8))
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(player.name.isEmpty ? (agent?.name ?? "Player") : player.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    if match.mvp == player.id {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(Theme.gold)
                    }
                    if partied {
                        Image(systemName: "person.2.fill").font(.system(size: 7)).foregroundStyle(Theme.textDim)
                    }
                }
                HStack(spacing: 3) {
                    if player.tier >= 3 {
                        RemoteImage(url: tier?.icon).frame(width: 12, height: 12)
                    }
                    Text(player.tag.isEmpty ? (agent?.name ?? "") : "#\(player.tag)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .frame(height: Self.rowHeight)
        .background(player.id == me ? Theme.win.opacity(0.16) : .clear, in: .rect(cornerRadii: .init(topLeading: 10, bottomLeading: 10)))
        .contentShape(.rect)
    }

    private func valueRow(_ player: Match.Player) -> some View {
        let rounds = match.hasRounds
        let delta = match.ddDelta(player)
        let values: [(String, Color)] = [
            ("\(match.rating(player))", .white),
            ("\(player.kills)/\(player.deaths)/\(player.assists)", .white),
            (StatText.number(match.adr(player)), .white),
            (StatText.signed(delta), delta.map { $0 >= 0 ? Theme.win : Theme.loss } ?? Theme.textFaint),
            (StatText.percent(match.headshotPercent(player)), .white),
            (StatText.percent(match.kast(player)), .white),
            (rounds ? "\(match.firstBloods(player))" : "–", .white),
            (rounds ? "\(match.firstDeaths(player))" : "–", .white),
            (rounds ? "\(match.multiKillRounds(player))" : "–", .white),
        ]
        return HStack(spacing: 0) {
            ForEach(values.indices, id: \.self) { index in
                Text(values[index].0)
                    .foregroundStyle(values[index].1)
                    .frame(width: columns[index].width, alignment: .trailing)
            }
        }
        .font(.system(size: 13, weight: .heavy).monospacedDigit())
        .frame(height: Self.rowHeight)
        .background(player.id == me ? Theme.win.opacity(0.16) : .clear, in: .rect(cornerRadii: .init(bottomTrailing: 10, topTrailing: 10)))
        .contentShape(.rect)
    }
}

/// Kills on and deaths to each opponent, kills growing left and deaths right from a centre line.
struct DuelBars: View {
    @Environment(MatchesModel.self) private var matches
    let match: Match
    let me: String
    @State private var grown = false

    var body: some View {
        let duels = match.player(me).map { match.duels($0) }?.filter { $0.kills + $0.deaths > 0 } ?? []
        let most = max(duels.map { max($0.kills, $0.deaths) }.max() ?? 1, 1)
        VStack(spacing: 10) {
            HStack {
                Spacer().frame(width: 112)
                Text("KILLS").foregroundStyle(Theme.win).frame(maxWidth: .infinity, alignment: .trailing)
                Text("·").foregroundStyle(Theme.textFaint)
                Text("DEATHS").foregroundStyle(Theme.loss).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Theme.label(8)).tracking(1.2)
            if duels.isEmpty {
                Text("–").font(Theme.display(22)).foregroundStyle(Theme.textFaint)
            }
            ForEach(duels, id: \.opponent.id) { duel in
                let agent = matches.assets?.agent(duel.opponent.agent)
                HStack(spacing: 8) {
                    RemoteImage(url: agent?.icon)
                        .frame(width: 28, height: 28)
                        .clipShape(.rect(cornerRadius: 7))
                    Text(duel.opponent.name.isEmpty ? (agent?.name ?? "Player") : duel.opponent.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .frame(width: 76, alignment: .leading)
                    bar(duel.kills, most, Theme.win, leading: false)
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 22)
                    bar(duel.deaths, most, Theme.loss, leading: true)
                }
            }
        }
        .statCard()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { grown = true }
        }
    }

    private func bar(_ count: Int, _ most: Int, _ color: Color, leading: Bool) -> some View {
        GeometryReader { proxy in
            let width = (proxy.size.width - 22) * CGFloat(count) / CGFloat(most)
            HStack(spacing: 4) {
                if leading { Spacer(minLength: 0).frame(width: 0) }
                if !leading { Spacer(minLength: 0) }
                if !leading { label(count) }
                Capsule().fill(color.gradient).frame(width: max(width, count > 0 ? 4 : 0), height: 10)
                    .scaleEffect(x: grown ? 1 : 0.02, anchor: leading ? .leading : .trailing)
                if leading { label(count) }
                if leading { Spacer(minLength: 0) }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 28)
    }

    private func label(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 13, weight: .heavy).monospacedDigit())
            .foregroundStyle(count > 0 ? .white : Theme.textFaint)
    }
}

/// Each team's average loadout per round, your bars coloured by whether the round was won.
struct EconomyTab: View {
    let match: Match
    let me: String

    private struct Point: Identifiable {
        let round: Int
        let team: String
        let loadout: Int
        let color: Color
        var id: String { "\(round)\(team)" }
    }

    var body: some View {
        let mine = match.player(me)
        let team = mine?.team ?? ""
        let enemy = match.teams.first { $0.id != team }?.id ?? ""
        let points = match.playedRounds.flatMap { round -> [Point] in
            let won = round.winner == team
            return [
                Point(round: round.number + 1, team: "You", loadout: match.teamLoadout(team, in: round) ?? 0,
                      color: won ? Theme.win : Theme.loss),
                Point(round: round.number + 1, team: "Them", loadout: match.teamLoadout(enemy, in: round) ?? 0,
                      color: .white.opacity(0.28)),
            ]
        }
        let spent = match.playedRounds.flatMap(\.players).filter { $0.id == me }.reduce(0) { $0 + $1.spent }
        let cheap = match.playedRounds.filter { [.eco, .force].contains(match.buy(of: team, in: $0)) }
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("Loadout")
                    Spacer()
                    legend(Theme.win, "Your team")
                    legend(.white.opacity(0.28), "Them")
                }
                Chart(points) { point in
                    BarMark(x: .value("Round", "\(point.round)"), y: .value("Loadout", point.loadout))
                        .foregroundStyle(point.color)
                        .position(by: .value("Team", point.team))
                        .clipShape(.rect(cornerRadius: 2))
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.system(size: 8, weight: .bold)) }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 2000, 4000]) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel { Text("\((value.as(Int.self) ?? 0) / 1000)K").font(.system(size: 8, weight: .bold)) }
                    }
                }
                .frame(height: 170)
            }
            .statCard()
            HStack(spacing: 8) {
                StatTileSmall(label: "You spent", value: String(format: "%.1fK", Double(spent) / 1000))
                StatTileSmall(label: "Econ rating", value: StatText.number(mine.flatMap(match.econRating)))
                StatTileSmall(label: "Eco + force", value: "\(cheap.filter { $0.winner == team }.count) of \(cheap.count)")
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text.uppercased()).font(Theme.label(7)).tracking(0.8).foregroundStyle(Theme.textDim)
        }
    }
}
