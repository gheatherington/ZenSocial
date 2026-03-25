# Domain Pitfalls

**Domain:** iOS WKWebView social media wrapper (Instagram + YouTube)
**Researched:** 2026-03-24

## Critical Pitfalls

Mistakes that cause App Store rejection, complete feature breakage, or project-level rewrites.

### Pitfall 1: App Store Rejection Under Guideline 4.2 (Minimum Functionality)

**What goes wrong:** Apple rejects the app because it looks like a "lazy wrapper" -- a WKWebView that loads instagram.com and youtube.com with no meaningful native layer. Reviewers specifically check for: browser-like loading bars, no native navigation, web-based hamburger menus, standard browser error pages on offline, and no use of device capabilities.

**Why it happens:** Developers focus on getting the webview content working and the CSS/JS injection right, treating native integration as polish to add later. Apple sees the app at review time, not after planned improvements.

**Consequences:** Rejected at App Store review. Repeated rejections can delay approval by weeks as each resubmission goes to the back of the queue. The app literally cannot ship.

**Prevention:**
- Build the native shell FIRST: native tab bar, native navigation headers, branded splash screen, custom offline error screens with retry buttons.
- Integrate at least one device capability: biometric login (Face ID/Touch ID) for locking the app, or push notifications (even local ones for usage reminders, since you won't have platform push access).
- Never show a browser-style loading bar. Use a native spinner or skeleton screen.
- In the App Review notes, explicitly describe the value proposition: "This app blocks addictive short-form video features from social media platforms, providing a healthier browsing experience not possible in Safari."

**Detection:** Before submission, ask: "If I opened this in Safari, would it look the same?" If yes, you will be rejected.

**Phase relevance:** Phase 1 -- the native shell must be built app-like from day one. Do not defer native navigation or offline handling.

**Confidence:** HIGH -- Guideline 4.2 is the single most common rejection reason for webview apps, per Apple Developer Forums and multiple third-party guides.

**Sources:**
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- Guideline 4.2
- [MobiLoud: Will Your Webview App Be Rejected?](https://www.mobiloud.com/blog/app-store-review-guidelines-webview-wrapper)
- [Fix Apple Guideline 4.2 Rejection](https://shopapper.com/fix-apple-guideline-4-2-rejection-minimum-functionality-explained/)

---

### Pitfall 2: App Store Rejection Under Guideline 5.2.2 (Third-Party Content Without Authorization)

**What goes wrong:** Apple rejects the app because it "uses, accesses, monetizes access to, or displays content from a third-party service" without explicit permission. Guideline 5.2.2 requires that you are "specifically permitted to do so under the service's terms of use." Instagram's and YouTube's Terms of Service prohibit automated access, scraping, and unauthorized modification of their services.

**Why it happens:** Developers assume that loading a public website in a webview is legally equivalent to visiting it in Safari. It is not -- wrapping it in an app and modifying it via injection is a different legal and policy question.

**Consequences:** Rejection, or worse -- approval followed by takedown after Instagram/YouTube/Google files a complaint. Potential legal exposure under the services' Terms of Use.

**Prevention:**
- Frame the app as a "browser with content preferences" rather than an "Instagram/YouTube client." The app loads URLs the user navigates to; it does not claim to be an alternative client.
- Do NOT use Instagram or YouTube logos, trademarks, or brand colors in the app icon, splash screen, or marketing materials.
- Do NOT name the app anything that implies affiliation (no "InstaZen" or "YTClean").
- Consider positioning the CSS/JS injection as user-controlled content preferences (like a content blocker / ad blocker), not as a core app feature in App Store description.
- Study how content blocker apps (1Blocker, AdGuard) frame their App Store presence -- they block content on third-party sites without claiming authorization.
- Be prepared to pivot: if Apple asks for authorization letters from Meta/Google, you will not get them. Have a backup framing strategy ready.

**Detection:** Before submission, read your App Store description. Does it mention Instagram or YouTube by name? If yes, you are inviting scrutiny.

**Phase relevance:** Phase 1 -- app naming, branding, and App Store metadata must be designed with this constraint from the start.

**Confidence:** HIGH -- Guideline 5.2.2 is explicit. Guideline 5.2.3 specifically calls out YouTube by name regarding content access. This is a real and significant risk.

**Sources:**
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- Guidelines 5.2.2, 5.2.3

---

### Pitfall 3: Instagram/YouTube Detecting and Blocking Webview Access

**What goes wrong:** Instagram or YouTube detects that the request is coming from a WKWebView (not Safari or their native app) and degrades the experience: showing interstitial banners urging users to "Open in App," blocking login, serving CAPTCHAs, or redirecting to app download pages. Instagram is particularly aggressive about this on mobile web.

**Why it happens:** These platforms want users in their native apps where they have full tracking, notification, and engagement capabilities. They actively detect non-Safari webviews via user-agent string analysis, JavaScript environment fingerprinting, and cookie behavior.

**Consequences:** Users cannot log in, see constant "Open in App" banners covering content, hit rate limiting, or get logged out repeatedly. The app becomes unusable.

**Prevention:**
- Set a custom user-agent string that mimics mobile Safari exactly. WKWebView defaults to including "Mobile/" but may differ from Safari in subtle ways. Use `WKWebView.customUserAgent` to set the full Safari UA string for the current iOS version.
- Inject JavaScript on page load to dismiss/hide "Open in App" banners and interstitial overlays. These are part of the DOM and can be targeted.
- Use a single persistent `WKProcessPool` across all webviews to maintain consistent session identity.
- Monitor for new detection techniques -- platforms update their detection regularly.
- Do NOT include "WKWebView" or app-specific identifiers in the user-agent string.

**Detection:** Test login flow monthly. If login starts failing or interstitials appear that were not there before, the platform has updated detection.

**Phase relevance:** Phase 1 (user-agent spoofing) and ongoing maintenance. Build a test harness that verifies login + basic browsing weekly.

**Confidence:** HIGH -- Instagram mobile web is well-documented as aggressively pushing users to the native app. Multiple developer forum posts confirm webview detection issues.

**Sources:**
- [Apple Developer Forums: WKWebView and Instagram](https://developer.apple.com/forums/thread/670042)
- [React Native WebView: Instagram login issues](https://github.com/react-native-webview/react-native-webview/issues/3637)

---

### Pitfall 4: DOM Structure Changes Breaking CSS/JS Injection

**What goes wrong:** Instagram or YouTube ships a frontend update that changes class names, element IDs, DOM hierarchy, or component structure. Your CSS selectors and JavaScript queries that target specific elements (Reels tab, Shorts shelf, etc.) silently stop working. Users see the features you promised to block.

**Why it happens:** Both platforms use build-time generated class names (obfuscated/hashed CSS classes like `._aagw` or `x1lliihq`) that change with every frontend deploy. YouTube uses Polymer/Lit web components with shadow DOM. Instagram uses React with dynamically generated class names. Neither platform guarantees DOM stability -- it is explicitly not a public API.

**Consequences:** Feature blocking stops working silently. Users lose trust. You are in a perpetual maintenance race against two of the largest engineering teams in the world.

**Prevention:**
- NEVER rely on class names. Use structural selectors: `nav > div:nth-child(N)`, `a[href*="/reels/"]`, `[data-testid="..."]`, or element hierarchy patterns.
- Use `aria-label` attributes where available -- these are more stable because they are tied to accessibility requirements and localization strings.
- Target `href` patterns (e.g., links containing "/reels/", "/shorts/") which are URL-structure-dependent and change less frequently than CSS classes.
- Build a "selector health check" system: on each app launch (or periodically), run a diagnostic that verifies expected elements exist. If selectors fail to match, log it and alert (via analytics or local notification).
- Maintain selectors in a separate, easily-updatable configuration (JSON or plist) rather than hardcoded in Swift. Consider remote configuration (even a simple GitHub-hosted JSON) so you can push selector updates without an App Store review cycle.
- Layer multiple selector strategies: try `aria-label` first, fall back to `href` pattern, fall back to structural position.

**Detection:** Automated selector health checks on launch. If fewer than expected elements are found/hidden, flag it. Monitor Instagram and YouTube engineering blogs and release notes for frontend architecture changes.

**Phase relevance:** Phase 2 (injection system design). The architecture of the injection system determines how painful updates are. Get the abstraction right early.

**Confidence:** HIGH -- this is the single most certain ongoing maintenance burden. Instagram and YouTube deploy frontend changes weekly to daily.

**Sources:**
- [Rebrowser: CSS Selector Cheat Sheet for Scraping](https://rebrowser.net/blog/css-selector-cheat-sheet-for-web-scraping-a-complete-guide)
- [Medium: Dynamic CSS Selector Generation for Resilient Scraping](https://medium.com/@yukselcosgun/smart-site-detection-and-dynamic-css-selector-generation-for-resilient-scraping-ba8a5ba6ce26)

---

## Moderate Pitfalls

### Pitfall 5: WKWebView Cookie and Session Loss

**What goes wrong:** Users get logged out of Instagram or YouTube unexpectedly. After backgrounding the app for an extended period (1+ hours), resuming shows a logged-out state. Cookies silently disappear, requiring re-login.

**Why it happens:** WKWebView runs in a separate process from the app. Cookies stored in `WKHTTPCookieStore` are not synchronized with `HTTPCookieStorage`. When the WebContent process is terminated by iOS (memory pressure, long background), cookies can be lost. There is also a race condition: `WKHTTPCookieStore` operations are asynchronous, so checking cookies immediately after app launch may show empty results before the async load completes.

**Prevention:**
- Use a single `WKProcessPool` shared across all webviews in the app. This prevents cookie isolation between webview instances.
- Use a non-ephemeral `WKWebsiteDataStore` (the default) to persist cookies to disk.
- On `applicationWillResignActive`, snapshot cookies from `WKHTTPCookieStore` and back them up to `UserDefaults` or Keychain.
- On `applicationDidBecomeActive`, check if cookies are present. If not, restore from backup before loading any URL.
- Delay initial URL load until `WKHTTPCookieStore.getAllCookies()` returns -- do not race the async cookie loading.
- Handle `webViewWebContentProcessDidTerminate` delegate callback to reload the page (this fires when the WebContent process crashes due to memory).

**Detection:** Users reporting "I keep getting logged out." Test by backgrounding the app for 2+ hours, then resuming.

**Phase relevance:** Phase 1 -- session persistence is foundational. If users cannot stay logged in, nothing else matters.

**Confidence:** HIGH -- extensively documented in Apple Developer Forums and multiple GitHub issues across webview frameworks.

**Sources:**
- [Apple Developer Forums: WKWebView loses cookies](https://developer.apple.com/forums/thread/745912)
- [Brave Location: Fixed WKWebView session cookies issue](https://bravelocation.com/Fixed-issue-with-WkWebViews-session-cookies)
- [Medium: Synchronization of native and WebView sessions](https://medium.com/axel-springer-tech/synchronization-of-native-and-webview-sessions-with-ios-9fe2199b44c9)

---

### Pitfall 6: Video Playback Issues in WKWebView

**What goes wrong:** Instagram videos freeze on the first frame. YouTube videos force fullscreen playback. Audio continues but video is black. Exiting fullscreen pauses/kills the video. Autoplay does not work.

**Why it happens:** WKWebView defaults to `allowsInlineMediaPlayback = false` on iPhone, forcing all video into a native fullscreen controller. Instagram video embeds are particularly problematic -- the video stream starts (HTTP 206 Partial Content) but WKWebView's player halts it. YouTube's player has its own fullscreen logic that conflicts with WKWebView's native fullscreen.

**Prevention:**
- Set `WKWebViewConfiguration`:
  ```swift
  config.allowsInlineMediaPlayback = true
  config.mediaTypesRequiringUserActionForPlayback = []  // or .audio only
  ```
- These must be set BEFORE creating the WKWebView -- they cannot be changed after initialization.
- Test video playback for both platforms on actual devices (simulator video behavior differs from real hardware).
- Instagram Stories and video posts may still have issues even with correct configuration -- inject CSS to ensure video containers have proper dimensions and are not clipped.

**Detection:** Test video playback on both platforms after every iOS update. Video behavior changes are common in WebKit updates.

**Phase relevance:** Phase 1 -- WKWebView configuration is set at initialization and affects all subsequent behavior.

**Confidence:** HIGH -- multiple documented issues in react-native-webview and Apple Developer Forums.

**Sources:**
- [React Native WebView: Instagram Video Embeds Freeze](https://github.com/react-native-webview/react-native-webview/issues/3796)
- [Thomas Visser: Autoplaying video in WKWebView](https://www.thomasvisser.me/2018/06/26/wkwebview-media/)

---

### Pitfall 7: WKWebView Memory Pressure and White Screens

**What goes wrong:** The webview goes white/blank. Content disappears. The app feels frozen. On older devices, this happens frequently when switching between Instagram and YouTube tabs.

**Why it happens:** WKWebView's WebContent process runs out-of-process and can be killed by iOS when memory is tight. Each WKWebView instance is very heavy (100-200MB+ for content-rich sites like Instagram/YouTube). Running two simultaneously (one per platform tab) doubles memory pressure. When the WebContent process is killed, the webview shows a blank white screen.

**Prevention:**
- Reuse a single WKWebView instance and swap URLs when switching between platforms, rather than maintaining two separate WKWebViews. This halves memory usage.
- If using two webviews (for preserving scroll position), implement lazy loading: only keep the visible webview's content process active; reload the other when switching to it.
- Implement `webViewWebContentProcessDidTerminate(_:)` delegate method to detect crashes and auto-reload.
- Show a branded "Reloading..." screen during recovery instead of a blank white screen.
- Test on the oldest supported device (e.g., iPhone SE 2nd gen) where memory limits are tightest.

**Detection:** White screen reports from users, especially on older devices. Memory profiling in Instruments showing 300MB+ app memory.

**Phase relevance:** Phase 1 -- architecture decision (one webview vs. two) must account for memory from the start.

**Confidence:** HIGH -- well-documented WKWebView behavior.

**Sources:**
- [Embrace: Why Is WKWebView So Heavy](https://embrace.io/blog/wkwebview-memory-leaks/)
- [NeverMeant: Handling Blank WKWebViews](https://nevermeant.dev/handling-blank-wkwebviews/)

---

### Pitfall 8: Content Security Policy Blocking Injected Scripts

**What goes wrong:** Your injected JavaScript silently fails to execute. CSS injection works but JS does nothing. No errors visible to the user -- features just are not blocked.

**Why it happens:** Instagram and YouTube set Content-Security-Policy headers that restrict script execution. While `WKUserScript` injection via `WKUserContentController` typically bypasses page-level CSP (because it runs in the WebKit layer, not as inline script), certain operations your JS tries to perform (like `fetch()` calls or dynamic script creation) may still be blocked by CSP.

**Prevention:**
- Use `WKUserScript` with `injectionTime: .atDocumentEnd` and `forMainFrameOnly: true` for your injection scripts -- these execute in WKWebView's privileged context, bypassing most CSP restrictions.
- Use `WKContentWorld.page` to run in the same world as the page's own scripts (needed to interact with page objects) or `.defaultClient` for isolation.
- Avoid creating `<script>` elements dynamically from injected code -- this IS subject to CSP. Instead, do all work directly in your `WKUserScript`.
- Test injection after every iOS update -- WebKit's CSP enforcement behavior has changed across versions.
- Use `MutationObserver` in your injected script to handle dynamically loaded content (SPAs like Instagram load content after initial page load).

**Detection:** Elements you expect to be hidden remain visible. Add logging to your injection scripts that reports success/failure back to the native layer via `WKScriptMessageHandler`.

**Phase relevance:** Phase 2 -- injection system architecture.

**Confidence:** MEDIUM -- WKUserScript generally bypasses CSP, but edge cases exist and behavior can change with iOS updates.

---

### Pitfall 9: Single Page Application Navigation Breaking Injection

**What goes wrong:** CSS/JS injection works on initial page load but stops working when the user navigates within Instagram or YouTube. New content appears unblocked. The Reels tab reappears after navigating to a profile and back.

**Why it happens:** Instagram and YouTube are Single Page Applications (SPAs). Navigation happens via JavaScript `history.pushState()` / `replaceState()` without triggering a full page load. `WKUserScript` with `injectionTime: .atDocumentStart` or `.atDocumentEnd` only fires on full page loads, not SPA navigations.

**Prevention:**
- Use `MutationObserver` in your injected script to watch for DOM changes continuously, not just at page load:
  ```javascript
  const observer = new MutationObserver((mutations) => {
    // Re-apply hiding rules whenever DOM changes
    applyBlockingRules();
  });
  observer.observe(document.body, { childList: true, subtree: true });
  ```
- Also use CSS injection (via `WKUserScript` adding a `<style>` element) for hiding rules where possible -- CSS rules persist across SPA navigations without needing re-injection. CSS `display: none !important` on selector-matched elements works continuously.
- Listen for URL changes via the `WKNavigationDelegate` methods AND by polling `window.location` from injected JS (SPA navigations may not trigger delegate callbacks).
- Prefer CSS over JS for hiding elements. CSS rules applied via a persistent `<style>` tag survive SPA navigations. JS-based hiding needs to be re-applied.

**Detection:** Navigate around within each platform and verify blocking persists. Specifically: go to profile, back to feed, into a post, back -- check if blocked elements reappear at each step.

**Phase relevance:** Phase 2 -- this is a core architectural requirement for the injection system.

**Confidence:** HIGH -- fundamental behavior of SPAs. Instagram and YouTube are both confirmed SPAs.

---

## Minor Pitfalls

### Pitfall 10: Deep Link and Universal Link Interception

**What goes wrong:** Tapping a link within Instagram's webview (e.g., a link to an external site, or a link that should open YouTube) causes iOS to open the Instagram native app instead of navigating within your webview. Or YouTube links try to open the YouTube native app.

**Prevention:**
- Implement `WKNavigationDelegate.decidePolicyFor` to intercept navigation actions. For URLs that would open Instagram/YouTube native apps, cancel the navigation and load the URL in your own webview instead.
- Handle `LSApplicationQueriesSchemes` and Universal Link domains carefully.
- Consider whether the user even has the native Instagram/YouTube apps installed -- if they do, iOS will aggressively try to open Universal Links in those apps.

**Phase relevance:** Phase 1 -- navigation delegate setup.

---

### Pitfall 11: Zoom and Viewport Issues

**What goes wrong:** The webview content appears zoomed in or out incorrectly. Double-tap zoom causes layout issues. The page does not fit the screen width properly.

**Prevention:**
- Inject a viewport meta tag if the page does not set one correctly, or override it:
  ```javascript
  document.querySelector('meta[name=viewport]').content =
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  ```
- Instagram mobile web generally handles viewport correctly, but your CSS injection (especially for theming) can break layout if you override widths or positions.

**Phase relevance:** Phase 2 -- theming/CSS injection.

---

### Pitfall 12: Keyboard and Input Field Issues

**What goes wrong:** Text input fields (search, comments, DMs) behave erratically. The keyboard pushes content incorrectly, overlaps input fields, or the cursor position is wrong after the keyboard appears.

**Prevention:**
- Use `scrollView.contentInsetAdjustmentBehavior = .never` and handle keyboard insets manually via `keyboardWillShow`/`keyboardWillHide` notifications.
- Test every input field in both platforms: search, login, comments, DMs, story replies.
- Instagram's web DM input is particularly finicky in webviews.

**Phase relevance:** Phase 1 -- affects core usability of login and any text interaction.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Native shell setup | Guideline 4.2 rejection | Build native tab bar, offline screens, branded splash from day one |
| App Store submission | Guideline 5.2.2 IP rejection | Avoid platform names in app name; frame as "focused browser," not "alternative client" |
| WKWebView initialization | Video freeze, cookie loss | Set `allowsInlineMediaPlayback`, shared `WKProcessPool`, non-ephemeral data store |
| User-agent configuration | Platform detection/blocking | Spoof full Safari UA string; never include WKWebView identifiers |
| CSS/JS injection system | DOM breakage on platform updates | Use `aria-label`, `href` patterns, structural selectors; never rely on class names |
| SPA navigation handling | Injection stops working on navigate | Use `MutationObserver` + persistent CSS `<style>` tags; avoid one-shot JS-only hiding |
| Multi-platform tabs | Memory pressure / white screens | Reuse single WKWebView or implement lazy loading with crash recovery |
| Ongoing maintenance | Silent selector breakage | Build selector health check system; remote-updatable selector config |
| Theme injection | Layout breakage from CSS overrides | Test theme CSS on both platforms; use specific selectors, avoid global overrides |
| Login flow | Session loss on background | Backup cookies on resign active; restore on become active; handle process termination |

## Risk Priority Matrix

| Pitfall | Likelihood | Impact | Priority |
|---------|-----------|--------|----------|
| App Store 4.2 rejection | HIGH | BLOCKER | P0 -- address in Phase 1 |
| App Store 5.2.2 IP issues | MEDIUM | BLOCKER | P0 -- address in Phase 1 |
| Platform detection/blocking | HIGH | HIGH | P0 -- address in Phase 1 |
| DOM selector breakage | CERTAIN | MEDIUM (ongoing) | P1 -- design for in Phase 2 |
| Cookie/session loss | HIGH | HIGH | P1 -- address in Phase 1 |
| SPA navigation breaking injection | HIGH | HIGH | P1 -- address in Phase 2 |
| Video playback issues | MEDIUM | MEDIUM | P2 -- address in Phase 1 config |
| Memory/white screens | MEDIUM | MEDIUM | P2 -- address in Phase 1 architecture |
| CSP blocking injection | LOW | HIGH | P2 -- verify in Phase 2 |
| Deep link interception | MEDIUM | LOW | P3 -- address in Phase 1 |

## Sources

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [MobiLoud: App Store Review Guidelines for Webview Wrappers](https://www.mobiloud.com/blog/app-store-review-guidelines-webview-wrapper)
- [Apple Developer Forums: WKWebView cookie loss](https://developer.apple.com/forums/thread/745912)
- [Embrace: WKWebView Memory Leaks](https://embrace.io/blog/wkwebview-memory-leaks/)
- [React Native WebView: Instagram Video Issues](https://github.com/react-native-webview/react-native-webview/issues/3796)
- [Rebrowser: CSS Selector Cheat Sheet for Scraping](https://rebrowser.net/blog/css-selector-cheat-sheet-for-web-scraping-a-complete-guide)
- [Medium: Synchronization of Native and WebView Sessions](https://medium.com/axel-springer-tech/synchronization-of-native-and-webview-sessions-with-ios-9fe2199b44c9)
- [NeverMeant: Handling Blank WKWebViews](https://nevermeant.dev/handling-blank-wkwebviews/)
