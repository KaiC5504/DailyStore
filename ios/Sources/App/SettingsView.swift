import SwiftUI
import ValorantCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Prefs.dailyReminder) private var dailyReminder = false
    @State private var wishlistAlerts = SharedState.alerts.wishlistEnabled
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Riot account", value: model.phase == .signedOut ? "Signed out" : "Signed in")
                    if let shard = model.shard { LabeledContent("Region", value: shard.uppercased()) }
                    LabeledContent("Store resets", value: "\(StoreClock.localResetTime()) your time")
                    Button("Refresh store now", systemImage: "arrow.clockwise") {
                        Task { await model.refresh(force: true) }
                    }
                    .disabled(model.phase == .loading || model.phase == .signedOut)
                }

                Section {
                    Toggle("Daily reset reminder", isOn: $dailyReminder)
                    Toggle("Wishlist alerts", isOn: $wishlistAlerts)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("The reminder fires at \(StoreClock.localResetTime()) every day and follows your timezone. Wishlist alerts are sent when the widget or background refresh finds a wishlisted skin, so they can arrive a little after the reset.")
                }

                Section("Troubleshooting") {
                    NavigationLink("Diagnostics") { DiagnosticsView() }
                    #if DEBUG
                    NavigationLink("Widget previews") { WidgetGallery() }
                    #endif
                }

                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                        .disabled(model.phase == .signedOut)
                } footer: {
                    Text("Signing out deletes the saved Riot session from this iPhone's Keychain. It never leaves the device.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AmbientBackground(tint: Theme.violet, secondary: Theme.accent.opacity(0.5)))
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of Riot?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Task { await model.signOut() } }
            } message: {
                Text("You'll need to log in again, and the widget will stop updating until you do.")
            }
            .onChange(of: dailyReminder) { _, on in
                Task {
                    if on, !(await Notifier.requestPermission()) { dailyReminder = false; return }
                    await Notifier.scheduleDailyReset(enabled: on)
                }
            }
            .onChange(of: wishlistAlerts) { _, on in
                var alerts = SharedState.alerts
                alerts.wishlistEnabled = on
                SharedState.alerts = alerts
                if on { Task { _ = await Notifier.requestPermission() } }
            }
        }
    }
}

struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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

extension Bundle {
    var versionString: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
