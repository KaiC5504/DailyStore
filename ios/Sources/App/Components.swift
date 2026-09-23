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

/// Muted, looping, control-free video for skin previews.
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.current != url { view.play(url) }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private(set) var current: URL?

        func play(_ url: URL) {
            stop()
            current = url
            let player = AVQueuePlayer()
            player.isMuted = true
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            (layer as! AVPlayerLayer).player = player
            (layer as! AVPlayerLayer).videoGravity = .resizeAspect
            self.player = player
            player.play()
        }

        func stop() {
            player?.pause()
            looper = nil
            player = nil
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
