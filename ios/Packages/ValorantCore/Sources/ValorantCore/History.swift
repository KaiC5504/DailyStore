import Foundation

/// Every store the app has seen, one entry per UTC day. Kept compact (short keys, IDs and
/// prices only) because it lives in the Keychain next to the snapshot and never shrinks.
public struct StoreHistory: Codable, Equatable, Sendable {
    public struct Offer: Codable, Equatable, Sendable {
        public let id: String
        public let cost: Int
        /// Full price, for Night Market offers only.
        public let was: Int?

        public init(id: String, cost: Int, was: Int? = nil) {
            self.id = id
            self.cost = cost
            self.was = was
        }

        enum CodingKeys: String, CodingKey { case id = "i", cost = "c", was = "w" }
    }

    public struct Day: Codable, Equatable, Sendable {
        /// UTC date, "yyyy-MM-dd".
        public let day: String
        public let daily: [Offer]
        public let nightMarket: [Offer]?
        /// Bundle data asset IDs.
        public let bundles: [String]

        enum CodingKeys: String, CodingKey { case day = "d", daily = "s", nightMarket = "n", bundles = "b" }
    }

    public private(set) var days: [Day]

    public init(days: [Day] = []) {
        self.days = days
    }

    public static func dayKey(_ date: Date) -> String {
        let parts = StoreClock.utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Adds or replaces the snapshot's day. Returns false when nothing changed, so callers can
    /// skip rewriting the Keychain item.
    @discardableResult
    public mutating func record(_ snapshot: StoreSnapshot) -> Bool {
        let store = snapshot.storefront
        let entry = Day(
            day: Self.dayKey(snapshot.fetchedAt),
            daily: store.daily.map { Offer(id: $0.itemID.lowercased(), cost: $0.cost) },
            nightMarket: store.nightMarket?.map {
                Offer(id: $0.offer.itemID.lowercased(), cost: $0.discountedCost, was: $0.offer.cost)
            },
            bundles: store.bundles.map { $0.dataAssetID.lowercased() }
        )
        if let index = days.firstIndex(where: { $0.day == entry.day }) {
            guard days[index] != entry else { return false }
            days[index] = entry
        } else {
            let index = days.firstIndex { $0.day > entry.day } ?? days.endIndex
            days.insert(entry, at: index)
        }
        return true
    }

    /// Days a skin was offered, oldest first.
    public func sightings(of levelID: String) -> [(day: String, place: WishlistHit.Place)] {
        let id = levelID.lowercased()
        return days.flatMap { day -> [(day: String, place: WishlistHit.Place)] in
            var found: [(day: String, place: WishlistHit.Place)] = []
            if day.daily.contains(where: { $0.id == id }) { found.append((day.day, .daily)) }
            if day.nightMarket?.contains(where: { $0.id == id }) == true { found.append((day.day, .nightMarket)) }
            return found
        }
    }
}
