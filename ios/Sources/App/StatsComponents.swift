import SwiftUI
import ValorantCore

/// Pills for switching between pages. Scrolling strips (the Matches sections) are separate pills;
/// the small tabs on the agent, map and match pages are one segmented capsule.
struct PillTabs<T: Hashable>: View {
    let items: [(value: T, title: String)]
    @Binding var selection: T
    var scrolls = false
    @Namespace private var pill

    init(_ items: [(value: T, title: String)], selection: Binding<T>, scrolls: Bool = false) {
        self.items = items
        _selection = selection
        self.scrolls = scrolls
    }

    var body: some View {
        if scrolls {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(items.indices, id: \.self) { index in
                            pill(items[index]).id(items[index].value)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .onChange(of: selection) {
                    withAnimation(.snappy) { proxy.scrollTo(selection, anchor: .center) }
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    pill(items[index]).frame(maxWidth: .infinity)
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
    }

    private func pill(_ item: (value: T, title: String)) -> some View {
        let on = item.value == selection
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = item.value }
        } label: {
            Text(item.title.uppercased())
                .font(Theme.label(10)).tracking(1.1)
                .foregroundStyle(on ? Theme.ink : .white.opacity(0.85))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: scrolls ? nil : .infinity)
                .background {
                    if on {
                        Capsule().fill(.white).matchedGeometryEffect(id: "pill", in: pill)
                    } else if scrolls {
                        Capsule().fill(.white.opacity(0.055)).overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var tint: Color = .white
    var size: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(Theme.label(8)).tracking(1).foregroundStyle(Theme.textFaint)
            Text(value).font(Theme.display(size)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(tint)
        }
    }
}

/// A small glass tile with one number, for rows of four.
struct StatTileSmall: View {
    let label: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(Theme.label(8)).tracking(1).foregroundStyle(tint == .white ? Theme.textDim : tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(Theme.display(26)).monospacedDigit().foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

/// What every stats page shows when the scope has no games, or while the first digests are built.
struct EmptyScope: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        VStack(spacing: 8) {
            if matches.digestsReady {
                Image(systemName: "chart.bar.xaxis").font(.title2).foregroundStyle(Theme.textDim)
                Text("NO GAMES").font(Theme.display(28))
                Text(matches.scopeLabel.uppercased()).font(Theme.label(9)).tracking(1.2).foregroundStyle(Theme.textFaint)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius))
    }
}

/// Wins then losses in one bar; `scale` sets its length against the longest bar in the list.
struct WinLossBar: View {
    let wins: Int
    let losses: Int
    var scale: Double = 1
    var delay: Double = 0
    @State private var grown = false

    var body: some View {
        GeometryReader { proxy in
            let total = max(wins + losses, 1)
            let length = proxy.size.width * max(scale, 0.04)
            HStack(spacing: 2) {
                if wins > 0 {
                    Capsule().fill(Theme.win).frame(width: length * CGFloat(wins) / CGFloat(total))
                }
                if losses > 0 {
                    Capsule().fill(Theme.loss.opacity(0.85)).frame(width: length * CGFloat(losses) / CGFloat(total))
                }
            }
            .scaleEffect(x: grown ? 1 : 0.02, anchor: .leading)
        }
        .frame(height: 7)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15 + delay)) { grown = true }
        }
    }
}

/// Expands a list cut at its first rows.
struct SeeAllButton: View {
    let count: Int
    @Binding var expanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            Text(expanded ? "SHOW LESS" : "SEE ALL \(count)")
                .font(Theme.label(9)).tracking(1.2)
                .foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// The glass card every stats section sits on.
    func statCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.cardRadius - 4))
    }
}

enum StatText {
    static func percent(_ value: Int?) -> String { value.map { "\($0)%" } ?? "–" }
    static func percent(_ value: Double?) -> String { value.map { String(format: "%.1f%%", $0) } ?? "–" }
    static func number(_ value: Int?) -> String { value.map(String.init) ?? "–" }
    static func signed(_ value: Int?) -> String { value.map { $0 > 0 ? "+\($0)" : "\($0)" } ?? "–" }
    static func kd(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
    static func record(_ tally: Tally) -> String { "\(tally.won)/\(tally.played)" }
    static func wins(_ wins: Int, _ games: Int) -> String { "\(wins)W \(games - wins)L" }

    static func playtime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
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
