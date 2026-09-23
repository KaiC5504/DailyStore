#if DEBUG
import Foundation
import ValorantCore

/// Real item IDs so the CI simulator screenshots show real art. Launch with `-DemoData YES`.
enum DemoData {
    private static let skinType = "e7c63390-eda7-46e0-bb7a-a6abdacd2433"

    static let snapshot = StoreSnapshot(
        storefront: Storefront(
            daily: [
                StoreOffer(offerID: "d1", itemID: "d58e1881-4126-9c75-347d-67bab6b98fb2", cost: 2175),
                StoreOffer(offerID: "d2", itemID: "1590d353-4b81-4207-b79a-5493231cbee7", cost: 1775),
                StoreOffer(offerID: "d3", itemID: "722a1311-43e1-7c18-ce90-acac33e9c2ad", cost: 2975),
                StoreOffer(offerID: "d4", itemID: "68564c51-4f7e-67d1-fd0d-4e9d216356e8", cost: 875),
            ],
            dailyRemainingSeconds: 5 * 3600 + 23 * 60,
            nightMarket: [
                night("n1", "ba42fe63-457a-78ce-4499-47950a698129", 1775, 37),
                night("n2", "c00e786e-4e6f-0ef7-0ce3-32ba9918ba41", 1775, 22),
                night("n3", "4b74b3ee-4a63-7339-a28f-8b8be010ca5a", 2175, 41),
                night("n4", "4e435234-49a2-1444-4640-908692c855b8", 2175, 18),
                night("n5", "636c1f83-44f7-6bc4-0b24-88a1beb66c2d", 2175, 29),
                night("n6", "2b555f97-46bb-5949-3531-979f5bc817f0", 1775, 45),
            ],
            nightMarketRemainingSeconds: 9 * 86400,
            bundles: [
                FeaturedBundle(
                    id: "b1", dataAssetID: "69d9b2be-4439-0785-780b-ba8951053683",
                    items: [
                        BundleItem(itemTypeID: skinType, itemID: "636c1f83-44f7-6bc4-0b24-88a1beb66c2d", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "0c989088-43ef-22ad-cc43-81a27bde2377", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "72b3bacc-48ac-85f7-ec38-5ab629654486", basePrice: 2175, discountedPrice: 1631),
                        BundleItem(itemTypeID: skinType, itemID: "99b0edce-48db-b898-1d6f-0fa89795226d", basePrice: 4350, discountedPrice: 3262),
                        BundleItem(itemTypeID: "3f296c07-64c3-494c-923b-fe692a4fa1bd", itemID: "1a127cbf-4131-3581-da59-529b7e0d9495", basePrice: 375, discountedPrice: 0),
                        BundleItem(itemTypeID: "d5f120f8-ff8c-4aac-92ea-f2b5acbe9475", itemID: "515a130a-4a2e-e0a4-9a73-c784f8f16e2a", basePrice: 325, discountedPrice: 0),
                    ],
                    baseCost: 10_875, discountedCost: 8_700, remainingSeconds: 6 * 86400 + 3600
                ),
                FeaturedBundle(
                    id: "b2", dataAssetID: "2116a38e-4b71-f169-0d16-ce9289af4bfa",
                    items: [], baseCost: 7_100, discountedCost: 7_100, remainingSeconds: 2 * 86400
                ),
            ]
        ),
        wallet: Wallet(vp: 4909, radianite: 0, kingdomCredits: 10000),
        clientVersion: "demo",
        fetchedAt: Date()
    )

    static let wishlist: Set<String> = ["722a1311-43e1-7c18-ce90-acac33e9c2ad", "636c1f83-44f7-6bc4-0b24-88a1beb66c2d"]

    private static func night(_ id: String, _ item: String, _ cost: Int, _ percent: Int) -> NightMarketOffer {
        NightMarketOffer(offer: StoreOffer(offerID: id, itemID: item, cost: cost),
                         discountedCost: cost * (100 - percent) / 100, discountPercent: percent, isSeen: false)
    }
}
#endif
