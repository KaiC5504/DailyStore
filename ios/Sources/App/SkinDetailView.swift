import SwiftUI
import ValorantCore

struct SkinDetailView: View {
    @Environment(AppModel.self) private var model
    let route: SkinRoute
    /// Zoom transitions pass a longer delay so the art's spin-in starts after the zoom settles
    /// instead of both animating the same layers at once, which dropped frames.
    var entranceDelay = 0.1

    @State private var chroma: SkinChroma?
    @State private var level: SkinLevel?
    @State private var tilt: CGSize = .zero
    @State private var appeared = false
    @State private var videoReady = false
    @AppStorage("previewSound") private var sound = true

    private var skin: SkinInfo? { model.catalog?.skin(route.levelID) }
    private var tier: ContentTier? { skin.flatMap { model.catalog?.tier(for: $0) } }
    private var color: Color { model.catalog.tierColor(route.levelID) }

    private var video: URL? { level?.video ?? chroma?.video }
    private var art: URL? { chroma?.render ?? skin?.icon }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                titleBlock
                if let skin, skin.chromas.count > 1 { chromaPicker(skin) }
                if let skin, skin.levels.contains(where: { $0.video != nil }) { levelPicker(skin) }
                wishlistButton
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(tint: color, secondary: color.opacity(0.6)))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(entranceDelay)) { appeared = true }
        }
        .task(id: skin?.name) {
            guard let skin else { return }
            let videos = skin.levels.compactMap(\.video) + skin.chromas.compactMap(\.video)
            await VideoCache.shared.prefetch(videos)
        }
    }

    private var hero: some View {
        ZStack {
            RadialGradient(colors: [color.opacity(0.7), .clear], center: .center, startRadius: 4, endRadius: 200)
                .blur(radius: 10)
                .scaleEffect(appeared ? 1 : 0.4)
            if let video {
                ZStack {
                    if !videoReady {
                        RemoteImage(url: art)
                            .padding(28)
                            .rotationEffect(.degrees(-8))
                            .opacity(0.3)
                        ProgressView().tint(.white).controlSize(.large)
                    }
                    LoopingVideo(url: video, muted: !sound, ready: $videoReady)
                        .opacity(videoReady ? 1 : 0)
                }
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
                .animation(.smooth(duration: 0.25), value: videoReady)
                .transition(.opacity)
            } else {
                // Shadow before rotation: the shadow is drawn once and turned with the art,
                // rather than recomputed every frame of the spin.
                RemoteImage(url: art)
                    .padding(28)
                    .shadow(color: color.opacity(0.6), radius: 30, y: 12)
                    .rotationEffect(.degrees(appeared ? -8 : -30))
                    .id(art)
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .rotation3DEffect(.degrees(Double(tilt.width) / 9), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-tilt.height) / 12), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .gesture(
            DragGesture()
                .onChanged { tilt = $0.translation }
                .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { tilt = .zero } }
        )
        .animation(.smooth, value: video)
        .onChange(of: video) { videoReady = false }
        .animation(.smooth, value: art)
        // Outside the tilt so the drag gesture and 3D transform can't take the tap.
        .overlay(alignment: .bottomTrailing) {
            if video != nil { soundButton.transition(.opacity) }
        }
        .padding(.top, 8)
    }

    private var soundButton: some View {
        Button {
            sound.toggle()
        } label: {
            Image(systemName: sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .padding(10)
        .sensoryFeedback(.selection, trigger: sound)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            TierBadge(tier: tier)
            Text((skin?.name ?? "New skin").uppercased())
                .font(Theme.display(44))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if skin == nil, model.catalog != nil {
                Label("Details coming soon", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.newItem)
            }
            if let price = route.price {
                PriceTag(amount: price, original: route.original, font: .system(size: 22, weight: .heavy).monospacedDigit())
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    private func chromaPicker(_ skin: SkinInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Variants")
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(skin.chromas, id: \.id) { item in
                            let selected = (chroma ?? skin.chromas.first) == item
                            Button {
                                withAnimation(.snappy) {
                                    chroma = item
                                    level = nil
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    RemoteImage(url: item.swatch ?? item.render, contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(.circle)
                                        .overlay(Circle().strokeBorder(selected ? color : .clear, lineWidth: 2.5))
                                    Text(item.name)
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                        .foregroundStyle(selected ? .white : Theme.textDim)
                                }
                                .frame(width: 72)
                                .padding(.vertical, 10)
                                .glassEffect(selected ? .regular.tint(color.opacity(0.25)).interactive() : .regular.interactive(),
                                             in: .rect(cornerRadius: Theme.chipRadius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func levelPicker(_ skin: SkinInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Upgrades")
            VStack(spacing: 8) {
                ForEach(skin.levels, id: \.id) { item in
                    let selected = level == item
                    Button {
                        withAnimation(.snappy) { level = selected ? nil : item }
                    } label: {
                        HStack {
                            Text(item.name).font(.subheadline.weight(.bold))
                            if let upgrade = item.upgrade {
                                Text(upgrade.uppercased())
                                    .font(Theme.label(10)).tracking(1)
                                    .foregroundStyle(color)
                            }
                            Spacer()
                            Image(systemName: item.video == nil ? "minus" : (selected ? "stop.fill" : "play.fill"))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(item.video == nil ? Theme.textFaint : .white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(selected ? .regular.tint(color.opacity(0.3)).interactive() : .regular.interactive(),
                                     in: .rect(cornerRadius: Theme.chipRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(item.video == nil)
                }
            }
        }
    }

    @ViewBuilder private var wishlistButton: some View {
        let on = model.isWishlisted(route.levelID)
        if model.isOwned(route.levelID) && !on {
            Label("In your collection", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Theme.owned)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassEffect(.regular.tint(Theme.owned.opacity(0.15)), in: .capsule)
        } else {
            wishlistToggle(on)
        }
    }

    private func wishlistToggle(_ on: Bool) -> some View {
        Button {
            withAnimation(.bouncy) { model.toggleWishlist(route.levelID) }
        } label: {
            Label(on ? "On your wishlist" : "Add to wishlist", systemImage: on ? "heart.fill" : "heart")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glassProminent)
        .tint(on ? Theme.accent.opacity(0.6) : Theme.accent)
        .sensoryFeedback(.success, trigger: on)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.label(11))
            .tracking(2)
            .foregroundStyle(Theme.textDim)
    }
}
