import SwiftUI
import ValorantCore

struct OverviewPage: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        let career = matches.career
        VStack(spacing: 12) {
            if career.games == 0 {
                EmptyScope()
            } else {
                hero(career)
                strip(career)
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("Playstyle")
                    PlaystyleRadar(stats: career)
                }
                .statCard()
                HStack(spacing: 8) {
                    StatTileSmall(label: "Aces", value: "\(career.multiKills[3])", tint: Theme.gold)
                    StatTileSmall(label: "4K · 3K", value: "\(career.multiKills[2]) · \(career.multiKills[1])")
                    StatTileSmall(label: "Clutch", value: StatText.record(career.clutch))
                    StatTileSmall(label: "Flawless", value: "\(career.flawless)")
                }
            }
        }
    }

    private func hero(_ career: CareerStats) -> some View {
        HStack(spacing: 18) {
            WinDonut(wins: career.wins, losses: career.losses, games: career.games)
                .frame(width: 124, height: 124)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    StatCell(label: "K/D", value: StatText.kd(career.kd), size: 28)
                    StatCell(label: "Avg PS", value: StatText.number(career.performance), size: 28)
                }
                GridRow {
                    StatCell(label: "HS%", value: StatText.percent(career.shots.percent(\.head)), size: 28)
                    StatCell(label: "ADR", value: StatText.number(career.adr), size: 28)
                }
            }
            Spacer(minLength: 0)
        }
        .statCard()
    }

    private func strip(_ career: CareerStats) -> some View {
        HStack(spacing: 0) {
            StatCell(label: "KAST", value: StatText.percent(career.kast), size: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatCell(label: "DDΔ", value: StatText.signed(career.ddDelta), tint: (career.ddDelta ?? 0) >= 0 ? Theme.win : Theme.loss,
                     size: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatCell(label: "Games", value: "\(career.games)", size: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatCell(label: "Played", value: StatText.playtime(career.playtime), size: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .statCard(padding: 14)
    }
}

/// Win share as a ring that draws itself in, the rest of the ring red.
struct WinDonut: View {
    let wins: Int
    let losses: Int
    let games: Int
    @State private var drawn: CGFloat = 0

    var body: some View {
        let share = games > 0 ? CGFloat(wins) / CGFloat(games) : 0
        ZStack {
            Circle().stroke(Theme.loss.opacity(0.8), lineWidth: 12)
            Circle()
                .trim(from: 0, to: share * drawn)
                .stroke(Theme.win, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.win.opacity(0.5), radius: 8)
            VStack(spacing: 0) {
                Text("\(Int((share * 100).rounded()))%")
                    .font(Theme.display(34))
                    .monospacedDigit()
                Text(StatText.wins(wins, wins + losses))
                    .font(Theme.label(8)).tracking(1)
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(6)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) { drawn = 1 }
        }
    }
}

/// Six axes on fixed scales, clockwise from the top. The shape grows out of the centre on appear.
struct PlaystyleRadar: View {
    let stats: CareerStats
    @State private var grown: CGFloat = 0

    private var axes: [(label: String, value: String, amount: Double)] {
        let style = stats.playstyle
        return [
            ("Aim", "\(StatText.percent(stats.shots.percent(\.head))) HS", style.aim),
            ("Entry", "\(StatText.kd(stats.entryRatio)) FK/FD", style.entry),
            ("Damage", "\(StatText.number(stats.adr)) ADR", style.damage),
            ("Consistency", "\(StatText.percent(stats.kast)) KAST", style.consistency),
            ("Clutch", "\(StatText.percent(stats.clutch.rate)) won", style.clutch),
            ("Economy", "\(StatText.number(stats.econRating)) rating", style.economy),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width * 0.24, proxy.size.height / 2 - 36)
            ZStack {
                ForEach([1.0, 2.0 / 3, 1.0 / 3], id: \.self) { ring in
                    polygon(center, radius, Array(repeating: ring, count: 6))
                        .stroke(.white.opacity(ring == 1 ? 0.14 : 0.08))
                }
                Path { path in
                    for index in 0..<6 {
                        path.move(to: center)
                        path.addLine(to: point(center, radius, index))
                    }
                }
                .stroke(.white.opacity(0.08))
                let shape = polygon(center, radius, axes.map { max($0.amount, 0.04) })
                ZStack {
                    shape.fill(Theme.win.opacity(0.28))
                    shape.stroke(Theme.win, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
                .scaleEffect(grown)
                ForEach(axes.indices, id: \.self) { index in
                    label(axes[index], at: point(center, radius, index), index: index)
                }
            }
        }
        .frame(height: 226)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.2)) { grown = 1 }
        }
        .accessibilityElement(children: .combine)
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ index: Int, scale: Double = 1) -> CGPoint {
        let angle = Double(index) * .pi / 3 - .pi / 2
        return CGPoint(x: center.x + radius * scale * cos(angle), y: center.y + radius * scale * sin(angle))
    }

    private func polygon(_ center: CGPoint, _ radius: CGFloat, _ amounts: [Double]) -> Path {
        Path { path in
            for index in amounts.indices {
                let next = point(center, radius, index, scale: amounts[index])
                if index == 0 { path.move(to: next) } else { path.addLine(to: next) }
            }
            path.closeSubpath()
        }
    }

    private func label(_ axis: (label: String, value: String, amount: Double), at vertex: CGPoint, index: Int) -> some View {
        let width: CGFloat = 110
        let alignment: HorizontalAlignment = index == 0 || index == 3 ? .center : index < 3 ? .leading : .trailing
        let position: CGPoint = switch index {
        case 0: CGPoint(x: vertex.x, y: vertex.y - 22)
        case 3: CGPoint(x: vertex.x, y: vertex.y + 22)
        case 1, 2: CGPoint(x: vertex.x + 8 + width / 2, y: vertex.y)
        default: CGPoint(x: vertex.x - 8 - width / 2, y: vertex.y)
        }
        return VStack(alignment: alignment, spacing: 1) {
            Text(axis.label.uppercased()).font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.textDim)
            Text(axis.value).font(.system(size: 12, weight: .heavy).monospacedDigit())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: width, alignment: Alignment(horizontal: alignment, vertical: .center))
        .position(position)
    }
}
