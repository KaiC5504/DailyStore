import SwiftUI
import ValorantCore
import WidgetKit

@main
struct DailyStoreWidgets: WidgetBundle {
    var body: some Widget {
        StoreWidget()
    }
}

struct StoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyStore", provider: StoreProvider()) { entry in
            StoreWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop() }
        }
        .configurationDisplayName("Today's Store")
        .description("Your four daily offers, refreshed right after the 00:00 UTC reset.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct StoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> StoreEntry { .placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (StoreEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder())
            return
        }
        Task { completion(await currentEntry(allowFetch: false)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StoreEntry>) -> Void) {
        Task {
            let entry = await currentEntry(allowFetch: true)
            var entries = [entry]
            var reset = entry.resetsAt
            if case .ready = entry.state, reset > Date() {
                let expired = StoreEntry(date: reset, state: .ready, items: entry.items, vp: entry.vp,
                                     resetsAt: reset, nightMarketCount: entry.nightMarketCount, expired: true)
                entries.append(expired)
            } else {
                // Riot sometimes lags a minute behind midnight; try again shortly rather than tomorrow.
                reset = Date().addingTimeInterval(15 * 60)
            }
            completion(Timeline(entries: entries, policy: .after(reset.addingTimeInterval(60))))
        }
    }

    private func currentEntry(allowFetch: Bool) async -> StoreEntry {
        let saved = SharedState.snapshot
        if let saved, !saved.isStale() || !allowFetch {
            return await WidgetEntryBuilder.entry(for: saved)
        }
        let service = StoreRefresher.makeService()
        guard await service.isSignedIn else {
            return StoreEntry(date: Date(), state: .signedOut, items: [], vp: nil,
                              resetsAt: StoreClock.nextReset(after: Date()), nightMarketCount: nil)
        }
        do {
            let fresh = try await StoreRefresher.current(using: service, force: true)
            return await WidgetEntryBuilder.entry(for: fresh)
        } catch RiotError.sessionExpired {
            return StoreEntry(date: Date(), state: .signedOut, items: [], vp: nil,
                              resetsAt: StoreClock.nextReset(after: Date()), nightMarketCount: nil)
        } catch {
            if let saved { return await WidgetEntryBuilder.entry(for: saved) }
            return StoreEntry(date: Date(), state: .failed("Couldn't reach Riot"), items: [], vp: nil,
                              resetsAt: Date().addingTimeInterval(900), nightMarketCount: nil)
        }
    }
}
