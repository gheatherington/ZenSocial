import WebKit
import UIKit

@MainActor
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let platform: Platform
    var state: WebViewState
    weak var webView: WKWebView?

    init(platform: Platform, state: WebViewState) {
        self.platform = platform
        self.state = state
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReloadNotification(_:)),
            name: .zenSocialReload,
            object: platform.rawValue
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleReloadNotification(_ notification: Notification) {
        webView?.reload()
    }

    // MARK: - Navigation Policy (D-07, D-08, D-09)

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url,
              let host = url.host?.lowercased()
        else {
            return .allow
        }

        // Auth domains -> modal (D-07)
        if AuthDomains.isAuthDomain(host) {
            state.pendingAuthURL = url
            return .cancel
        }

        // Platform's own domains -> allow in-place navigation
        if platform.isOwnDomain(host) {
            return .allow
        }

        // External non-auth domains -> system browser (per UI-SPEC)
        await UIApplication.shared.open(url)
        return .cancel
    }

    // MARK: - Navigation Events (SHELL-02, SHELL-03 state transitions)

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        state.loadingState = .loading
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        state.loadingState = .loaded
        state.canGoBack = webView.canGoBack
        state.canGoForward = webView.canGoForward
        state.currentURL = webView.url

        // Re-enable bounces after each navigation (RESEARCH Pitfall 5)
        webView.scrollView.bounces = true
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        handleNavigationError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handleNavigationError(error)
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError

        // Cancelled navigation is not a real error (user tapped link while loading)
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        // Distinguish offline vs generic failure (SHELL-03)
        if nsError.domain == NSURLErrorDomain
            && (nsError.code == NSURLErrorNotConnectedToInternet
                || nsError.code == NSURLErrorNetworkConnectionLost
                || nsError.code == NSURLErrorDataNotAllowed)
        {
            state.loadingState = .error(.offline)
        } else {
            state.loadingState = .error(.failed)
        }
    }

    // MARK: - Pull-to-Refresh (WEB-05)

    @objc func handleRefresh(_ sender: UIRefreshControl) {
        webView?.reload()
        // Dismiss spinner after a brief delay if didFinish hasn't fired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sender.endRefreshing()
        }
    }

    // MARK: - WKUIDelegate (handle window.open, alerts)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // window.open() links -- load in main webview or open externally
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
