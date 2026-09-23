import SwiftUI
import ValorantCore

struct WishlistView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var results: [SkinInfo] {
        guard let catalog = model.catalog else { return [] }
        let words = query.lowercased().split(separator: " ")
        guard !words.isEmpty else { return [] }
        return catalog.skins.values
            .filter { skin in
                let name = skin.name.lowercased()
                return words.allSatisfy { name.contains($0) }
            }
            .sorted { $0.name < $1.name }
            .prefix(60)
            .map { $0 }
    }

    private var saved: [SkinInfo] {
        model.wishlist.compactMap { model.catalog?.skin($0) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if query.isEmpty {
                        ScreenTitle(kicker: "Get pinged when it drops", title: "Wishlist")
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        if !model.wishlistHits.isEmpty {
                            WishlistHitBanner(hits: model.wishlistHits)
                        }
                        if saved.isEmpty {
                            ContentUnavailableView("Nothing wishlisted yet", systemImage: "heart",
                                                   description: Text("Search for a skin above. When it shows up in your daily store or Night Market, you get a notification and the widget lights up."))
                                .padding(.top, 40)
                        }
                        ForEach(saved, id: \.levelID) { skin in row(skin) }
                    } else {
                        ForEach(results, id: \.levelID) { skin in row(skin) }
                        if results.isEmpty {
                            ContentUnavailableView.search(text: query).padding(.top, 40)
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(AmbientBackground(tint: Theme.accent, secondary: .pink.opacity(0.5)))
            .searchable(text: $query, prompt: "Search all skins")
            .navigationDestination(for: SkinRoute.self) { SkinDetailView(route: $0) }
        }
    }

    private func row(_ skin: SkinInfo) -> some View {
        let on = model.isWishlisted(skin.levelID)
        let color = model.catalog.tierColor(skin.levelID)
        let inStore = model.wishlistHits.contains { $0.levelID == skin.levelID }
        return HStack(spacing: 12) {
            NavigationLink(value: SkinRoute(levelID: skin.levelID, price: nil)) {
                HStack(spacing: 12) {
                    RemoteImage(url: skin.icon)
                        .frame(width: 96, height: 44)
                        .shadow(color: color.opacity(0.5), radius: 8)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin.name).font(.subheadline.weight(.bold)).lineLimit(1)
                        HStack(spacing: 6) {
                            TierBadge(tier: model.catalog?.tier(for: skin))
                            if inStore {
                                Text("IN STORE").font(Theme.label(9)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.bouncy) { model.toggleWishlist(skin.levelID) }
            } label: {
                WishlistHeart(isOn: on)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: on)
        }
        .foregroundStyle(.white)
        .padding(10)
        .glassEffect(.regular.tint(inStore ? Theme.accent.opacity(0.2) : color.opacity(0.06)),
                     in: .rect(cornerRadius: Theme.chipRadius + 4))
    }
}
