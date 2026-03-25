import Foundation
import Observation

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

    var loadingState: LoadingState = .idle
    var pendingAuthURL: URL? = nil
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: URL? = nil
}
