import SwiftUI
@preconcurrency import WebKit

struct AuthModalView: View {
    let platform: Platform
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AuthWebView(platform: platform, url: url, onReturnToPlatform: {
                dismiss()  // D-09: auto-dismiss on return to platform domain
            })
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // D-08: Open in Safari fallback
                        UIApplication.shared.open(url)
                        dismiss()
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Internal UIViewRepresentable for the auth WKWebView

private struct AuthWebView: UIViewRepresentable {
    let platform: Platform
    let url: URL
    let onReturnToPlatform: () -> Void

    func makeCoordinator() -> AuthCoordinator {
        AuthCoordinator(platform: platform, onReturnToPlatform: onReturnToPlatform)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Use same data store as platform (D-07: cookies written to correct store)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = DataStoreManager.dataStore(for: platform)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = UserAgentProvider.shared.safariUserAgent
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Auth Navigation Coordinator

@MainActor
private class AuthCoordinator: NSObject, WKNavigationDelegate {
    let platform: Platform
    let onReturnToPlatform: () -> Void

    init(platform: Platform, onReturnToPlatform: @escaping () -> Void) {
        self.platform = platform
        self.onReturnToPlatform = onReturnToPlatform
        super.init()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url,
              let host = url.host?.lowercased()
        else {
            return .allow
        }

        // D-09: Auto-dismiss when navigation returns to platform domain
        if platform.isOwnDomain(host) {
            onReturnToPlatform()
            return .cancel
        }

        return .allow
    }
}
