import WebKit

@MainActor
class UserAgentProvider {
    static let shared = UserAgentProvider()
    private(set) var safariUserAgent: String?

    func extractUserAgent() async {
        let webView = WKWebView(frame: .zero)
        do {
            let ua = try await webView.evaluateJavaScript("navigator.userAgent") as? String
            if let ua, !ua.contains("Safari/") {
                self.safariUserAgent = ua + " Safari/605.1.15"
            } else {
                self.safariUserAgent = ua
            }
        } catch {
            self.safariUserAgent = nil
        }
    }
}
