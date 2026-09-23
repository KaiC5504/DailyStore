import Foundation

public enum Currency {
    public static let vp = "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
    public static let radianite = "e59aa87c-4cbf-517a-5983-6e81511be9b7"
    public static let kingdomCredits = "85ca954a-41f2-ce94-9b45-8ca3dd39a00d"
}

public struct StoreOffer: Codable, Hashable, Sendable {
    public let offerID: String
    /// Skin level UUID; valorant-api.com keys skins by their first level.
    public let itemID: String
    public let cost: Int
}

public struct NightMarketOffer: Codable, Hashable, Sendable {
    public let offer: StoreOffer
    public let discountedCost: Int
    public let discountPercent: Int
    public let isSeen: Bool
}

public struct BundleItem: Codable, Hashable, Sendable {
    public let itemTypeID: String
    public let itemID: String
    public let basePrice: Int
    public let discountedPrice: Int
}

public struct FeaturedBundle: Codable, Hashable, Sendable {
    public let id: String
    /// Matches `uuid` in valorant-api.com /v1/bundles.
    public let dataAssetID: String
    public let items: [BundleItem]
    public let baseCost: Int?
    public let discountedCost: Int?
    public let remainingSeconds: Int
}

public struct Storefront: Codable, Hashable, Sendable {
    public let daily: [StoreOffer]
    public let dailyRemainingSeconds: Int
    /// Nil when no night market is running; Riot omits `BonusStore` entirely then.
    public let nightMarket: [NightMarketOffer]?
    public let nightMarketRemainingSeconds: Int?
    public let bundles: [FeaturedBundle]

    public init(json data: Data) throws {
        let raw = try JSONDecoder().decode(RawStorefront.self, from: data)
        guard let panel = raw.SkinsPanelLayout else { throw RiotError.unexpected(step: "Storefront") }
        daily = (panel.SingleItemStoreOffers ?? []).compactMap(\.offer)
        dailyRemainingSeconds = panel.SingleItemOffersRemainingDurationInSeconds ?? 0
        nightMarket = raw.BonusStore.map { bonus in
            bonus.BonusStoreOffers.compactMap { item in
                guard let offer = item.Offer.offer else { return nil }
                return NightMarketOffer(
                    offer: offer,
                    discountedCost: item.DiscountCosts?[Currency.vp] ?? offer.cost,
                    discountPercent: Int(item.DiscountPercent ?? 0),
                    isSeen: item.IsSeen ?? false
                )
            }
        }
        nightMarketRemainingSeconds = raw.BonusStore?.BonusStoreRemainingDurationInSeconds
        bundles = (raw.FeaturedBundle?.Bundles ?? []).map { bundle in
            FeaturedBundle(
                id: bundle.ID,
                dataAssetID: bundle.DataAssetID,
                items: (bundle.Items ?? []).map {
                    BundleItem(
                        itemTypeID: $0.Item.ItemTypeID,
                        itemID: $0.Item.ItemID,
                        basePrice: $0.BasePrice ?? 0,
                        discountedPrice: $0.DiscountedPrice ?? $0.BasePrice ?? 0
                    )
                },
                baseCost: bundle.TotalBaseCost?[Currency.vp],
                discountedCost: bundle.TotalDiscountedCost?[Currency.vp],
                remainingSeconds: bundle.DurationRemainingInSeconds ?? 0
            )
        }
    }
}

public struct Wallet: Codable, Hashable, Sendable {
    public let vp: Int
    public let radianite: Int
    public let kingdomCredits: Int

    public init(json data: Data) throws {
        let balances = try JSONDecoder().decode(RawWallet.self, from: data).Balances
        vp = balances[Currency.vp] ?? 0
        radianite = balances[Currency.radianite] ?? 0
        kingdomCredits = balances[Currency.kingdomCredits] ?? 0
    }
}

// Mirrors of Riot's JSON. Everything optional that Riot has been seen to omit.

private struct RawStorefront: Decodable {
    let SkinsPanelLayout: RawPanel?
    let BonusStore: RawBonusStore?
    let FeaturedBundle: RawFeatured?
}

private struct RawPanel: Decodable {
    let SingleItemStoreOffers: [RawOffer]?
    let SingleItemOffersRemainingDurationInSeconds: Int?
}

private struct RawOffer: Decodable {
    let OfferID: String
    let Cost: [String: Int]?
    let Rewards: [RawReward]?

    var offer: StoreOffer? {
        guard let item = Rewards?.first?.ItemID else { return nil }
        return StoreOffer(offerID: OfferID, itemID: item, cost: Cost?[Currency.vp] ?? 0)
    }
}

private struct RawReward: Decodable {
    let ItemID: String
}

private struct RawBonusStore: Decodable {
    let BonusStoreOffers: [RawBonusOffer]
    let BonusStoreRemainingDurationInSeconds: Int?
}

private struct RawBonusOffer: Decodable {
    let Offer: RawOffer
    let DiscountPercent: Double?
    let DiscountCosts: [String: Int]?
    let IsSeen: Bool?
}

private struct RawFeatured: Decodable {
    let Bundles: [RawBundle]?
}

private struct RawBundle: Decodable {
    let ID: String
    let DataAssetID: String
    let Items: [RawBundleItem]?
    let TotalBaseCost: [String: Int]?
    let TotalDiscountedCost: [String: Int]?
    let DurationRemainingInSeconds: Int?
}

private struct RawBundleItem: Decodable {
    struct Ref: Decodable {
        let ItemTypeID: String
        let ItemID: String
    }

    let Item: Ref
    let BasePrice: Int?
    let DiscountedPrice: Int?
}

private struct RawWallet: Decodable {
    let Balances: [String: Int]
}
