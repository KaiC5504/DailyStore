import Foundation
import Observation
import ValorantCore

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching, signedOut, loading, ready
        case failed(String)
    }

    private(set) var phase: Phase = .launching
    private(set) var snapshot: StoreSnapshot?
    private(set) var catalog: Catalog?
    private(set) var catalogError: String?
    private(set) var log: [String] = []
    var showLogin = false

    @ObservationIgnored private let http: URLSessionHTTPClient
    @ObservationIgnored private let service: StoreService
    @ObservationIgnored private let snapshotCache = FileCache<StoreSnapshot>(name: "snapshot.json")
    @ObservationIgnored private let catalogCache = FileCache<Catalog>(name: "catalog.json")

    init() {
        let http = URLSessionHTTPClient()
        let relay = LogRelay()
        self.http = http
        self.service = StoreService(http: http, sessions: KeychainSessionStore(), log: relay.send)
        relay.model = self
    }

    /// True once the daily rotation the snapshot was taken in has ended.
    var isStale: Bool {
        guard let snapshot else { return true }
        return Date() >= snapshot.fetchedAt.addingTimeInterval(TimeInterval(snapshot.storefront.dailyRemainingSeconds))
    }

    func start() async {
        snapshot = snapshotCache.load()
        catalog = catalogCache.load()
        if await service.isSignedIn {
            await refresh()
        } else {
            phase = .signedOut
            showLogin = true
        }
    }

    func refreshIfStale() async {
        guard phase != .loading, phase != .launching, phase != .signedOut, isStale else { return }
        await refresh()
    }

    func refresh() async {
        phase = .loading
        await run { try await self.service.fetch() }
    }

    func signIn(cookies: RiotCookies) async {
        showLogin = false
        phase = .loading
        await run { try await self.service.signIn(cookies: cookies) }
    }

    func signOut() async {
        try? await service.signOut()
        snapshot = nil
        snapshotCache.clear()
        phase = .signedOut
        showLogin = true
    }

    func record(_ line: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        log.append("\(stamp)  \(line)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    private func run(_ work: @escaping () async throws -> StoreSnapshot) async {
        do {
            let fresh = try await work()
            snapshot = fresh
            snapshotCache.save(fresh)
            phase = .ready
            await loadCatalogIfNeeded(for: fresh.clientVersion)
        } catch RiotError.sessionExpired, RiotError.notSignedIn {
            phase = .signedOut
            showLogin = true
        } catch {
            record("Error: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadCatalogIfNeeded(for version: String) async {
        guard catalog?.clientVersion != version else { return }
        do {
            let fresh = try await Catalog.fetch(http: http, clientVersion: version)
            catalog = fresh
            catalogCache.save(fresh)
            catalogError = nil
            record("Catalog OK: \(fresh.skins.count) skins")
        } catch {
            catalogError = "Couldn't load skin names and images (\(error.localizedDescription))."
            record("Catalog error: \(error.localizedDescription)")
        }
    }
}

/// Lets the service log before the model finishes initialising.
private final class LogRelay: @unchecked Sendable {
    weak var model: AppModel?

    func send(_ line: String) {
        Task { @MainActor [weak model] in model?.record(line) }
    }
}

struct FileCache<Value: Codable> {
    let name: String

    private var url: URL {
        URL.cachesDirectory.appending(path: name)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) {
        try? JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
