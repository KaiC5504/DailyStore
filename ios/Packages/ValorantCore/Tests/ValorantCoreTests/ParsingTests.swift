import Foundation
import Testing
@testable import ValorantCore

@Suite struct StorefrontTests {
    @Test func dailyOffersCarryVPCostAndLevelID() throws {
        let store = try Storefront(json: Data(Fixtures.storefront.utf8))
        #expect(store.daily.map(\.itemID) == ["lvl-1", "lvl-2", "lvl-3", "lvl-4"])
        #expect(store.daily.map(\.cost) == [2175, 1775, 2975, 875])
        #expect(store.dailyRemainingSeconds == 58680)
    }

    @Test func nightMarketIsParsedWhenPresent() throws {
        let store = try Storefront(json: Data(Fixtures.storefront.utf8))
        let offer = try #require(store.nightMarket?.first)
        #expect(offer.offer.itemID == "lvl-n1")
        #expect(offer.offer.cost == 1775)
        #expect(offer.discountedCost == 1118)
        #expect(offer.discountPercent == 37)
        #expect(offer.isSeen)
        #expect(store.nightMarketRemainingSeconds == 900000)
    }

    @Test func missingBonusStoreMeansNoNightMarket() throws {
        var object = try JSONSerialization.jsonObject(with: Data(Fixtures.storefront.utf8)) as! [String: Any]
        object.removeValue(forKey: "BonusStore")
        let store = try Storefront(json: try JSONSerialization.data(withJSONObject: object))
        #expect(store.nightMarket == nil)
        #expect(store.daily.count == 4)
    }

    @Test func bundlesKeepTotalsAndItems() throws {
        let bundle = try #require(try Storefront(json: Data(Fixtures.storefront.utf8)).bundles.first)
        #expect(bundle.dataAssetID == "2116a38e-4b71-f169-0d16-ce9289af4bfa")
        #expect(bundle.baseCost == 7100)
        #expect(bundle.discountedCost == 5325)
        #expect(bundle.items.first?.discountedPrice == 1189)
    }

    @Test func responseWithoutSkinsPanelIsAnError() {
        #expect(throws: RiotError.unexpected(step: "Storefront")) {
            try Storefront(json: Data(#"{"FeaturedBundle": {}}"#.utf8))
        }
    }

    @Test func walletPicksTheThreeCurrencies() throws {
        let wallet = try Wallet(json: Data(Fixtures.wallet.utf8))
        #expect(wallet.vp == 4909)
        #expect(wallet.kingdomCredits == 10000)
        #expect(wallet.radianite == 0)
    }
}

@Suite struct CatalogTests {
    @Test func skinsAreKeyedByLowercasedFirstLevel() throws {
        let skins = try Catalog.parseSkins(Data(Fixtures.skins.utf8))
        #expect(Set(skins.keys) == ["lvl-1", "lvl-4"])
        let catalog = Catalog(clientVersion: "v", skins: skins, tiers: [:])
        #expect(catalog.skin("LVL-1")?.name == "Araxys Sheriff")
    }

    @Test func iconFallsBackToChromaRenderAndVideoToLaterLevels() throws {
        let araxys = try #require(try Catalog.parseSkins(Data(Fixtures.skins.utf8))["lvl-1"])
        #expect(araxys.icon?.absoluteString == "https://media.valorant-api.com/chroma-a.png")
        #expect(araxys.video?.absoluteString == "https://valorant.dyn.riotcdn.net/a.mp4")
        #expect(araxys.tierID == "411e4a55-4e59-7757-41f0-86a53f101bb5")
    }

    @Test func tierLookupThroughSkin() throws {
        let catalog = Catalog(
            clientVersion: "v",
            skins: try Catalog.parseSkins(Data(Fixtures.skins.utf8)),
            tiers: try Catalog.parseTiers(Data(Fixtures.tiers.utf8))
        )
        let tier = try #require(catalog.skin("lvl-1").flatMap(catalog.tier(for:)))
        #expect(tier.name == "Ultra")
        #expect(tier.color == "fad66333")
        #expect(catalog.skin("lvl-4").flatMap(catalog.tier(for:)) == nil)
    }
}
