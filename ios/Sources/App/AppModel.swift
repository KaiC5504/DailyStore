import BackgroundTasks
import Foundation
import Observation
import ValorantCore

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching, signedOut, loading, ready
        case failed(String)
    }

    nonisolated static let refreshTaskID = "com.kaichuan.dailystore.refresh"

    private(set) var phase: Phase = .launching
    private(set) var snapshot: StoreSnapshot?
    private(set) var catalog: Catalog?
    private(set) var catalogError: String?
    private(set) var log: [String] = []
    private(set) var wishlist: Set<String> = []
    private(set) var revealed: Set<String> = []
    private(set) var shard: String?
    var showLogin = false

    let isDemo: Bool

    @ObservationIgnored private let http = URLSessionHTTPClient()
    @ObservationIgnored private let service: StoreService
    @ObservationIgnored private let catalogCache = FileCache<Catalog>(name: "catalog.json")
    @ObservationIgnored private var resetTimer: Task<Void, Never>?

    init() {
        #if DEBUG
        isDemo = UserDefaults.standard.bool(forKey: "DemoData")
        #else
        isDemo = false
        #endif
        let relay = LogRelay()
        service = StoreRefresher.makeService(log: { relay.send($0) })
        relay.model = self
        revealed = Set(UserDefaults.standard.stringArray(forKey: "revealedNightOffers") ?? [])
    }

    var isStale: Bool { snapshot?.isStale() ?? true }

    func start() async {
        catalog = catalogCache.load()
        #if DEBUG
        if isDemo {
            snapshot = DemoData.snapshot
            wishlist = DemoData.wishlist
            phase = .ready
            await loadCatalogIfNeeded(for: DemoData.snapshot)
            return
        }
        #endif
        SharedKeychain.shared.migrateLegacySession()
        FileCache<StoreSnapshot>(name: "snapshot.json").clear()
        wishlist = SharedState.wishlist
        snapshot = SharedState.snapshot
        shard = (try? KeychainSessionStore().load())?.shard
        guard await service.isSignedIn else {
            phase = .signedOut
            showLogin = true
            return
        }
        if let snapshot, !snapshot.isStale() {
            // Today's store is already saved; Riot is only asked again after the 00:00 UTC reset.
            record("Using saved store from \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)), next fetch after reset")
            phase = .ready
            armResetTimer()
            await loadCatalogIfNeeded(for: snapshot)
        } else {
            await refresh(force: true)
        }
    }

    /// Called when the app comes to the foreground.
    func resume() async {
        guard !isDemo, phase != .loading, phase != .launching, phase != .signedOut else { return }
        if let saved = SharedState.snapshot, saved.fetchedAt > (snapshot?.fetchedAt ?? .distantPast) {
            snapshot = saved
        }
        if isStale {
            await refresh(force: true)
        } else {
            armResetTimer()
            if let snapshot { await loadCatalogIfNeeded(for: snapshot) }
        }
    }

    func refresh(force: Bool = true) async {
        guard !isDemo else { return }
        phase = .loading
        await run { [service] in try await StoreRefresher.current(using: service, force: force) }
    }

    func signIn(cookies: RiotCookies) async {
        showLogin = false
        phase = .loading
        await run { [service] in
            let snapshot = try await service.signIn(cookies: cookies)
            await StoreRefresher.didFetch(snapshot)
            return snapshot
        }
    }

    func signOut() async {
        try? await service.signOut()
        snapshot = nil
        SharedState.clearSnapshot()
        StoreRefresher.reloadWidgets()
        phase = .signedOut
        showLogin = true
    }

    func isWishlisted(_ levelID: String) -> Bool { wishlist.contains(levelID.lowercased()) }

    func toggleWishlist(_ levelID: String) {
        let id = levelID.lowercased()
        if wishlist.contains(id) { wishlist.remove(id) } else { wishlist.insert(id) }
        guard !isDemo else { return }
        SharedState.wishlist = wishlist
        StoreRefresher.reloadWidgets()
    }

    var wishlistHits: [WishlistHit] {
        snapshot.map { Wishlist.hits(in: $0, wishlist: wishlist) } ?? []
    }

    func isRevealed(_ offer: NightMarketOffer) -> Bool {
        offer.isSeen || revealed.contains(offer.offer.offerID) || UserDefaults.standard.bool(forKey: "DemoReveal")
    }

    func reveal(_ offer: NightMarketOffer) {
        revealed.insert(offer.offer.offerID)
        UserDefaults.standard.set(Array(revealed), forKey: "revealedNightOffers")
    }

    func record(_ line: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        log.append("\(stamp)  \(line)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        // A couple of minutes past the reset so Riot has rotated the offers.
        request.earliestBeginDate = StoreClock.nextReset(after: Date()).addingTimeInterval(120)
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated static func backgroundRefresh() async {
        scheduleBackgroundRefresh()
        let service = StoreRefresher.makeService()
        if (try? await StoreRefresher.current(using: service)) != nil {
            StoreRefresher.reloadWidgets()
        }
    }

    private func run(_ work: @escaping () async throws -> StoreSnapshot) async {
        do {
            let fresh = try await work()
            snapshot = fresh
            phase = .ready
            shard = (try? KeychainSessionStore().load())?.shard
            armResetTimer()
            StoreRefresher.reloadWidgets()
            await loadCatalogIfNeeded(for: fresh)
            await setUpNotificationsOnce()
        } catch RiotError.sessionExpired, RiotError.notSignedIn {
            phase = .signedOut
            showLogin = true
        } catch {
            record("Error: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    /// The reset reminder is on by default; the permission prompt comes after the first
    /// successful fetch so it isn't the first thing a new install sees.
    private func setUpNotificationsOnce() async {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Prefs.dailyReminder) == nil {
            let granted = await Notifier.requestPermission()
            defaults.set(granted, forKey: Prefs.dailyReminder)
        }
        await Notifier.scheduleDailyReset(enabled: defaults.bool(forKey: Prefs.dailyReminder))
    }

    /// Picks up the new store the moment it rotates if the app is open at the time.
    private func armResetTimer() {
        resetTimer?.cancel()
        guard let reset = snapshot?.dailyResetsAt else { return }
        let delay = max(5, reset.timeIntervalSinceNow + 5)
        resetTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.refresh(force: true)
        }
    }

    private func loadCatalogIfNeeded(for snapshot: StoreSnapshot) async {
        let defaults = UserDefaults.standard
        if let catalog, catalog.clientVersion == snapshot.clientVersion, !catalog.bundles.isEmpty {
            let missing = catalog.missingIDs(in: snapshot)
            // valorant-api.com can lag a new release by a day or two, so every open checks again.
            // The whole catalog is under a megabyte; the gap only stops back-to-back opens repeating it.
            let retryAt = defaults.object(forKey: "catalogRetryAt") as? Date ?? .distantPast
            guard !missing.isEmpty, Date() >= retryAt else {
                if !isDemo { SharedState.save(CompactCatalog(catalog)) }
                return
            }
            record("Catalog is missing \(missing.count) store items, refetching")
            defaults.set(Date().addingTimeInterval(300), forKey: "catalogRetryAt")
        }
        do {
            let fresh = try await Catalog.fetch(http: http, clientVersion: snapshot.clientVersion)
            catalog = fresh
            catalogCache.save(fresh)
            catalogError = nil
            record("Catalog OK: \(fresh.skins.count) skins, \(fresh.bundles.count) bundles")
            if !isDemo {
                SharedState.save(CompactCatalog(fresh))
                StoreRefresher.reloadWidgets()
            }
        } catch {
            catalogError = "Couldn't load skin names and images (\(error.localizedDescription))."
            record("Catalog error: \(error.localizedDescription)")
        }
    }
}

/// Lets the service log before the model finishes initialising.
private final class LogRelay: @unchecked Sendable {
    weak var model: AppModel?

    func send(_ line: String) {
        Task { @MainActor [weak model] in model?.record(line) }
    }
}

struct FileCache<Value: Codable> {
    let name: String

    private var url: URL {
        URL.cachesDirectory.appending(path: name)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) {
        try? JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
