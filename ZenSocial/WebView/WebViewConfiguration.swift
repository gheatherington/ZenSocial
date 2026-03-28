import WebKit

@MainActor
enum WebViewConfiguration {
    static func make(for platform: Platform) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // D-03: Shared process pool — WKProcessPool was deprecated in iOS 15.
        // On iOS 17+ all WKWebViews share a single process pool by default,
        // so the D-03 intent (shared process, lower memory) is satisfied automatically.

        // D-04: Separate persistent data store per platform
        config.websiteDataStore = DataStoreManager.dataStore(for: platform)

        // D-05 / D-06: Per-platform autoplay policy
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        switch platform {
        case .instagram:
            config.mediaTypesRequiringUserActionForPlayback = .all
        case .youtube:
            config.mediaTypesRequiringUserActionForPlayback = []
        }

        // Media configuration
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        // Prepare WKUserContentController for Phase 2 injection
        let contentController = WKUserContentController()

        // Phase 2: Inject platform-specific dark theme CSS (atDocumentStart, FOUC-free)
        if let themeScript = ScriptLoader.themeScript(for: platform) {
            contentController.addUserScript(themeScript)
        }

        // Phase 2: Nav bar fixer — uses getComputedStyle to target fixed/sticky elements
        // that CSS selectors cannot reach (class-based backgrounds, not inline styles).
        if let navScript = ScriptLoader.navFixerScript(for: platform) {
            contentController.addUserScript(navScript)
        }

        config.userContentController = contentController

        return config
    }
}
