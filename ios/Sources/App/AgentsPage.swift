import SwiftUI
import ValorantCore

struct AgentsPage: View {
    @Environment(MatchesModel.self) private var matches
    @State private var sort = Sort.games
    @State private var showAll = false

    enum Sort: String, CaseIterable {
        case games = "Games", winRate = "Win %", kd = "K/D"
    }

    private static let shortList = 8

    var body: some View {
        let career = matches.career
        VStack(spacing: 12) {
            if career.games == 0 {
                EmptyScope()
            } else {
                RoleSplit(lines: career.agents)
                if let main = career.agents.first {
                    NavigationLink(value: AgentRoute(id: main.key)) {
                        MainAgentCard(line: main)
                    }
                    .buttonStyle(PressableStyle())
                }
                list(career.agents)
            }
        }
    }

    private func sorted(_ lines: [CareerStats.Line]) -> [CareerStats.Line] {
        switch sort {
        case .games: lines
        case .winRate: lines.sorted { ($0.winRate, $0.games) > ($1.winRate, $1.games) }
        case .kd: lines.sorted { ($0.kd, $0.games) > ($1.kd, $1.games) }
        }
    }

    private func list(_ lines: [CareerStats.Line]) -> some View {
        let rows = sorted(lines)
        let most = lines.map(\.games).max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("All agents")
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sort.rawValue.uppercased()).font(Theme.label(9)).tracking(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .heavy))
                    }
                    .foregroundStyle(Theme.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            ForEach(Array((showAll ? rows : Array(rows.prefix(Self.shortList))).enumerated()), id: \.element.id) { index, line in
                NavigationLink(value: AgentRoute(id: line.key)) {
                    AgentRow(line: line, scale: Double(line.games) / Double(most), index: index)
                }
                .buttonStyle(PressableStyle())
            }
            if rows.count > Self.shortList {
                SeeAllButton(count: rows.count, expanded: $showAll)
            }
        }
        .statCard()
    }
}

/// One bar split by role, sized by games, with each role's games and win % under it.
private struct RoleSplit: View {
    @Environment(MatchesModel.self) private var matches
    let lines: [CareerStats.Line]
    @State private var grown = false

    private struct Role: Identifiable {
        let name: String
        let short: String
        let color: Color
        var games = 0
        var wins = 0
        var id: String { name }
    }

    private var roles: [Role] {
        var roles = [
            Role(name: "Duelist", short: "Duelist", color: Theme.attack),
            Role(name: "Initiator", short: "Init", color: Theme.gold),
            Role(name: "Sentinel", short: "Sent", color: Theme.defense),
            Role(name: "Controller", short: "Ctrl", color: Theme.ability),
        ]
        for line in lines {
            guard let role = matches.assets?.agent(line.key)?.role,
                  let index = roles.firstIndex(where: { $0.name == role }) else { continue }
            roles[index].games += line.games
            roles[index].wins += line.wins
        }
        return roles.filter { $0.games > 0 }
    }

    var body: some View {
        let roles = roles
        let total = max(roles.reduce(0) { $0 + $1.games }, 1)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Roles")
            GeometryReader { proxy in
                let room = proxy.size.width - CGFloat(max(roles.count - 1, 0)) * 3
                HStack(spacing: 3) {
                    ForEach(roles) { role in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(role.color.gradient)
                            .frame(width: room * CGFloat(role.games) / CGFloat(total))
                    }
                }
                .scaleEffect(x: grown ? 1 : 0.02, anchor: .leading)
            }
            .frame(height: 12)
            HStack(alignment: .top, spacing: 12) {
                ForEach(roles) { role in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(role.short.uppercased()).font(Theme.label(8)).tracking(1).foregroundStyle(role.color)
                        Text(role.games >= 3 ? "\(role.games) · \(Int((Double(role.wins) / Double(role.games) * 100).rounded()))%" : "\(role.games)")
                            .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .statCard()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { grown = true }
        }
    }
}

private struct MainAgentCard: View {
    @Environment(MatchesModel.self) private var matches
    let line: CareerStats.Line

    var body: some View {
        let agent = matches.assets?.agent(line.key)
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MAIN").font(Theme.label(9)).tracking(1.6).foregroundStyle(agent?.tint ?? Theme.accent)
                Text((agent?.name ?? "Agent").uppercased())
                    .font(Theme.display(40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    Text("\(line.winRate)%").foregroundStyle(line.winRate >= 50 ? Theme.win : Theme.loss)
                    Text("· \(StatText.kd(line.kd)) K/D · \(StatText.number(line.performance)) PS").foregroundStyle(Theme.textDim)
                }
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(16)
            Spacer(minLength: 0)
            FillImage(url: agent?.portrait ?? agent?.icon, alignment: .top)
                .frame(width: 120, height: 130)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .frame(maxWidth: .infinity)
        .background {
            RadialGradient(colors: [(agent?.tint ?? Theme.violet).opacity(0.55), .clear], center: .bottomTrailing,
                           startRadius: 5, endRadius: 240)
                .clipShape(.rect(cornerRadius: Theme.cardRadius - 4))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius - 4))
    }
}

private struct AgentRow: View {
    @Environment(MatchesModel.self) private var matches
    let line: CareerStats.Line
    let scale: Double
    let index: Int

    var body: some View {
        let agent = matches.assets?.agent(line.key)
        HStack(spacing: 10) {
            RemoteImage(url: agent?.icon)
                .frame(width: 34, height: 34)
                .background((agent?.tint ?? Theme.violet).opacity(0.25), in: .rect(cornerRadius: 9))
                .clipShape(.rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text((agent?.name ?? "Agent").uppercased()).font(Theme.label(10)).tracking(0.8)
                    Text(StatText.wins(line.wins, line.games)).font(Theme.label(8)).foregroundStyle(Theme.textFaint)
                }
                WinLossBar(wins: line.wins, losses: line.games - line.wins, scale: scale, delay: Double(index) * 0.04)
            }
            Text("\(line.winRate)%")
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .foregroundStyle(line.winRate >= 50 ? Theme.win : Theme.loss)
                .frame(width: 44, alignment: .trailing)
            Text(StatText.kd(line.kd))
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .frame(width: 40, alignment: .trailing)
        }
        .contentShape(.rect)
    }
}
