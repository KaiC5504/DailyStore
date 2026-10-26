import Charts
import SwiftUI
import ValorantCore

struct MatchRoute: Hashable {
    let id: String
}

struct MatchesView: View {
    @Environment(AppModel.self) private var model
    @Environment(MatchesModel.self) private var matches
    @Namespace private var zoom
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(kicker: "Your games", title: "Match History")
                        .padding(.top, 12)
                    if model.phase == .signedOut {
                        ContentUnavailableView("Sign in to see your matches", systemImage: "person.crop.circle.badge.questionmark")
                            .padding(.top, 40)
                    } else {
                        content
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable { await matches.refresh() }
            .background(AmbientBackground(tint: rankColor, secondary: Theme.violet))
            .navigationDestination(for: MatchRoute.self) { route in
                MatchDetailView(id: route.id)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoom))
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .task { await matches.appear(clientVersion: model.snapshot?.clientVersion) }
        #if DEBUG
        .task(id: matches.summaries.count) {
            let index = UserDefaults.standard.integer(forKey: "DemoMatch")
            guard index > 0, path.isEmpty, matches.shown.indices.contains(index - 1) else { return }
            path.append(MatchRoute(id: matches.shown[index - 1].id))
        }
        #endif
    }

    private var rankColor: Color {
        matches.rank.flatMap { matches.assets?.tier($0.tier) }.map { Color(rgbaHex: $0.color) } ?? Theme.accent
    }

    @ViewBuilder
    private var content: some View {
        if case let .failed(message) = matches.phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(12)
                .glassEffect(.regular.tint(.orange.opacity(0.15)), in: .rect(cornerRadius: Theme.chipRadius))
        }
        if let rank = matches.rank {
            RankCard(rank: rank, updates: matches.updates)
        }
        if matches.summaries.isEmpty && matches.pending.isEmpty {
            if matches.phase == .syncing {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Loading your matches…").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
            } else {
                ContentUnavailableView("No matches yet", systemImage: "scope",
                                       description: Text("Play a game, then pull down to refresh."))
                    .padding(.top, 20)
            }
        }
        ForEach(matches.shownPending) { entry in
            PendingMatchCard(entry: entry)
        }
        ForEach(Array(matches.shown.enumerated()), id: \.element.id) { index, summary in
            NavigationLink(value: MatchRoute(id: summary.id)) {
                MatchCard(summary: summary, index: index)
                    .matchedTransitionSource(id: summary.id, in: zoom)
            }
            .buttonStyle(PressableStyle())
            .onAppear {
                if summary.id == matches.shown.last?.id { Task { await matches.loadMore() } }
            }
        }
        footer
    }

    @ViewBuilder
    private var footer: some View {
        if matches.loadingOlder {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Asking Riot for older games…").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        } else if matches.reachedEnd, matches.shown.count == matches.filtered.count, !matches.summaries.isEmpty {
            Text("That's everything Riot still lists. Every game loaded here stays saved on this iPhone.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}

struct RankCard: View {
    @Environment(MatchesModel.self) private var matches
    let rank: RankStatus
    let updates: [CompetitiveUpdate]

    private var tier: MatchAssets.RankTier? { matches.assets?.tier(rank.tier) }
    private var color: Color { tier.map { Color(rgbaHex: $0.color) } ?? Theme.textDim }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RemoteImage(url: tier?.icon)
                    .frame(width: 76, height: 76)
                    .shadow(color: color.opacity(0.7), radius: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text((rank.act ?? "Current act").uppercased())
                        .font(Theme.label(10)).tracking(1.6)
                        .foregroundStyle(Theme.textDim)
                    Text(rank.isRanked ? (tier?.name ?? "Rank \(rank.tier)").uppercased() : "UNRANKED")
                        .font(Theme.display(34))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if rank.isRanked {
                        RRBar(rr: rank.rr, color: color)
                    } else {
                        Text("No ranked games this act yet")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                Spacer(minLength: 0)
            }
            if updates.count >= 2 {
                RRTrend(updates: Array(updates.prefix(20).reversed()), color: color)
                    .frame(height: 74)
            }
            if rank.games > 0 {
                Text("\(rank.wins)W · \(rank.games - rank.wins)L this act")
                    .font(Theme.label(10)).tracking(1.2)
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(16)
        .background {
            RadialGradient(colors: [color.opacity(0.35), .clear], center: .topLeading, startRadius: 10, endRadius: 260)
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
        }
        .glassEffect(.regular.tint(color.opacity(0.1)), in: .rect(cornerRadius: Theme.cardRadius))
    }
}

struct RRBar: View {
    let rr: Int
    let color: Color
    @State private var fill: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                Capsule().fill(.white.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(color.gradient).frame(width: proxy.size.width * fill)
                    }
            }
            .frame(height: 8)
            Text("\(rr) RR")
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .fixedSize()
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                fill = min(CGFloat(rr) / 100, 1)
            }
        }
    }
}

/// Tier and RR over recent ranked games, drawn left to right when it appears.
struct RRTrend: View {
    let updates: [CompetitiveUpdate]
    let color: Color
    @State private var reveal: CGFloat = 0

    private var domain: ClosedRange<Int> {
        let values = updates.map(\.ladder)
        return (values.min()! - 15)...(values.max()! + 15)
    }

    var body: some View {
        Chart(Array(updates.enumerated()), id: \.offset) { index, update in
            AreaMark(x: .value("Game", index), yStart: .value("Floor", domain.lowerBound), yEnd: .value("RR", update.ladder))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Game", index), y: .value("RR", update.ladder))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            if index == updates.count - 1 {
                PointMark(x: .value("Game", index), y: .value("RR", update.ladder))
                    .foregroundStyle(.white)
                    .symbolSize(40)
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .mask(alignment: .leading) {
            GeometryReader { proxy in
                Rectangle().frame(width: proxy.size.width * reveal)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { reveal = 1 }
        }
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(10)).tracking(1.6)
            .foregroundStyle(Theme.textDim)
            .padding(.top, 4)
    }
}

struct MatchCard: View {
    @Environment(MatchesModel.self) private var matches
    let summary: MatchSummary
    let index: Int
    @State private var shown = false

    private var agent: MatchAssets.AgentInfo? { matches.assets?.agent(summary.agent) }
    private var map: MatchAssets.MapInfo? { matches.assets?.map(summary.mapURL) }

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: agent?.icon)
                .frame(width: 56, height: 56)
                .background(.black.opacity(0.25), in: .rect(cornerRadius: 12))
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary.outcome.label)
                        .font(Theme.display(26))
                        .foregroundStyle(summary.outcome.color)
                    if let mine = summary.mine, let theirs = summary.theirs {
                        Text("\(mine)–\(theirs)")
                            .font(Theme.display(22))
                            .monospacedDigit()
                    }
                }
                Text("\(summary.kills) / \(summary.deaths) / \(summary.assists)")
                    .font(.system(size: 14, weight: .heavy).monospacedDigit())
                Text("\(matches.queueName(summary.isCustom ? MatchesModel.customFilter : summary.queue).uppercased()) · \(map?.name.uppercased() ?? "MAP") · \(summary.start.formatted(.relative(presentation: .named)))")
                    .font(Theme.label(9)).tracking(0.8)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                if let rr = summary.rrEarned {
                    RRChip(earned: rr)
                }
                if let performance = summary.performance {
                    Text("\(performance) PS")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textDim)
                } else if summary.acs > 0 {
                    Text("\(summary.acs) ACS")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textDim)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background {
            ZStack(alignment: .leading) {
                FillImage(url: map?.banner)
                LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.45), .black.opacity(0.2)],
                               startPoint: .leading, endPoint: .trailing)
                summary.outcome.color.frame(width: 4)
            }
            .clipShape(.rect(cornerRadius: Theme.chipRadius + 6))
        }
        .glassEffect(.regular.tint(summary.outcome.color.opacity(0.08)), in: .rect(cornerRadius: Theme.chipRadius + 6))
        .rotation3DEffect(.degrees(shown ? 0 : 50), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
        .offset(y: shown ? 0 : 30)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(min(index, 6)) * 0.06)) { shown = true }
        }
    }
}

/// Riot has listed the game but its details are still downloading.
struct PendingMatchCard: View {
    @Environment(MatchesModel.self) private var matches
    let entry: HistoryEntry
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)).frame(width: 120, height: 18)
                Text("\(matches.queueName(entry.queue.isEmpty ? MatchesModel.customFilter : entry.queue).uppercased()) · \(entry.start.formatted(.relative(presentation: .named)))")
                    .font(Theme.label(9)).tracking(0.8)
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer()
            ProgressView().tint(.white.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .opacity(pulse ? 0.55 : 1)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.chipRadius + 6))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true }
        }
    }
}

struct RRChip: View {
    let earned: Int

    var body: some View {
        Text(earned > 0 ? "+\(earned) RR" : "\(earned) RR")
            .font(.system(size: 12, weight: .heavy).monospacedDigit())
            .foregroundStyle(earned >= 0 ? Theme.win : Theme.loss)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint((earned >= 0 ? Theme.win : Theme.loss).opacity(0.18)), in: .capsule)
    }
}

extension MatchOutcome {
    var label: String {
        switch self {
        case .win: "VICTORY"
        case .loss: "DEFEAT"
        case .draw: "DRAW"
        case let .placement(place): Self.ordinal(place)
        }
    }

    var color: Color {
        switch self {
        case .win: Theme.win
        case .loss: Theme.loss
        case .draw: Theme.textDim
        case let .placement(place): place == 1 ? Theme.win : place <= 3 ? .white : Theme.textDim
        }
    }

    static func ordinal(_ n: Int) -> String {
        let suffix = (11...13).contains(n % 100) ? "TH" : ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
        return "\(n)\(suffix)"
    }
}

extension MatchAssets.AgentInfo {
    var tint: Color { colors.first.map { Color(rgbaHex: $0) } ?? Theme.violet }
}
