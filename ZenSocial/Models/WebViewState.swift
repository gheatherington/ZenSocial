import Foundation
import Observation
import WebKit

@Observable
@MainActor
class WebViewState {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(ErrorKind)
    }

    enum ErrorKind: Equatable {
        case offline
        case failed
    }

    @ObservationIgnored
    weak var webView: WKWebView? = nil

    var loadingState: LoadingState = .idle
    var pendingAuthURL: URL? = nil
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: URL? = nil

    func pauseAllVideos() {
        webView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())", completionHandler: nil)
    }
}
