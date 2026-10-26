import SwiftUI
import ValorantCore

/// One agent within the current scope: stats, maps played on it, guns used on it.
struct AgentPage: View {
    @Environment(MatchesModel.self) private var matches
    let id: String
    @State private var tab = Tab.stats

    enum Tab: String, CaseIterable {
        case stats = "Stats", maps = "Maps", guns = "Guns"
    }

    var body: some View {
        let career = matches.career { $0.agent == id }
        let agent = matches.assets?.agent(id)
        ScrollView {
            VStack(spacing: 12) {
                hero(career, agent)
                if career.games == 0 {
                    EmptyScope()
                } else {
                    PillTabs(Tab.allCases.map { ($0, $0.rawValue) }, selection: $tab)
                    switch tab {
                    case .stats: stats(career)
                    case .maps: maps(career)
                    case .guns: KillBars(lines: career.guns).statCard()
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 110)
            .animation(.smooth, value: tab)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(tint: agent?.tint ?? Theme.violet, secondary: Theme.violet))
    }

    private func hero(_ career: CareerStats, _ agent: MatchAssets.AgentInfo?) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(agent?.role ?? "Agent") · \(career.games == 1 ? "1 game" : "\(career.games) games")".uppercased())
                    .font(Theme.label(9)).tracking(1.4)
                    .foregroundStyle(agent?.tint ?? Theme.accent)
                Text((agent?.name ?? "Agent").uppercased())
                    .font(Theme.display(50))
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
            Spacer(minLength: 0)
            FillImage(url: agent?.portrait ?? agent?.icon, alignment: .top)
                .frame(width: 150, height: 180)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .frame(maxWidth: .infinity)
        .background {
            RadialGradient(colors: [(agent?.tint ?? Theme.violet).opacity(0.6), .clear], center: .bottomTrailing,
                           startRadius: 5, endRadius: 280)
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private func stats(_ career: CareerStats) -> some View {
        VStack(spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    StatCell(label: "K/D", value: StatText.kd(career.kd), size: 28)
                    StatCell(label: "Avg PS", value: StatText.number(career.performance), size: 28)
                    StatCell(label: "HS%", value: StatText.percent(career.shots.percent(\.head)), size: 28)
                }
                GridRow {
                    StatCell(label: "ADR", value: StatText.number(career.adr), size: 28)
                    StatCell(label: "KAST", value: StatText.percent(career.kast), size: 28)
                    StatCell(label: "FK · FD", value: "\(career.firstKills)·\(career.firstDeaths)", size: 28)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .statCard()
            HStack(spacing: 8) {
                StatTileSmall(label: "3K", value: "\(career.multiKills[1])")
                StatTileSmall(label: "4K", value: "\(career.multiKills[2])")
                StatTileSmall(label: "Ace", value: "\(career.multiKills[3])", tint: Theme.gold)
                StatTileSmall(label: "Clutch", value: StatText.record(career.clutch))
            }
        }
    }

    private func maps(_ career: CareerStats) -> some View {
        VStack(spacing: 8) {
            ForEach(career.maps) { line in
                NavigationLink(value: MapRoute(url: line.key)) {
                    LineRow(title: matches.assets?.map(line.key)?.name ?? "Map", image: matches.assets?.map(line.key)?.banner,
                            wide: true, line: line)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .statCard(padding: 12)
    }
}

/// A map or agent with its record, win % and K/D, for the small lists on the agent and map pages.
struct LineRow: View {
    let title: String
    let image: URL?
    var wide = false
    let line: CareerStats.Line

    var body: some View {
        HStack(spacing: 10) {
            RemoteImage(url: image, contentMode: wide ? .fill : .fit)
                .frame(width: wide ? 64 : 34, height: 34)
                .clipShape(.rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(Theme.label(10)).tracking(0.8).lineLimit(1)
                Text(line.games == 1 ? "1 GAME" : "\(line.games) GAMES").font(Theme.label(8)).foregroundStyle(Theme.textFaint)
            }
            Spacer(minLength: 4)
            Text(StatText.wins(line.wins, line.games))
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textDim)
            Text("\(line.winRate)%")
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .foregroundStyle(line.winRate >= 50 ? Theme.win : Theme.loss)
                .frame(width: 44, alignment: .trailing)
            Text(StatText.kd(line.kd))
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
