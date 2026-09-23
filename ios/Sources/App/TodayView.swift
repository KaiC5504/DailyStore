import SwiftUI
import ValorantCore

struct SkinRoute: Hashable {
    let levelID: String
    let price: Int?
    var original: Int?
}

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var path = NavigationPath()
    var openNightMarket: () -> Void = {}

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    StatusBanner()
                    if let snapshot = model.snapshot {
                        if !model.wishlistHits.isEmpty { WishlistHitBanner(hits: model.wishlistHits) }
                        ForEach(Array(snapshot.storefront.daily.enumerated()), id: \.element.offerID) { index, offer in
                            NavigationLink(value: SkinRoute(levelID: offer.itemID, price: offer.cost)) {
                                SkinCard(offer: offer, index: index)
                                    .matchedTransitionSource(id: offer.itemID, in: zoom)
                            }
                            .buttonStyle(PressableStyle())
                        }
                        if let night = snapshot.storefront.nightMarket, let ends = snapshot.nightMarketEndsAt {
                            NightMarketTeaser(count: night.count, ends: ends, action: openNightMarket)
                        }
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)) · pull to refresh")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.refresh(force: true) }
            .background(AmbientBackground(tint: topTint))
            .navigationDestination(for: SkinRoute.self) { route in
                SkinDetailView(route: route)
                    .navigationTransition(.zoom(sourceID: route.levelID, in: zoom))
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        #if DEBUG
        .task(id: model.catalog?.clientVersion) {
            let index = UserDefaults.standard.integer(forKey: "DemoDetail")
            guard index > 0, path.isEmpty, model.catalog != nil,
                  let offers = model.snapshot?.storefront.daily, offers.indices.contains(index - 1) else { return }
            path.append(SkinRoute(levelID: offers[index - 1].itemID, price: offers[index - 1].cost))
        }
        #endif
    }

    private var topTint: Color {
        guard let first = model.snapshot?.storefront.daily.max(by: { $0.cost < $1.cost }) else { return Theme.accent }
        return model.catalog.tierColor(first.itemID)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenTitle(kicker: "Daily offers", title: "Today's Store")
            HStack(spacing: 8) {
                if let snapshot = model.snapshot {
                    CountdownChip(label: "Resets in", end: snapshot.dailyResetsAt, systemImage: "arrow.triangle.2.circlepath")
                }
                Text("at \(StoreClock.localResetTime())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
            }
            if let wallet = model.snapshot?.wallet { WalletBar(wallet: wallet) }
        }
        .padding(.top, 12)
    }
}

struct WalletBar: View {
    let wallet: Wallet

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                chip(wallet.vp, Currency.vp)
                chip(wallet.radianite, Currency.radianite)
                chip(wallet.kingdomCredits, Currency.kingdomCredits)
            }
        }
    }

    private func chip(_ amount: Int, _ currency: String) -> some View {
        PriceTag(amount: amount, currency: currency, font: .system(size: 14, weight: .heavy).monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
    }
}

struct SkinCard: View {
    @Environment(AppModel.self) private var model
    let offer: StoreOffer
    let index: Int

    private var skin: SkinInfo? { model.catalog?.skin(offer.itemID) }
    private var tier: ContentTier? { skin.flatMap { model.catalog?.tier(for: $0) } }
    private var color: Color { model.catalog.tierColor(offer.itemID) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            glow
            RemoteImage(url: skin?.icon)
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 64)
                .rotationEffect(.degrees(-9))
                .shadow(color: color.opacity(0.55), radius: 22, y: 8)
                .visualEffect { content, proxy in
                    // Art drifts against the scroll so the card feels deeper than it is.
                    let y = proxy.frame(in: .scrollView).midY
                    return content.offset(x: (y - 380) * -0.04)
                }
            VStack(alignment: .leading, spacing: 6) {
                TierBadge(tier: tier)
                HStack(alignment: .lastTextBaseline) {
                    Text((skin?.name ?? "Loading…").uppercased())
                        .font(Theme.display(30))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    PriceTag(amount: offer.cost)
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
        }
        .frame(height: 230)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if model.isWishlisted(offer.itemID) {
                WishlistHeart(isOn: true).padding(12)
            }
        }
        .overlay(alignment: .topLeading) {
            Text(String(format: "%02d", index + 1))
                .font(Theme.display(22))
                .foregroundStyle(color.opacity(0.9))
                .padding(16)
        }
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: Theme.cardRadius))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                .opacity(phase.isIdentity ? 1 : 0.35)
                .rotation3DEffect(.degrees(phase.value * -14), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .blur(radius: phase.isIdentity ? 0 : 2)
        }
    }

    private var glow: some View {
        ZStack {
            RadialGradient(colors: [color.opacity(0.55), .clear], center: .init(x: 0.62, y: 0.42),
                           startRadius: 10, endRadius: 230)
            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
        }
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StatusBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch model.phase {
            case .launching, .loading:
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(model.snapshot == nil ? "Loading your store…" : "Refreshing…")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
            case .signedOut:
                Button {
                    model.showLogin = true
                } label: {
                    Label("Sign in with Riot", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(12)
                    .glassEffect(.regular.tint(.orange.opacity(0.15)), in: .rect(cornerRadius: Theme.chipRadius))
            case .ready:
                EmptyView()
            }
            if let error = model.catalogError {
                Label(error, systemImage: "photo.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .animation(.snappy, value: model.phase)
    }
}

struct WishlistHitBanner: View {
    @Environment(AppModel.self) private var model
    let hits: [WishlistHit]
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text(hits.count == 1 ? "WISHLIST HIT" : "\(hits.count) WISHLIST HITS")
                    .font(Theme.label(11)).tracking(1.6)
                    .foregroundStyle(Theme.accent)
                Text(hits.compactMap { model.catalog?.skin($0.levelID)?.name }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.22)), in: .rect(cornerRadius: Theme.chipRadius + 4))
        .onAppear { pulse.toggle() }
    }
}

struct NightMarketTeaser: View {
    let count: Int
    let ends: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Theme.violet, Theme.accent], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 3) {
                    Text("NIGHT MARKET IS OPEN").font(Theme.label(12)).tracking(1.4)
                    Text("\(count) discounted offers · ends \(ends, style: .relative)")
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold))
            }
            .padding(16)
            .glassEffect(.regular.tint(Theme.violet.opacity(0.2)).interactive(), in: .rect(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}
