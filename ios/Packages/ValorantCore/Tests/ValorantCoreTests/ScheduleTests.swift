import Foundation
import Testing
@testable import ValorantCore

@Suite struct ScheduleTests {
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    @Test func nextResetIsTheFollowingUTCMidnight() {
        #expect(StoreClock.nextReset(after: date("2026-09-23T07:41:50Z")) == date("2026-09-24T00:00:00Z"))
        #expect(StoreClock.nextReset(after: date("2026-09-23T00:00:00Z")) == date("2026-09-24T00:00:00Z"))
        #expect(StoreClock.nextReset(after: date("2026-09-23T23:59:59Z")) == date("2026-09-24T00:00:00Z"))
    }

    @Test func resetShowsInLocalTimeIncludingDaylightSaving() {
        let locale = Locale(identifier: "en_US_POSIX")
        // ICU puts a narrow no-break space before AM on some platforms.
        func time(_ iso: String, _ zone: String) -> String {
            StoreClock.localResetTime(on: date(iso), in: TimeZone(identifier: zone)!, locale: locale)
                .replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(time("2026-09-23T07:00:00Z", "Asia/Kuala_Lumpur") == "8:00 AM")
        // Sydney is UTC+10 in winter and UTC+11 once daylight saving starts in October.
        #expect(time("2026-07-01T07:00:00Z", "Australia/Sydney") == "10:00 AM")
        #expect(time("2026-12-01T07:00:00Z", "Australia/Sydney") == "11:00 AM")
    }

    @Test func snapshotIsFreshUntilRiotsCountdownEnds() throws {
        let store = try Storefront(json: Data(Fixtures.storefront.utf8))
        let fetched = date("2026-09-23T07:42:00Z")
        let snapshot = StoreSnapshot(storefront: store, wallet: Wallet(vp: 0, radianite: 0, kingdomCredits: 0),
                                     clientVersion: "v", fetchedAt: fetched)
        #expect(!snapshot.isStale(at: fetched.addingTimeInterval(58679)))
        #expect(snapshot.isStale(at: fetched.addingTimeInterval(58680)))
    }

    @Test func zeroCountdownFallsBackToUTCMidnight() {
        let store = Storefront(daily: [], dailyRemainingSeconds: 0, nightMarket: nil, nightMarketRemainingSeconds: nil, bundles: [])
        let snapshot = StoreSnapshot(storefront: store, wallet: Wallet(vp: 0, radianite: 0, kingdomCredits: 0),
                                     clientVersion: "v", fetchedAt: date("2026-09-23T10:00:00Z"))
        #expect(!snapshot.isStale(at: date("2026-09-23T23:00:00Z")))
        #expect(snapshot.isStale(at: date("2026-09-24T00:00:01Z")))
    }

    @Test func wishlistMatchesDailyAndNightMarketIgnoringCase() throws {
        let store = try Storefront(json: Data(Fixtures.storefront.utf8))
        let snapshot = StoreSnapshot(storefront: store, wallet: Wallet(vp: 0, radianite: 0, kingdomCredits: 0),
                                     clientVersion: "v", fetchedAt: Date())
        let hits = Wishlist.hits(in: snapshot, wishlist: ["LVL-3", "lvl-n1", "not-there"])
        #expect(hits == [
            WishlistHit(levelID: "lvl-3", place: .daily, cost: 2975),
            WishlistHit(levelID: "lvl-n1", place: .nightMarket, cost: 1118),
        ])
    }
}

@Suite struct CatalogExtrasTests {
    @Test func chromasGetShortNamesAndLevelsTheirUpgrade() throws {
        let araxys = try #require(try Catalog.parseSkins(Data(Fixtures.skins.utf8))["lvl-1"])
        #expect(araxys.chromas.map(\.name) == ["Standard", "Red"])
        #expect(araxys.chromas[1].render?.absoluteString == "https://x/c2.png")
        #expect(araxys.levels.map(\.name) == ["Level 1", "Level 2"])
        #expect(araxys.levels.map(\.upgrade) == [nil, "VFX"])
    }

    @Test func itemsPreferTransparentArtAndTitleText() throws {
        let sprays = try Catalog.parseItems(Data(Fixtures.sprays.utf8), kind: .spray)
        #expect(sprays["spray-1"]?.icon?.absoluteString == "https://x/t.png")
        let titles = try Catalog.parseItems(Data(Fixtures.titles.utf8), kind: .title)
        #expect(titles["t-1"]?.name == "Tiger")
    }

    @Test func bundlesAreKeyedByLowercasedDataAsset() throws {
        let bundles = try Catalog.parseBundles(Data(Fixtures.bundles.utf8))
        let catalog = Catalog(clientVersion: "v", skins: [:], tiers: [:], bundles: bundles)
        #expect(catalog.bundle("2116a38e-4b71-f169-0d16-ce9289af4bfa")?.name == "Reaver 2.0")
    }

    @Test func itemKindFromRiotTypeID() {
        #expect(ItemKind(typeID: "E7C63390-EDA7-46E0-BB7A-A6ABDACD2433") == .skin)
        #expect(ItemKind(typeID: "dd3bf334-87f3-40bd-b043-682a57a8dc3a") == .buddy)
        #expect(ItemKind(typeID: "nope") == .other)
    }

    @Test func compactCatalogOmitsStandardIconsButStillResolvesThem() throws {
        let catalog = Catalog(clientVersion: "v", skins: try Catalog.parseSkins(Data(Fixtures.skins.utf8)),
                              tiers: try Catalog.parseTiers(Data(Fixtures.tiers.utf8)))
        let compact = CompactCatalog(catalog)
        #expect(compact.entries["lvl-4"]?.icon == nil)
        #expect(compact.icon("LVL-4")?.absoluteString == "https://media.valorant-api.com/weaponskinlevels/lvl-4/displayicon.png")
        #expect(compact.icon("lvl-1")?.absoluteString == "https://media.valorant-api.com/chroma-a.png")
        #expect(compact.color("lvl-1") == "fad66333")
        #expect(compact.name("lvl-1") == "Araxys Sheriff")
    }
}
