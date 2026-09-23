import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import ValorantCore

final class MockHTTP: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var routes: [(match: String, respond: (URLRequest) -> HTTPResponse)] = []
    private(set) var requests: [URLRequest] = []

    func on(_ match: String, _ respond: @escaping (URLRequest) -> HTTPResponse) {
        routes.append((match, respond))
    }

    func on(_ match: String, status: Int = 200, json: String) {
        on(match) { _ in HTTPResponse(status: status, body: Data(json.utf8)) }
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        lock.withLock { requests.append(request) }
        let url = request.url!.absoluteString
        guard let route = routes.last(where: { url.contains($0.match) }) else {
            return HTTPResponse(status: 404)
        }
        return route.respond(request)
    }

    func requests(to match: String) -> [URLRequest] {
        lock.withLock { requests.filter { $0.url!.absoluteString.contains(match) } }
    }
}

final class MemorySessions: SessionStore, @unchecked Sendable {
    var session: RiotSession?
    init(_ session: RiotSession? = nil) { self.session = session }
    func load() throws -> RiotSession? { session }
    func save(_ session: RiotSession) throws { self.session = session }
    func clear() throws { session = nil }
}

enum Fixtures {
    static let puuid = "11111111-2222-3333-4444-555555555555"

    static let successLocation =
        "https://playvalorant.com/opt_in#access_token=ACCESS.TOKEN.X&scope=account+openid&iss=https%3A%2F%2Fauth.riotgames.com&id_token=ID.TOKEN.Y&token_type=Bearer&session_state=abc&expires_in=3600"

    static let expiredLocation =
        "https://authenticate.riotgames.com/login?client_id=play-valorant-web-prod&method=riot_identity"

    /// Two cookies joined by Foundation, including the comma inside Expires.
    static let rotatedSetCookie =
        "ssid=NEW_SSID; Path=/; Expires=Fri, 23 Oct 2026 07:41:50 GMT; Max-Age=2592000; HttpOnly; Secure, clid=NEW_CLID; Path=/; Expires=Fri, 23 Oct 2026 07:41:50 GMT; Max-Age=2592000, __cf_bm=junk; Path=/"

    static let storefront = """
    {
      "FeaturedBundle": {
        "Bundle": {},
        "Bundles": [{
          "ID": "b1", "DataAssetID": "2116a38e-4b71-f169-0d16-ce9289af4bfa", "CurrencyID": "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741",
          "Items": [{"Item": {"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-a", "Amount": 1},
                     "BasePrice": 1775, "CurrencyID": "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741", "DiscountPercent": 0.33, "DiscountedPrice": 1189, "IsPromoItem": false}],
          "ItemOffers": null,
          "TotalBaseCost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 7100},
          "TotalDiscountedCost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 5325},
          "TotalDiscountPercent": 0.25, "DurationRemainingInSeconds": 400000, "WholesaleOnly": false
        }],
        "BundleRemainingDurationInSeconds": 400000
      },
      "SkinsPanelLayout": {
        "SingleItemOffers": ["lvl-1", "lvl-2", "lvl-3", "lvl-4"],
        "SingleItemStoreOffers": [
          {"OfferID": "lvl-1", "IsDirectPurchase": true, "StartDate": "2026-09-23T00:00:00Z", "Cost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 2175}, "Rewards": [{"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-1", "Quantity": 1}]},
          {"OfferID": "lvl-2", "IsDirectPurchase": true, "StartDate": "2026-09-23T00:00:00Z", "Cost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 1775}, "Rewards": [{"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-2", "Quantity": 1}]},
          {"OfferID": "lvl-3", "IsDirectPurchase": true, "StartDate": "2026-09-23T00:00:00Z", "Cost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 2975}, "Rewards": [{"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-3", "Quantity": 1}]},
          {"OfferID": "lvl-4", "IsDirectPurchase": true, "StartDate": "2026-09-23T00:00:00Z", "Cost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 875}, "Rewards": [{"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-4", "Quantity": 1}]}
        ],
        "SingleItemOffersRemainingDurationInSeconds": 58680
      },
      "UpgradeCurrencyStore": {"UpgradeCurrencyOffers": []},
      "AccessoryStore": {"AccessoryStoreOffers": [], "AccessoryStoreRemainingDurationInSeconds": 1000, "StorefrontID": "s"},
      "PluginStores": [{"PluginID": "p", "Offers": []}],
      "BonusStore": {
        "BonusStoreOffers": [
          {"BonusOfferID": "n1", "Offer": {"OfferID": "o1", "IsDirectPurchase": true, "StartDate": "2026-09-01T00:00:00Z", "Cost": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 1775}, "Rewards": [{"ItemTypeID": "e7c63390-eda7-46e0-bb7a-a6abdacd2433", "ItemID": "lvl-n1", "Quantity": 1}]},
           "DiscountPercent": 37, "DiscountCosts": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 1118}, "IsSeen": true}
        ],
        "BonusStoreRemainingDurationInSeconds": 900000
      }
    }
    """

    static let wallet = """
    {"Balances": {"85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741": 4909, "85ca954a-41f2-ce94-9b45-8ca3dd39a00d": 10000, "e59aa87c-4cbf-517a-5983-6e81511be9b7": 0, "f08d4ae3-939c-4576-ab26-09ce1f23bb37": 3}}
    """

    static let skins = """
    {"status": 200, "data": [
      {"uuid": "SKIN-A", "displayName": "Araxys Sheriff", "contentTierUuid": "411e4a55-4e59-7757-41f0-86a53f101bb5",
       "displayIcon": null,
       "chromas": [{"uuid": "c-a1", "displayName": "Araxys Sheriff", "displayIcon": null, "fullRender": "https://media.valorant-api.com/chroma-a.png", "swatch": null, "streamedVideo": null},
                   {"uuid": "c-a2", "displayName": "Araxys Sheriff Level 4\\r\\n(Variant 1 Red)", "displayIcon": "https://x/c2.png", "fullRender": null, "swatch": "https://x/s2.png", "streamedVideo": "https://x/c2.mp4"}],
       "levels": [{"uuid": "LVL-1", "levelItem": null, "displayIcon": null, "streamedVideo": null},
                  {"uuid": "lvl-1b", "levelItem": "EEquippableSkinLevelItem::VFX", "displayIcon": null, "streamedVideo": "https://valorant.dyn.riotcdn.net/a.mp4"}]},
      {"uuid": "skin-b", "displayName": "Luxe Ghost", "contentTierUuid": null, "displayIcon": "https://media.valorant-api.com/b.png",
       "chromas": [], "levels": [{"uuid": "lvl-4", "displayIcon": "https://media.valorant-api.com/weaponskinlevels/lvl-4/displayicon.png", "streamedVideo": null}]},
      {"uuid": "skin-empty", "displayName": "Random Favorite Skin", "contentTierUuid": null, "displayIcon": null, "chromas": [], "levels": []}
    ]}
    """

    static let tiers = """
    {"status": 200, "data": [
      {"uuid": "411e4a55-4e59-7757-41f0-86a53f101bb5", "devName": "Ultra", "rank": 4, "highlightColor": "fad66333", "displayIcon": "https://media.valorant-api.com/contenttiers/411e4a55-4e59-7757-41f0-86a53f101bb5/displayicon.png"}
    ]}
    """

    static let sprays = """
    {"status": 200, "data": [{"uuid": "SPRAY-1", "displayName": "Nice Spray", "displayIcon": "https://x/d.png", "fullTransparentIcon": "https://x/t.png"}]}
    """

    static let titles = """
    {"status": 200, "data": [{"uuid": "t-1", "displayName": "Tiger Title", "titleText": "Tiger", "displayIcon": null}]}
    """

    static let bundles = """
    {"status": 200, "data": [{"uuid": "2116A38E-4b71-f169-0d16-ce9289af4bfa", "displayName": "Reaver 2.0", "displayNameSubText": null,
      "displayIcon": "https://x/b.png", "verticalPromoImage": "https://x/v.png", "extra": 1}]}
    """
}
