import SwiftUI
import ValorantCore

struct MatchRoute: Hashable {
    let id: String
}

struct AgentRoute: Hashable {
    let id: String
}

struct MapRoute: Hashable {
    let url: String
}

enum MatchesSection: String, CaseIterable, Identifiable {
    case history, overview, agents, maps, guns, rounds

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Every match and stats screen lives under this one tab: a fixed header with the scope menu,
/// a strip of sections, and the sections side by side so a swipe moves between them.
struct MatchesView: View {
    @Environment(AppModel.self) private var model
    @Environment(MatchesModel.self) private var matches
    @Namespace private var zoom
    @State private var path = NavigationPath()
    @State private var section: MatchesSection? = .history

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    ScreenTitle(kicker: "Your games", title: "Matches")
                    Spacer(minLength: 8)
                    if model.phase != .signedOut {
                        ScopeMenu().padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)
                if model.phase == .signedOut {
                    ContentUnavailableView("Sign in to see your matches", systemImage: "person.crop.circle.badge.questionmark")
                        .padding(.top, 40)
                    Spacer()
                } else {
                    PillTabs(MatchesSection.allCases.map { ($0, $0.title) }, selection: selected, scrolls: true)
                    pages
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AmbientBackground(tint: rankColor, secondary: Theme.violet))
            .navigationDestination(for: MatchRoute.self) { route in
                MatchDetailView(id: route.id)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoom))
            }
            .navigationDestination(for: AgentRoute.self) { _ in
                ContentUnavailableView("Soon", systemImage: "person.fill")
            }
            .navigationDestination(for: MapRoute.self) { _ in
                ContentUnavailableView("Soon", systemImage: "map.fill")
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .task { await matches.appear(clientVersion: model.snapshot?.clientVersion) }
        #if DEBUG
        .task {
            if let raw = UserDefaults.standard.string(forKey: "DemoSection"), let start = MatchesSection(rawValue: raw) {
                section = start
            }
        }
        .task(id: matches.summaries.count) {
            let index = UserDefaults.standard.integer(forKey: "DemoMatch")
            guard index > 0, path.isEmpty, matches.shown.indices.contains(index - 1) else { return }
            path.append(MatchRoute(id: matches.shown[index - 1].id))
        }
        #endif
    }

    private var selected: Binding<MatchesSection> {
        Binding(get: { section ?? .history }, set: { new in withAnimation(.smooth) { section = new } })
    }

    private var rankColor: Color {
        matches.rank.flatMap { matches.assets?.tier($0.tier) }.map { Color(rgbaHex: $0.color) } ?? Theme.accent
    }

    private var pages: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(MatchesSection.allCases) { section in
                    ScrollView {
                        page(section)
                            .padding(.horizontal, Theme.gutter)
                            .padding(.top, 4)
                            .padding(.bottom, 110)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { await matches.refresh() }
                    .containerRelativeFrame(.horizontal)
                    .id(section)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $section)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func page(_ section: MatchesSection) -> some View {
        switch section {
        case .history: HistoryPage(zoom: zoom)
        case .overview: OverviewPage()
        case .agents: AgentsPage()
        default: ContentUnavailableView("Soon", systemImage: "chart.bar").padding(.top, 60)
        }
    }
}

/// The act and queue every section counts, in one capsule at the top of the tab.
struct ScopeMenu: View {
    @Environment(MatchesModel.self) private var matches

    var body: some View {
        @Bindable var matches = matches
        Menu {
            Section("Act") {
                Picker("Act", selection: $matches.scope.act) {
                    Text(matches.actLabel).tag(StatsScope.Act.current)
                    Text("All time").tag(StatsScope.Act.all)
                }
                .pickerStyle(.inline)
            }
            Section("Queue") {
                Picker("Queue", selection: $matches.scope.queue) {
                    Text("All").tag(String?.none)
                    ForEach(queues, id: \.self) { queue in
                        Text(matches.queueName(queue)).tag(String?.some(queue))
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            HStack(spacing: 6) {
                Text(matches.scopeLabel.uppercased())
                    .font(Theme.label(10)).tracking(1)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    /// The archive's queues, plus the chosen one even when no game of it is saved yet.
    private var queues: [String] {
        var list = matches.queues
        if let chosen = matches.scope.queue, !list.contains(chosen) { list.insert(chosen, at: 0) }
        return list
    }
}
