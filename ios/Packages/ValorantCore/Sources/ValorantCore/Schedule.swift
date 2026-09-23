import Foundation

/// The daily store rotates at 00:00 UTC for every region.
public enum StoreClock {
    public static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    public static func nextReset(after date: Date) -> Date {
        let calendar = utc
        let midnight = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: midnight)!
    }

    /// Reset time in the viewer's zone, e.g. "8:00 AM" in Malaysia, "10:00 AM" or "11:00 AM" in Sydney.
    public static func localResetTime(on date: Date = Date(), in zone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: nextReset(after: date))
    }
}

extension StoreSnapshot {
    public var dailyResetsAt: Date { fetchedAt.addingTimeInterval(TimeInterval(storefront.dailyRemainingSeconds)) }

    public var nightMarketEndsAt: Date? {
        storefront.nightMarketRemainingSeconds.map { fetchedAt.addingTimeInterval(TimeInterval($0)) }
    }

    public func bundleEndsAt(_ bundle: FeaturedBundle) -> Date {
        fetchedAt.addingTimeInterval(TimeInterval(bundle.remainingSeconds))
    }

    /// True once the rotation this snapshot was taken in has ended. Riot's own countdown is used,
    /// with the UTC clock as a guard in case the countdown came back as zero.
    public func isStale(at now: Date = Date()) -> Bool {
        let reset = storefront.dailyRemainingSeconds > 0 ? dailyResetsAt : StoreClock.nextReset(after: fetchedAt)
        return now >= reset
    }

    public var allOfferedLevelIDs: [String] {
        storefront.daily.map(\.itemID) + (storefront.nightMarket ?? []).map(\.offer.itemID)
    }
}

public struct WishlistHit: Hashable, Sendable {
    public enum Place: String, Sendable { case daily, nightMarket }
    public let levelID: String
    public let place: Place
    public let cost: Int
}

public enum Wishlist {
    public static func hits(in snapshot: StoreSnapshot, wishlist: Set<String>) -> [WishlistHit] {
        let wanted = Set(wishlist.map { $0.lowercased() })
        var hits: [WishlistHit] = []
        for offer in snapshot.storefront.daily where wanted.contains(offer.itemID.lowercased()) {
            hits.append(WishlistHit(levelID: offer.itemID.lowercased(), place: .daily, cost: offer.cost))
        }
        for offer in snapshot.storefront.nightMarket ?? [] where wanted.contains(offer.offer.itemID.lowercased()) {
            hits.append(WishlistHit(levelID: offer.offer.itemID.lowercased(), place: .nightMarket, cost: offer.discountedCost))
        }
        return hits
    }
}

/// What the widget needs to name and colour skins without loading the full catalog,
/// which is far too big for a widget's memory limit.
public struct CompactCatalog: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let name: String
        public let color: String?
        /// Only stored when it differs from the standard level icon URL.
        public let icon: URL?
    }

    public let clientVersion: String
    public let entries: [String: Entry]

    public init(clientVersion: String, entries: [String: Entry]) {
        self.clientVersion = clientVersion
        self.entries = entries
    }

    public init(_ catalog: Catalog) {
        clientVersion = catalog.clientVersion
        var entries: [String: Entry] = [:]
        for (id, skin) in catalog.skins {
            let standard = Self.standardIcon(id)
            entries[id] = Entry(name: skin.name, color: catalog.tier(for: skin)?.color,
                                icon: skin.icon == standard ? nil : skin.icon)
        }
        self.entries = entries
    }

    public func name(_ levelID: String) -> String? { entries[levelID.lowercased()]?.name }
    public func color(_ levelID: String) -> String? { entries[levelID.lowercased()]?.color }

    public func icon(_ levelID: String) -> URL? {
        guard let entry = entries[levelID.lowercased()] else { return nil }
        return entry.icon ?? Self.standardIcon(levelID.lowercased())
    }

    static func standardIcon(_ levelID: String) -> URL? {
        URL(string: "https://media.valorant-api.com/weaponskinlevels/\(levelID)/displayicon.png")
    }
}

extension Catalog {
    /// Skins and bundles in the store that this catalog can't name. Riot ships bundles mid-patch,
    /// so a catalog cached for the current client version can still be out of date.
    public func missingIDs(in snapshot: StoreSnapshot) -> Set<String> {
        let store = snapshot.storefront
        var skinIDs = store.daily.map(\.itemID) + (store.nightMarket ?? []).map(\.offer.itemID)
        var missing: Set<String> = []
        for bundle in store.bundles {
            if self.bundle(bundle.dataAssetID) == nil { missing.insert(bundle.dataAssetID.lowercased()) }
            skinIDs += bundle.items.filter { $0.kind == .skin }.map(\.itemID)
        }
        for id in skinIDs where skin(id) == nil { missing.insert(id.lowercased()) }
        return missing
    }
}
