import SwiftUI
import ValorantCore

struct MapsPage: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        let career = matches.career
        VStack(spacing: 12) {
            if career.games == 0 {
                EmptyScope()
            } else {
                SideSplit(attack: career.attack, defense: career.defense)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(career.maps.enumerated()), id: \.element.id) { index, line in
                        NavigationLink(value: MapRoute(url: line.key)) {
                            MapTile(line: line, index: index)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if !notPlayed(career).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOT PLAYED").font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.textFaint)
                            Text(notPlayed(career).joined(separator: " · "))
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Theme.textDim)
                                .lineLimit(3)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .glassEffect(.regular, in: .rect(cornerRadius: Theme.chipRadius + 4))
                    }
                }
            }
        }
    }

    /// Riot doesn't publish the map pool, so this is every map you have played Competitive on but not in this scope.
    private func notPlayed(_ career: CareerStats) -> [String] {
        let played = Set(career.maps.map(\.key))
        let pool = Set(matches.digests.filter { $0.queue == "competitive" && !$0.isCustom }.map(\.mapURL))
        return pool.subtracting(played).compactMap { matches.assets?.map($0)?.name }.sorted()
    }
}

/// Attack rounds won to the left, defense to the right, from a shared centre.
struct SideSplit: View {
    let attack: Tally
    let defense: Tally
    @State private var grown = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("ATK").font(Theme.label(9)).tracking(1.2).foregroundStyle(Theme.attack)
                Text(StatText.percent(attack.rate)).font(Theme.display(30)).monospacedDigit()
                Spacer()
                Text("ROUNDS WON").font(Theme.label(8)).tracking(1.4).foregroundStyle(Theme.textFaint)
                Spacer()
                Text(StatText.percent(defense.rate)).font(Theme.display(30)).monospacedDigit()
                Text("DEF").font(Theme.label(9)).tracking(1.2).foregroundStyle(Theme.defense)
            }
            GeometryReader { proxy in
                let half = proxy.size.width / 2 - 2
                HStack(spacing: 4) {
                    ZStack(alignment: .trailing) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(Theme.attack.gradient)
                            .frame(width: half * CGFloat(attack.rate ?? 0) / 100)
                            .scaleEffect(x: grown ? 1 : 0.02, anchor: .trailing)
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(Theme.defense.gradient)
                            .frame(width: half * CGFloat(defense.rate ?? 0) / 100)
                            .scaleEffect(x: grown ? 1 : 0.02, anchor: .leading)
                    }
                }
            }
            .frame(height: 10)
        }
        .statCard()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { grown = true }
        }
    }
}

private struct MapTile: View {
    @Environment(MatchesModel.self) private var matches
    let line: CareerStats.Line
    let index: Int
    @State private var shown = false

    var body: some View {
        let map = matches.assets?.map(line.key)
        let good = line.winRate >= 50
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text((map?.name ?? "Map").uppercased())
                    .font(Theme.display(22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text("\(line.winRate)%")
                    .font(.system(size: 12, weight: .heavy).monospacedDigit())
                    .foregroundStyle(good ? Theme.win : Theme.loss)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((good ? Theme.win : Theme.loss).opacity(0.16), in: .capsule)
            }
            Text(StatText.wins(line.wins, line.games))
                .font(Theme.label(9)).tracking(1)
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 2)
            sideBar(Theme.attack, line.attack.rate)
            sideBar(Theme.defense, line.defense.rate)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background {
            ZStack {
                FillImage(url: map?.banner)
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: Theme.chipRadius + 4))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.chipRadius + 4))
        .scaleEffect(shown ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(min(index, 8)) * 0.05)) { shown = true }
        }
    }

    private func sideBar(_ color: Color, _ rate: Int?) -> some View {
        HStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(color).frame(width: proxy.size.width * CGFloat(rate ?? 0) / 100)
                }
            }
            .frame(height: 4)
            Text(StatText.percent(rate))
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textDim)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
