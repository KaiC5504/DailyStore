import SwiftUI
import ValorantCore

/// One map within the current scope: sides, sites and the agents played on it.
struct MapPage: View {
    @Environment(MatchesModel.self) private var matches
    let url: String
    @State private var tab = Tab.rounds

    enum Tab: String, CaseIterable {
        case rounds = "Rounds", sites = "Sites", agents = "Agents"
    }

    var body: some View {
        let career = matches.career { $0.mapURL == url }
        ScrollView {
            VStack(spacing: 12) {
                hero(career)
                if career.games == 0 {
                    EmptyScope()
                } else {
                    PillTabs(Tab.allCases.map { ($0, $0.rawValue) }, selection: $tab)
                    switch tab {
                    case .rounds: rounds(career)
                    case .sites: sites(career)
                    case .agents: agents(career)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 110)
            .animation(.smooth, value: tab)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(tint: Theme.defense, secondary: Theme.violet))
    }

    private func hero(_ career: CareerStats) -> some View {
        let map = matches.assets?.map(url)
        return VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text(career.games == 1 ? "1 GAME" : "\(career.games) GAMES")
                .font(Theme.label(9)).tracking(1.4)
                .foregroundStyle(Theme.textDim)
            Text((map?.name ?? "Map").uppercased())
                .font(Theme.display(54))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 6) {
                Text("\(career.wins)W").foregroundStyle(Theme.win)
                Text("\(career.losses)L").foregroundStyle(Theme.loss)
                Text("· \(StatText.percent(career.winRate))").foregroundStyle(Theme.textDim)
            }
            .font(.system(size: 15, weight: .heavy).monospacedDigit())
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .bottomLeading)
        .background {
            ZStack {
                FillImage(url: map?.splash)
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private func rounds(_ career: CareerStats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                side("Attack", career.attack, Theme.attack)
                side("Defense", career.defense, Theme.defense)
            }
            HStack(spacing: 8) {
                StatTileSmall(label: "Pistols", value: StatText.record(career.pistol))
                StatTileSmall(label: "Start atk", value: StatText.wins(career.startAttack.won, career.startAttack.played))
                StatTileSmall(label: "Start def", value: StatText.wins(career.startDefense.won, career.startDefense.played))
            }
        }
    }

    private func side(_ name: String, _ tally: Tally, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name.uppercased()).font(Theme.label(9)).tracking(1.2).foregroundStyle(color)
            Text(StatText.percent(tally.rate)).font(Theme.display(40)).monospacedDigit()
            Text("\(tally.won) of \(tally.played)".uppercased()).font(Theme.label(8)).foregroundStyle(Theme.textFaint)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(color.gradient).frame(width: proxy.size.width * CGFloat(tally.rate ?? 0) / 100)
                }
            }
            .frame(height: 6)
            .padding(.top, 4)
        }
        .statCard()
    }

    private func sites(_ career: CareerStats) -> some View {
        let letters = career.sites.keys.sorted()
        return VStack(spacing: 12) {
            siteList("Attack · after plant", letters.map { ($0, career.sites[$0]!.postPlant) }, unit: "plant", color: Theme.attack)
            siteList("Defense · retakes", letters.map { ($0, career.sites[$0]!.retake) }, unit: "retake", color: Theme.defense)
        }
    }

    private func siteList(_ title: String, _ rows: [(site: String, tally: Tally)], unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            let played = rows.filter { $0.tally.played > 0 }
            if played.isEmpty {
                Text("–").font(Theme.display(22)).foregroundStyle(Theme.textFaint)
            }
            ForEach(played, id: \.site) { row in
                HStack(spacing: 12) {
                    Text(row.site)
                        .font(Theme.display(28))
                        .foregroundStyle(color)
                        .frame(width: 28)
                    Text(row.tally.played == 1 ? "1 \(unit)".uppercased() : "\(row.tally.played) \(unit)s".uppercased())
                        .font(Theme.label(9)).tracking(0.8)
                        .foregroundStyle(Theme.textDim)
                    Spacer()
                    Text(StatText.percent(row.tally.rate))
                        .font(.system(size: 16, weight: .heavy).monospacedDigit())
                        .foregroundStyle((row.tally.rate ?? 0) >= 50 ? Theme.win : Theme.loss)
                }
            }
        }
        .statCard()
    }

    private func agents(_ career: CareerStats) -> some View {
        VStack(spacing: 8) {
            ForEach(career.agents) { line in
                NavigationLink(value: AgentRoute(id: line.key)) {
                    LineRow(title: matches.assets?.agent(line.key)?.name ?? "Agent", image: matches.assets?.agent(line.key)?.icon,
                            line: line)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .statCard(padding: 12)
    }
}
