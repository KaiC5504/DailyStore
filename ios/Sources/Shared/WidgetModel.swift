import Foundation
import ImageIO
import UniformTypeIdentifiers
import ValorantCore
import WidgetKit

struct WidgetItem: Hashable {
    let levelID: String
    let name: String
    let price: Int
    let colorHex: String?
    let image: Data?
    let wishlisted: Bool
}

struct StoreEntry: TimelineEntry {
    enum State { case ready, signedOut, failed(String) }

    let date: Date
    let state: State
    let items: [WidgetItem]
    let vp: Int?
    let resetsAt: Date
    let nightMarketCount: Int?
    /// Set on the entry scheduled for the reset itself, before the widget has refetched.
    var expired = false

    var wishlistCount: Int { items.filter(\.wishlisted).count }

    static func placeholder(at date: Date = Date()) -> StoreEntry {
        StoreEntry(
            date: date, state: .ready,
            items: [
                WidgetItem(levelID: "a", name: "Araxys Sheriff", price: 2175, colorHex: "f5955b33", image: nil, wishlisted: false),
                WidgetItem(levelID: "b", name: "Undercity Classic", price: 1775, colorHex: "d1548d33", image: nil, wishlisted: false),
                WidgetItem(levelID: "c", name: "RES Operator", price: 2975, colorHex: "fad66333", image: nil, wishlisted: true),
                WidgetItem(levelID: "d", name: "Luxe Ghost", price: 875, colorHex: "5a9fe233", image: nil, wishlisted: false),
            ],
            vp: 4909, resetsAt: StoreClock.nextReset(after: date), nightMarketCount: 6
        )
    }
}

enum WidgetEntryBuilder {
    static func entry(for snapshot: StoreSnapshot, now: Date = Date()) async -> StoreEntry {
        let names = SharedState.compactCatalog
        let wishlist = SharedState.wishlist
        var items: [WidgetItem] = []
        for offer in snapshot.storefront.daily {
            let id = offer.itemID.lowercased()
            let image = await ThumbnailCache.image(for: id, url: names?.icon(id))
            items.append(WidgetItem(levelID: id, name: names?.name(id) ?? "Skin", price: offer.cost,
                                    colorHex: names?.color(id), image: image, wishlisted: wishlist.contains(id)))
        }
        return StoreEntry(date: now, state: .ready, items: items, vp: snapshot.wallet.vp,
                          resetsAt: snapshot.dailyResetsAt, nightMarketCount: snapshot.storefront.nightMarket?.count,
                          expired: snapshot.isStale(at: now))
    }
}

/// Small PNGs of skin art, kept in whichever process's own caches folder is asking.
enum ThumbnailCache {
    static func image(for levelID: String, url: URL?) async -> Data? {
        let file = URL.cachesDirectory.appending(path: "thumb-\(levelID).png")
        if let cached = try? Data(contentsOf: file) { return cached }
        guard let url, let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let small = downscale(data, maxPixel: 360) else { return nil }
        try? small.write(to: file, options: .atomic)
        return small
    }

    /// Decoding the full render would blow the widget's memory limit; ImageIO thumbnails never do.
    static func downscale(_ data: Data, maxPixel: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
