# Project Research Summary

**Project:** ZenSocial (freesocial)
**Domain:** iOS WKWebView social media wrapper with CSS/JS injection (digital wellbeing)
**Researched:** 2026-03-24
**Confidence:** HIGH

## Executive Summary

ZenSocial is a native iOS digital wellbeing app that wraps Instagram and YouTube in a focused browsing shell, blocking short-form video content (Reels, Shorts) and applying a calm dark theme. The correct implementation path is well-established: a SwiftUI app shell with WKWebView rendered via `UIViewRepresentable`, using `WKUserContentController` for CSS/JS injection at document start to prevent flash of blocked content, and `WKContentRuleList` for network-level blocking. The iOS 26 native SwiftUI `WebView`/`WebPage` API must be explicitly avoided — it lacks `WKUserContentController` access, `.atDocumentStart` injection timing, and `WKContentRuleList` support, all of which are non-negotiable for this app's core value proposition.

The competitive landscape (ScrollGuard, WallHabit, One Sec, Opal) shows that ZenSocial's differentiated position is combining a full in-app browsing experience with a branded dark/minimal theme — no current competitor does both. The feature set is tightly scoped: MVP is a native shell, injection engine, Reels/Shorts blocking, dark theme, and persistent sessions. Everything beyond that is Phase 2+. The most important anti-features are push notifications, gamification, and a backend — all of which would contradict the "calm, intentional" brand.

Two categories of risk dominate the project. The first is App Store compliance: Guideline 4.2 (minimum functionality) and 5.2.2 (third-party content authorization) are both active rejection threats that must be designed around from day one, not retrofitted. The native shell must feel like an app — not a browser — at submission time. The second is ongoing maintenance: Instagram and YouTube change their frontend DOM weekly, which will silently break CSS/JS selectors. The injection system architecture must make selector updates cheap, ideally through externalized config files that can be updated without App Store review cycles.

## Key Findings

### Recommended Stack

The entire stack is Apple-first with zero third-party dependencies needed for MVP. Swift 6.x with SwiftUI (iOS 17+ minimum) provides the app shell, settings UI, and navigation. WKWebView wrapped in `UIViewRepresentable` is the only viable web rendering approach. `WKUserContentController` and `WKUserScript` handle injection; `WKContentRuleList` handles network-level blocking. The Observation framework (`@Observable` macro) replaces `ObservableObject` for state. SPM is the dependency manager.

The iOS 17 minimum target is correct — it covers 95%+ of active iPhones, provides mature SwiftUI APIs (`NavigationStack`, `Observable`), and avoids the iOS 26 `WebView`/`WebPage` trap. CSS is injected as JavaScript creating a `<style>` element (WKUserScript only supports JS), applied at `.atDocumentStart` to prevent FOUC. Feature-blocking JS runs at `.atDocumentEnd` via MutationObserver to catch dynamically injected elements from these SPA-heavy platforms.

**Core technologies:**
- **Swift 6.x**: Primary language — Apple-native, strict concurrency, async/await
- **SwiftUI (iOS 17+)**: App shell and settings — mature enough for navigation/settings; `UIViewRepresentable` bridges to WKWebView
- **WKWebView (UIKit)**: Web rendering — the only API that exposes `WKUserContentController` and `.atDocumentStart` injection
- **WKUserContentController**: Injection engine — attaches `WKUserScript` objects for CSS and JS injection
- **WKContentRuleList**: Network blocking — declarative JSON rules blocking Reels/Shorts asset URLs before load
- **Swift Package Manager**: Dependency management — Apple-native, no external dependencies needed for MVP

### Expected Features

The feature research establishes a clear critical path: WKWebView container → CSS/JS injection engine → individual blocks → settings → tracking/nudges. The injection engine is the shared infrastructure that all blocking features depend on.

**Must have (table stakes):**
- WKWebView rendering of Instagram and YouTube with persistent login — core value prop, users will abandon without it
- Block Instagram Reels tab and content — primary use case, all competitors support this
- Block YouTube Shorts tab and shelf — primary use case, all competitors support this
- Native tab bar for platform switching — App Store Guideline 4.2 requirement
- Loading states and offline error handling — App Store requirement; blank screens cause rejection
- Basic onboarding (2-3 screens) — users need to understand the value proposition
- Pull-to-refresh and back/forward navigation — standard iOS interaction patterns

**Should have (competitive differentiators):**
- Dark/minimal CSS theme overlay — unique competitive position; no competitor does this well
- Per-platform block settings UI — user control over exactly what to hide
- Explore/Discover feed blocking — algorithmic feeds are a major distraction vector beyond Reels/Shorts
- Usage time tracking (per platform) — users want behavioral feedback
- Session time nudges — gentle reminders after X minutes of continuous use
- Share sheet integration — natural content sharing without leaving the app

**Defer (Phase 3+):**
- Feed algorithm replacement (following-only mode) — HIGH complexity, fragile DOM surgery
- Scroll detection and intervention — HIGH complexity, ScrollGuard's premium feature
- Comments section blocking — medium complexity, lower priority
- Additional platform support (Facebook, Reddit)

**Do not build:** Push notifications, multi-account, gamification, backend/cloud sync, TikTok support, AI filtering, subscription pricing at launch.

### Architecture Approach

The architecture follows a clean separation between the SwiftUI shell, the UIViewRepresentable WKWebView wrapper, and a dedicated InjectionEngine that loads platform-specific scripts from bundle resources. Per-platform behavior is driven by a declarative `PlatformConfig` struct — adding a new platform should require zero Swift changes, only new config and script files. This extensibility is critical because selectors will break and new platforms may be added. Session isolation between Instagram and YouTube is enforced via `WKWebsiteDataStore(forIdentifier:)` with deterministic UUIDs derived from platform IDs.

**Major components:**
1. **ZenSocialApp + MainTabView** — SwiftUI entry point and `TabView` for platform switching
2. **PlatformWebView** — `UIViewRepresentable` wrapper owning `WKWebViewConfiguration`, navigation delegate, and injection setup
3. **InjectionEngine** — loads CSS/JS from bundle, compiles `WKUserScript` objects, applies two-layer blocking (content rules + DOM injection)
4. **PlatformConfig / PlatformRegistry** — declarative data model defining per-platform URLs, selectors, scripts, and theme overrides
5. **ScriptLoader + MutationWatcher** — reads bundle files, generates persistent MutationObserver JS that survives SPA navigation
6. **ContentRuleCompiler** — builds `WKContentRuleList` JSON from `PlatformConfig` selectors, compiled once and cached

The two-layer blocking strategy (WKContentRuleList for network-level + WKUserScript CSS/MutationObserver for DOM-level) is defense-in-depth: content rules prevent assets from loading at all; DOM injection catches everything client-side rendering adds afterward. Both are needed because Instagram and YouTube are heavy SPAs.

### Critical Pitfalls

1. **App Store 4.2 rejection (minimum functionality)** — Build the native shell first: branded splash, native tab bar, custom offline screens, at least one device capability (e.g., Face ID app lock or local notifications). Test before submission: "If I opened this in Safari, would it look the same?" If yes, you will be rejected.

2. **App Store 5.2.2 rejection (third-party content)** — Do not use Instagram or YouTube logos, trademarks, or brand colors anywhere. Do not name the app in a way that implies affiliation. Frame the App Store description around "focused browser with content preferences," not "alternative Instagram/YouTube client." Study how content blocker apps (1Blocker, AdGuard) frame their presence.

3. **Platform detection and blocking** — Instagram aggressively detects non-Safari webviews and shows "Open in App" banners or blocks login. Spoof a complete mobile Safari user agent string via `WKWebView.customUserAgent`. Inject JS to dismiss "Open in App" overlays. Test login flow monthly; if login starts failing, the platform updated detection.

4. **DOM selector breakage on platform updates** — Instagram and YouTube deploy frontend changes daily-to-weekly. Never target CSS class names (hashed/obfuscated, change constantly). Use `aria-label` attributes, `href` patterns (`a[href*="/reels/"]`), and structural selectors. Maintain selectors in external bundle files, not in Swift code. Build a selector health-check on launch to detect silent breakage. Remote config (GitHub-hosted JSON) is the long-term solution for over-the-air selector updates.

5. **SPA navigation breaking injection** — Instagram and YouTube use `history.pushState()` for navigation, which does not trigger `WKUserScript` re-injection. MutationObserver in the injected script and persistent CSS `<style>` tags are the solution — CSS rules survive SPA navigations automatically; JS blocking must be re-applied via MutationObserver, not one-shot injection.

## Implications for Roadmap

Based on the combined research, the architecture file's suggested build order is well-reasoned and aligns with both the feature critical path and the pitfall priority matrix. The following phase structure is recommended:

### Phase 1: Native Shell + WKWebView Foundation

**Rationale:** App Store compliance depends entirely on the native shell feeling like a real app, not a browser wrapper. This must be built first — not deferred as polish. Cookie/session persistence and video playback configuration must be set at WKWebView initialization time and cannot be retrofitted cleanly.

**Delivers:** A working app that loads Instagram and YouTube in separate tabs with persistent login, native navigation, branded offline screens, and correct WKWebView configuration. Passes the "would this look the same in Safari?" test.

**Addresses:** WKWebView rendering, native tab bar, persistent login sessions, loading states, video playback, back/forward navigation, basic onboarding.

**Avoids:** Guideline 4.2 rejection (native shell built first), Guideline 5.2.2 (branding and naming designed correctly), platform detection/blocking (user-agent spoofing), cookie/session loss, video freeze, memory/white screen architecture decision (single vs. dual WKWebView), deep link interception, keyboard/input issues.

**Research flag:** Standard patterns. WKWebView configuration and UIViewRepresentable patterns are well-documented. No research phase needed.

### Phase 2: Injection Engine + Dark Theme

**Rationale:** Theme injection proves the end-to-end injection pipeline works (ScriptLoader → WKUserScript compilation → WKWebView) before adding feature-blocking complexity on top of it. Architecture of the injection system is the highest-leverage design decision — if selectors are hardcoded in Swift, every DOM change requires an App Store resubmission.

**Delivers:** Dark/minimal theme applied to both platforms. Injection infrastructure (ScriptLoader, CSS injector template, MutationObserver setup) that all subsequent blocking features build on. Bundle-based script organization in place.

**Addresses:** Dark/minimal CSS theme overlay (key differentiator), injection engine architecture with externalized selectors, MutationObserver for SPA navigation survival.

**Avoids:** DOM selector breakage (externalized selector config from day one), SPA navigation breaking injection (MutationObserver built into the engine), CSP blocking (WKUserScript privileged execution, no dynamic script element creation), viewport/layout breakage from CSS overrides.

**Research flag:** Standard patterns. CSS injection via WKUserScript is well-documented. MutationObserver is a standard Web API. No research phase needed.

### Phase 3: Feature Blocking (Reels + Shorts)

**Rationale:** Feature blocking flows through the injection engine built in Phase 2. The two-layer strategy (WKContentRuleList network-level + CSS/JS DOM-level) is architecturally established; Phase 3 adds the platform-specific selector sets that populate it. This is the core user-facing value proposition.

**Delivers:** Instagram Reels tab and content hidden. YouTube Shorts tab and shelf hidden. WKContentRuleList compiled and attached. Selector health-check system on launch.

**Addresses:** Block Instagram Reels, block YouTube Shorts, Explore/Discover feed blocking (optionally in Phase 3 or 4).

**Avoids:** DOM selector breakage (selector health-check built here), SPA navigation issues (inherited from Phase 2 injection system).

**Research flag:** Low uncertainty. The selector identification for Reels/Shorts is well-documented. Platform-specific CSS selectors will need hands-on testing during implementation, but the patterns are clear.

### Phase 4: Settings + Per-Platform Controls

**Rationale:** Settings UI requires the blocking infrastructure to exist first — settings toggle things that must already work. This is the first phase where third-party user-facing control is introduced, raising the app's completeness for App Store review and user retention.

**Delivers:** Settings screen with per-platform toggles for each block type. `@AppStorage`-backed preferences wired to injection engine. Native SwiftUI settings UI with `NavigationStack`.

**Addresses:** Per-platform block settings, Explore/Discover feed blocking toggle (if not in Phase 3).

**Avoids:** No new pitfalls introduced; inherits all Phase 1-3 mitigations.

**Research flag:** Standard patterns. SwiftUI settings screens and `@AppStorage` are well-documented. No research phase needed.

### Phase 5: Usage Tracking + Wellbeing Features

**Rationale:** Tracking requires knowing which platform is active (requires Phase 1 tab bar) and a stable injection/blocking system (Phases 2-3). Nudges depend on tracking data. These are Phase 2 candidates from the feature research — high-value differentiators but not launch blockers.

**Delivers:** Per-platform time tracking, daily/weekly usage stats display, session time nudges (timer-based local notifications or in-app alerts), share sheet integration.

**Addresses:** Usage time tracking, session nudges, share sheet integration.

**Avoids:** Gamification anti-pattern (show stats without streaks/leaderboards), push notification anti-pattern (use local notifications triggered by user-set timers, not platform push).

**Research flag:** Low uncertainty for time tracking and nudges. Share sheet is a standard iOS API. No research phase needed.

### Phase Ordering Rationale

- Phase 1 before everything because WKWebView configuration is immutable after initialization, App Store compliance cannot be retrofitted, and session persistence is foundational — nothing else matters if users get logged out.
- Phase 2 before Phase 3 because the injection pipeline is shared infrastructure; proving it with theme CSS (visible, low-stakes) before trusting it with feature blocking prevents debugging two systems at once.
- Phase 3 delivers the core user value proposition; Phases 4 and 5 layer control and wellbeing features on a verified foundation.
- The declarative `PlatformConfig` pattern (Phase 1) ensures every subsequent phase adds features by extending config, not rewriting Swift architecture.

### Research Flags

Phases with standard, well-documented patterns — skip research phase:
- **Phase 1:** WKWebView + UIViewRepresentable is a 10-year-old pattern with extensive Apple documentation
- **Phase 2:** CSS injection via WKUserScript and MutationObserver are thoroughly documented
- **Phase 4:** SwiftUI settings UI and `@AppStorage` are standard Apple patterns
- **Phase 5:** Time tracking via tab observation and local notifications are standard iOS APIs

Phases that may need targeted investigation during implementation (not a full research phase, but hands-on selector testing):
- **Phase 3:** Instagram and YouTube DOM selectors for Reels/Shorts need live validation in Safari Web Inspector. Selectors found in research may already be stale. Plan for selector discovery time, not just implementation time.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations backed by Apple official docs and WWDC 2025 session. iOS 26 WebView limitation confirmed by multiple sources. No ambiguity in technology choice. |
| Features | HIGH | Competitive landscape well-researched with named competitors. Feature table stakes and anti-features have clear rationale. MVP scope is opinionated and defensible. |
| Architecture | HIGH | Patterns are battle-tested WKWebView patterns documented across multiple Apple Developer Forum threads, WWDC sessions, and third-party guides. The declarative config pattern is standard practice. |
| Pitfalls | HIGH | App Store rejection risks verified against official guidelines. DOM breakage, session loss, and SPA navigation pitfalls have extensive prior art in webview app development. |

**Overall confidence: HIGH**

### Gaps to Address

- **Exact CSS selectors for Reels/Shorts:** Research identifies the strategy (`aria-label`, `href` patterns) but specific working selectors must be discovered and validated during Phase 3 implementation using Safari Web Inspector on live platforms. Budget time for this — selectors may have already changed since research was completed.

- **"Open in App" banner dismissal selectors:** Instagram's interstitial detection countermeasures require specific DOM targeting that will need live testing. The user-agent spoofing strategy is confirmed but the specific banner dismissal selectors are not provided in research.

- **WKWebsiteDataStore UUID collision:** The deterministic UUID strategy for session isolation uses SHA-256-derived bytes. The specific implementation should be validated — the iOS API requires a valid `UUID` format and the byte manipulation must be verified correct at implementation time.

- **App Store submission framing:** Research strongly recommends framing the app as a "focused browser with content preferences" rather than an alternative client. The exact App Store description language needs careful drafting; consider pre-submission review note strategy before first submission.

- **Remote config for selectors:** The research recommends a GitHub-hosted JSON for over-the-air selector updates to avoid App Store review cycles. This is deferred past MVP but the selector data structure should be designed to support it from Phase 3 onward.

## Sources

### Primary (HIGH confidence)
- [Apple Developer: WKUserContentController](https://developer.apple.com/documentation/webkit/wkusercontentcontroller) — injection API
- [Apple Developer: WKContentRuleListStore](https://developer.apple.com/documentation/webkit/wkcontentruleliststore) — content blocking API
- [Apple Developer: WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore) — session isolation API
- [WWDC 2025: Meet WebKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2025/231/) — iOS 26 WebView/WebPage limitations confirmed
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — Guidelines 4.2, 5.2.2, 5.2.3, 2.5.6
- [Apple Developer Forums: WKWebView and Instagram](https://developer.apple.com/forums/thread/670042) — platform detection behavior
- [Apple Developer Forums: WKWebView cookie loss](https://developer.apple.com/forums/thread/745912) — session persistence

### Secondary (MEDIUM confidence)
- [AppCoda: Exploring WebView and WebPage in SwiftUI for iOS 26](https://www.appcoda.com/swiftui-webview/) — iOS 26 WebView practical guide
- [Swift Senpai: JavaScript Injection in WKWebView](https://swiftsenpai.com/development/web-view-javascript-injection/) — injection patterns and timing
- [WebApp2App: Avoiding CSS Injection Delays](https://www.webapp2app.com/2023/01/06/avoiding-css-injection-delays-in-wkwebview-ios-swift-apps/) — FOUC prevention
- [MobiLoud: App Store Review Guidelines for Webview Wrappers](https://www.mobiloud.com/blog/app-store-review-guidelines-webview-wrapper) — Guideline 4.2 rejection patterns
- [Embrace: Why Is WKWebView So Heavy](https://embrace.io/blog/wkwebview-memory-leaks/) — memory pressure documentation
- [Capital One: JavaScript Manipulation on iOS Using WebKit](https://www.capitalone.com/tech/software-engineering/javascript-manipulation-on-ios-using-webkit/) — injection architecture patterns
- [ScrollGuard](https://scrollguard.app/) — direct competitor, web-wrapper approach
- [One Sec](https://one-sec.app/) — behavioral intervention competitor

### Tertiary (LOW confidence)
- [React Native WebView: Instagram Video Issues](https://github.com/react-native-webview/react-native-webview/issues/3796) — video playback behavior (cross-platform but informative)
- [Medium: Injecting CSS and JavaScript in WKWebView](https://medium.com/@mahdi.mahjoobi/injection-css-and-javascript-in-wkwebview-eabf58e5c54e) — implementation examples

---
*Research completed: 2026-03-24*
*Ready for roadmap: yes*
