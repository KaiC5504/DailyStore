import SwiftUI
import ValorantCore
import WebKit

struct LoginView: View {
    let onCookies: (RiotCookies) -> Void
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            RiotLoginWebView(isLoading: $isLoading, onCookies: onCookies)
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if isLoading { ProgressView().controlSize(.large) }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 3) {
                        Label("Tick “Stay signed in” so you stay logged in for weeks.", systemImage: "checkmark.square")
                        Text("Saved your Riot login in Passwords? Tap the key above the keyboard to fill it.")
                            .foregroundStyle(.secondary)
                    }
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                }
                .navigationTitle("Riot sign-in")
                .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

private struct RiotLoginWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    let onCookies: (RiotCookies) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // A throwaway store: every sign-in starts clean and the cookies end up only in the Keychain.
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: RiotAuth.authorizeURL()))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: RiotLoginWebView
        private var finished = false

        init(_ parent: RiotLoginWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url, RiotAuth.isRedirect(url) else { return .allow }
            harvest(webView)
            return .cancel
        }

        // Server redirects do not always surface as a navigation action.
        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if let url = webView.url, RiotAuth.isRedirect(url) { harvest(webView) }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        private func harvest(_ webView: WKWebView) {
            guard !finished else { return }
            finished = true
            parent.isLoading = true
            let store = webView.configuration.websiteDataStore.httpCookieStore
            Task { @MainActor in
                let riot = await store.allCookies().filter { $0.domain.hasSuffix("riotgames.com") }
                var values: [String: String] = [:]
                // auth.riotgames.com wins over a parent-domain cookie of the same name.
                for cookie in riot.sorted(by: { $0.domain.count < $1.domain.count }) {
                    values[cookie.name] = cookie.value
                }
                parent.onCookies(RiotCookies(values))
            }
        }
    }
}
