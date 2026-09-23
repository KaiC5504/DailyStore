import SwiftUI

@main
struct DailyStoreApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StoreView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.refreshIfStale() } }
                }
                .sheet(isPresented: $model.showLogin) {
                    LoginView { cookies in Task { await model.signIn(cookies: cookies) } }
                }
        }
    }
}
