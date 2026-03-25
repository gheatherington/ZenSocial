import SwiftUI
@preconcurrency import WebKit

struct PlatformWebView: UIViewRepresentable {
    let platform: Platform
    @Bindable var state: WebViewState

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(platform: platform, state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WebViewConfiguration.make(for: platform)
        let webView = WKWebView(frame: .zero, configuration: config)

        // Set Safari UA (D-01, D-02, BLOCK-03)
        webView.customUserAgent = UserAgentProvider.shared.safariUserAgent

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // WEB-04: Back/forward swipe navigation
        webView.allowsBackForwardNavigationGestures = true

        // Prevent white flash (RESEARCH Pitfall 4)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.underPageBackgroundColor = .black

        // WEB-05: Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .zenAccent
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(WebViewCoordinator.handleRefresh(_:)),
            for: .valueChanged
        )
        webView.scrollView.refreshControl = refreshControl
        webView.scrollView.bounces = true

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load initial URL only once (RESEARCH anti-pattern: do NOT recreate in updateUIView)
        if webView.url == nil {
            let request = URLRequest(url: platform.homeURL)
            webView.load(request)
            state.loadingState = .loading
        }
    }
}
