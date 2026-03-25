# Architecture Patterns

**Domain:** iOS WKWebView social media wrapper with CSS/JS injection
**Researched:** 2026-03-24

## Technology Decision: WKWebView via UIViewRepresentable (Not iOS 26 WebView)

iOS 26 introduced native `WebView`/`WebPage` in SwiftUI. However, ZenSocial should use **WKWebView wrapped in UIViewRepresentable** because:

1. **Full WKWebViewConfiguration control** -- iOS 26's `WebPage` uses `callJavaScript()` for JS execution but does not expose `WKUserContentController` or `WKUserScript` for injection at document start/end timing. ZenSocial needs `atDocumentStart` injection to hide elements before they render (prevents flash of blocked content).
2. **WKContentRuleList support** -- Content blocking rules (Safari-style JSON rules) can hide elements via `css-display-none` before page render. This requires `WKWebViewConfiguration` access.
3. **WKWebsiteDataStore isolation** -- Session isolation between Instagram and YouTube requires `WKWebsiteDataStore(forIdentifier:)` on the configuration object.
4. **iOS 26 is beta/new** -- Stability risk. UIViewRepresentable + WKWebView is battle-tested.

**Confidence: HIGH** -- Multiple sources confirm iOS 26 WebPage lacks deep configuration access. Apple's own docs recommend UIKit integration for advanced WKWebView use cases.

## Recommended Architecture

```
+----------------------------------------------------------+
|                    ZenSocialApp (SwiftUI)                  |
|                                                           |
|  +-----------------------------------------------------+ |
|  |              MainTabView (SwiftUI TabView)           | |
|  |                                                      | |
|  |  +------------------+  +------------------+          | |
|  |  |  Instagram Tab   |  |   YouTube Tab    |          | |
|  |  +------------------+  +------------------+          | |
|  +-----------------------------------------------------+ |
|                          |                                |
|  +-----------------------------------------------------+ |
|  |           PlatformWebView (UIViewRepresentable)      | |
|  |                                                      | |
|  |  +----------------------------------------------+   | |
|  |  |         WKWebView Instance                    |   | |
|  |  |                                               |   | |
|  |  |  WKWebViewConfiguration                       |   | |
|  |  |    +-- WKUserContentController                |   | |
|  |  |    |     +-- WKUserScript (CSS injection)     |   | |
|  |  |    |     +-- WKUserScript (JS injection)      |   | |
|  |  |    |     +-- WKContentRuleList (element hide) |   | |
|  |  |    +-- WKWebsiteDataStore (per-platform)      |   | |
|  |  +----------------------------------------------+   | |
|  +-----------------------------------------------------+ |
|                          |                                |
|  +-----------------------------------------------------+ |
|  |          InjectionEngine (Swift module)               | |
|  |                                                      | |
|  |  PlatformConfig        ScriptLoader                  | |
|  |    - platform ID         - load JS from bundle       | |
|  |    - base URL             - load CSS from bundle     | |
|  |    - blocked selectors    - compile to WKUserScript   | |
|  |    - theme overrides                                  | |
|  |                                                      | |
|  |  ContentRuleCompiler    MutationWatcher               | |
|  |    - JSON rule builder    - JS MutationObserver setup | |
|  |    - compile & cache      - post-load element hiding  | |
|  +-----------------------------------------------------+ |
+----------------------------------------------------------+
```

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **ZenSocialApp** | App entry point, app lifecycle | MainTabView |
| **MainTabView** | Native tab bar, platform switching | PlatformWebView instances |
| **PlatformWebView** | UIViewRepresentable wrapper around WKWebView; owns configuration, navigation delegate | InjectionEngine, WKWebView |
| **InjectionEngine** | Loads platform-specific JS/CSS, compiles scripts, builds content rules | PlatformConfig, ScriptLoader, ContentRuleCompiler |
| **PlatformConfig** | Declarative definition of what to block/theme per platform | InjectionEngine (read by) |
| **ScriptLoader** | Reads .js and .css files from app bundle, wraps CSS in JS injection boilerplate | InjectionEngine |
| **ContentRuleCompiler** | Builds WKContentRuleList JSON from PlatformConfig selectors | PlatformWebView (applied to config) |
| **MutationWatcher** | Generates JS that uses MutationObserver to catch dynamically-added elements | InjectionEngine (bundled into user scripts) |
| **ThemeEngine** | Generates CSS variables and overrides for ZenSocial dark theme | InjectionEngine (merged into CSS injection) |

## Data Flow

### Page Load Flow

```
1. User taps tab (Instagram/YouTube)
     |
2. MainTabView shows PlatformWebView for that platform
     |
3. PlatformWebView creates WKWebView with:
   a. WKWebsiteDataStore(forIdentifier: "instagram") -- session isolation
   b. WKUserContentController with:
      - WKContentRuleList (compiled from PlatformConfig selectors)
      - WKUserScript(.atDocumentStart): CSS injection (theme + element hiding)
      - WKUserScript(.atDocumentEnd): MutationObserver setup + JS feature blocking
     |
4. WKWebView loads platform URL (e.g., https://www.instagram.com)
     |
5. At document start: CSS hides blocked elements immediately (no flash)
     |
6. At document end: MutationObserver activates, catches any dynamically
   loaded elements that match block selectors, hides/removes them
     |
7. User interacts with cleaned page
```

### Script Injection Pipeline

```
Bundle Resources:
  Scripts/
    instagram/
      block-reels.js        -- JS to remove Reels tab/content
      block-reels.css        -- CSS to hide Reels elements
    youtube/
      block-shorts.js        -- JS to remove Shorts tab/content
      block-shorts.css       -- CSS to hide Shorts elements
    shared/
      mutation-watcher.js    -- Generic MutationObserver setup
      theme-dark.css         -- ZenSocial dark theme base
      css-injector.js        -- Helper: wraps CSS string into <style> tag injection

            |
            v
     ScriptLoader reads files from bundle
            |
            v
     InjectionEngine combines:
       1. css-injector.js + [platform].css + theme-dark.css --> WKUserScript(.atDocumentStart)
       2. mutation-watcher.js + [platform].js               --> WKUserScript(.atDocumentEnd)
            |
            v
     PlatformWebView applies to WKUserContentController
```

### Session Isolation

```
Instagram WKWebView                    YouTube WKWebView
  |                                      |
  WKWebViewConfiguration                 WKWebViewConfiguration
    |                                      |
    WKWebsiteDataStore                     WKWebsiteDataStore
    (identifier: "instagram")              (identifier: "youtube")
    |                                      |
    Own cookies, localStorage,             Own cookies, localStorage,
    sessionStorage, cache                  sessionStorage, cache

--> No data leaks between platforms
--> Each platform maintains independent login sessions
--> Clearing one platform's data does not affect the other
```

## Patterns to Follow

### Pattern 1: Declarative Platform Configuration

Define platform rules as data, not code. Adding a new platform or new block rules should require zero Swift changes -- only new config and script files.

**What:** Each platform is a `PlatformConfig` struct that declares its URL, selectors to block, and theme adjustments.

**Why:** Extensibility. Adding Twitter support later means adding a new config + scripts, not modifying the injection engine.

```swift
struct PlatformConfig: Identifiable {
    let id: String                    // "instagram", "youtube"
    let displayName: String
    let baseURL: URL
    let icon: String                  // SF Symbol name
    let blockSelectors: [String]      // CSS selectors for WKContentRuleList
    let scriptFiles: [String]         // JS files in bundle (platform-specific)
    let cssFiles: [String]            // CSS files in bundle (platform-specific)
}

// Registry -- single source of truth
enum PlatformRegistry {
    static let platforms: [PlatformConfig] = [
        PlatformConfig(
            id: "instagram",
            displayName: "Instagram",
            baseURL: URL(string: "https://www.instagram.com")!,
            icon: "camera",
            blockSelectors: [
                "a[href='/reels/']",
                "[aria-label='Reels']"
            ],
            scriptFiles: ["instagram/block-reels.js"],
            cssFiles: ["instagram/block-reels.css"]
        ),
        PlatformConfig(
            id: "youtube",
            displayName: "YouTube",
            baseURL: URL(string: "https://m.youtube.com")!,
            icon: "play.rectangle",
            blockSelectors: [
                "a[title='Shorts']",
                "ytm-pivot-bar-item-renderer:has(a[title='Shorts'])"
            ],
            scriptFiles: ["youtube/block-shorts.js"],
            cssFiles: ["youtube/block-shorts.css"]
        )
    ]
}
```

### Pattern 2: Two-Layer Element Blocking

Use both WKContentRuleList AND injected CSS/JS for defense-in-depth.

**What:** Layer 1 (WKContentRuleList) applies Safari-style content blocking rules that fire before render. Layer 2 (CSS injection at documentStart + JS MutationObserver at documentEnd) catches anything the content rules miss, especially dynamically-injected elements.

**Why:** Instagram and YouTube use heavy client-side rendering. Content rules alone will not catch elements added after initial DOM parse. MutationObserver catches those. CSS at documentStart prevents flash-of-unwanted-content for static elements.

```swift
// Layer 1: Content Rules (compiled once, cached)
let ruleJSON = """
[
  {
    "trigger": {"url-filter": ".*", "if-domain": ["*instagram.com"]},
    "action": {"type": "css-display-none", "selector": "a[href='/reels/']"}
  }
]
"""

// Layer 2: MutationObserver (injected as WKUserScript)
// mutation-watcher.js
let mutationJS = """
const BLOCK_SELECTORS = %SELECTORS%;
const observer = new MutationObserver((mutations) => {
    for (const sel of BLOCK_SELECTORS) {
        document.querySelectorAll(sel).forEach(el => {
            el.style.display = 'none';
            el.setAttribute('data-zen-blocked', 'true');
        });
    }
});
observer.observe(document.body, { childList: true, subtree: true });
// Initial pass
for (const sel of BLOCK_SELECTORS) {
    document.querySelectorAll(sel).forEach(el => {
        el.style.display = 'none';
        el.setAttribute('data-zen-blocked', 'true');
    });
}
"""
```

### Pattern 3: CSS Injection via documentStart

**What:** Inject a `<style>` element into the document head at `.atDocumentStart` timing to apply theme and hide elements before the page renders.

**Why:** Prevents flash of original theme or blocked elements. The style element is applied before any body content renders.

```swift
// css-injector.js (template -- ScriptLoader fills in %CSS%)
let cssInjectorTemplate = """
(function() {
    var style = document.createElement('style');
    style.type = 'text/css';
    style.textContent = `%CSS%`;
    // At documentStart, <head> may not exist yet. Wait for it.
    function inject() {
        if (document.head) {
            document.head.appendChild(style);
        } else {
            var obs = new MutationObserver(function() {
                if (document.head) {
                    document.head.appendChild(style);
                    obs.disconnect();
                }
            });
            obs.observe(document.documentElement, { childList: true });
        }
    }
    inject();
})();
"""
```

### Pattern 4: Coordinator Pattern for WKWebView Delegation

**What:** Use the standard UIViewRepresentable Coordinator to handle WKNavigationDelegate and WKUIDelegate.

**Why:** Captures navigation events (block external redirects, handle login flows), manages load errors, and enables JS-to-Swift communication via WKScriptMessageHandler.

```swift
struct PlatformWebView: UIViewRepresentable {
    let config: PlatformConfig

    func makeCoordinator() -> Coordinator {
        Coordinator(config: config)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = context.coordinator.buildConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // Set mobile user agent to ensure mobile web version loads
        webView.customUserAgent = "Mozilla/5.0 (iPhone; ...)"
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: config.baseURL))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
                       WKScriptMessageHandler {
        let config: PlatformConfig

        func buildConfiguration() -> WKWebViewConfiguration {
            let config = WKWebViewConfiguration()
            // Session isolation
            config.websiteDataStore = WKWebsiteDataStore(
                forIdentifier: UUID(uuidString: self.config.id)!
            )
            // ... add user scripts, content rules
            return config
        }
        // ... delegate methods
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Shared WKProcessPool / Default DataStore

**What:** Using the default `WKWebsiteDataStore.default()` for all web views.

**Why bad:** Instagram and YouTube sessions bleed into each other. Cookies, localStorage, and cache are shared. Logging out of one could affect the other. Privacy violation.

**Instead:** Use `WKWebsiteDataStore(forIdentifier:)` with a unique identifier per platform.

### Anti-Pattern 2: evaluateJavaScript() for Persistent Modifications

**What:** Using `webView.evaluateJavaScript()` calls triggered from Swift after page load to hide elements.

**Why bad:** Race conditions -- elements may render before script executes. Does not persist across SPA navigation (Instagram is a single-page app). Must be re-triggered on every navigation event.

**Instead:** Use `WKUserScript` with `.forMainFrameOnly = false` to inject on every page/frame load automatically.

### Anti-Pattern 3: Hardcoded Selectors in Swift Code

**What:** Embedding CSS selectors and JS logic directly in Swift source files.

**Why bad:** When Instagram changes their DOM (which they do frequently), you must modify Swift code, recompile, and resubmit to App Store. Selectors change more often than app architecture.

**Instead:** Keep selectors in bundle resource files (JSON/JS/CSS). In a future version, these could be fetched from a remote config server for over-the-air updates without app resubmission.

### Anti-Pattern 4: Blocking Navigation Instead of Hiding Elements

**What:** Using `WKNavigationDelegate` to block URLs containing "/reels/" or "/shorts/".

**Why bad:** Over-blocks legitimate content. Instagram Reels URLs may be embedded in feeds. YouTube Shorts URLs may appear in search results. Blocking navigation breaks the browsing experience.

**Instead:** Hide the UI entry points (tabs, sections, buttons) that lead to the blocked content. Let the content technically exist -- just remove the paths users would take to reach it.

## Key Architectural Decisions

### WKWebsiteDataStore Identifier Strategy

Use deterministic UUIDs derived from platform ID strings (not random UUIDs). This ensures the same data store is used across app launches for session persistence.

```swift
extension String {
    var deterministicUUID: UUID {
        let hash = SHA256.hash(data: Data(self.utf8))
        let bytes = Array(hash.prefix(16))
        // Set version 5 (name-based) UUID bits
        var uuid = bytes
        uuid[6] = (uuid[6] & 0x0F) | 0x50
        uuid[8] = (uuid[8] & 0x3F) | 0x80
        return UUID(uuid: (uuid[0], uuid[1], uuid[2], uuid[3],
                           uuid[4], uuid[5], uuid[6], uuid[7],
                           uuid[8], uuid[9], uuid[10], uuid[11],
                           uuid[12], uuid[13], uuid[14], uuid[15]))
    }
}
```

### User Agent Strategy

Set `customUserAgent` on each WKWebView to a mobile Safari user agent string. Instagram and YouTube serve different layouts based on user agent. The mobile web versions are what ZenSocial targets -- they are simpler and more predictable for CSS/JS injection than desktop versions.

### Navigation Policy

Restrict navigation to the platform's domain and known subdomains. External links should either be blocked or opened in SFSafariViewController (system browser), not in the ZenSocial web view. This prevents users from navigating away from the controlled environment.

```swift
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = navigationAction.request.url,
          let host = url.host else {
        decisionHandler(.cancel)
        return
    }
    let allowedDomains = config.allowedDomains // e.g., ["instagram.com", "cdninstagram.com"]
    if allowedDomains.contains(where: { host.hasSuffix($0) }) {
        decisionHandler(.allow)
    } else {
        // Open in system browser
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }
}
```

## Suggested Build Order

Build order follows dependency chains -- each layer depends on the one before it.

```
Phase 1: Foundation
  1. Project setup (Xcode, SwiftUI app target)
  2. PlatformConfig data model
  3. PlatformWebView (UIViewRepresentable + basic WKWebView)
  4. MainTabView with tab switching
  --> Result: App that loads Instagram and YouTube in separate tabs

Phase 2: Injection Engine
  5. ScriptLoader (read JS/CSS from bundle)
  6. CSS injector script template
  7. Theme CSS (dark theme base)
  8. WKUserScript compilation and attachment
  --> Result: Dark theme applied to both platforms

Phase 3: Feature Blocking
  9. Block selectors for Instagram Reels
  10. Block selectors for YouTube Shorts
  11. WKContentRuleList compilation
  12. MutationObserver watcher script
  --> Result: Reels and Shorts tabs hidden

Phase 4: Polish
  13. Navigation policy (domain restriction)
  14. Session isolation (WKWebsiteDataStore per platform)
  15. Loading states, error handling
  16. User agent configuration
  --> Result: Production-quality app

Phase 5: Extensibility (future)
  17. Settings UI for toggling blocks per platform
  18. Remote config for selector updates
  19. Additional platform support
```

**Dependency rationale:**
- Phase 1 must come first: you need a working web view before you can inject anything.
- Phase 2 before Phase 3: the injection pipeline (ScriptLoader, WKUserScript compilation) is shared infrastructure. Theme CSS proves the pipeline works before adding feature blocking complexity.
- Phase 3 depends on Phase 2: feature blocking scripts flow through the same injection pipeline.
- Phase 4 can partially overlap with Phase 3: session isolation and navigation policy are independent of feature blocking, but polish makes more sense once core functionality works.

## Scalability Considerations

| Concern | 2 platforms | 5 platforms | 10+ platforms |
|---------|-------------|-------------|---------------|
| Memory | Each WKWebView ~50-150MB. Acceptable. | ~500MB total. May need lazy loading (only instantiate active tab). | Must destroy inactive web views and restore from WKWebsiteDataStore on reactivation. |
| Script management | Manual bundle files fine. | Structured bundle directories per platform. Consider script validation tests. | Remote config system for selectors. Automated DOM change detection. |
| Selector maintenance | Manual testing on each app update. | Need automated screenshot comparison tests. | Dedicated selector update pipeline with CI. |
| Build time | Negligible. | Negligible. | WKContentRuleList compilation may add seconds. Pre-compile and cache. |

## Sources

- [Apple WKWebView Documentation](https://developer.apple.com/documentation/webkit/wkwebview)
- [Apple WKWebsiteDataStore Documentation](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)
- [Apple WKContentRuleListStore Documentation](https://developer.apple.com/documentation/webkit/wkcontentruleliststore)
- [Apple WKUserContentController Documentation](https://developer.apple.com/documentation/webkit/wkusercontentcontroller)
- [Capital One: JavaScript Manipulation on iOS Using WebKit](https://www.capitalone.com/tech/software-engineering/javascript-manipulation-on-ios-using-webkit/)
- [AppCoda: Exploring WebView and WebPage in SwiftUI for iOS 26](https://www.appcoda.com/swiftui-webview/)
- [MDN: MutationObserver API](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver)
- [Medium: Injecting CSS and JavaScript in WKWebView](https://medium.com/@mahdi.mahjoobi/injection-css-and-javascript-in-wkwebview-eabf58e5c54e)
- [Swift Senpai: Injecting JavaScript Into Web View](https://swiftsenpai.com/development/web-view-javascript-injection/)
- [WKContentRuleList css-display-none Discussion](https://developer.apple.com/forums/thread/734182)
- [Apple Developer Forums: Separate cookies for multiple WKWebViews](https://developer.apple.com/forums/thread/47622)
