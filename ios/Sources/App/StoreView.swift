import SwiftUI
import ValorantCore

struct StoreView: View {
    @Environment(AppModel.self) private var model
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    status
                    if let snapshot = model.snapshot {
                        WalletRow(wallet: snapshot.wallet)
                        dailySection(snapshot)
                        if let night = snapshot.storefront.nightMarket {
                            Text("Night Market is live: \(night.count) offers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .refreshable { await model.refresh() }
            .navigationTitle("Today's Store")
            .toolbar {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    Button("Diagnostics", systemImage: "stethoscope") { showDiagnostics = true }
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await model.signOut() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        }
    }

    @ViewBuilder private var status: some View {
        switch model.phase {
        case .launching, .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading store…").foregroundStyle(.secondary)
            }
        case .signedOut:
            Button("Sign in with Riot") { model.showLogin = true }
                .buttonStyle(.borderedProminent)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .ready:
            EmptyView()
        }
        if let error = model.catalogError {
            Label(error, systemImage: "photo.badge.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    private func dailySection(_ snapshot: StoreSnapshot) -> some View {
        let resetsAt = snapshot.fetchedAt.addingTimeInterval(TimeInterval(snapshot.storefront.dailyRemainingSeconds))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily offers").font(.headline)
                Spacer()
                if resetsAt > Date() {
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Store has reset, pull to refresh")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            ForEach(snapshot.storefront.daily, id: \.offerID) { offer in
                OfferRow(offer: offer, skin: model.catalog?.skin(offer.itemID), catalog: model.catalog)
            }
        }
    }
}

private struct OfferRow: View {
    let offer: StoreOffer
    let skin: SkinInfo?
    let catalog: Catalog?

    private var tierColor: Color {
        skin.flatMap { catalog?.tier(for: $0) }.map { Color(rgbaHex: $0.color) } ?? .gray
    }

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: skin?.icon) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 120, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(skin?.name ?? offer.itemID)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text("\(offer.cost) VP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tierColor.opacity(0.18), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tierColor.opacity(0.6)))
    }
}

private struct WalletRow: View {
    let wallet: Wallet

    var body: some View {
        HStack(spacing: 18) {
            Text("\(wallet.vp) VP")
            Text("\(wallet.radianite) RP")
            Text("\(wallet.kingdomCredits) KC")
        }
        .font(.subheadline.monospacedDigit().weight(.medium))
        .foregroundStyle(.secondary)
    }
}

private struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List(Array(model.log.enumerated().reversed()), id: \.offset) { _, line in
                Text(line).font(.caption.monospaced())
            }
            .overlay {
                if model.log.isEmpty { ContentUnavailableView("No activity yet", systemImage: "stethoscope") }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension Color {
    /// valorant-api.com tier colors are RRGGBBAA with a faint alpha meant for backgrounds; the alpha is dropped.
    init(rgbaHex hex: String) {
        let value = UInt64(hex.prefix(6), radix: 16) ?? 0x808080
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
