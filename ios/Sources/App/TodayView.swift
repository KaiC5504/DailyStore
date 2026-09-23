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
            FitPage(minHeight: 660, refresh: { await model.refresh(force: true) }) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    StatusBanner()
                    if let snapshot = model.snapshot {
                        if !model.wishlistHits.isEmpty { WishlistHitBanner(hits: model.wishlistHits) }
                        FillGrid(items: snapshot.storefront.daily) { index, offer in
                            NavigationLink(value: SkinRoute(levelID: offer.itemID, price: offer.cost)) {
                                SkinCard(offer: offer, index: index)
                                    .matchedTransitionSource(id: offer.itemID, in: zoom)
                            }
                            .buttonStyle(PressableStyle())
                        }
                        .frame(maxHeight: .infinity)
                        if snapshot.storefront.nightMarket != nil, let ends = snapshot.nightMarketEndsAt {
                            NightMarketTeaser(ends: ends, action: openNightMarket)
                        }
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)) · pull to refresh")
                            .font(.caption2)
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                ScreenTitle(kicker: "Daily offers", title: "Today's Store")
                if let wallet = model.snapshot?.wallet { WalletStack(wallet: wallet) }
            }
            HStack(spacing: 8) {
                if let snapshot = model.snapshot {
                    CountdownChip(label: "Resets in", end: snapshot.dailyResetsAt, systemImage: "arrow.triangle.2.circlepath")
                }
                Text("at \(StoreClock.localResetTime())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.top, 8)
    }
}

/// Balances stacked beside the title so they don't cost a row of their own.
struct WalletStack: View {
    let wallet: Wallet

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            line(wallet.vp, Currency.vp)
            line(wallet.radianite, Currency.radianite)
            line(wallet.kingdomCredits, Currency.kingdomCredits)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.chipRadius))
        .fixedSize()
    }

    private func line(_ amount: Int, _ currency: String) -> some View {
        PriceTag(amount: amount, currency: currency, font: .system(size: 13, weight: .heavy).monospacedDigit())
    }
}

struct SkinCard: View {
    @Environment(AppModel.self) private var model
    let offer: StoreOffer
    let index: Int
    @State private var shown = false

    private var skin: SkinInfo? { model.catalog?.skin(offer.itemID) }
    private var tier: ContentTier? { skin.flatMap { model.catalog?.tier(for: $0) } }
    private var color: Color { model.catalog.tierColor(offer.itemID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: skin?.icon)
                .padding(.horizontal, 12)
                .padding(.top, 34)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .rotationEffect(.degrees(-12))
                .shadow(color: color.opacity(0.55), radius: 16, y: 6)
            VStack(alignment: .leading, spacing: 5) {
                TierBadge(tier: tier)
                Text((skin?.name ?? "Loading…").uppercased())
                    .font(Theme.display(22))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                PriceTag(amount: offer.cost, font: .system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(glow)
        .overlay(alignment: .topTrailing) {
            if model.isWishlisted(offer.itemID) {
                WishlistHeart(isOn: true).padding(10)
            }
        }
        .overlay(alignment: .topLeading) {
            Text(String(format: "%02d", index + 1))
                .font(Theme.display(20))
                .foregroundStyle(color.opacity(0.9))
                .padding(14)
        }
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: Theme.cardRadius))
        // The page no longer scrolls, so the cards deal in one after another on appear instead.
        .rotation3DEffect(.degrees(shown ? 0 : 55), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
        .offset(y: shown ? 0 : 36)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.08)) { shown = true }
        }
    }

    private var glow: some View {
        ZStack {
            RadialGradient(colors: [color.opacity(0.55), .clear], center: .init(x: 0.6, y: 0.38),
                           startRadius: 6, endRadius: 170)
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
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
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.22)), in: .rect(cornerRadius: Theme.chipRadius + 4))
        .onAppear { pulse.toggle() }
    }
}

struct NightMarketTeaser: View {
    let ends: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Theme.violet, Theme.accent], startPoint: .top, endPoint: .bottom))
                    .symbolEffect(.breathe, options: .repeat(.continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("NIGHT MARKET IS OPEN")
                        .font(Theme.display(28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Ends in \(ends, style: .relative)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textDim)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(Theme.violet.opacity(0.2)).interactive(), in: .rect(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}
