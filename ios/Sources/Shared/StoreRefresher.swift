import Foundation
import UserNotifications
import ValorantCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// One fetch path for the app, background refresh and the widget, so all three
/// save the rotated cookies, the snapshot and the wishlist alert the same way.
enum StoreRefresher {
    static func makeService(log: @escaping @Sendable (String) -> Void = { _ in }) -> StoreService {
        StoreService(http: URLSessionHTTPClient(), sessions: KeychainSessionStore(), log: log)
    }

    /// Returns the saved snapshot when it is still today's, otherwise fetches.
    static func current(using service: StoreService, force: Bool = false) async throws -> StoreSnapshot {
        if !force, let saved = SharedState.snapshot, !saved.isStale() { return saved }
        let fresh = try await service.fetch()
        await didFetch(fresh)
        return fresh
    }

    static func didFetch(_ snapshot: StoreSnapshot) async {
        SharedState.save(snapshot)
        await Notifier.alertWishlistIfNeeded(snapshot)
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

enum Notifier {
    static let dailyID = "daily-reset"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Fires at 00:01 UTC every day, which lands on the right local time in any zone and across
    /// daylight saving without rescheduling.
    static func scheduleDailyReset(enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        guard enabled else { return }
        var components = DateComponents()
        components.calendar = StoreClock.utc
        components.timeZone = TimeZone(identifier: "UTC")
        components.hour = 0
        components.minute = 1
        let content = UNMutableNotificationContent()
        content.title = "New store is up"
        content.body = "Your daily VALORANT offers just reset. Tap to see today's four."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: dailyID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    static func alertWishlistIfNeeded(_ snapshot: StoreSnapshot) async {
        let hits = Wishlist.hits(in: snapshot, wishlist: SharedState.wishlist)
        guard !hits.isEmpty else { return }
        // Keyed by UTC day: dailyResetsAt drifts by a second or two between fetches.
        let day = StoreClock.utc.startOfDay(for: snapshot.fetchedAt)
        var alerts = SharedState.alerts
        guard alerts.wishlistEnabled, alerts.wishlistAlertedFor != day else { return }
        alerts.wishlistAlertedFor = day
        SharedState.alerts = alerts

        let names = SharedState.compactCatalog
        let lines = hits.map { hit in
            let name = names?.name(hit.levelID) ?? "A wishlisted skin"
            return hit.place == .nightMarket ? "\(name) (Night Market, \(hit.cost) VP)" : "\(name) (\(hit.cost) VP)"
        }
        let content = UNMutableNotificationContent()
        content.title = hits.count == 1 ? "Wishlist skin in your store" : "\(hits.count) wishlist skins in your store"
        content.body = lines.joined(separator: "\n")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "wishlist-\(Int(day.timeIntervalSince1970))",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

enum Prefs {
    static let dailyReminder = "dailyReminder"
}
