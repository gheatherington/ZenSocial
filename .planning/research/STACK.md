# Stack Research

**Domain:** iOS WKWebView social media wrapper app with CSS/JS injection
**Researched:** 2026-03-24
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.x | Primary language | Apple's modern language with strict concurrency, async/await, and full platform integration. No alternative for native iOS. |
| SwiftUI | iOS 17+ | App shell, navigation, settings UI | Declarative UI framework for all native chrome (tab bar, settings screens, onboarding). Mature enough at iOS 17+ for production use. UIKit bridging via `UIViewRepresentable` handles WKWebView. |
| WKWebView (UIKit) | iOS 17+ | Web content rendering | The only viable path for rendering third-party web content. Wrapped via `UIViewRepresentable` in SwiftUI -- required because the new iOS 26 SwiftUI `WebView`/`WebPage` API does NOT expose `WKUserContentController` or `atDocumentStart` script injection, which are critical for this app. |
| WKUserContentController | iOS 17+ | CSS/JS injection engine | Apple's built-in mechanism for injecting `WKUserScript` objects at `.atDocumentStart` or `.atDocumentEnd`. This is how ZenSocial injects its blocking scripts and theme CSS. No third-party library needed. |
| WKContentRuleList | iOS 17+ | Network-level content blocking | Safari-style declarative JSON content blocking rules compiled at runtime. Use for blocking network requests to known short-form video endpoints (Reels/Shorts assets). Complements CSS/JS hiding. |
| Xcode | 16.x+ | IDE and build system | Required for App Store submission (iOS 18 SDK mandate since April 2025). Use latest stable Xcode. |
| Swift Package Manager | Built-in | Dependency management | Apple-native, integrated into Xcode, no Ruby dependency. CocoaPods is legacy -- SPM is the standard for new projects in 2025+. |

### Minimum Deployment Target

**iOS 17.0** -- because:
- Covers 95%+ of active iPhones (iOS 17 supports iPhone XS and later)
- Gives access to mature SwiftUI APIs (NavigationStack, Observable macro via Observation framework)
- `WKWebView`, `WKUserContentController`, and `WKContentRuleList` are stable and well-documented at this target
- No need for iOS 26 minimum (the new SwiftUI `WebView`/`WebPage` lacks the injection APIs we need)

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeychainAccess | 4.2+ | Secure credential storage | If ZenSocial ever stores user preferences securely. Lightweight Swift wrapper around Keychain Services. |
| None (first-party WebKit) | -- | CSS/JS injection | All injection uses built-in `WKUserScript` + `WKUserContentController`. No third-party injection library needed or recommended. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.x | IDE, simulator, debugging | Use Web Inspector for debugging injected JS/CSS (enable in Safari > Develop menu) |
| Safari Web Inspector | Debug WKWebView content | Connect via Safari > Develop > [Simulator/Device] to inspect injected CSS/JS live |
| SF Symbols | Native icons for tab bar | Apple's built-in icon set; no need for custom icon libraries |
| SwiftLint | Code quality | Optional but recommended; enforces Swift style conventions via SPM plugin |

## Architecture: WKWebView + UIViewRepresentable

This is the critical architectural decision. Here is why we use UIKit's WKWebView wrapped in SwiftUI rather than the new iOS 26 native `WebView`:

### Why NOT iOS 26 SwiftUI WebView/WebPage

The new `WebView` and `WebPage` types announced at WWDC 2025 (available in iOS 26) are significant but **insufficient for ZenSocial's core use case**:

1. **No `WKUserContentController` access** -- Cannot add `WKUserScript` objects for injection at document start
2. **No `.atDocumentStart` timing** -- `callJavaScript()` only works after page load, causing flash of unstyled/unblocked content (FOUC)
3. **No `WKContentRuleList` support** -- Cannot apply declarative content blocking rules
4. **iOS 26 minimum deployment** -- Would exclude all users not on the latest OS (released Fall 2025)
5. **Beta maturity** -- iOS 26 APIs are new; UIKit WKWebView has 10+ years of production hardening

### The Correct Pattern

```swift
// SwiftUI wrapper around UIKit's WKWebView
struct PlatformWebView: UIViewRepresentable {
    let platform: Platform  // .instagram, .youtube

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()

        // Inject CSS at document start (prevents FOUC)
        let cssScript = WKUserScript(
            source: platform.cssInjectionJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(cssScript)

        // Inject feature-blocking JS at document end
        let blockScript = WKUserScript(
            source: platform.featureBlockingJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(blockScript)

        config.userContentController = controller

        // Add content blocking rules (network-level)
        // Compiled from JSON rule sets per platform

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }
}
```

### CSS Injection via JavaScript (atDocumentStart)

CSS must be injected as JavaScript that creates a `<style>` element, because `WKUserScript` only supports JavaScript:

```javascript
// Injected at .atDocumentStart
var style = document.createElement('style');
style.textContent = `
  /* ZenSocial dark theme overrides */
  body { background: #1a1a1a !important; color: #e0e0e0 !important; }
  /* Hide Reels tab (Instagram) */
  [aria-label="Reels"] { display: none !important; }
`;
document.documentElement.appendChild(style);
```

### Feature Blocking JS (atDocumentEnd)

More complex blocking (MutationObserver for dynamically loaded content):

```javascript
// Injected at .atDocumentEnd
const observer = new MutationObserver((mutations) => {
  // Re-hide elements that Instagram/YouTube dynamically injects
  document.querySelectorAll('[aria-label="Reels"]')
    .forEach(el => el.style.display = 'none');
});
observer.observe(document.body, { childList: true, subtree: true });
```

## Cookie/Session Persistence

WKWebView cookie handling is a known pain point. Key facts:

- **Default behavior**: WKWebView stores cookies in its own process-isolated cookie store (`WKHTTPCookieStore`), separate from `HTTPCookieStorage`
- **Session survival**: Cookies persist across app launches by default with the default `WKWebsiteDataStore` (non-ephemeral). Users stay logged into Instagram/YouTube between sessions.
- **Risk**: iOS may purge WKWebView data under memory pressure or after extended backgrounding. This is rare but can cause unexpected logouts.
- **Mitigation**: Monitor cookies via `WKHTTPCookieStore.cookiesDidChange(in:)` and back up critical auth cookies to Keychain if needed. Only implement if logout complaints arise -- premature optimization otherwise.

## Content Blocking Strategy (Two Layers)

### Layer 1: WKContentRuleList (Network-Level)

Declarative JSON rules compiled at runtime. Block network requests before they reach the renderer:

```json
[
  {
    "trigger": { "url-filter": ".*reels.*", "resource-type": ["script", "image", "media"] },
    "action": { "type": "block" }
  },
  {
    "trigger": { "url-filter": ".*shorts.*", "resource-type": ["script", "image", "media"] },
    "action": { "type": "block" }
  }
]
```

**Advantage**: Prevents content from loading at all (saves bandwidth, faster).
**Limitation**: URL-pattern-based only; cannot target DOM elements.

### Layer 2: WKUserScript (DOM-Level)

CSS hiding + JS MutationObserver for surgical element removal. Catches everything that slips past URL filtering.

**Both layers together** provide defense-in-depth against platform UI changes.

## Installation

```bash
# No external dependencies needed for MVP.
# The entire stack uses Apple-provided frameworks:
#   - SwiftUI (app shell)
#   - WebKit (WKWebView, WKUserContentController, WKContentRuleList)
#   - Foundation (networking, data)
#   - Observation (state management)

# Optional (add via SPM if needed later):
# KeychainAccess - https://github.com/kishikawakatsumi/KeychainAccess
# SwiftLint - https://github.com/realm/SwiftLint (as build plugin)
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI + UIViewRepresentable WKWebView | iOS 26 native SwiftUI WebView/WebPage | When Apple adds `WKUserContentController` access to `WebPage` (future iOS versions). Monitor WWDC 2026. |
| SwiftUI (app shell) | UIKit (full app) | Never for a new project in 2025. SwiftUI is mature enough for navigation/settings; UIKit only needed for the WKWebView wrapper. |
| WKUserScript injection | Proxy/MITM approach | Never. Intercepting HTTPS traffic violates App Store guidelines and breaks certificate pinning. |
| WKContentRuleList | WKNavigationDelegate URL blocking | Only if you need programmatic (non-declarative) blocking logic. Content rules are faster and declarative. |
| Swift Package Manager | CocoaPods | Never for new projects. CocoaPods is in maintenance mode; SPM is Apple-native and simpler. |
| iOS 17 minimum | iOS 16 minimum | Only if analytics show significant iOS 16 user base. iOS 17 gives better SwiftUI APIs (Observable, NavigationStack). |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| React Native / Flutter | Adds massive complexity for zero benefit. This app is a thin native shell around WKWebView. Cross-platform frameworks add build tooling, bridge overhead, and App Store risk for a single-platform app. | Native Swift/SwiftUI |
| SFSafariViewController | Cannot inject CSS/JS. Read-only Safari chrome. Designed for "open a link" use cases, not app-hosted web content. | WKWebView |
| iOS 26 SwiftUI WebView/WebPage | Lacks `WKUserContentController`, `.atDocumentStart` injection, and `WKContentRuleList`. Would cause FOUC and incomplete blocking. Also requires iOS 26 minimum. | WKWebView via UIViewRepresentable |
| CocoaPods | Legacy dependency manager. Requires Ruby, generates xcworkspace files, slower builds. | Swift Package Manager |
| Alamofire / URLSession wrappers | No HTTP networking needed. WKWebView handles all web requests internally. | Nothing -- not applicable |
| WebKit message handler libraries | Unnecessary abstraction. `WKScriptMessageHandler` is simple enough to use directly for native-to-web communication. | Built-in `WKScriptMessageHandler` |
| Realm / Core Data | No local database needed for MVP. User preferences are simple key-value pairs. | UserDefaults for preferences |

## Stack Patterns

**For per-platform injection scripts:**
- Store CSS/JS as `.js` and `.css` files in the app bundle, organized by platform (`Scripts/Instagram/`, `Scripts/YouTube/`)
- Load at runtime via `Bundle.main.url(forResource:)` and inject as `WKUserScript`
- This makes scripts easy to update without changing Swift code
- Because selectors WILL break when platforms update their DOM

**For state management:**
- Use SwiftUI's `@Observable` macro (Observation framework, iOS 17+) for app state
- Use `@AppStorage` for simple user preferences (which platforms are enabled, theme preferences)
- No need for third-party state management (Redux-like patterns are overkill here)

**For navigation:**
- SwiftUI `TabView` for platform switching (Instagram tab, YouTube tab, Settings tab)
- Each tab contains a `PlatformWebView` (the UIViewRepresentable WKWebView wrapper)
- Native SwiftUI `NavigationStack` for settings/preferences screens

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| Swift 6.x | Xcode 16.x+ | Strict concurrency enabled by default. WKWebView delegate callbacks need `@MainActor` annotation. |
| SwiftUI (iOS 17+) | WKWebView via UIViewRepresentable | Well-established pattern. No compatibility concerns. |
| WKContentRuleList | iOS 11+ (stable) | Mature API. JSON rule format is stable and well-documented. |
| WKUserScript | iOS 8+ (stable) | Core WebKit API. Will not be deprecated. |
| Observation framework | iOS 17+ | Requires iOS 17 minimum. Replaces older `ObservableObject`/`@Published` pattern. |

## App Store Compliance

CSS/JS injection into WKWebView is explicitly permitted by Apple. Key guidelines:

- **Guideline 2.5.6**: Apps that browse the web must use WebKit (WKWebView). ZenSocial complies.
- **Guideline 4.7 (updated Nov 2025)**: Mini apps/games rules. Does NOT apply -- ZenSocial is not hosting mini apps; it is rendering existing web pages with cosmetic modifications.
- **JavaScript injection**: Apple's own `WKUserContentController` API is designed for this purpose. Using it as intended is not a guideline violation.
- **Risk area**: Do not expose native device APIs to injected JavaScript. ZenSocial's scripts only modify CSS/DOM -- no native bridge needed for core features.

**Confidence: HIGH** -- Multiple apps on the App Store use identical WKWebView + CSS/JS injection patterns (ad blockers, reader mode apps, web wrappers).

## Sources

- [Apple Developer: WKUserContentController](https://developer.apple.com/documentation/webkit/wkusercontentcontroller) -- Official API docs (HIGH confidence)
- [Apple Developer: WKContentRuleListStore](https://developer.apple.com/documentation/webkit/wkcontentruleliststore) -- Content blocking rules API (HIGH confidence)
- [WWDC 2025: Meet WebKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2025/231/) -- iOS 26 WebView/WebPage capabilities and limitations (HIGH confidence)
- [AppCoda: Exploring WebView and WebPage in SwiftUI for iOS 26](https://www.appcoda.com/swiftui-webview/) -- Practical iOS 26 WebView guide (MEDIUM confidence)
- [Apple Developer Forums: Is it legit to inject JavaScript into WKWebView](https://developer.apple.com/forums/thread/718101) -- App Store compliance confirmation (HIGH confidence)
- [Swift Senpai: JavaScript Injection in WKWebView](https://swiftsenpai.com/development/web-view-javascript-injection/) -- Injection patterns and timing (MEDIUM confidence)
- [WebApp2App: Avoiding CSS Injection Delays](https://www.webapp2app.com/2023/01/26/avoiding-css-injection-delays-in-wkwebview-ios-swift-apps/) -- FOUC prevention via atDocumentStart (MEDIUM confidence)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- Official compliance rules (HIGH confidence)

---
*Stack research for: iOS WKWebView social media wrapper with CSS/JS injection*
*Researched: 2026-03-24*
