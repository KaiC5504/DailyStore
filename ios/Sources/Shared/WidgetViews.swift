import SwiftUI
import UIKit
import WidgetKit

struct StoreWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StoreEntry

    var body: some View {
        Group {
            switch entry.state {
            case .signedOut:
                message("Open DailyStore to sign in", systemImage: "person.crop.circle.badge.exclamationmark")
            case let .failed(reason):
                message(reason, systemImage: "exclamationmark.triangle")
            case .ready:
                switch family {
                case .systemSmall: SmallStoreView(entry: entry)
                case .systemLarge: LargeStoreView(entry: entry)
                case .accessoryRectangular: RectangularStoreView(entry: entry)
                case .accessoryInline: InlineStoreView(entry: entry)
                case .accessoryCircular: CircularStoreView(entry: entry)
                default: MediumStoreView(entry: entry)
                }
            }
        }
        .widgetURL(URL(string: "dailystore://today"))
    }

    private func message(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.title3)
            Text(text).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
    }
}

struct WidgetBackdrop: View {
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Theme.ink
            RadialGradient(colors: [tint.opacity(0.45), .clear], center: .topTrailing, startRadius: 5, endRadius: 220)
            RadialGradient(colors: [Theme.violet.opacity(0.35), .clear], center: .bottomLeading, startRadius: 5, endRadius: 200)
        }
    }
}

private func tierColor(_ item: WidgetItem) -> Color {
    item.colorHex.map(Color.init(rgbaHex:)) ?? Theme.fallbackTier
}

private struct SkinThumb: View {
    let item: WidgetItem

    var body: some View {
        if let data = item.image, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(-8))
                .shadow(color: tierColor(item).opacity(0.7), radius: 6)
        } else {
            Image(systemName: "photo").foregroundStyle(Theme.textFaint)
        }
    }
}

private struct ResetLine: View {
    let entry: StoreEntry

    var body: some View {
        if entry.expired {
            Text("New store ready").font(.system(size: 11, weight: .heavy))
        } else {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .bold))
                Text(timerInterval: entry.date...max(entry.date, entry.resetsAt), countsDown: true)
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
            }
        }
    }
}

struct SmallStoreView: View {
    let entry: StoreEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY").font(Theme.label(10)).tracking(1.4).foregroundStyle(Theme.accent)
                Spacer()
                if entry.wishlistCount > 0 { Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Theme.accent) }
            }
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow { cell(0); cell(1) }
                GridRow { cell(2); cell(3) }
            }
            ResetLine(entry: entry).foregroundStyle(Theme.textDim)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private func cell(_ index: Int) -> some View {
        if entry.items.indices.contains(index) {
            let item = entry.items[index]
            SkinThumb(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
                .background(tierColor(item).opacity(0.18), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(item.wishlisted ? Theme.accent : .clear, lineWidth: 1.5))
        } else {
            Color.clear
        }
    }
}

struct MediumStoreView: View {
    let entry: StoreEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY'S STORE").font(Theme.display(18))
                Spacer()
                ResetLine(entry: entry).foregroundStyle(Theme.textDim)
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { tile(0); tile(1) }
                GridRow { tile(2); tile(3) }
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private func tile(_ index: Int) -> some View {
        if entry.items.indices.contains(index) {
            let item = entry.items[index]
            HStack(spacing: 6) {
                SkinThumb(item: item).frame(width: 56, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.system(size: 11, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(item.price) VP").font(.system(size: 10, weight: .heavy).monospacedDigit())
                        .foregroundStyle(tierColor(item))
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tierColor(item).opacity(0.16), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(item.wishlisted ? Theme.accent : .clear, lineWidth: 1.5))
        } else {
            Color.clear
        }
    }
}

struct LargeStoreView: View {
    let entry: StoreEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("DAILY OFFERS").font(Theme.label(10)).tracking(1.6).foregroundStyle(Theme.accent)
                    Text("TODAY'S STORE").font(Theme.display(28))
                }
                Spacer()
                if let vp = entry.vp {
                    Text("\(vp) VP").font(.system(size: 13, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.textDim)
                }
            }
            ForEach(entry.items, id: \.levelID) { item in
                HStack(spacing: 10) {
                    SkinThumb(item: item).frame(width: 96, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.uppercased()).font(Theme.display(17)).lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(item.price) VP").font(.system(size: 12, weight: .heavy).monospacedDigit())
                            .foregroundStyle(tierColor(item))
                    }
                    Spacer(minLength: 0)
                    if item.wishlisted { Image(systemName: "heart.fill").foregroundStyle(Theme.accent) }
                }
                .padding(8)
                .frame(maxHeight: .infinity)
                .background(tierColor(item).opacity(0.15), in: .rect(cornerRadius: 14))
            }
            HStack {
                ResetLine(entry: entry)
                Spacer()
                if let night = entry.nightMarketCount {
                    Label("Night Market · \(night)", systemImage: "moon.stars.fill")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(Theme.textDim)
        }
        .foregroundStyle(.white)
    }
}

struct RectangularStoreView: View {
    let entry: StoreEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: entry.wishlistCount > 0 ? "heart.fill" : "sparkles")
                ResetLine(entry: entry)
            }
            .font(.system(size: 12, weight: .bold))
            ForEach(entry.items.prefix(3), id: \.levelID) { item in
                Text(item.name).font(.system(size: 12, weight: item.wishlisted ? .heavy : .medium)).lineLimit(1)
            }
        }
        .widgetAccentable()
    }
}

struct InlineStoreView: View {
    let entry: StoreEntry

    var body: some View {
        if entry.wishlistCount > 0 {
            Label("Wishlist skin in store", systemImage: "heart.fill")
        } else {
            Label {
                Text("Store resets \(entry.resetsAt, style: .relative)")
            } icon: {
                Image(systemName: "sparkles")
            }
        }
    }
}

struct CircularStoreView: View {
    let entry: StoreEntry

    var body: some View {
        let total = 86_400.0
        let left = max(0, entry.resetsAt.timeIntervalSince(entry.date))
        Gauge(value: total - min(left, total), in: 0...total) {
            Image(systemName: entry.wishlistCount > 0 ? "heart.fill" : "sparkles")
        } currentValueLabel: {
            Text("\(Int(left / 3600))h")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

#if DEBUG
/// Widget layouts rendered inside the app so CI screenshots can show them.
struct WidgetGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                frame(SmallStoreView(entry: .placeholder()), width: 170, height: 170)
                frame(MediumStoreView(entry: .placeholder()), width: 364, height: 170)
                frame(LargeStoreView(entry: .placeholder()), width: 364, height: 382)
                frame(RectangularStoreView(entry: .placeholder()), width: 172, height: 76)
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Widget previews")
    }

    private func frame(_ view: some View, width: CGFloat, height: CGFloat) -> some View {
        view
            .padding(14)
            .frame(width: width, height: height)
            .background(WidgetBackdrop())
            .clipShape(.rect(cornerRadius: 22))
    }
}
#endif
