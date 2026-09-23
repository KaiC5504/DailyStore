import SwiftUI
import ValorantCore

struct BundlesView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom

    var body: some View {
        let bundles = model.snapshot?.storefront.bundles ?? []
        NavigationStack {
            FitPage(minHeight: CGFloat(110 + bundles.count * 170), refresh: { await model.refresh(force: true) }) {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(kicker: "Featured", title: "Bundles")
                        .padding(.top, 8)
                    if let snapshot = model.snapshot, !bundles.isEmpty {
                        ForEach(bundles, id: \.id) { bundle in
                            NavigationLink(value: bundle) {
                                BundleCard(bundle: bundle, ends: snapshot.bundleEndsAt(bundle))
                                    .matchedTransitionSource(id: bundle.id, in: zoom)
                            }
                            .buttonStyle(PressableStyle())
                            .frame(maxHeight: 340)
                        }
                    } else {
                        ContentUnavailableView("No bundles loaded", systemImage: "shippingbox",
                                               description: Text("Pull down to refresh."))
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .background(AmbientBackground(tint: Theme.accent, secondary: .cyan.opacity(0.6)))
            .navigationDestination(for: FeaturedBundle.self) { bundle in
                BundleDetailView(bundle: bundle)
                    .navigationTransition(.zoom(sourceID: bundle.id, in: zoom))
            }
            .navigationDestination(for: SkinRoute.self) { route in
                SkinDetailView(route: route)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
}

private struct BundleCard: View {
    @Environment(AppModel.self) private var model
    let bundle: FeaturedBundle
    let ends: Date
    @State private var shown = false

    var body: some View {
        let info = model.catalog?.bundle(bundle.dataAssetID)
        ZStack(alignment: .bottomLeading) {
            BundleArt(bundle: bundle, info: info)
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.92)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text((info?.name ?? model.catalog?.collectionName(of: bundle) ?? "New bundle").uppercased())
                    .font(Theme.display(34))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack {
                    if let cost = bundle.discountedCost ?? bundle.baseCost {
                        PriceTag(amount: cost, original: bundle.baseCost)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Ends in \(ends, style: .relative)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textDim)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .glassEffect(.clear, in: .rect(cornerRadius: Theme.cardRadius))
        .scaleEffect(shown ? 1 : 0.92)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { shown = true } }
    }
}

/// The bundle banner, or its first skin while valorant-api.com hasn't published the new bundle yet.
struct BundleArt: View {
    @Environment(AppModel.self) private var model
    let bundle: FeaturedBundle
    let info: BundleInfo?
    var height: CGFloat?

    var body: some View {
        if let art = info?.art {
            BannerImage(url: art, height: height)
        } else {
            let skin = bundle.items.first { $0.kind == .skin }.flatMap { model.catalog?.skin($0.itemID) }
            let color = skin.map { model.catalog.tierColor($0.levelID) } ?? Theme.accent
            ZStack {
                RadialGradient(colors: [color.opacity(0.55), .clear], center: .init(x: 0.5, y: 0.4),
                               startRadius: 8, endRadius: 220)
                RemoteImage(url: skin?.icon)
                    .padding(.horizontal, 36)
                    .padding(.top, 20)
                    .padding(.bottom, 64)
                    .rotationEffect(.degrees(-8))
                    .shadow(color: color.opacity(0.6), radius: 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
    }
}

struct BundleDetailView: View {
    @Environment(AppModel.self) private var model
    let bundle: FeaturedBundle

    var body: some View {
        let info = model.catalog?.bundle(bundle.dataAssetID)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BundleArt(bundle: bundle, info: info, height: 230)
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
                VStack(alignment: .leading, spacing: 6) {
                    Text((info?.name ?? model.catalog?.collectionName(of: bundle) ?? "New bundle").uppercased())
                        .font(Theme.display(44))
                    if let cost = bundle.discountedCost ?? bundle.baseCost {
                        PriceTag(amount: cost, original: bundle.baseCost,
                                 font: .system(size: 22, weight: .heavy).monospacedDigit())
                    }
                }
                if bundle.items.isEmpty {
                    Text("Riot didn't list the contents of this bundle.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                }
                ForEach(Array(bundle.items.enumerated()), id: \.offset) { _, item in
                    row(item)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground())
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func row(_ item: BundleItem) -> some View {
        if item.kind == .skin {
            NavigationLink(value: SkinRoute(levelID: item.itemID, price: item.discountedPrice, original: item.basePrice)) {
                rowBody(item, name: model.catalog?.skin(item.itemID)?.name, icon: model.catalog?.skin(item.itemID)?.icon,
                        color: model.catalog.tierColor(item.itemID))
            }
            .buttonStyle(PressableStyle())
        } else {
            let info = model.catalog?.item(item.itemID)
            rowBody(item, name: info?.name, icon: info?.icon, color: Theme.fallbackTier)
        }
    }

    private func rowBody(_ item: BundleItem, name: String?, icon: URL?, color: Color) -> some View {
        let isNew = name == nil
        let color = isNew ? Theme.newItem : color
        return HStack(spacing: 14) {
            Group {
                if isNew {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.newItem)
                        .symbolEffect(.pulse, options: .repeat(.continuous))
                } else {
                    RemoteImage(url: icon)
                }
            }
            .frame(width: item.kind == .skin ? 110 : 56, height: 56)
            .shadow(color: color.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(name ?? "New item")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(isNew ? "\(kindLabel(item.kind)) · DETAILS COMING SOON" : kindLabel(item.kind))
                    .font(Theme.label(9)).tracking(1.2)
                    .foregroundStyle(isNew ? Theme.newItem : Theme.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            if item.discountedPrice == 0 && item.basePrice > 0 {
                Text("FREE").font(Theme.label(11)).foregroundStyle(Theme.accent)
            } else {
                PriceTag(amount: item.discountedPrice, original: item.basePrice,
                         font: .system(size: 14, weight: .heavy).monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .glassEffect(.regular.tint(color.opacity(isNew ? 0.16 : 0.08)), in: .rect(cornerRadius: Theme.chipRadius + 4))
    }

    private func kindLabel(_ kind: ItemKind) -> String {
        switch kind {
        case .skin: "WEAPON SKIN"
        case .buddy: "GUN BUDDY"
        case .spray: "SPRAY"
        case .card: "PLAYER CARD"
        case .title: "PLAYER TITLE"
        case .flex: "FLEX"
        case .other: "ITEM"
        }
    }
}

/// Wide art cropped to fill a fixed-height slot. The image sits in an overlay so its
/// natural width can't widen the layout, which a plain `.fill` frame does.
struct BannerImage: View {
    let url: URL?
    var height: CGFloat?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay { RemoteImage(url: url, contentMode: .fill) }
            .clipped()
    }
}

extension Catalog {
    /// Riot names bundle skins "<Collection> <Weapon>", so the shared prefix stands in for a
    /// bundle name that valorant-api.com hasn't published yet.
    func collectionName(of bundle: FeaturedBundle) -> String? {
        let names = bundle.items.filter { $0.kind == .skin }.compactMap { skin($0.itemID)?.name.split(separator: " ") }
        guard names.count > 1, var prefix = names.first else { return nil }
        for words in names.dropFirst() {
            prefix = zip(prefix, words).prefix(while: { $0.0 == $0.1 }).map { $0.0 }
        }
        return prefix.isEmpty ? nil : prefix.joined(separator: " ")
    }
}
