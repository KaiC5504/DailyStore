import Foundation
import Testing
@testable import ValorantCore

@Suite struct HistoryTests {
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func snapshot(_ iso: String, daily: [String] = ["LVL-1", "lvl-2"]) throws -> StoreSnapshot {
        let fixture = try Storefront(json: Data(Fixtures.storefront.utf8))
        let store = Storefront(daily: daily.enumerated().map { StoreOffer(offerID: "o\($0)", itemID: $1, cost: 875) },
                               dailyRemainingSeconds: 3600, nightMarket: fixture.nightMarket,
                               nightMarketRemainingSeconds: 900000, bundles: fixture.bundles)
        return StoreSnapshot(storefront: store, wallet: Wallet(vp: 0, radianite: 0, kingdomCredits: 0),
                             clientVersion: "v", fetchedAt: date(iso))
    }

    @Test func dayKeyIsTheUTCDate() {
        #expect(StoreHistory.dayKey(date("2026-09-23T00:00:00Z")) == "2026-09-23")
        #expect(StoreHistory.dayKey(date("2026-09-23T23:59:59Z")) == "2026-09-23")
        #expect(StoreHistory.dayKey(date("2026-01-05T08:00:00+08:00")) == "2026-01-05")
    }

    @Test func recordsOneEntryPerDayWithLowercasedIDs() throws {
        var history = StoreHistory()
        #expect(history.record(try snapshot("2026-09-23T01:00:00Z")))
        #expect(!history.record(try snapshot("2026-09-23T09:00:00Z")))
        #expect(history.days.count == 1)
        let day = try #require(history.days.first)
        #expect(day.day == "2026-09-23")
        #expect(day.daily.map(\.id) == ["lvl-1", "lvl-2"])
        #expect(day.nightMarket == [StoreHistory.Offer(id: "lvl-n1", cost: 1118, was: 1775)])
        #expect(day.bundles == ["2116a38e-4b71-f169-0d16-ce9289af4bfa"])
    }

    @Test func sameDayWithDifferentStoreReplacesAndOlderDaysSortFirst() throws {
        var history = StoreHistory()
        history.record(try snapshot("2026-09-24T01:00:00Z"))
        history.record(try snapshot("2026-09-22T01:00:00Z"))
        #expect(history.record(try snapshot("2026-09-24T05:00:00Z", daily: ["lvl-9"])))
        #expect(history.days.map(\.day) == ["2026-09-22", "2026-09-24"])
        #expect(history.days.last?.daily.map(\.id) == ["lvl-9"])
    }

    @Test func sightingsListDailyAndNightMarketDays() throws {
        var history = StoreHistory()
        history.record(try snapshot("2026-09-22T01:00:00Z"))
        history.record(try snapshot("2026-09-23T01:00:00Z", daily: ["lvl-3"]))
        let sightings = history.sightings(of: "LVL-1")
        #expect(sightings.map(\.day) == ["2026-09-22"])
        #expect(history.sightings(of: "lvl-n1").map(\.place) == [.nightMarket, .nightMarket])
    }

    @Test func encodesWithShortKeysAndSurvivesARoundTrip() throws {
        var history = StoreHistory()
        history.record(try snapshot("2026-09-23T01:00:00Z"))
        let data = try JSONEncoder().encode(history)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""d":"2026-09-23""#))
        #expect(!json.contains("nightMarket"))
        #expect(try JSONDecoder().decode(StoreHistory.self, from: data) == history)
    }

    @Test func snapshotsSavedBeforeOwnedExistedStillDecode() throws {
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(try snapshot("2026-09-23T01:00:00Z"))) as! [String: Any]
        old.removeValue(forKey: "owned")
        let decoded = try JSONDecoder().decode(StoreSnapshot.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.owned == nil)
    }
}
