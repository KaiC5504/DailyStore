import SwiftUI

// Smoke-test stub so the pipeline can be proven end to end before the real app exists.
@main
struct DailyStoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("DailyStore")
                .font(.largeTitle.bold())
            Text("Pipeline smoke test")
                .foregroundStyle(.secondary)
        }
    }
}
