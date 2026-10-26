import SwiftUI
import ValorantCore

struct GunsPage: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        let career = matches.career
        VStack(spacing: 12) {
            if career.games == 0 {
                EmptyScope()
            } else {
                HitsCard(shots: career.shots)
                KillBars(lines: career.guns)
                    .statCard()
            }
        }
    }
}

private struct HitsCard: View {
    let shots: Shots

    var body: some View {
        let parts = [("Head", shots.percent(\.head)), ("Body", shots.percent(\.body)), ("Legs", shots.percent(\.leg))]
        let top = parts.compactMap(\.1).max()
        HStack(spacing: 22) {
            HitFigure(head: parts[0].1 ?? 0, torso: parts[1].1 ?? 0, legs: parts[2].1 ?? 0)
                .frame(width: 74, height: 168)
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Hits")
                ForEach(parts, id: \.0) { name, percent in
                    let leading = percent != nil && percent == top
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name.uppercased()).font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.textFaint)
                        Text(StatText.percent(percent))
                            .font(Theme.display(leading ? 30 : 22))
                            .monospacedDigit()
                            .foregroundStyle(leading ? Theme.win : Theme.textDim)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .statCard()
    }
}

/// Head, body and legs as separate shapes with a gap between them; the most-hit part is teal.
struct HitFigure: View {
    let head: Double
    let torso: Double
    let legs: Double
    @State private var shown = false

    // The approved mockup's outlines, in a 100 x 200 box of which x 10-90, y 2-184 is used.
    private static let headShape = Path(svg: "M50 3 C56.2 3 59.6 7.6 59.6 13.6 C59.6 20 55.6 26.6 50 26.6 C44.4 26.6 40.4 20 40.4 13.6 C40.4 7.6 43.8 3 50 3 Z")
    private static let bodyShape = Path(svg: "M44.5 30 C39 31.5 32 33.5 27.5 36.5 C23 39 21.5 43 21 48 C20 58 18 68 16.5 77 C15 88 13.5 98 12.8 106 C12.3 111 13.8 115.5 17.2 115.8 C20.6 116 22.2 113 22 109 C22.6 99 24 89 25.6 80 C27.2 68 29.2 58 31.2 50 C33.5 61 38 76 39.2 88 C41.5 94 46.5 100 50 103.5 C53.5 100 58.5 94 60.8 88 C62 76 66.5 61 68.8 50 C70.8 58 72.8 68 74.4 80 C76 89 77.4 99 78 109 C77.8 113 79.4 116 82.8 115.8 C86.2 115.5 87.7 111 87.2 106 C86.5 98 85 88 83.5 77 C82 68 80 58 79 48 C78.5 43 77 39 72.5 36.5 C68 33.5 61 31.5 55.5 30 Z")
    private static let legsShape = Path(svg: "M38 84 C35.8 94 34.6 103 34.5 111 C34 124 33 135 32.6 144 C32 154 31.6 163 31.3 170 L27.5 179 C27 181 27.6 182 29.4 182 L41 182 C42.2 182 42.6 181 42.3 179.5 L41.2 170 C41.8 163 42.8 154 43.6 144 C44.4 135 46.2 122 50 112 C53.8 122 55.6 135 56.4 144 C57.2 154 58.2 163 58.8 170 L57.7 179.5 C57.4 181 57.8 182 59 182 L70.6 182 C72.4 182 73 181 72.5 179 L68.7 170 C68.4 163 68 154 67.4 144 C67 135 66 124 65.5 111 C65.4 103 64.2 94 62 84 Z")

    private func fill(_ value: Double) -> Color {
        let higher = [head, torso, legs].filter { $0 > value }.count
        return [Theme.win, Theme.hitMid, Theme.hitLow][min(higher, 2)]
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 80, size.height / 182)
            let fit = CGAffineTransform(translationX: -10, y: -2)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            let legsPath = Self.legsShape.applying(fit)
            let bodyPath = Self.bodyShape.applying(fit)
            context.fill(legsPath, with: .color(fill(legs)))
            // Cuts the gap where the hips overlap the legs, the way the mockup's mask did.
            context.blendMode = .destinationOut
            context.stroke(bodyPath, with: .color(.black), style: StrokeStyle(lineWidth: 5 * scale, lineJoin: .round))
            context.blendMode = .normal
            context.fill(bodyPath, with: .color(fill(torso)))
            context.fill(Self.headShape.applying(fit), with: .color(fill(head)))
        }
        .shadow(color: Theme.win.opacity(0.25), radius: 10)
        .scaleEffect(shown ? 1 : 0.92)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { shown = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Hits: head \(Int(head.rounded())), body \(Int(torso.rounded())), legs \(Int(legs.rounded())) percent")
    }
}

extension Path {
    /// Absolute M, L, C and Z only, which is all the hit figure's outlines use.
    init(svg: String) {
        self.init()
        var command: Character = "M"
        var numbers: [CGFloat] = []
        let spaced = svg.reduce(into: "") { result, character in
            result += character.isLetter ? " \(character) " : String(character)
        }
        for token in spaced.split(whereSeparator: { $0 == " " || $0 == "," }) {
            if let letter = token.first, letter.isLetter {
                command = letter
                if letter == "Z" { closeSubpath() }
                continue
            }
            guard let value = Double(token) else { continue }
            numbers.append(CGFloat(value))
            switch command {
            case "M" where numbers.count == 2:
                move(to: CGPoint(x: numbers[0], y: numbers[1]))
                numbers = []
            case "L" where numbers.count == 2:
                addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
                numbers = []
            case "C" where numbers.count == 6:
                addCurve(to: CGPoint(x: numbers[4], y: numbers[5]),
                         control1: CGPoint(x: numbers[0], y: numbers[1]),
                         control2: CGPoint(x: numbers[2], y: numbers[3]))
                numbers = []
            default:
                break
            }
        }
    }
}

/// Kills per gun as bars, with the head % of hits in rounds that gun was bought.
struct KillBars: View {
    @Environment(MatchesModel.self) private var matches
    let lines: [CareerStats.GunLine]
    @State private var showAll = false
    @State private var grown = false

    private static let shortList = 8

    private struct Row: Identifiable {
        let id: String
        let name: String
        let kills: Int
        let headshots: Double?
        let isAbility: Bool
    }

    /// Ultimates that act like guns (Chamber's, Jett's knives) have uuids valorant-api.com doesn't list
    /// as weapons, so they join the abilities row.
    private var rows: [Row] {
        var rows: [Row] = []
        var abilityKills = 0
        for line in lines {
            if let weapon = matches.assets?.weapon(line.key), line.key != "ability" {
                rows.append(Row(id: line.key, name: weapon.name, kills: line.kills,
                                headshots: line.shots.percent(\.head), isAbility: false))
            } else if matches.assets != nil || line.key == "ability" {
                abilityKills += line.kills
            }
        }
        if abilityKills > 0 {
            rows.append(Row(id: "ability", name: "Abilities", kills: abilityKills, headshots: nil, isAbility: true))
        }
        return rows.filter { $0.kills > 0 }.sorted { $0.kills > $1.kills }
    }

    var body: some View {
        let rows = rows
        let most = max(rows.first?.kills ?? 1, 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Kills by gun")
                Spacer()
                Text("KILLS").frame(width: 40, alignment: .trailing)
                Text("HS").frame(width: 40, alignment: .trailing)
            }
            .font(Theme.label(8)).tracking(1)
            .foregroundStyle(Theme.textFaint)
            ForEach(Array((showAll ? rows : Array(rows.prefix(Self.shortList))).enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 10) {
                    Text(row.name.uppercased())
                        .font(Theme.label(9)).tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 78, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill((row.isAbility ? Theme.ability : Theme.win).gradient)
                            .frame(width: max(proxy.size.width * CGFloat(row.kills) / CGFloat(most), 4))
                            .scaleEffect(x: grown ? 1 : 0.02, anchor: .leading)
                            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1 + Double(index) * 0.04), value: grown)
                    }
                    .frame(height: 8)
                    Text("\(row.kills)")
                        .font(.system(size: 14, weight: .heavy).monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                    Text(row.headshots.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            if rows.count > Self.shortList {
                SeeAllButton(count: rows.count, expanded: $showAll)
            }
        }
        .onAppear { grown = true }
    }
}
