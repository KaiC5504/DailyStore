import Charts
import SwiftUI
import ValorantCore

struct HistoryPage: View {
    @Environment(MatchesModel.self) private var matches
    let zoom: Namespace.ID

    private struct Day: Identifiable {
        let id: Date
        var games: [(index: Int, summary: MatchSummary)]
    }

    /// The shown games split by calendar day, keeping each card's position for its deal-in delay.
    private var days: [Day] {
        let calendar = Calendar.current
        var days: [Day] = []
        for (index, summary) in matches.shown.enumerated() {
            let day = calendar.startOfDay(for: summary.start)
            if days.last?.id == day {
                days[days.count - 1].games.append((index, summary))
            } else {
                days.append(Day(id: day, games: [(index, summary)]))
            }
        }
        return days
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
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
            } else if matches.filtered.isEmpty && matches.shownPending.isEmpty {
                EmptyScope()
            }
            ForEach(matches.shownPending) { entry in
                PendingMatchCard(entry: entry)
            }
            ForEach(days) { day in
                DayHeader(day: day.id, games: day.games.map(\.summary))
                    .padding(.top, 6)
                ForEach(day.games, id: \.summary.id) { index, summary in
                    NavigationLink(value: MatchRoute(id: summary.id)) {
                        MatchCard(summary: summary, index: index)
                            .matchedTransitionSource(id: summary.id, in: zoom)
                    }
                    .buttonStyle(PressableStyle())
                    .onAppear {
                        if summary.id == matches.shown.last?.id { Task { await matches.loadMore() } }
                    }
                }
            }
            footer
        }
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

/// "TODAY 3W 1L · +38 RR · 1.58 K/D"
private struct DayHeader: View {
    let day: Date
    let games: [MatchSummary]

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var rest: String {
        let rr = games.compactMap(\.rrEarned)
        let kills = games.reduce(0) { $0 + $1.kills }
        let deaths = games.reduce(0) { $0 + $1.deaths }
        let kd = "\(StatText.kd(Double(kills) / Double(max(deaths, 1)))) K/D"
        guard !rr.isEmpty else { return "· " + kd }
        return "· \(StatText.signed(rr.reduce(0, +))) RR · " + kd
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased()).foregroundStyle(.white)
            Text("\(games.filter { $0.outcome.isWin }.count)W").foregroundStyle(Theme.win)
            Text("\(games.filter { $0.outcome == .loss }.count)L").foregroundStyle(Theme.loss)
            Text(rest.uppercased()).foregroundStyle(Theme.textDim).lineLimit(1)
        }
        .font(Theme.label(10)).tracking(1.2)
        .monospacedDigit()
    }
}

struct RankCard: View {
    @Environment(MatchesModel.self) private var matches
    let rank: RankStatus
    let updates: [CompetitiveUpdate]

    private var tier: MatchAssets.RankTier? { matches.assets?.tier(rank.tier) }
    private var color: Color { tier.map { Color(rgbaHex: $0.color) } ?? Theme.textDim }

    private var kicker: String {
        var parts = [rank.act ?? "Current act"]
        if rank.games > 0 { parts.append(StatText.wins(rank.wins, rank.games)) }
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: tier?.icon)
                .frame(width: 56, height: 56)
                .shadow(color: color.opacity(0.7), radius: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(kicker)
                    .font(Theme.label(9)).tracking(1.2)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(rank.isRanked ? (tier?.name ?? "Rank \(rank.tier)").uppercased() : "UNRANKED")
                    .font(Theme.display(28))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if rank.isRanked {
                    RRBar(rr: rank.rr, color: color)
                }
            }
            if updates.count >= 2 {
                RRTrend(updates: Array(updates.prefix(20).reversed()), color: color)
                    .frame(width: 104, height: 54)
            }
        }
        .padding(14)
        .background {
            RadialGradient(colors: [color.opacity(0.35), .clear], center: .topLeading, startRadius: 10, endRadius: 220)
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

struct MatchCard: View {
    @Environment(MatchesModel.self) private var matches
    let summary: MatchSummary
    let index: Int
    @State private var shown = false

    private var agent: MatchAssets.AgentInfo? { matches.assets?.agent(summary.agent) }
    private var map: MatchAssets.MapInfo? { matches.assets?.map(summary.mapURL) }
    private var digest: MatchDigest? { matches.digest(summary.id) }

    private var line: String {
        var parts = [map?.name ?? "Map", agent?.name ?? "Agent", summary.start.formatted(date: .omitted, time: .shortened)]
        // With one queue picked the header already names it.
        if matches.scope.queue == nil {
            parts.insert(matches.shortQueueName(summary.isCustom ? MatchesModel.customFilter : summary.queue), at: 0)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    private var badge: (text: String, color: Color)? {
        guard let digest else { return nil }
        if digest.isMVP { return ("Match MVP", Theme.gold) }
        if digest.teamPlace == 1 { return ("Team MVP", Theme.gold) }
        return digest.teamPlace.map { (MatchOutcome.ordinal($0), Theme.textDim) }
    }

    private var rating: (label: String, value: String) {
        if let performance = summary.performance { return ("PS", "\(performance)") }
        return summary.acs > 0 ? ("ACS", "\(summary.acs)") : ("PS", "–")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RemoteImage(url: agent?.icon)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.25), in: .rect(cornerRadius: 12))
                    .clipShape(.rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(summary.outcome.label)
                            .font(Theme.display(24))
                            .foregroundStyle(summary.outcome.color)
                        if let mine = summary.mine, let theirs = summary.theirs {
                            Text("\(mine) : \(theirs)")
                                .font(Theme.display(20))
                                .monospacedDigit()
                        }
                    }
                    Text(line)
                        .font(Theme.label(8)).tracking(0.8)
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    if let rr = summary.rrEarned {
                        RRChip(earned: rr)
                    }
                    if let badge {
                        Text(badge.text.uppercased())
                            .font(Theme.label(8)).tracking(1)
                            .foregroundStyle(badge.color)
                    }
                }
            }
            HStack(spacing: 0) {
                StatCell(label: "K / D / A", value: "\(summary.kills)/\(summary.deaths)/\(summary.assists)", size: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatCell(label: rating.label, value: rating.value, size: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatCell(label: "HS", value: StatText.percent(digest?.shots.percent(\.head).map { Int($0.rounded()) }), size: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatCell(label: "ADR", value: StatText.number(digest?.adr), size: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 58)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .leading) {
                FillImage(url: map?.banner)
                LinearGradient(colors: [.black.opacity(0.88), .black.opacity(0.55), .black.opacity(0.3)],
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
