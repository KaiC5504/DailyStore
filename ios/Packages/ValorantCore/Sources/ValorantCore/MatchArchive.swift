import Foundation

/// Every match the app has downloaded, kept on disk for good because Riot only lists the last
/// few weeks. One small index for the list, one file per match, loaded only when opened.
public actor MatchArchive {
    private let directory: URL
    private var index: [MatchSummary]?
    private var updates: [CompetitiveUpdate]?
    private var digestCache: [MatchDigest]?

    public init(directory: URL) {
        self.directory = directory
    }

    /// Newest first.
    public func summaries() -> [MatchSummary] {
        loadIndex()
    }

    public func contains(_ id: String) -> Bool {
        let id = id.lowercased()
        return loadIndex().contains { $0.id == id }
    }

    /// Archived from the current `Match` shape; older entries are worth downloading again while Riot lists them.
    public func isCurrent(_ id: String) -> Bool {
        let id = id.lowercased()
        return loadIndex().contains { $0.id == id && $0.schema == Match.currentSchema }
    }

    public func match(_ id: String) -> Match? {
        read(Match.self, "details/\(id.lowercased()).json")
    }

    /// Newest first. Games saved before digests existed, or under an older `MatchDigest.version`,
    /// are worked out from their saved details once and kept in digests.json after that.
    public func digests(puuid: String) -> [MatchDigest] {
        var known = Dictionary(loadDigests().map { ($0.id, $0) }) { a, _ in a }
        var changed = false
        for summary in loadIndex() where known[summary.id]?.version != MatchDigest.version {
            guard let match = match(summary.id) else { continue }
            known[summary.id] = MatchDigest(match: match, puuid: puuid)
            changed = true
        }
        guard changed else { return loadDigests() }
        let digests = known.values.sorted { $0.start > $1.start }
        digestCache = digests
        write(digests, "digests.json")
        return digests
    }

    public func digest(_ id: String) -> MatchDigest? {
        let id = id.lowercased()
        return loadDigests().first { $0.id == id }
    }

    @discardableResult
    public func save(_ match: Match, puuid: String) -> MatchSummary {
        write(match, "details/\(match.id).json")
        let digest = MatchDigest(match: match, puuid: puuid)
        var digests = loadDigests().filter { $0.id != match.id }
        digests.insert(digest, at: digests.firstIndex { $0.start < digest.start } ?? digests.endIndex)
        digestCache = digests
        write(digests, "digests.json")
        let summary = MatchSummary(match: match, puuid: puuid, update: loadUpdates().first { $0.id == match.id })
        var summaries = loadIndex().filter { $0.id != match.id }
        let position = summaries.firstIndex { $0.start < summary.start } ?? summaries.endIndex
        summaries.insert(summary, at: position)
        index = summaries
        write(summaries, "index.json")
        return summary
    }

    /// Newest first.
    public func rrUpdates() -> [CompetitiveUpdate] {
        loadUpdates()
    }

    /// Adds RR results and fills them into matches already in the list. Returns true when anything changed.
    @discardableResult
    public func merge(_ incoming: [CompetitiveUpdate]) -> Bool {
        var known = loadUpdates()
        let ids = Set(known.map(\.id))
        let fresh = incoming.filter { !ids.contains($0.id) }
        if !fresh.isEmpty {
            known = (known + fresh).sorted { $0.start > $1.start }
            updates = known
            write(known, "updates.json")
        }
        let byID = Dictionary(known.map { ($0.id, $0) }) { a, _ in a }
        var changed = !fresh.isEmpty
        var summaries = loadIndex()
        for i in summaries.indices {
            guard let update = byID[summaries[i].id], summaries[i].rrEarned != update.rrEarned else { continue }
            summaries[i].rrEarned = update.rrEarned
            summaries[i].tierAfter = update.tierAfter
            changed = true
        }
        if changed {
            index = summaries
            write(summaries, "index.json")
        }
        return changed
    }

    public func rank() -> RankStatus? {
        read(RankStatus.self, "rank.json")
    }

    public func save(rank: RankStatus) {
        write(rank, "rank.json")
    }

    private func loadIndex() -> [MatchSummary] {
        if let index { return index }
        let loaded = read([MatchSummary].self, "index.json") ?? []
        index = loaded
        return loaded
    }

    private func loadDigests() -> [MatchDigest] {
        if let digestCache { return digestCache }
        let loaded = read([MatchDigest].self, "digests.json") ?? []
        digestCache = loaded
        return loaded
    }

    private func loadUpdates() -> [CompetitiveUpdate] {
        if let updates { return updates }
        let loaded = read([CompetitiveUpdate].self, "updates.json") ?? []
        updates = loaded
        return loaded
    }

    private func read<T: Decodable>(_ type: T.Type, _ path: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(path)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, _ path: String) {
        let url = directory.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
