import Foundation

public enum MatchSyncEvent: Sendable {
    /// Listed by Riot, details on the way.
    case pending([HistoryEntry])
    case saved(MatchSummary)
    /// Riot listed it but has no details for it; drop the placeholder.
    case unavailable(String)
}

public struct MatchSyncResult: Sendable, Equatable {
    public var added = 0
    public var failed = 0
    /// Riot history index to continue from, nil once the end of Riot's list is reached.
    public var next: Int?
    public var rank: RankStatus?
}

extension StoreService {
    /// The newest page of history, RR and rank, then details for anything not archived yet.
    public func syncMatches(into archive: MatchArchive,
                            onEvent: @escaping @Sendable (MatchSyncEvent) async -> Void) async throws -> MatchSyncResult {
        try await withGameContext { ctx in
            async let page = api.matchHistory(ctx, start: 0)
            async let updates = optional("Competitive updates") { try await self.api.competitiveUpdates(ctx) }
            async let rank = optional("Rank") { try await self.api.rank(ctx) }

            if let updates = await updates { await archive.merge(updates) }
            let rankStatus = await rank
            if let rankStatus { await archive.save(rank: rankStatus) }
            let history = try await page
            var result = await download(history.entries, ctx: ctx, archive: archive, onEvent: onEvent)
            result.next = history.next
            result.rank = rankStatus
            log("Matches OK: \(history.total) on Riot, \(result.added) new, \(result.failed) failed")
            return result
        }
    }

    /// Pages further back through Riot's list, skipping pages that are already archived.
    public func olderMatches(from start: Int, into archive: MatchArchive,
                             onEvent: @escaping @Sendable (MatchSyncEvent) async -> Void) async throws -> MatchSyncResult {
        try await withGameContext { ctx in
            var result = MatchSyncResult(next: start)
            var pages = 0
            while let next = result.next, result.added == 0, pages < 3 {
                let page = try await api.matchHistory(ctx, start: next)
                let batch = await download(page.entries, ctx: ctx, archive: archive, onEvent: onEvent)
                result.added += batch.added
                result.failed += batch.failed
                result.next = page.next
                pages += 1
            }
            // RR pages don't line up with history pages; archived updates are contiguous from the newest,
            // so their count is where Riot's next RR page starts.
            let known = await archive.rrUpdates().count
            if result.added > 0,
               let older = await optional("Competitive updates", { try await self.api.competitiveUpdates(ctx, start: known) }) {
                await archive.merge(older)
            }
            log("Older matches: \(result.added) added, next \(result.next.map(String.init) ?? "end")")
            return result
        }
    }

    private func download(_ entries: [HistoryEntry], ctx: RiotAPI.Context, archive: MatchArchive,
                          onEvent: @escaping @Sendable (MatchSyncEvent) async -> Void) async -> MatchSyncResult {
        var missing: [HistoryEntry] = []
        for entry in entries where !(await archive.contains(entry.id)) {
            missing.append(entry)
        }
        var result = MatchSyncResult()
        guard !missing.isEmpty else { return result }
        await onEvent(.pending(missing))

        let api = self.api
        let puuid = ctx.puuid
        // Two at a time with a short gap keeps a first sync of 20 matches clear of Riot's rate limit.
        for start in stride(from: 0, to: missing.count, by: 2) {
            let chunk = missing[start..<min(start + 2, missing.count)]
            let results = await withTaskGroup(of: (String, Result<Match?, Error>).self) { group in
                for entry in chunk {
                    group.addTask {
                        do { return (entry.id, .success(try await api.matchDetails(ctx, id: entry.id))) }
                        catch { return (entry.id, .failure(error)) }
                    }
                }
                return await group.reduce(into: []) { $0.append($1) }
            }
            for (id, outcome) in results {
                switch outcome {
                case let .success(match?):
                    let summary = await archive.save(match, puuid: puuid)
                    result.added += 1
                    await onEvent(.saved(summary))
                case .success(nil):
                    await onEvent(.unavailable(id))
                case let .failure(error):
                    result.failed += 1
                    log("Match details: \(error.localizedDescription)")
                }
            }
            if start + 2 < missing.count, api.retryBase > 0 {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        return result
    }

    /// A cached token can be revoked early; one retry with fresh tokens covers that.
    private func withGameContext<T>(_ work: (RiotAPI.Context) async throws -> T) async throws -> T {
        do {
            return try await work(try await context())
        } catch let RiotError.http(_, status) where status == 400 || status == 401 {
            return try await work(try await context(fresh: true))
        }
    }

    private func optional<T>(_ step: String, _ work: () async throws -> T) async -> T? {
        do {
            return try await work()
        } catch {
            log("\(step): \(error.localizedDescription)")
            return nil
        }
    }
}
