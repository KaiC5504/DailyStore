import Foundation
import Observation
import ValorantCore

/// Match history state, kept apart from the store's AppModel. The archive on disk is the
/// source of truth; Riot is only asked for what the archive doesn't have yet.
@MainActor
@Observable
final class MatchesModel {
    enum Phase: Equatable {
        case idle, syncing
        case failed(String)
    }

    /// Queue filter value for custom games, which Riot sends with an empty queue ID.
    static let customFilter = "custom"
    static let pageSize = 20

    private(set) var summaries: [MatchSummary] = []
    private(set) var stats = MatchStats([])
    /// Listed by Riot, details still downloading.
    private(set) var pending: [HistoryEntry] = []
    private(set) var rank: RankStatus?
    /// Newest first.
    private(set) var updates: [CompetitiveUpdate] = []
    private(set) var assets: MatchAssets?
    private(set) var phase: Phase = .idle
    private(set) var loadingOlder = false
    private(set) var reachedEnd = false
    private(set) var visibleCount = MatchesModel.pageSize
    private(set) var puuid: String?
    private(set) var filter: String?

    @ObservationIgnored private let service: StoreService
    @ObservationIgnored private let log: (String) -> Void
    @ObservationIgnored private let isDemo: Bool
    @ObservationIgnored private let http = URLSessionHTTPClient()
    @ObservationIgnored private let assetsCache = FileCache<MatchAssets>(name: "match-assets.json")
    @ObservationIgnored private var archive: MatchArchive?
    @ObservationIgnored private var nextRiotIndex: Int? = RiotAPI.pageSize
    @ObservationIgnored private var lastSync: Date?

    init(service: StoreService, isDemo: Bool, log: @escaping (String) -> Void) {
        self.service = service
        self.isDemo = isDemo
        self.log = log
    }

    var filtered: [MatchSummary] {
        guard let filter else { return summaries }
        return summaries.filter { filter == Self.customFilter ? $0.isCustom : (!$0.isCustom && $0.queue == filter) }
    }

    var shown: [MatchSummary] { Array(filtered.prefix(visibleCount)) }

    /// Skeleton rows only make sense in the unfiltered list, where they land in order.
    var shownPending: [HistoryEntry] { filter == nil ? pending : [] }

    /// Queues present in the archive, most played first.
    var queues: [String] {
        let keys = summaries.map { $0.isCustom ? Self.customFilter : $0.queue }
        let counts = Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.keys.sorted { (counts[$0]!, $1) > (counts[$1]!, $0) }
    }

    func queueName(_ queue: String) -> String {
        queue == Self.customFilter ? "Custom" : (assets?.queueName(queue) ?? MatchAssets.displayFallback(queue))
    }

    /// Called whenever the tab shows. Syncs on first show and then at most every two minutes.
    func appear(clientVersion: String?) async {
        await loadAssets(clientVersion: clientVersion)
        #if DEBUG
        if isDemo {
            if summaries.isEmpty {
                puuid = DemoData.me
                setSummaries(DemoData.summaries)
                rank = DemoData.rank
                updates = DemoData.updates
            }
            return
        }
        #endif
        guard await openArchiveIfNeeded() != nil else { return }
        if let lastSync, Date().timeIntervalSince(lastSync) < 120 { return }
        await refresh()
    }

    func refresh() async {
        guard !isDemo, phase != .syncing, let archive = await openArchiveIfNeeded() else { return }
        phase = .syncing
        do {
            let result = try await service.syncMatches(into: archive) { [weak self] event in
                await self?.handle(event)
            }
            nextRiotIndex = result.next
            reachedEnd = result.next == nil
            lastSync = Date()
            await reload(from: archive)
            phase = .idle
        } catch {
            log("Matches error: \(error.localizedDescription)")
            pending = []
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows the next page of the archive, and asks Riot for older games once the archive runs out.
    func loadMore() async {
        if visibleCount < filtered.count {
            visibleCount += Self.pageSize
            return
        }
        guard !isDemo, !loadingOlder, let start = nextRiotIndex, let archive else {
            reachedEnd = nextRiotIndex == nil
            return
        }
        loadingOlder = true
        defer { loadingOlder = false }
        do {
            let result = try await service.olderMatches(from: start, into: archive) { [weak self] event in
                await self?.handle(event)
            }
            nextRiotIndex = result.next
            reachedEnd = result.next == nil
            await reload(from: archive)
            visibleCount += Self.pageSize
        } catch {
            log("Older matches error: \(error.localizedDescription)")
        }
    }

    func select(_ queue: String?) {
        filter = queue
        visibleCount = Self.pageSize
    }

    func match(_ id: String) async -> Match? {
        #if DEBUG
        if isDemo { return DemoData.matches.first { $0.id == id } }
        #endif
        return await archive?.match(id)
    }

    /// Matches archived before build 10 have blank names; they get filled in the first time they're opened.
    func named(_ match: Match) async -> Match? {
        guard !isDemo, let archive else { return nil }
        return await service.fillNames(match, archive: archive)
    }

    func signedOut() {
        archive = nil
        puuid = nil
        setSummaries([])
        pending = []
        rank = nil
        updates = []
        lastSync = nil
        nextRiotIndex = RiotAPI.pageSize
        reachedEnd = false
        phase = .idle
    }

    private func handle(_ event: MatchSyncEvent) {
        switch event {
        case let .pending(entries):
            let known = Set(summaries.map(\.id)).union(pending.map(\.id))
            pending = (pending + entries.filter { !known.contains($0.id) }).sorted { $0.start > $1.start }
        case let .saved(summary):
            pending.removeAll { $0.id == summary.id }
            var list = summaries.filter { $0.id != summary.id }
            list.insert(summary, at: list.firstIndex { $0.start < summary.start } ?? list.endIndex)
            setSummaries(list)
        case let .unavailable(id):
            pending.removeAll { $0.id == id }
        }
    }

    private func setSummaries(_ list: [MatchSummary]) {
        summaries = list
        stats = MatchStats(list)
    }

    private func reload(from archive: MatchArchive) async {
        setSummaries(await archive.summaries())
        updates = await archive.rrUpdates()
        rank = await archive.rank()
        pending.removeAll { entry in summaries.contains { $0.id == entry.id } }
    }

    /// Archives are per account, so a second Riot account never mixes into the first one's history.
    private func openArchiveIfNeeded() async -> MatchArchive? {
        if let archive { return archive }
        guard let id = await service.puuid else { return nil }
        let directory = URL.applicationSupportDirectory.appending(path: "matches/\(id)")
        let archive = MatchArchive(directory: directory)
        self.archive = archive
        puuid = id
        await reload(from: archive)
        return archive
    }

    private func loadAssets(clientVersion: String?) async {
        if assets == nil { assets = assetsCache.load() }
        if let assets, clientVersion == nil || assets.clientVersion == clientVersion { return }
        do {
            let fresh = try await MatchAssets.fetch(http: http, clientVersion: clientVersion ?? "unknown")
            assets = fresh
            assetsCache.save(fresh)
            log("Match assets OK: \(fresh.maps.count) maps, \(fresh.agents.count) agents")
        } catch {
            log("Match assets error: \(error.localizedDescription)")
        }
    }
}
