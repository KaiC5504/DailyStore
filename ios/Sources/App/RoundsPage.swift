import SwiftUI
import ValorantCore

struct RoundsPage: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        let career = matches.career
        VStack(spacing: 12) {
            if career.games == 0 {
                EmptyScope()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Round win %")
                    HStack(alignment: .top, spacing: 12) {
                        impact(career.withFirstKill, "You get first kill", Theme.win)
                        impact(career.withFirstDeath, "You die first", Theme.loss)
                    }
                }
                .statCard()
                BuyColumns(buys: [("Pistol", career.pistol), ("Eco", career.eco), ("Force", career.force), ("Full", career.full)])
                ClutchDots(clutches: career.clutches, total: career.clutch)
                HStack(spacing: 8) {
                    StatTileSmall(label: "Plants", value: "\(career.plants)")
                    StatTileSmall(label: "Defuses", value: "\(career.defuses)")
                    StatTileSmall(label: "Flawless", value: "\(career.flawless)")
                }
            }
        }
    }

    private func impact(_ tally: Tally, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(StatText.percent(tally.rate))
                .font(Theme.display(40))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label.uppercased()).font(Theme.label(8)).tracking(1).foregroundStyle(Theme.textDim)
            Text(StatText.record(tally)).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Round win % for each kind of buy as columns that grow in.
private struct BuyColumns: View {
    let buys: [(name: String, tally: Tally)]
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Win % by buy")
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(buys.indices, id: \.self) { index in
                    let buy = buys[index]
                    let rate = buy.tally.rate ?? 0
                    VStack(spacing: 6) {
                        Text(StatText.percent(buy.tally.rate))
                            .font(.system(size: 14, weight: .heavy).monospacedDigit())
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.win.opacity(rate >= 50 ? 1 : 0.45).gradient)
                            .frame(height: max(CGFloat(rate) * 1.2, 4))
                            .scaleEffect(y: grown ? 1 : 0.02, anchor: .bottom)
                            .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1 + Double(index) * 0.06), value: grown)
                        Text(buy.name.uppercased()).font(Theme.label(8)).tracking(1).foregroundStyle(Theme.textDim)
                        Text(StatText.record(buy.tally)).font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 190, alignment: .bottom)
        }
        .statCard()
        .onAppear { grown = true }
    }
}

/// One row per clutch size, a dot per attempt: teal when won.
private struct ClutchDots: View {
    let clutches: [Tally]
    let total: Tally

    private static let maxDots = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Clutches")
                Spacer()
                Text(StatText.record(total)).font(Theme.display(22)).monospacedDigit()
            }
            ForEach(clutches.indices, id: \.self) { index in
                let tally = clutches[index]
                HStack(spacing: 10) {
                    Text("1v\(index + 1)")
                        .font(Theme.label(10)).tracking(0.6)
                        .frame(width: 32, alignment: .leading)
                    HStack(spacing: 4) {
                        ForEach(0..<min(tally.played, Self.maxDots), id: \.self) { dot in
                            Circle()
                                .fill(dot < tally.won ? Theme.win : .white.opacity(0.12))
                                .frame(width: 9, height: 9)
                        }
                        if tally.played > Self.maxDots {
                            Text("+\(tally.played - Self.maxDots)").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textFaint)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(StatText.record(tally))
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .foregroundStyle(tally.played > 0 ? .white : Theme.textFaint)
                }
            }
        }
        .statCard()
    }
}
