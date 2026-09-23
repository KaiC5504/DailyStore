import SwiftUI

@main
struct DailyStoreApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Skin art is large and re-requested on every screen; AsyncImage goes through the shared cache.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 400 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: Task { await model.resume() }
                    case .background: AppModel.scheduleBackgroundRefresh()
                    default: break
                    }
                }
                .sheet(isPresented: $model.showLogin) {
                    LoginView { cookies in Task { await model.signIn(cookies: cookies) } }
                }
        }
        .backgroundTask(.appRefresh(AppModel.refreshTaskID)) {
            await AppModel.backgroundRefresh()
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "DemoTab") ?? "") ?? .today

    enum AppTab: String { case today, night, bundles, wishlist, settings }

    var body: some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "DemoWidgets") {
            NavigationStack { WidgetGallery() }
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sparkles", value: AppTab.today) {
                TodayView(openNightMarket: { tab = .night })
            }
            Tab("Night Market", systemImage: "moon.stars.fill", value: AppTab.night) {
                NightMarketView()
            }
            .badge(model.snapshot?.storefront.nightMarket.map { offers in
                offers.filter { !model.isRevealed($0) }.count
            } ?? 0)
            Tab("Bundles", systemImage: "shippingbox.fill", value: AppTab.bundles) {
                BundlesView()
            }
            Tab("Wishlist", systemImage: "heart.fill", value: AppTab.wishlist) {
                WishlistView()
            }
            .badge(model.wishlistHits.count)
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .background(Theme.ink)
    }
}
