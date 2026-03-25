# Phase 1: Native Shell + WKWebView Foundation - Research

**Researched:** 2026-03-24
**Domain:** iOS native shell (SwiftUI + WKWebView), web content rendering, session persistence, auth flows
**Confidence:** HIGH

## Summary

Phase 1 delivers a working iOS app that loads Instagram and YouTube in separate WKWebView instances, wrapped in a native SwiftUI tab bar, with persistent login sessions, loading/error states, pull-to-refresh, and Safari user agent spoofing. The entire stack uses Apple first-party frameworks -- no third-party dependencies are needed.

The most significant technical risk is **Google's blocking of authentication flows in embedded web views (WKWebView)**. When YouTube redirects to `accounts.google.com` for login, Google may detect the embedded browser and return a `403: disallowed_useragent` error, even with a spoofed Safari user agent. The auth modal design (D-07/D-08) with an "Open in Safari" fallback is essential and should be treated as the primary YouTube login path, not a fallback.

iOS 17+ provides the `WKWebsiteDataStore(forIdentifier:)` API for creating separate persistent data stores with custom UUIDs -- this is the exact mechanism needed for D-04 (isolated persistent sessions per platform). Swift 6 strict concurrency requires `@MainActor` annotation on all WKNavigationDelegate implementations and use of async delegate variants where available.

**Primary recommendation:** Build a `PlatformWebView` UIViewRepresentable with per-platform `WKWebsiteDataStore(forIdentifier:)` isolation, dynamic Safari UA extraction at launch, and an auth modal sheet that opens `accounts.google.com` (and other auth domains) in a separate WKWebView with "Open in Safari" as the primary escape hatch for Google login.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use mobile iOS Safari UA -- loads the touch-optimized mobile web app experience for both platforms.
- **D-02:** UA is **dynamic** -- read the actual Safari UA from a temporary WKWebView at launch and apply it. Never hardcoded. Always matches the iOS version on the device with zero maintenance.
- **D-03:** **Shared `WKProcessPool`** across both platform WebViews -- single web content process, lower memory footprint, better performance on all devices.
- **D-04:** **Separate `WKWebsiteDataStore` per platform** -- Instagram and YouTube each get their own cookie/session/localStorage store. Clean isolation: clearing one platform's data doesn't touch the other. This is an immutable-at-init decision.
- **D-05:** **Instagram:** `mediaTypesRequiringUserActionForPlayback = .all` -- no video plays without a user tap.
- **D-06:** **YouTube:** `mediaTypesRequiringUserActionForPlayback = []` -- autoplay allowed.
- **D-07:** When `WKNavigationDelegate` detects navigation to a non-platform domain (e.g., `accounts.google.com` for YouTube login), **present a modal sheet containing a new WKWebView** configured with the same `WKWebsiteDataStore` as the originating platform. Auth cookies are written to the correct store.
- **D-08:** The modal sheet toolbar includes an **"Open in Safari" button** (`UIApplication.shared.open(url)`) as a fallback for cases where OAuth blocks WebView-based login.
- **D-09:** The modal **auto-dismisses** when navigation returns to the platform domain (e.g., back to `instagram.com` or `youtube.com`).

### Claude's Discretion
- External link handling (non-auth external URLs): already decided in UI-SPEC -- open in system browser.
- WKWebView media configuration beyond autoplay (e.g., `allowsInlineMediaPlayback`, `allowsAirPlayForMediaPlayback`) -- Claude picks sensible defaults.
- Specific URL allowlist for "known auth domains" that trigger the modal vs. other external domains that open in system browser -- Claude defines based on Instagram/YouTube login flow research.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHELL-01 | User can switch between Instagram and YouTube via a native tab bar | SwiftUI `TabView` with `.tabItem` modifiers, 2 tabs, accent tint per UI-SPEC |
| SHELL-02 | User sees a native loading indicator while web content loads per platform | SwiftUI `ProgressView` overlay, driven by `WKNavigationDelegate.didFinish` |
| SHELL-03 | User sees a native offline/error screen when a platform fails to load | Custom SwiftUI view with state machine (idle/loading/loaded/error:offline/error:failed) |
| WEB-01 | User can browse Instagram via WKWebView with full platform functionality | WKWebView loading `https://www.instagram.com/` with Safari UA spoofing (D-01/D-02) |
| WEB-02 | User can browse YouTube via WKWebView with full platform functionality | WKWebView loading `https://m.youtube.com/` with Safari UA, autoplay enabled (D-06) |
| WEB-03 | User stays logged in to both platforms across app launches (persistent sessions) | `WKWebsiteDataStore(forIdentifier:)` creates persistent isolated stores per platform (iOS 17+) |
| WEB-04 | User can navigate within each platform (back/forward swipe, back button) | `webView.allowsBackForwardNavigationGestures = true` |
| WEB-05 | User can pull-to-refresh to reload the current platform page | `UIRefreshControl` attached to `webView.scrollView` |
| BLOCK-03 | User-agent is spoofed to a Safari UA to prevent Instagram/YouTube from detecting WKWebView | Dynamic UA extraction via temporary WKWebView + `evaluateJavaScript("navigator.userAgent")` at launch |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** iOS only -- Swift/SwiftUI + WKWebView
- **Language:** Swift 6.x with strict concurrency
- **UI framework:** SwiftUI (iOS 17+) for app shell, UIKit only for WKWebView wrapper via `UIViewRepresentable`
- **Minimum deployment target:** iOS 17 (covers 95%+ active iPhones)
- **IDE:** Xcode 16.x+
- **Dependency management:** Swift Package Manager only (no CocoaPods)
- **No third-party dependencies** for Phase 1 -- all Apple first-party frameworks
- **Color mode:** Dark mode only (`UIUserInterfaceStyle = Dark` in Info.plist)
- **WKWebView via UIViewRepresentable** -- NOT iOS 26 SwiftUI WebView/WebPage (lacks `WKUserContentController` access)
- **App Store compliance:** Guideline 2.5.6 (must use WebKit), no native device APIs exposed to injected JS
- **State management:** `@Observable` macro (Observation framework), `@AppStorage` for preferences
- **Icons:** SF Symbols only
- **Cookie persistence:** Default (non-ephemeral) `WKWebsiteDataStore` behavior; no premature Keychain backup

## Standard Stack

### Core
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Swift | 6.2.x (installed: 6.2.4) | Primary language | Only option for native iOS. Strict concurrency enabled by default. |
| SwiftUI | iOS 17+ | App shell, tab bar, error screens, loading overlay | Declarative UI for all native chrome. Mature at iOS 17+. |
| WKWebView (WebKit) | iOS 17+ | Web content rendering | Only viable path for rendering third-party web content with injection capability. |
| WKWebsiteDataStore | iOS 17+ | Per-platform persistent cookie/session storage | `WKWebsiteDataStore(forIdentifier:)` API (iOS 17+) creates isolated persistent stores. |
| WKProcessPool | iOS 17+ | Shared web content process | Single instance shared across both WebViews (D-03). |
| WKNavigationDelegate | iOS 17+ | Navigation events, error handling, auth detection | Drives loading state, error state, auth redirect detection. |
| Observation framework | iOS 17+ | App state management | `@Observable` macro replaces `ObservableObject`/`@Published`. |
| Xcode | 26.3 (installed) | IDE and build system | Required for App Store submission. |

### Supporting
| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| UIRefreshControl | iOS 17+ | Pull-to-refresh | Attached to `webView.scrollView` for WEB-05 |
| NWPathMonitor (Network framework) | iOS 17+ | Network connectivity monitoring | Distinguish offline vs. load-failed errors for SHELL-03 |
| @AppStorage | iOS 17+ | Simple user preferences | Store platform UUIDs for data store identifiers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `WKWebsiteDataStore(forIdentifier:)` | `WKWebsiteDataStore.default()` singleton | Cannot isolate platforms -- shared cookies, clearing one clears both |
| `WKWebsiteDataStore(forIdentifier:)` | `WKWebsiteDataStore.nonPersistent()` | Loses all data on app termination -- users must re-login every launch |
| `NWPathMonitor` | `URLSession` reachability check | NWPathMonitor is purpose-built for connectivity monitoring, simpler |
| Dynamic UA from temp WKWebView | Hardcoded UA string | Breaks on every iOS version update, maintenance burden |

**Installation:**
```bash
# No external dependencies. All Apple first-party frameworks.
# Project created via Xcode > New Project > App (SwiftUI)
```

## Architecture Patterns

### Recommended Project Structure
```
ZenSocial/
├── ZenSocialApp.swift              # @main App entry point, TabView
├── Models/
│   ├── Platform.swift              # Platform enum (instagram, youtube) with config
│   └── WebViewState.swift          # @Observable state: loading, loaded, error
├── Views/
│   ├── ContentView.swift           # TabView with platform tabs
│   ├── PlatformTabView.swift       # Per-tab container: WebView + loading + error
│   ├── ErrorView.swift             # Offline / load-failed error screen
│   └── AuthModalView.swift         # Sheet for auth domain navigation
├── WebView/
│   ├── PlatformWebView.swift       # UIViewRepresentable wrapping WKWebView
│   ├── WebViewCoordinator.swift    # WKNavigationDelegate + WKUIDelegate
│   └── WebViewConfiguration.swift  # Factory for WKWebViewConfiguration per platform
├── Services/
│   ├── UserAgentProvider.swift     # Dynamic Safari UA extraction at launch
│   ├── NetworkMonitor.swift        # NWPathMonitor wrapper
│   └── DataStoreManager.swift      # WKWebsiteDataStore(forIdentifier:) management
├── Extensions/
│   └── Color+ZenSocial.swift       # Brand colors (accent blue, etc.)
└── Resources/
    └── Info.plist                   # UIUserInterfaceStyle = Dark
```

### Pattern 1: UIViewRepresentable + Coordinator for WKWebView
**What:** Wrap WKWebView in `UIViewRepresentable`, use a `Coordinator` class as `WKNavigationDelegate` and `WKUIDelegate`.
**When to use:** Always -- this is the only way to get WKWebView into SwiftUI with full delegate control.
**Example:**
```swift
// Source: Apple Developer Documentation + community best practice
struct PlatformWebView: UIViewRepresentable {
    let platform: Platform
    @Bindable var state: WebViewState

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(platform: platform, state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WebViewConfiguration.make(for: platform)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true  // WEB-04
        webView.isOpaque = false
        webView.backgroundColor = .black  // Prevent white flash
        webView.scrollView.backgroundColor = .black

        // Pull-to-refresh (WEB-05)
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(named: "AccentBlue")
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
        // Load initial URL only once
        if webView.url == nil {
            let request = URLRequest(url: platform.homeURL)
            webView.load(request)
        }
    }
}
```

### Pattern 2: Dynamic Safari UA Extraction
**What:** Create a temporary WKWebView at app launch, evaluate `navigator.userAgent` to get the real Safari UA string, then apply it to all platform WebViews via `customUserAgent`.
**When to use:** Once at app launch, before creating platform WebViews.
**Example:**
```swift
// Source: Apple Developer Forums + community pattern
@MainActor
class UserAgentProvider {
    static let shared = UserAgentProvider()
    private(set) var safariUserAgent: String?

    func extractUserAgent() async {
        let webView = WKWebView(frame: .zero)
        do {
            let ua = try await webView.evaluateJavaScript("navigator.userAgent") as? String
            // WKWebView default UA contains "Mobile/" but NOT "Safari/"
            // Real Safari UA contains both "Mobile/" AND "Safari/"
            // Append "Safari/605.1.15" if missing (the WebKit version is stable)
            if let ua, !ua.contains("Safari/") {
                self.safariUserAgent = ua + " Safari/605.1.15"
            } else {
                self.safariUserAgent = ua
            }
        } catch {
            // Fallback: nil means don't override UA (WKWebView default)
            self.safariUserAgent = nil
        }
    }
}
```

### Pattern 3: Per-Platform WKWebsiteDataStore with UUID Identifiers
**What:** Use `WKWebsiteDataStore(forIdentifier:)` (iOS 17+) to create persistent, isolated data stores per platform.
**When to use:** When creating WKWebViewConfiguration for each platform.
**Example:**
```swift
// Source: WebKit Blog "Building Profiles with new WebKit API"
// https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/
enum DataStoreManager {
    // Fixed UUIDs -- stable across app launches
    private static let instagramStoreID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let youtubeStoreID   = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func dataStore(for platform: Platform) -> WKWebsiteDataStore {
        switch platform {
        case .instagram:
            return WKWebsiteDataStore(forIdentifier: instagramStoreID)
        case .youtube:
            return WKWebsiteDataStore(forIdentifier: youtubeStoreID)
        }
    }
}
```

### Pattern 4: Auth Domain Detection and Modal Presentation
**What:** In `WKNavigationDelegate.decidePolicyFor`, detect navigation to known auth domains and present a modal sheet instead of navigating in-place.
**When to use:** When user taps "Log in" on Instagram or YouTube.
**Example:**
```swift
// Source: CONTEXT.md decisions D-07, D-08, D-09
// In WebViewCoordinator:
@MainActor
func webView(_ webView: WKWebView,
             decidePolicyFor navigationAction: WKNavigationAction)
             async -> WKNavigationActionPolicy {
    guard let url = navigationAction.request.url,
          let host = url.host?.lowercased() else {
        return .allow
    }

    // Known auth domains -- trigger modal
    let authDomains = [
        "accounts.google.com",
        "accounts.youtube.com",
        "www.facebook.com",   // Instagram login via Facebook
        "m.facebook.com",
        "login.instagram.com"
    ]

    if authDomains.contains(where: { host.contains($0) }) {
        state.pendingAuthURL = url
        return .cancel
    }

    // Platform domain -- allow navigation
    if platform.isOwnDomain(host) {
        return .allow
    }

    // External non-auth domain -- open in Safari
    await UIApplication.shared.open(url)
    return .cancel
}
```

### Anti-Patterns to Avoid
- **Creating WKWebView in `updateUIView`:** WKWebView must be created once in `makeUIView`. Creating new instances on every SwiftUI state change destroys session state and causes flicker.
- **Using `WKWebsiteDataStore.default()` for both platforms:** Singleton -- impossible to isolate cookies. Clearing one platform's data clears both.
- **Using `WKWebsiteDataStore.nonPersistent()` for session persistence:** Data is lost on app termination. Users must re-login every launch.
- **Hardcoding user agent strings:** Breaks on iOS version updates. Dynamic extraction (D-02) is zero-maintenance.
- **Modifying `WKWebViewConfiguration` after init:** Configuration is immutable after the WKWebView is created. All settings must be applied before `WKWebView(frame:configuration:)`.
- **Ignoring Swift 6 strict concurrency:** WKNavigationDelegate callbacks are `@MainActor`-isolated in iOS 18+. Using completion-handler variants without proper actor annotation causes silent failures.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Network connectivity detection | Custom reachability class | `NWPathMonitor` (Network framework) | Handles all edge cases: cellular, WiFi, VPN, captive portals |
| Pull-to-refresh | Custom scroll gesture recognizer | `UIRefreshControl` on `webView.scrollView` | System component, handles all edge cases, familiar UX |
| Cookie persistence | Manual Keychain cookie backup | `WKWebsiteDataStore(forIdentifier:)` persistent stores | Apple manages persistence, survives app restarts by default |
| Auth flow handling | Custom OAuth SDK integration | Auth modal with "Open in Safari" fallback (D-07/D-08) | Google blocks OAuth in WKWebView; Safari fallback is the compliant path |
| User agent string construction | Manual string concatenation | `evaluateJavaScript("navigator.userAgent")` + append Safari suffix | Always matches device iOS version automatically |
| Loading state management | Custom timers or polling | `WKNavigationDelegate` callbacks (didStart, didFinish, didFail) | WebKit reports all navigation events natively |

**Key insight:** Phase 1 uses zero third-party libraries. Every capability is provided by Apple's first-party frameworks. The complexity is in correct configuration (immutable at init) and proper delegate wiring, not in library selection.

## Common Pitfalls

### Pitfall 1: Google Blocks OAuth in WKWebView (CRITICAL)
**What goes wrong:** When YouTube redirects to `accounts.google.com` for login, Google detects the embedded browser and returns `403: disallowed_useragent`. Even spoofing a Safari user agent may not bypass detection -- Google uses multiple fingerprinting signals beyond user-agent (TLS fingerprint, JavaScript API availability, canvas rendering).
**Why it happens:** Google policy since September 2021 blocks all OAuth requests from embedded web views for security reasons.
**How to avoid:** The auth modal (D-07) with "Open in Safari" button (D-08) is not optional -- it is the primary escape hatch. Test YouTube login end-to-end early. If in-modal WKWebView login works with Safari UA, great. If not, the Safari fallback must be seamless.
**Warning signs:** User sees "This browser or app may not be secure" or a blank white page on `accounts.google.com`.

### Pitfall 2: WKWebViewConfiguration Is Immutable After Init
**What goes wrong:** Attempting to change `processPool`, `websiteDataStore`, `mediaTypesRequiringUserActionForPlayback`, or `customUserAgent` after the WKWebView is created has no effect or crashes.
**Why it happens:** `WKWebViewConfiguration` is copied at `WKWebView(frame:configuration:)` init time. The copy is frozen.
**How to avoid:** Build a complete `WKWebViewConfiguration` factory that sets ALL properties before creating the WKWebView. Never modify config after init.
**Warning signs:** Settings appear to be ignored, or changes don't take effect until app restart.

### Pitfall 3: Swift 6 Strict Concurrency + WKNavigationDelegate
**What goes wrong:** WKNavigationDelegate methods silently stop being called, or the compiler produces confusing errors about `@Sendable` closures.
**Why it happens:** iOS 18+ WebKit adds `@MainActor` to `WKNavigationDelegate` protocol and `@Sendable` on handler closures. Swift 6 strict concurrency enforces this.
**How to avoid:** Use the async variants of delegate methods: `func webView(_:decidePolicyFor:) async -> WKNavigationActionPolicy`. Mark the Coordinator class with `@MainActor`. Use `@preconcurrency import WebKit` if targeting iOS 17 where the old signatures are still valid.
**Warning signs:** Delegate methods not firing, compiler warnings about actor isolation.

### Pitfall 4: White Flash on Page Load (FOUC)
**What goes wrong:** WKWebView briefly shows a white background before web content renders, breaking the dark theme.
**Why it happens:** WKWebView defaults to white/opaque background. Content takes time to render.
**How to avoid:** Set `webView.isOpaque = false`, `webView.backgroundColor = .black`, `webView.scrollView.backgroundColor = .black`. Also set `webView.underPageBackgroundColor = .black` (iOS 15+).
**Warning signs:** Visible white flash when switching tabs or loading pages.

### Pitfall 5: UIRefreshControl Not Working After Navigation
**What goes wrong:** Pull-to-refresh works on the first page but stops working after navigating to subsequent pages.
**Why it happens:** Some web pages set `scrollView.bounces = false` or the scroll view's content offset interferes with the refresh control.
**How to avoid:** Re-enable `webView.scrollView.bounces = true` in `webView(_:didFinish:)` delegate callback after each navigation.
**Warning signs:** Pull gesture doesn't trigger refresh on certain pages.

### Pitfall 6: Instagram Redirects to App Store or Native App
**What goes wrong:** Instagram's mobile web may show "Open in App" interstitials or redirect to the App Store.
**Why it happens:** Instagram's mobile web aggressively promotes its native app. With a WKWebView user agent, this behavior may be more or less aggressive than Safari.
**How to avoid:** The Safari UA spoofing (D-01/D-02) should reduce this. If interstitials persist, Phase 2's JS injection can hide them. For Phase 1, accept that some interstitials may appear.
**Warning signs:** Users see "Open in App" banners or are redirected to App Store.

### Pitfall 7: Tab Switch Destroys WebView State
**What goes wrong:** Switching between Instagram and YouTube tabs causes the web view to reload, losing scroll position and page state.
**Why it happens:** SwiftUI's `TabView` may recreate views when switching tabs if the WebView is not properly retained.
**How to avoid:** Store the WKWebView instances outside SwiftUI's view lifecycle. Use a shared object (e.g., `@Observable` class) that holds references to both WKWebView instances. The `UIViewRepresentable` should return the existing instance, not create a new one.
**Warning signs:** Pages reload when switching tabs, scroll position lost.

## Code Examples

### WKWebViewConfiguration Factory
```swift
// Source: Apple Developer Documentation + CONTEXT.md decisions
@MainActor
enum WebViewConfiguration {
    /// Shared process pool (D-03)
    private static let sharedProcessPool = WKProcessPool()

    static func make(for platform: Platform) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // D-03: Shared process pool
        config.processPool = sharedProcessPool

        // D-04: Separate persistent data store per platform
        config.websiteDataStore = DataStoreManager.dataStore(for: platform)

        // D-05 / D-06: Per-platform autoplay policy
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        config.defaultWebpagePreferences = prefs

        // Autoplay configuration
        switch platform {
        case .instagram:
            // D-05: No autoplay
            config.mediaTypesRequiringUserActionForPlayback = .all
        case .youtube:
            // D-06: Autoplay allowed
            config.mediaTypesRequiringUserActionForPlayback = []
        }

        // Media configuration (Claude's discretion)
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        // Prepare WKUserContentController for Phase 2 injection
        let contentController = WKUserContentController()
        config.userContentController = contentController

        return config
    }
}
```

### Platform Enum
```swift
// Source: App architecture pattern
enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        }
    }

    var homeURL: URL {
        switch self {
        case .instagram: return URL(string: "https://www.instagram.com/")!
        case .youtube: return URL(string: "https://m.youtube.com/")!
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera"
        case .youtube: return "play.rectangle"
        }
    }

    /// Domains that belong to this platform (navigation stays in-app)
    func isOwnDomain(_ host: String) -> Bool {
        switch self {
        case .instagram:
            return host.hasSuffix("instagram.com") || host.hasSuffix("cdninstagram.com")
        case .youtube:
            return host.hasSuffix("youtube.com") || host.hasSuffix("googlevideo.com")
                || host.hasSuffix("ytimg.com")
        }
    }
}
```

### Network Monitor
```swift
// Source: Apple Network framework documentation
import Network

@Observable
@MainActor
class NetworkMonitor {
    var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
```

### Auth Domain Allowlist (Claude's Discretion)
```swift
// Source: Research into Instagram and YouTube login flows
enum AuthDomains {
    /// Domains that trigger the auth modal (D-07) instead of opening in Safari
    static let allowlist: Set<String> = [
        // Google / YouTube auth
        "accounts.google.com",
        "accounts.youtube.com",
        "myaccount.google.com",

        // Facebook / Instagram auth
        "www.facebook.com",
        "m.facebook.com",
        "web.facebook.com",
        "login.instagram.com",

        // Apple ID (if either platform offers Sign in with Apple)
        "appleid.apple.com",
    ]

    static func isAuthDomain(_ host: String) -> Bool {
        allowlist.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `WKWebsiteDataStore.default()` (singleton) | `WKWebsiteDataStore(forIdentifier:)` (custom persistent) | iOS 17 / WWDC 2023 | Enables per-platform data isolation with persistence |
| `ObservableObject` + `@Published` | `@Observable` macro (Observation framework) | iOS 17 / WWDC 2023 | Simpler state management, automatic dependency tracking |
| Completion-handler WKNavigationDelegate | Async WKNavigationDelegate variants | iOS 18 / WWDC 2024 | Required for Swift 6 strict concurrency compliance |
| Manual cookie sync (HTTPCookieStorage) | WKHTTPCookieStore (per data store) | iOS 11+ | Each `WKWebsiteDataStore` has its own `httpCookieStore` |

**Deprecated/outdated:**
- `UIWebView`: Fully removed. Apps using it are rejected from App Store.
- `ObservableObject`/`@Published`: Still works but `@Observable` is the modern replacement for iOS 17+.
- Completion-handler `WKNavigationDelegate` methods: Still work on iOS 17 but async variants preferred for Swift 6.

## Open Questions

1. **Does Google's `accounts.google.com` login actually block WKWebView with a spoofed Safari UA?**
   - What we know: Google blocks OAuth in WKWebView by checking user-agent. Spoofing Safari UA is a ToS violation but may technically work. Google may also use TLS fingerprinting or JS API fingerprinting.
   - What's unclear: Whether the standard form-based login on `accounts.google.com` (not OAuth SDK) is subject to the same blocking as the OAuth 2.0 authorization endpoint.
   - Recommendation: Test early in Phase 1. The auth modal "Open in Safari" fallback (D-08) covers this risk. If in-WKWebView login works, the modal is a bonus. If not, the Safari button is the primary path.

2. **Instagram "Open in App" interstitials**
   - What we know: Instagram mobile web aggressively promotes the native app. Safari UA should reduce this.
   - What's unclear: How aggressive the interstitials are with a Safari UA in 2026. May need JS injection (Phase 2) to hide.
   - Recommendation: Accept interstitials in Phase 1. Phase 2 injection will handle them.

3. **WKWebView lifecycle in SwiftUI TabView**
   - What we know: SwiftUI may recreate views on tab switch, destroying WKWebView state.
   - What's unclear: Exact behavior with iOS 17+ `TabView` and `UIViewRepresentable`.
   - Recommendation: Hold WKWebView instances in an `@Observable` manager outside the view hierarchy. The `UIViewRepresentable` returns the existing instance rather than creating new ones.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system | Yes | 26.3 | -- |
| Swift | Language | Yes | 6.2.4 | -- |
| iOS Simulator | Testing | Yes (via Xcode) | -- | Physical device |
| Safari Web Inspector | WKWebView debugging | Yes (via Safari > Develop) | -- | Xcode console logging |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest + XCUITest (built into Xcode) |
| Config file | None -- Wave 0 creates Xcode project with test targets |
| Quick run command | `xcodebuild test -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZenSocialTests` |
| Full suite command | `xcodebuild test -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELL-01 | Tab bar switches between Instagram and YouTube | UI test | `xcodebuild test ... -only-testing:ZenSocialUITests/TabBarTests` | Wave 0 |
| SHELL-02 | Loading indicator appears/disappears | Unit test (state) + UI test | `xcodebuild test ... -only-testing:ZenSocialTests/WebViewStateTests` | Wave 0 |
| SHELL-03 | Error screen shows on failure | Unit test (state) + UI test | `xcodebuild test ... -only-testing:ZenSocialTests/WebViewStateTests` | Wave 0 |
| WEB-01 | Instagram loads in WKWebView | UI test (smoke) | `xcodebuild test ... -only-testing:ZenSocialUITests/InstagramLoadTests` | Wave 0 |
| WEB-02 | YouTube loads in WKWebView | UI test (smoke) | `xcodebuild test ... -only-testing:ZenSocialUITests/YouTubeLoadTests` | Wave 0 |
| WEB-03 | Session persists across launches | Manual | Manual: login, force-quit, relaunch, verify session | Manual-only -- requires real platform login |
| WEB-04 | Back/forward swipe navigation | UI test | `xcodebuild test ... -only-testing:ZenSocialUITests/NavigationTests` | Wave 0 |
| WEB-05 | Pull-to-refresh works | UI test | `xcodebuild test ... -only-testing:ZenSocialUITests/RefreshTests` | Wave 0 |
| BLOCK-03 | Safari UA applied to WKWebView | Unit test | `xcodebuild test ... -only-testing:ZenSocialTests/UserAgentTests` | Wave 0 |

### Sampling Rate
- **Per task commit:** Quick unit test run
- **Per wave merge:** Full suite (unit + UI tests)
- **Phase gate:** Full suite green + manual session persistence verification

### Wave 0 Gaps
- [ ] Xcode project creation with app target + test targets (ZenSocialTests, ZenSocialUITests)
- [ ] `ZenSocialTests/WebViewStateTests.swift` -- state machine transitions
- [ ] `ZenSocialTests/UserAgentTests.swift` -- UA extraction and Safari suffix
- [ ] `ZenSocialTests/PlatformTests.swift` -- Platform enum, domain matching
- [ ] `ZenSocialTests/AuthDomainTests.swift` -- auth domain allowlist detection
- [ ] `ZenSocialUITests/TabBarTests.swift` -- tab switching
- [ ] `ZenSocialUITests/` -- smoke tests for WebView loading (require simulator + network)

## Sources

### Primary (HIGH confidence)
- [Apple Developer: WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore) -- `forIdentifier:` API, persistent vs non-persistent
- [WebKit Blog: Building Profiles with new WebKit API](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/) -- iOS 17 custom persistent data store API with code examples
- [Apple Developer: WKWebView.customUserAgent](https://developer.apple.com/documentation/webkit/wkwebview/customuseragent) -- UA override property
- [Apple Developer: WKWebView.allowsBackForwardNavigationGestures](https://developer.apple.com/documentation/webkit/wkwebview/allowsbackforwardnavigationgestures) -- Swipe navigation
- [Apple Developer: WKNavigationDelegate](https://developer.apple.com/documentation/webkit/wknavigationdelegate) -- Navigation events, error handling
- [Apple Developer: WKWebsiteDataStore.nonPersistent()](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/nonpersistent()) -- Non-persistent store behavior
- [Apple Developer Forums: WKWebView userAgent](https://developer.apple.com/forums/thread/650458) -- Dynamic UA extraction patterns

### Secondary (MEDIUM confidence)
- [Swift Forums: Strict Concurrency + WKNavigationDelegate](https://forums.swift.org/t/strict-concurrency-checking-complete-than-wknavigationdelegate-function-not-work/78962) -- Swift 6 async delegate patterns
- [cnr.sh: OAuth "Sign In With Google" in WKWebView](https://cnr.sh/posts/2021-10-11-google-oauth-wkwebview/) -- Google OAuth blocking details and Safari redirect workaround
- [Atomic Object: WKWebView Reload with RefreshControl](https://spin.atomicobject.com/reload-wkwebview/) -- UIRefreshControl on WKWebView scrollView
- [Hacking with Swift: WKWebView back/forward gestures](https://www.hackingwithswift.com/example-code/wkwebview/how-to-enable-back-and-forward-swiping-gestures-in-wkwebview) -- allowsBackForwardNavigationGestures

### Tertiary (LOW confidence)
- [Google Developers Blog: OAuth security changes in embedded webviews](https://developers.googleblog.com/upcoming-security-changes-to-googles-oauth-20-authorization-endpoint-in-embedded-webviews/) -- Confirmed Google blocks OAuth in WKWebView (policy from 2021, enforcement since Sep 2021). LOW because unclear if standard form login on `accounts.google.com` is also blocked in 2026.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all Apple first-party, well-documented APIs, verified against official docs
- Architecture: HIGH -- UIViewRepresentable + Coordinator is the canonical pattern for WKWebView in SwiftUI
- Pitfalls: HIGH -- Google OAuth blocking is well-documented; Swift 6 concurrency issues confirmed on Swift Forums
- Auth domain allowlist: MEDIUM -- based on known login flow domains, but platforms may change redirect patterns
- WKWebView tab lifecycle: MEDIUM -- SwiftUI TabView behavior with UIViewRepresentable needs empirical testing

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (30 days -- stable Apple APIs, unlikely to change)
