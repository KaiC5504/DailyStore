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

    /// Queue value for custom games, which Riot sends with an empty queue ID.
    static let customFilter = "custom"
    static let pageSize = 20
    private static let scopeKey = "MatchesScope"

    private(set) var summaries: [MatchSummary] = []
    /// Newest first.
    private(set) var digests: [MatchDigest] = []
    /// False until the archive's digests are loaded; the first launch after an update builds them.
    private(set) var digestsReady = false
    /// Digests in the current scope, newest first.
    private(set) var scoped: [MatchDigest] = []
    private(set) var career = CareerStats([])
    /// Listed by Riot, details still downloading.
    private(set) var pending: [HistoryEntry] = []
    private(set) var rank: RankStatus? {
        didSet { recompute() }
    }
    /// Newest first.
    private(set) var updates: [CompetitiveUpdate] = []
    private(set) var assets: MatchAssets?
    private(set) var phase: Phase = .idle
    private(set) var loadingOlder = false
    private(set) var reachedEnd = false
    private(set) var visibleCount = MatchesModel.pageSize
    private(set) var puuid: String?
    var scope: StatsScope {
        didSet {
            guard scope != oldValue else { return }
            visibleCount = Self.pageSize
            recompute()
            if !isDemo, let data = try? JSONEncoder().encode(scope) {
                UserDefaults.standard.set(data, forKey: Self.scopeKey)
            }
        }
    }

    @ObservationIgnored private let service: StoreService
    @ObservationIgnored private let log: (String) -> Void
    @ObservationIgnored private let isDemo: Bool
    @ObservationIgnored private let http = URLSessionHTTPClient()
    @ObservationIgnored private let assetsCache = FileCache<MatchAssets>(name: "match-assets.json")
    @ObservationIgnored private var archive: MatchArchive?
    @ObservationIgnored private var nextRiotIndex: Int? = RiotAPI.pageSize
    @ObservationIgnored private var lastSync: Date?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var digestByID: [String: MatchDigest] = [:]

    init(service: StoreService, isDemo: Bool, log: @escaping (String) -> Void) {
        self.service = service
        self.isDemo = isDemo
        self.log = log
        let saved = UserDefaults.standard.data(forKey: Self.scopeKey).flatMap { try? JSONDecoder().decode(StatsScope.self, from: $0) }
        // Demo screenshots index into the full list, so demo mode always starts on every queue.
        scope = isDemo ? StatsScope(act: .current, queue: nil) : (saved ?? StatsScope())
    }

    /// History's list: the same act and queue as the stats.
    var filtered: [MatchSummary] {
        let act = currentAct
        return summaries.filter {
            scope.includes(queue: $0.queue, isCustom: $0.isCustom, season: digestByID[$0.id]?.season, currentAct: act)
        }
    }

    var shown: [MatchSummary] { Array(filtered.prefix(visibleCount)) }

    /// New games belong to the current act, so only the queue decides whether their skeletons fit the list.
    var shownPending: [HistoryEntry] {
        pending.filter { entry in
            switch scope.queue {
            case nil: true
            case .some(Self.customFilter): entry.queue.isEmpty
            case let wanted?: entry.queue == wanted
            }
        }
    }

    func digest(_ id: String) -> MatchDigest? { digestByID[id] }

    /// The act the stats call "this act": the one Riot's rank came from, else the newest game's.
    var currentAct: String? {
        rank?.actID ?? digests.first { !$0.isCustom && !$0.season.isEmpty }?.season
    }

    var actLabel: String {
        guard let act = rank?.act, let last = act.components(separatedBy: " · ").last else { return "This act" }
        return last.capitalized
    }

    var scopeLabel: String {
        let queue = scope.queue.map(shortQueueName) ?? "All"
        return "\(scope.act == .all ? "All time" : actLabel) · \(queue)"
    }

    /// Queues present in the archive, most played first.
    var queues: [String] {
        let keys = summaries.map { $0.isCustom ? Self.customFilter : $0.queue }
        let counts = Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.keys.sorted { (counts[$0]!, $1) > (counts[$1]!, $0) }
    }

    func queueName(_ queue: String) -> String {
        queue == Self.customFilter ? "Custom" : (assets?.queueName(queue) ?? MatchAssets.displayFallback(queue))
    }

    /// For tight spots like the scope capsule and card lines.
    func shortQueueName(_ queue: String) -> String {
        queue == "competitive" ? "Comp" : queueName(queue)
    }

    /// Stats for part of the scope, such as one agent or one map.
    func career(where keep: (MatchDigest) -> Bool) -> CareerStats {
        CareerStats(scoped.filter(keep))
    }

    /// Called whenever the tab shows. Syncs on first show and then at most every two minutes.
    func appear(clientVersion: String?) async {
        await loadAssets(clientVersion: clientVersion)
        #if DEBUG
        if isDemo {
            if summaries.isEmpty {
                puuid = DemoData.me
                summaries = DemoData.summaries
                rank = DemoData.rank
                updates = DemoData.updates
                setDigests(DemoData.digests)
            }
            return
        }
        #endif
        guard await openArchiveIfNeeded() != nil else { return }
        if let lastSync, Date().timeIntervalSince(lastSync) < 120 { return }
        await refresh()
    }

    /// The sync runs in its own task: SwiftUI cancels the tab's `.task` and the pull-to-refresh
    /// task when the tab is left or the refresh ends, and cancelled downloads used to leave games
    /// stuck as skeletons with "cancelled" on top. A second caller waits for the running sync.
    func refresh() async {
        if let syncTask { return await syncTask.value }
        guard !isDemo, let archive = await openArchiveIfNeeded() else { return }
        if let syncTask { return await syncTask.value }
        let task = Task { [self] in
            await sync(archive)
            syncTask = nil
        }
        syncTask = task
        await task.value
    }

    private func sync(_ archive: MatchArchive) async {
        phase = .syncing
        do {
            let result = try await service.syncMatches(into: archive) { [weak self] event in
                await self?.handle(event)
            }
            nextRiotIndex = result.next
            reachedEnd = result.next == nil
            // Games that failed to download are retried on the next visit, not two minutes later.
            lastSync = result.failed == 0 ? Date() : nil
            await reload(from: archive)
            phase = .idle
        } catch {
            pending = []
            if Task.isCancelled {
                phase = .idle
                return
            }
            log("Matches error: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows the next page of the archive, and asks Riot for older games once the archive runs out.
    /// Older games belong to older acts, so a list scoped to this act never pages Riot.
    func loadMore() async {
        if visibleCount < filtered.count {
            visibleCount += Self.pageSize
            return
        }
        guard !isDemo, scope.act == .all, !loadingOlder, let start = nextRiotIndex, let archive else {
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
        syncTask?.cancel()
        syncTask = nil
        archive = nil
        puuid = nil
        summaries = []
        setDigests([])
        digestsReady = false
        pending = []
        rank = nil
        updates = []
        lastSync = nil
        nextRiotIndex = RiotAPI.pageSize
        reachedEnd = false
        phase = .idle
    }

    private func handle(_ event: MatchSyncEvent) async {
        switch event {
        case let .pending(entries):
            let known = Set(summaries.map(\.id)).union(pending.map(\.id))
            pending = (pending + entries.filter { !known.contains($0.id) }).sorted { $0.start > $1.start }
        case let .saved(summary):
            // The digest first, so the card lands with its HS and ADR and in the right scope.
            if let digest = await archive?.digest(summary.id) {
                setDigests(digests.filter { $0.id != digest.id } + [digest])
            }
            pending.removeAll { $0.id == summary.id }
            var list = summaries.filter { $0.id != summary.id }
            list.insert(summary, at: list.firstIndex { $0.start < summary.start } ?? list.endIndex)
            summaries = list
        case let .unavailable(id), let .failed(id):
            pending.removeAll { $0.id == id }
        }
    }

    private func setDigests(_ list: [MatchDigest]) {
        digests = list.sorted { $0.start > $1.start }
        digestByID = Dictionary(digests.map { ($0.id, $0) }) { a, _ in a }
        digestsReady = true
        recompute()
    }

    private func recompute() {
        let act = currentAct
        scoped = digests.filter { scope.includes($0, currentAct: act) }
        career = CareerStats(scoped)
    }

    private func reload(from archive: MatchArchive) async {
        summaries = await archive.summaries()
        updates = await archive.rrUpdates()
        rank = await archive.rank()
        pending.removeAll { entry in summaries.contains { $0.id == entry.id } }
        setDigests(await archive.digests(puuid: puuid ?? ""))
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
