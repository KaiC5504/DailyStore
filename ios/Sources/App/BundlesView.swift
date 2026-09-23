import SwiftUI
import ValorantCore

struct BundlesView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(kicker: "Featured", title: "Bundles")
                        .padding(.top, 12)
                    if let snapshot = model.snapshot, !snapshot.storefront.bundles.isEmpty {
                        ForEach(snapshot.storefront.bundles, id: \.id) { bundle in
                            NavigationLink(value: bundle) {
                                BundleCard(bundle: bundle, ends: snapshot.bundleEndsAt(bundle))
                                    .matchedTransitionSource(id: bundle.id, in: zoom)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    } else {
                        ContentUnavailableView("No bundles loaded", systemImage: "shippingbox",
                                               description: Text("Pull down to refresh."))
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.refresh(force: true) }
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

    var body: some View {
        let info = model.catalog?.bundle(bundle.dataAssetID)
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: info?.art, contentMode: .fill)
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipped()
                .visualEffect { content, proxy in
                    content.offset(y: (proxy.frame(in: .scrollView).minY - 200) * -0.08)
                }
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.92)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text((info?.name ?? "Bundle").uppercased())
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
                    Text("Ends \(ends, style: .relative)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textDim)
                }
            }
            .padding(16)
        }
        .frame(height: 210)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .glassEffect(.clear, in: .rect(cornerRadius: Theme.cardRadius))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                .opacity(phase.isIdentity ? 1 : 0.4)
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
                RemoteImage(url: info?.art, contentMode: .fill)
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
                VStack(alignment: .leading, spacing: 6) {
                    Text((info?.name ?? "Bundle").uppercased())
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
        HStack(spacing: 14) {
            RemoteImage(url: icon)
                .frame(width: item.kind == .skin ? 110 : 56, height: 56)
                .shadow(color: color.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(name ?? "Unknown item")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(kindLabel(item.kind))
                    .font(Theme.label(9)).tracking(1.2)
                    .foregroundStyle(Theme.textFaint)
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
        .glassEffect(.regular.tint(color.opacity(0.08)), in: .rect(cornerRadius: Theme.chipRadius + 4))
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
