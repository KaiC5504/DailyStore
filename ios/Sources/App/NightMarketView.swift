import SwiftUI
import ValorantCore

struct NightMarketView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(kicker: "Limited discounts", title: "Night Market")
                        .padding(.top, 12)
                    if let snapshot = model.snapshot, let offers = snapshot.storefront.nightMarket {
                        HStack {
                            if let ends = snapshot.nightMarketEndsAt {
                                CountdownChip(label: "Ends", end: ends, systemImage: "moon.fill")
                            }
                            Spacer()
                            if offers.contains(where: { !model.isRevealed($0) }) {
                                Button("Reveal all") {
                                    for (index, offer) in offers.enumerated() {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.12)) {
                                            model.reveal(offer)
                                        }
                                    }
                                }
                                .buttonStyle(.glass)
                                .font(.footnote.weight(.bold))
                            }
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(offers, id: \.offer.offerID) { offer in
                                NightCard(offer: offer, zoom: zoom)
                            }
                        }
                    } else {
                        ContentUnavailableView("No Night Market right now", systemImage: "moon.zzz",
                                               description: Text("It shows up here the moment Riot opens one."))
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.refresh(force: true) }
            .background(AmbientBackground(tint: Theme.violet, secondary: Theme.accent))
            .navigationDestination(for: SkinRoute.self) { route in
                SkinDetailView(route: route)
                    .navigationTransition(.zoom(sourceID: route.levelID, in: zoom))
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
}

private struct NightCard: View {
    @Environment(AppModel.self) private var model
    let offer: NightMarketOffer
    let zoom: Namespace.ID

    private var revealed: Bool { model.isRevealed(offer) }
    private var color: Color { model.catalog.tierColor(offer.offer.itemID) }

    var body: some View {
        ZStack {
            front
                .opacity(revealed ? 1 : 0)
                .rotation3DEffect(.degrees(revealed ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            back
                .opacity(revealed ? 0 : 1)
                .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        }
        .frame(height: 210)
        .sensoryFeedback(.impact(weight: .medium), trigger: revealed)
    }

    private var back: some View {
        Button {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { model.reveal(offer) }
        } label: {
            ZStack {
                LinearGradient(colors: [Theme.violet.opacity(0.5), Theme.accent.opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
                VStack(spacing: 10) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 44, weight: .black))
                    Text("TAP TO REVEAL").font(Theme.label(10)).tracking(1.6)
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(PressableStyle())
    }

    private var front: some View {
        NavigationLink(value: SkinRoute(levelID: offer.offer.itemID, price: offer.discountedCost, original: offer.offer.cost)) {
            let skin = model.catalog?.skin(offer.offer.itemID)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("-\(offer.discountPercent)%")
                        .font(Theme.display(26))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    if model.isWishlisted(offer.offer.itemID) {
                        Image(systemName: "heart.fill").foregroundStyle(Theme.accent)
                    }
                }
                RemoteImage(url: skin?.icon)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .rotationEffect(.degrees(-10))
                    .shadow(color: color.opacity(0.6), radius: 14)
                Text((skin?.name ?? "…").uppercased())
                    .font(Theme.display(19))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                PriceTag(amount: offer.discountedCost, original: offer.offer.cost,
                         font: .system(size: 15, weight: .heavy).monospacedDigit())
            }
            .padding(14)
            .background(
                RadialGradient(colors: [color.opacity(0.45), .clear], center: .center, startRadius: 4, endRadius: 140)
            )
            .glassEffect(.regular.tint(color.opacity(0.1)), in: .rect(cornerRadius: Theme.cardRadius))
            .matchedTransitionSource(id: offer.offer.itemID, in: zoom)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .allowsHitTesting(revealed)
    }
}
