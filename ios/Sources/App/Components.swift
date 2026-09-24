import AVFoundation
import SwiftUI
import ValorantCore

/// Slowly drifting mesh behind every screen, tinted by what the screen is showing.
struct AmbientBackground: View {
    var tint: Color = Theme.accent
    var secondary: Color = Theme.violet

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            let drift = SIMD2<Float>(0.08 * sin(t * 0.21), 0.06 * cos(t * 0.17))
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], SIMD2<Float>(0.5, 0.45) + drift, [1, 0.55],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    secondary.opacity(0.55), Theme.ink, tint.opacity(0.35),
                    Theme.ink, tint.opacity(0.22), Theme.ink,
                    Theme.ink, secondary.opacity(0.25), Theme.ink,
                ]
            )
        }
        .overlay(Theme.ink.opacity(0.35))
        .ignoresSafeArea()
    }
}

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
            switch phase {
            case let .success(image):
                image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .failure:
                Image(systemName: "photo").font(.title2).foregroundStyle(Theme.textFaint)
            default:
                Color.clear
            }
        }
    }
}

/// Art that fills whatever frame it is given without widening it. A `.fill` image on its
/// own reports its overflowing size to the layout and drags the whole row wider than the screen.
struct FillImage: View {
    let url: URL?
    var alignment: Alignment = .center

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) { RemoteImage(url: url, contentMode: .fill) }
            .clipped()
    }
}

struct PriceTag: View {
    let amount: Int
    var original: Int?
    var currency: String = Currency.vp
    var font: Font = Theme.price

    var body: some View {
        HStack(spacing: 6) {
            RemoteImage(url: CurrencyIcon.url(currency))
                .frame(width: 16, height: 16)
            if let original, original != amount {
                Text(original, format: .number)
                    .strikethrough()
                    .foregroundStyle(Theme.textFaint)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            Text(amount, format: .number).font(font)
        }
    }
}

struct TierBadge: View {
    let tier: ContentTier?

    var body: some View {
        if let tier {
            HStack(spacing: 5) {
                RemoteImage(url: tier.icon).frame(width: 14, height: 14)
                Text(tier.name.uppercased())
                    .font(Theme.label(10))
                    .tracking(1.2)
            }
            .foregroundStyle(Color(rgbaHex: tier.color))
        }
    }
}

/// "Resets in 5:23:10" that ticks without redrawing the rest of the screen.
struct CountdownChip: View {
    let label: String
    let end: Date
    var systemImage = "clock"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
            Text(label.uppercased()).font(Theme.label(10)).tracking(1)
            if end > Date() {
                if end.timeIntervalSinceNow > 86_400 {
                    Text(end, style: .relative).font(.system(size: 13, weight: .heavy).monospacedDigit())
                } else {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                }
            } else {
                Text("now").font(.system(size: 13, weight: .heavy))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

struct ScreenTitle: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased())
                .font(Theme.label(11))
                .tracking(2.4)
                .foregroundStyle(Theme.accent)
            Text(title.uppercased())
                .font(Theme.display(52))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WishlistHeart: View {
    let isOn: Bool

    var body: some View {
        Image(systemName: isOn ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isOn ? Theme.accent : .white.opacity(0.7))
            .contentTransition(.symbolEffect(.replace))
            .padding(9)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

/// Takes the heart's place for skins already in the collection; they can't show up in the store.
struct OwnedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.owned)
            .padding(9)
            .glassEffect(.regular.tint(Theme.owned.opacity(0.18)), in: .circle)
    }
}

/// Looping, control-free video for skin previews, played from `VideoCache`'s copy on disk.
/// Streaming it straight from the CDN took seconds to start: AVPlayerLooper loads its copies
/// of the item one by one, each over the network.
struct LoopingVideo: UIViewRepresentable {
    let url: URL
    var muted = false
    @Binding var ready: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.onReady = { ready = $0 }
        view.play(url, muted: muted)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.onReady = { ready = $0 }
        if view.current != url {
            view.play(url, muted: muted)
        } else {
            view.setMuted(muted)
        }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var readiness: NSKeyValueObservation?
        private var loading: Task<Void, Never>?
        private var audible = false
        /// Kept apart from the player so a toggle made while the file is still downloading isn't lost.
        private var wantsMuted = false
        private(set) var current: URL?
        var onReady: (Bool) -> Void = { _ in }

        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        func play(_ url: URL, muted: Bool) {
            teardown()
            current = url
            wantsMuted = muted
            loading = Task { [weak self] in
                let file = await VideoCache.shared.file(for: url)
                guard let self, !Task.isCancelled, self.current == url else { return }
                self.start(file ?? url)
            }
        }

        private func start(_ source: URL) {
            let player = AVQueuePlayer()
            player.automaticallyWaitsToMinimizeStalling = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: source))
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
            readiness = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                let ready = layer.isReadyForDisplay
                Task { @MainActor in self?.onReady(ready) }
            }
            self.player = player
            setMuted(wantsMuted)
            player.play()
        }

        func setMuted(_ muted: Bool) {
            wantsMuted = muted
            guard let player else { return }
            player.isMuted = muted
            // Switching straight to another video keeps the session, so other audio doesn't blip back in between.
            if audible == muted {
                muted ? PreviewAudio.end() : PreviewAudio.begin()
                audible = !muted
            }
        }

        func stop() {
            teardown()
            if audible {
                PreviewAudio.end()
                audible = false
            }
        }

        private func teardown() {
            loading?.cancel()
            readiness = nil
            player?.pause()
            looper = nil
            player = nil
            playerLayer.player = nil
            current = nil
        }
    }
}

/// Previews play through the silent switch like any video app, and hand audio back to
/// whatever was playing before once the preview goes away.
@MainActor
enum PreviewAudio {
    static func begin() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func end() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Skin preview videos kept in Caches so a second look starts instantly. The skin detail
/// screen prefetches every video it can show, so the first tap usually finds it on disk too.
actor VideoCache {
    static let shared = VideoCache()

    private let directory = URL.cachesDirectory.appending(path: "videos")
    private let limit = 400 * 1_024 * 1_024
    private var downloads: [URL: Task<URL?, Never>] = [:]
    /// Prefetching skips Low Data Mode; a tap still downloads.
    private let prefetchSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsConstrainedNetworkAccess = false
        return URLSession(configuration: config)
    }()

    /// The local copy, downloading it first if needed. Nil if the download fails.
    func file(for url: URL) async -> URL? {
        await download(url, session: .shared)
    }

    func prefetch(_ urls: [URL]) async {
        for url in urls {
            _ = await download(url, session: prefetchSession)
        }
    }

    private func download(_ url: URL, session: URLSession) async -> URL? {
        let target = directory.appending(path: url.pathComponents.suffix(2).joined(separator: "-"))
        if FileManager.default.fileExists(atPath: target.path) { return target }
        if let running = downloads[url] { return await running.value }
        let directory = directory
        let task = Task<URL?, Never> {
            guard let (temp, response) = try? await session.download(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: target)
            guard (try? FileManager.default.moveItem(at: temp, to: target)) != nil else { return nil }
            return target
        }
        downloads[url] = task
        let result = await task.value
        downloads[url] = nil
        if result != nil { trim() }
        return result
    }

    /// Oldest first once the folder passes the limit; iOS may also clear Caches on its own.
    private func trim() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        let entries = files.compactMap { file -> (URL, Int, Date)? in
            guard let values = try? file.resourceValues(forKeys: Set(keys)) else { return nil }
            return (file, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        for (file, size, _) in entries.sorted(by: { $0.2 < $1.2 }) where total > limit {
            try? FileManager.default.removeItem(at: file)
            total -= size
        }
    }
}

extension Catalog {
    func tierColor(_ levelID: String) -> Color {
        skin(levelID).flatMap { tier(for: $0) }.map { Color(rgbaHex: $0.color) } ?? Theme.fallbackTier
    }
}

extension Optional where Wrapped == Catalog {
    func tierColor(_ levelID: String) -> Color {
        self?.tierColor(levelID) ?? Theme.fallbackTier
    }
}

/// A tab sized to exactly one screen. It stays in a ScrollView so pull-to-refresh keeps
/// working, and only scrolls on phones shorter than `minHeight`.
struct FitPage<Content: View>: View {
    var minHeight: CGFloat = 0
    let refresh: () async -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content()
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .frame(width: proxy.size.width, height: max(proxy.size.height, minHeight), alignment: .top)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refresh() }
        }
    }
}

/// Rows that split whatever height the page leaves them, which LazyVGrid's fixed rows can't do.
struct FillGrid<Item, Cell: View>: View {
    let items: [Item]
    var columns = 2
    var spacing: CGFloat = 12
    @ViewBuilder let cell: (Int, Item) -> Cell

    private var rows: [[Int]] {
        stride(from: 0, to: items.count, by: columns).map { Array($0 ..< min($0 + columns, items.count)) }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { index in
                        cell(index, items[index])
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    ForEach(row.count ..< columns, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
