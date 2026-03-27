# Phase 2: Injection Engine + Dark Theme - Research

**Researched:** 2026-03-27
**Domain:** WKWebView CSS/JS injection, Instagram/YouTube web theming
**Confidence:** HIGH

## Summary

Phase 2 builds ZenSocial's CSS injection pipeline on top of the Phase 1 WKWebView foundation. The core technical challenge is injecting CSS dark theme overrides into Instagram and YouTube's web content early enough to prevent any flash of unstyled content (FOUC), while keeping scripts externalized in bundle files for maintainability.

The injection mechanism is well-understood: `WKUserScript` with `atDocumentStart` injection time fires after the document element (`<html>`) is created but before the `<head>` or `<body>` exist. CSS must therefore be injected via JavaScript that appends a `<style>` element to `document.documentElement` (not `document.head`, which is null at that point). Both Instagram and YouTube use CSS custom properties extensively for theming, making variable overrides the primary mechanism, supplemented by direct `!important` overrides for elements that don't respond to variables.

The `WKUserContentController` is already wired in `WebViewConfiguration.make(for:)` (Phase 1, line 33). Scripts added to this controller persist across SPA navigations automatically -- no re-injection is needed when navigating between feed, profile, and settings within a platform.

**Primary recommendation:** Build a thin `ScriptLoader` service that reads `.css` files from `Scripts/{Platform}/` bundle directories, wraps them in a JavaScript injection IIFE, and returns `WKUserScript` objects. Add these scripts in `WebViewConfiguration.make(for:)` before the config is returned.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Theme targets structural elements -- backgrounds, navigation bars, toolbars, text color -- plus ZenSocial brand accents (#4DA6FF / `zenAccent`) applied to interactive elements (links, active states, focus rings, selected indicators).
- **D-02:** Individual content (photos, video thumbnails, post cards) is NOT re-themed. Only the platform "chrome" is darkened.
- **D-03:** This is v1 scope. Color theme system (user-selectable themes) is explicitly deferred to a future phase.
- **D-04:** Dark theme is always forced -- ZenSocial enforces dark regardless of the user's system dark/light mode setting. `prefers-color-scheme` is ignored.
- **D-05:** ZenSocial's accent layer is always injected on top of the platform's own styling.
- **D-06:** Hybrid approach -- CSS variable overrides first (`:root {}` block targeting platform CSS custom properties), then targeted direct property overrides with `!important` for elements that don't respond to variable overrides.
- **D-07:** Instagram and YouTube each get their own CSS file. Claude's discretion on exact file naming within `Scripts/Instagram/` and `Scripts/YouTube/` bundle directories.
- **D-08:** Injection timing is `atDocumentStart` for CSS to prevent FOUC.
- **D-09:** Debug builds: `assertionFailure` when a script bundle file cannot be loaded.
- **D-10:** Release builds: Skip injection for the failed script, log via `os_log`. Show in-app alert with "Report Issue" button opening share sheet with diagnostic info.
- **D-11:** Phase 2 injection scripts MUST NOT interfere with Instagram's service worker, PWA manifest, or web push APIs.

### Claude's Discretion
- Exact CSS file names within the bundle directories
- Which specific CSS variables each platform exposes (research at implementation time -- they change)
- Specificity strategy for `!important` overrides (use judiciously, only where variables don't work)
- Whether a thin Swift `ScriptLoader` service is warranted or inline loading in `WebViewConfiguration` is sufficient
- `os_log` subsystem/category naming conventions

### Deferred Ideas (OUT OF SCOPE)
- **Color theme system** -- User-selectable color themes beyond dark (e.g., OLED black, sepia, custom). Explicitly out of scope for v1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INJ-01 | CSS/JS injection system executes platform-specific scripts at page load for Instagram and YouTube | WKUserScript + WKUserContentController pattern documented; ScriptLoader architecture; atDocumentStart timing; forMainFrameOnly:false for iframe coverage |
| INJ-02 | ZenSocial's dark/minimal theme is applied to Instagram via CSS injection | Instagram CSS variable system documented (--fds-*, __ig-dark-mode class); hybrid override strategy; color palette from UI-SPEC |
| INJ-03 | ZenSocial's dark/minimal theme is applied to YouTube via CSS injection | YouTube CSS variable system documented (--yt-spec-*); hybrid override strategy; m.youtube.com mobile web targeting |
| INJ-04 | Injection scripts are stored as externalized bundle files (not hardcoded strings) for maintainability | Bundle.main.url(forResource:withExtension:subdirectory:) pattern; Scripts/ directory structure; ScriptLoader service |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WebKit (WKUserScript) | iOS 17+ built-in | CSS/JS injection into WKWebView | Apple's first-party API for user script injection. No alternative exists for WKWebView. |
| WebKit (WKUserContentController) | iOS 17+ built-in | Script management and registration | Manages WKUserScript lifecycle. Already instantiated in Phase 1 at WebViewConfiguration.swift:33. |
| os (OSLog / Logger) | iOS 17+ built-in | Structured logging for script load failures | Apple's modern logging framework. Replaces NSLog. Supports subsystems and categories for filtering. |
| Foundation (Bundle) | iOS 17+ built-in | Loading .css files from app bundle | Standard mechanism for reading bundled resources at runtime. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI (.alert) | iOS 17+ built-in | Error alert for script load failures (D-10) | Release build only -- presents "Theme failed to load" alert with Report/Dismiss actions |
| UIKit (UIActivityViewController) | iOS 17+ built-in | Share sheet for error reporting (D-10) | When user taps "Report Issue" in the failure alert |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WKUserScript | evaluateJavaScript() at didFinish | Would cause FOUC -- CSS applied after render. WKUserScript at atDocumentStart is the only FOUC-free path. |
| os.Logger | print() / NSLog | No structured logging, no subsystem filtering, no privacy annotations. Logger is the correct tool. |
| Bundle file loading | Hardcoded Swift strings | Violates INJ-04. Harder to maintain when selectors change. Bundle files are independently editable. |

**Installation:**
```bash
# No external dependencies. All APIs are Apple first-party frameworks:
# WebKit, Foundation, os, SwiftUI, UIKit
```

## Architecture Patterns

### Recommended Project Structure
```
ZenSocial/
  Scripts/
    Instagram/
      theme.css           # Instagram dark theme CSS overrides
    YouTube/
      theme.css           # YouTube dark theme CSS overrides
  Services/
    ScriptLoader.swift    # Loads .css from bundle, wraps in JS, returns WKUserScript
  WebView/
    WebViewConfiguration.swift  # (existing) Adds scripts via ScriptLoader
```

### Pattern 1: ScriptLoader Service
**What:** A stateless enum (or struct with static methods) that reads CSS files from the bundle, wraps them in a JavaScript injection IIFE, and returns `WKUserScript` objects ready to add to `WKUserContentController`.
**When to use:** Called from `WebViewConfiguration.make(for:)` for each platform.
**Example:**
```swift
// Source: Apple Developer Documentation + CLAUDE.md Stack Patterns
import WebKit
import os

@MainActor
enum ScriptLoader {
    private static let logger = Logger(
        subsystem: "com.zensocial.app",
        category: "ScriptLoader"
    )

    static func themeScript(for platform: Platform) -> WKUserScript? {
        let subdirectory = "Scripts/\(platform.displayName)"
        guard let url = Bundle.main.url(
            forResource: "theme",
            withExtension: "css",
            subdirectory: subdirectory
        ) else {
            handleMissingScript(platform: platform, filename: "theme.css")
            return nil
        }

        guard let css = try? String(contentsOf: url, encoding: .utf8) else {
            handleMissingScript(platform: platform, filename: "theme.css")
            return nil
        }

        let js = wrapCSSInJS(css)
        return WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false  // Apply to iframes too
        )
    }

    private static func wrapCSSInJS(_ css: String) -> String {
        // Escape backticks and backslashes for JS template literal
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        return """
        (function() {
            var style = document.createElement('style');
            style.type = 'text/css';
            style.textContent = `\(escaped)`;
            document.documentElement.appendChild(style);
        })();
        """
    }

    private static func handleMissingScript(platform: Platform, filename: String) {
        #if DEBUG
        assertionFailure(
            "ScriptLoader: Missing \\(filename) for \\(platform.displayName). "
            + "Check that Scripts/\\(platform.displayName)/\\(filename) is in the app bundle."
        )
        #else
        logger.error(
            "Failed to load \\(filename) for \\(platform.displayName)"
        )
        // Post notification for the UI layer to present alert
        NotificationCenter.default.post(
            name: .zenScriptLoadFailure,
            object: nil,
            userInfo: [
                "platform": platform.displayName,
                "filename": filename
            ]
        )
        #endif
    }
}
```

### Pattern 2: CSS Injection via document.documentElement (FOUC Prevention)
**What:** At `atDocumentStart`, `document.head` does not exist yet. The `<html>` element (`document.documentElement`) IS available because Apple's documentation states the script fires "after the creation of the webpage's document element, but before loading any other content." The style element must be appended to `document.documentElement`.
**When to use:** Always for CSS injection at document start.
**Example:**
```javascript
// Source: Apple WKUserScriptInjectionTime.atDocumentStart docs + community verification
(function() {
    var style = document.createElement('style');
    style.type = 'text/css';
    style.textContent = `/* CSS content here */`;
    document.documentElement.appendChild(style);
})();
```

### Pattern 3: CSS Variable Override Strategy (D-06 Hybrid)
**What:** Override platform CSS custom properties at `:root` level first, then use direct `!important` overrides for elements that don't respond.
**When to use:** Both Instagram and YouTube CSS files follow this two-pass structure.
**Example:**
```css
/* Pass 1: Variable overrides (preferred -- cascade naturally) */
:root {
    --yt-spec-base-background: #000000 !important;
    --yt-spec-raised-background: #1C1C1E !important;
    --yt-spec-general-background-a: #1C1C1E !important;
    --yt-spec-text-primary: #FFFFFF !important;
    --yt-spec-text-secondary: #8E8E93 !important;
    --yt-spec-call-to-action: #4DA6FF !important;
}

/* Pass 2: Direct overrides for elements ignoring variables */
body, html {
    background-color: #000000 !important;
    color: #FFFFFF !important;
}
```

### Pattern 4: Integration into WebViewConfiguration
**What:** Add scripts to `WKUserContentController` inside the existing `make(for:)` method.
**When to use:** This is the only integration point -- WKWebViewConfiguration is immutable after WKWebView init.
**Example:**
```swift
// In WebViewConfiguration.make(for:)
// After existing contentController setup (line 33):
if let themeScript = ScriptLoader.themeScript(for: platform) {
    contentController.addUserScript(themeScript)
}
```

### Anti-Patterns to Avoid
- **Injecting CSS at atDocumentEnd:** Causes visible flash of the platform's light theme before dark override applies. Always use atDocumentStart.
- **Using document.head.appendChild at atDocumentStart:** `document.head` is null at this injection time. Use `document.documentElement.appendChild` instead.
- **Hardcoding CSS in Swift strings:** Violates INJ-04, makes maintenance painful when selectors change. Always load from bundle files.
- **Using forMainFrameOnly: true:** Instagram uses iframes for some modals and overlays. Setting `forMainFrameOnly: false` ensures the theme applies everywhere.
- **Modifying WKWebViewConfiguration after WKWebView init:** Configuration is immutable post-init. All scripts must be added before the config is passed to the WKWebView constructor.
- **Overriding `<img>`, `<video>`, `<canvas>` styling:** D-02 prohibits re-theming user content. CSS selectors must explicitly exclude media elements.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSS injection into WKWebView | Custom URL protocol or proxy | WKUserScript + WKUserContentController | Apple's purpose-built API. Proxy/MITM violates App Store guidelines. |
| Structured logging | Custom file logger | os.Logger | System-integrated, filterable in Console.app, privacy-aware, zero config. |
| Error reporting UI | Custom overlay view | SwiftUI .alert + UIActivityViewController | Standard iOS patterns. Alert is native, share sheet is system-provided. |
| JavaScript escaping | Manual string escaping | Template literal with backtick escaping | Template literals handle newlines and quotes. Only backticks, backslashes, and `$` need escaping. |

**Key insight:** This phase uses entirely first-party Apple APIs. There is nothing to install and nothing to hand-roll. The complexity is in the CSS selectors, not the injection plumbing.

## Common Pitfalls

### Pitfall 1: FOUC from Wrong Injection Timing
**What goes wrong:** CSS injected at `atDocumentEnd` or via `evaluateJavaScript` in `didFinish` causes a visible flash of the platform's default light theme.
**Why it happens:** The page renders with its own styles before the override CSS is applied.
**How to avoid:** Always use `WKUserScript` with `injectionTime: .atDocumentStart`. This fires before any content is parsed or rendered.
**Warning signs:** White flash visible on page load; theme "pops in" after content appears.

### Pitfall 2: document.head is null at atDocumentStart
**What goes wrong:** JavaScript tries `document.head.appendChild(style)` and throws a TypeError because `document.head` is null.
**Why it happens:** At `atDocumentStart`, only the document element (`<html>`) exists. The `<head>` has not been parsed yet.
**How to avoid:** Use `document.documentElement.appendChild(style)` instead. The browser will move the `<style>` element into `<head>` once it is created.
**Warning signs:** Theme not appearing at all; JavaScript errors in Web Inspector console.

### Pitfall 3: CSS Not Applying to Iframes
**What goes wrong:** Theme works on the main page but modals, login popups, or embedded content appear with the default light theme.
**Why it happens:** `WKUserScript` defaults to `forMainFrameOnly: true` if not specified, which skips iframes. Instagram uses iframes for some UI elements.
**How to avoid:** Set `forMainFrameOnly: false` when creating WKUserScript objects.
**Warning signs:** Inconsistent theming; some overlays or popups appear light.

### Pitfall 4: CSS Selectors Breaking on Platform Updates
**What goes wrong:** Instagram or YouTube updates their DOM structure or CSS class names, breaking ZenSocial's theme overrides.
**Why it happens:** Both platforms use obfuscated/hashed class names (e.g., `._aagw`, `.style-scope`) that change with deployments.
**How to avoid:** Prefer CSS variable overrides (`:root {}` block) over class-name selectors. Variables like `--yt-spec-base-background` are stable API-level tokens. Fall back to structural selectors (`nav`, `header`, `[role="banner"]`) over class names when direct overrides are needed.
**Warning signs:** Theme suddenly breaks without any ZenSocial code changes.

### Pitfall 5: Escaping CSS Content for JavaScript Template Literals
**What goes wrong:** CSS containing backticks, `${}`, or backslashes breaks the JavaScript template literal wrapper.
**Why it happens:** These characters have special meaning in JS template literals.
**How to avoid:** Escape `\` to `\\`, backtick to `` \` ``, and `$` to `\$` before embedding CSS in the JavaScript wrapper.
**Warning signs:** JavaScript syntax errors in Web Inspector; theme partially applied or not at all.

### Pitfall 6: Accidentally Interfering with Service Workers (D-11)
**What goes wrong:** Broad CSS selectors or JavaScript inadvertently blocks service worker registration, breaking future push notification support.
**Why it happens:** Over-aggressive selectors matching `<link rel="manifest">` or scripts that override `navigator.serviceWorker`.
**How to avoid:** Phase 2 scripts are CSS-only (wrapped in JS for injection). No JavaScript logic that touches DOM elements, navigator APIs, or network requests. CSS cannot interfere with service workers.
**Warning signs:** Push notifications (Phase 3) fail to register.

### Pitfall 7: Bundle Files Not Included in Xcode Target
**What goes wrong:** CSS files exist on disk but `Bundle.main.url(forResource:)` returns nil at runtime.
**Why it happens:** Files added to the project directory but not to the Xcode target's "Copy Bundle Resources" build phase, or not added to the correct target membership.
**How to avoid:** After creating `Scripts/Instagram/theme.css` and `Scripts/YouTube/theme.css`, verify they appear in Xcode > Target > Build Phases > Copy Bundle Resources. The D-09 assertionFailure will catch this in debug builds.
**Warning signs:** D-09 assertion fires immediately on first launch in debug.

## Code Examples

### Loading and Injecting Theme CSS (Complete Flow)
```swift
// Source: Apple Developer Documentation (WKUserScript, WKUserContentController, Bundle)
// In WebViewConfiguration.make(for:) -- after line 33:

let contentController = WKUserContentController()

// Load platform-specific theme CSS
if let themeScript = ScriptLoader.themeScript(for: platform) {
    contentController.addUserScript(themeScript)
}

config.userContentController = contentController
```

### Instagram Theme CSS Structure (Recommended)
```css
/* Source: Instagram CSS analysis (Project Wallace) + community dark themes */
/* File: Scripts/Instagram/theme.css */

/* Pass 1: Override Facebook Design System (FDS) variables */
:root,
.__ig-light-mode,
.__ig-dark-mode {
    /* Surface colors */
    --fds-black: #000000 !important;
    --ig-primary-background: #000000 !important;
    --ig-secondary-background: #1C1C1E !important;
    --ig-elevated-background: #1C1C1E !important;
    --ig-separator: #2C2C2E !important;
    --ig-stroke: #2C2C2E !important;

    /* Text colors */
    --ig-primary-text: #FFFFFF !important;
    --ig-secondary-text: #8E8E93 !important;

    /* Accent */
    --ig-link: #4DA6FF !important;
    --ig-badge: #4DA6FF !important;
    --ig-primary-button: #4DA6FF !important;
}

/* Pass 2: Direct overrides for elements not using variables */
body, html {
    background-color: #000000 !important;
    color: #FFFFFF !important;
}

/* Navigation and structural chrome */
nav, header, [role="banner"], [role="navigation"] {
    background-color: #1C1C1E !important;
}

/* Exclude media content (D-02) */
img, video, canvas, svg {
    /* Do not apply color overrides */
}
```

### YouTube Theme CSS Structure (Recommended)
```css
/* Source: YouTube CSS variable analysis (community themes + DevTools inspection) */
/* File: Scripts/YouTube/theme.css */

/* Pass 1: Override YouTube spec variables */
:root,
html[dark],
html:not([dark]) {
    /* Surface colors */
    --yt-spec-base-background: #000000 !important;
    --yt-spec-raised-background: #1C1C1E !important;
    --yt-spec-general-background-a: #1C1C1E !important;
    --yt-spec-general-background-b: #1C1C1E !important;
    --yt-spec-general-background-c: #000000 !important;
    --yt-spec-menu-background: #1C1C1E !important;

    /* Text colors */
    --yt-spec-text-primary: #FFFFFF !important;
    --yt-spec-text-secondary: #8E8E93 !important;
    --yt-spec-text-disabled: #8E8E93 !important;

    /* Accent */
    --yt-spec-call-to-action: #4DA6FF !important;
    --yt-spec-icon-active-other: #4DA6FF !important;

    /* Borders */
    --yt-spec-10-percent-layer: #2C2C2E !important;

    /* Keep brand red for subscribe button */
    --yt-spec-brand-icon-active: #FF0000 !important;
}

/* Pass 2: Direct overrides */
body, html, ytm-app {
    background-color: #000000 !important;
    color: #FFFFFF !important;
}

/* Mobile YouTube uses ytm- prefixed elements */
ytm-pivot-bar-renderer {
    background-color: #1C1C1E !important;
}
```

### Error Alert with Report Action (D-10)
```swift
// Source: SwiftUI .alert documentation, UIActivityViewController
// Triggered by .zenScriptLoadFailure notification

.alert("Theme failed to load", isPresented: $showScriptError) {
    Button("Dismiss", role: .cancel) { }
    Button("Report Issue") {
        let text = """
        ZenSocial theme loading failed
        Platform: \(failedPlatform)
        iOS: \(UIDevice.current.systemVersion)
        App: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        Script: \(failedFilename)
        """
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        // Present share sheet from root view controller
    }
} message: {
    Text("\(failedPlatform) theme could not be applied. The app will work normally without it.")
}
```

## Instagram CSS Variable Reference

Instagram uses the Facebook Design System (FDS) prefix `--fds-*` plus Instagram-specific `--ig-*` variables. Theme switching is controlled by CSS classes:
- `:root, .__ig-light-mode` -- light theme defaults
- `.__ig-dark-mode` -- dark theme overrides

**Key variables (from Project Wallace analysis and community themes):**

| Variable | Controls | ZenSocial Override |
|----------|----------|--------------------|
| `--ig-primary-background` | Page background | `#000000` |
| `--ig-secondary-background` | Cards, elevated surfaces | `#1C1C1E` |
| `--ig-elevated-background` | Modals, dropdowns | `#1C1C1E` |
| `--ig-separator` | Divider lines | `#2C2C2E` |
| `--ig-stroke` | Card/input borders | `#2C2C2E` |
| `--ig-primary-text` | Primary text color | `#FFFFFF` |
| `--ig-secondary-text` | Metadata, captions | `#8E8E93` |
| `--ig-link` | Link text | `#4DA6FF` |
| `--ig-badge` | Notification badges | `#4DA6FF` |
| `--ig-primary-button` | Primary action buttons | `#4DA6FF` |

**Confidence: MEDIUM** -- Instagram's variable names are not officially documented. They are derived from CSS analysis tools and community dark theme projects. Variable names may change without notice. The hybrid approach (D-06) mitigates this by having direct overrides as fallback.

## YouTube CSS Variable Reference

YouTube uses `--yt-spec-*` variables for its design system. Dark mode is toggled via the `dark` attribute on `<html>`. Mobile YouTube (`m.youtube.com`) uses `ytm-*` custom elements.

**Key variables (from community theme analysis and DevTools inspection):**

| Variable | Controls | ZenSocial Override |
|----------|----------|--------------------|
| `--yt-spec-base-background` | Page background | `#000000` |
| `--yt-spec-raised-background` | Cards, elevated surfaces | `#1C1C1E` |
| `--yt-spec-general-background-a` | Section backgrounds | `#1C1C1E` |
| `--yt-spec-general-background-b` | Alternative sections | `#1C1C1E` |
| `--yt-spec-general-background-c` | Tertiary backgrounds | `#000000` |
| `--yt-spec-menu-background` | Menu/dropdown backgrounds | `#1C1C1E` |
| `--yt-spec-text-primary` | Primary text | `#FFFFFF` |
| `--yt-spec-text-secondary` | Secondary text | `#8E8E93` |
| `--yt-spec-call-to-action` | Links, action buttons | `#4DA6FF` |
| `--yt-spec-icon-active-other` | Active icons | `#4DA6FF` |
| `--yt-spec-brand-icon-active` | YouTube brand red | `#FF0000` (preserved) |
| `--yt-spec-10-percent-layer` | Borders, dividers | `#2C2C2E` |

**Confidence: MEDIUM** -- YouTube's `--yt-spec-*` naming convention is well-established and more stable than Instagram's, but m.youtube.com may use a different subset than desktop. The project loads `m.youtube.com` (confirmed in Platform.swift line 20).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| evaluateJavaScript in didFinish | WKUserScript at atDocumentStart | iOS 11+ (stable) | Eliminates FOUC entirely |
| NSLog for logging | os.Logger with subsystem/category | iOS 14+ (os framework) | Structured, filterable, privacy-aware |
| ObservableObject + @Published | @Observable macro | iOS 17 (Observation framework) | Already used in Phase 1; relevant for error state propagation |
| document.head.appendChild | document.documentElement.appendChild | Always (at atDocumentStart) | Prevents null reference when head doesn't exist yet |

**Deprecated/outdated:**
- `UIWebView`: Removed from iOS entirely. WKWebView is the only option.
- `WKProcessPool` explicit sharing: Deprecated iOS 15+; sharing is automatic on iOS 17+.

## Open Questions

1. **Instagram variable stability**
   - What we know: Instagram uses `--fds-*` and `--ig-*` CSS custom properties with 548+ variables. Variable overrides at `:root` level should cascade.
   - What's unclear: Exact variable names may differ on the mobile web version Instagram serves to WKWebView (with Safari UA). Instagram may also obfuscate or change variable names during deployments.
   - Recommendation: Implement the hybrid approach (D-06). Test variable overrides first; add direct `!important` overrides as needed during implementation. The CSS files are externalized (INJ-04) precisely so they can be updated when selectors break.

2. **YouTube mobile vs desktop variables**
   - What we know: The project loads `m.youtube.com` (mobile). YouTube's `--yt-spec-*` variables are documented from desktop analysis. Mobile uses `ytm-*` custom elements.
   - What's unclear: Whether m.youtube.com uses the identical `--yt-spec-*` variable set as desktop YouTube.
   - Recommendation: Start with the documented `--yt-spec-*` variables. Test on m.youtube.com in simulator. Add mobile-specific overrides for `ytm-*` elements in the direct override pass.

3. **Instagram dark mode URL parameter**
   - What we know: Instagram supports `?theme=dark` URL parameter to force dark mode. This could simplify the CSS needed.
   - What's unclear: Whether this parameter persists across SPA navigations, and whether it is reliable long-term.
   - Recommendation: Do NOT rely on it. ZenSocial's own CSS injection is the authoritative theming mechanism (D-04, D-05). However, appending `?theme=dark` to the initial load URL could reduce the volume of CSS overrides needed since Instagram's own dark mode handles much of the work. This is an optimization the implementer can explore.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | none -- XCTest requires no config file |
| Quick run command | `xcodebuild test -project ZenSocial.xcodeproj -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZenSocialTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project ZenSocial.xcodeproj -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -20` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INJ-01 | ScriptLoader returns valid WKUserScript for each platform | unit | `xcodebuild test -only-testing:ZenSocialTests/ScriptLoaderTests` | Wave 0 |
| INJ-02 | Instagram theme.css exists in bundle and contains expected variable overrides | unit | `xcodebuild test -only-testing:ZenSocialTests/ScriptLoaderTests/testInstagramThemeLoads` | Wave 0 |
| INJ-03 | YouTube theme.css exists in bundle and contains expected variable overrides | unit | `xcodebuild test -only-testing:ZenSocialTests/ScriptLoaderTests/testYouTubeThemeLoads` | Wave 0 |
| INJ-04 | Scripts loaded from bundle files, not hardcoded | unit | Verified by INJ-01 test -- ScriptLoader reads from Bundle | Wave 0 |
| INJ-01 | FOUC-free (atDocumentStart timing) | manual-only | Visual inspection in simulator | N/A -- requires human eye |
| INJ-01 | Theme persists across SPA navigation | manual-only | Navigate feed > profile > settings in simulator | N/A -- requires human eye |
| D-09 | assertionFailure fires when script file missing (debug) | unit | `xcodebuild test -only-testing:ZenSocialTests/ScriptLoaderTests/testMissingScriptDebugAsserts` | Wave 0 |
| D-10 | Release builds log failure and post notification | unit | `xcodebuild test -only-testing:ZenSocialTests/ScriptLoaderTests/testMissingScriptReleaseLogsAndNotifies` | Wave 0 |

### Sampling Rate
- **Per task commit:** Quick test run (ScriptLoaderTests only)
- **Per wave merge:** Full test suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `ZenSocialTests/ScriptLoaderTests.swift` -- covers INJ-01 through INJ-04, D-09, D-10
- [ ] `ZenSocialTests/` directory -- may need to be created if it does not exist
- [ ] Test target membership -- Scripts/ bundle files must also be in test target's Copy Bundle Resources

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build, test, bundle resources | Yes | 26.3 (Build 17C529) | -- |
| Swift | All source code | Yes | 6.2.4 | -- |
| iOS Simulator | Manual FOUC/theme testing | Yes (via Xcode) | -- | Physical device |
| Safari Web Inspector | Debugging injected CSS/JS | Yes (via Safari Develop menu) | -- | -- |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Project Constraints (from CLAUDE.md)

- **WKWebView via UIViewRepresentable** -- not iOS 26 SwiftUI WebView/WebPage (lacks WKUserContentController access)
- **WKUserContentController + WKUserScript** for all injection -- no third-party libraries
- **atDocumentStart** timing for CSS injection (CLAUDE.md explicit)
- **Scripts organized by platform** -- `Scripts/Instagram/`, `Scripts/YouTube/` bundle directories
- **Load via Bundle.main.url(forResource:)** -- runtime bundle loading
- **@Observable macro** (Observation framework) for state management
- **No CocoaPods** -- SPM only (though this phase has zero external dependencies)
- **No external dependencies for MVP** -- entire stack uses Apple-provided frameworks
- **Swift 6 strict concurrency** -- WKWebView delegate callbacks need `@MainActor` annotation (already done in Phase 1)
- **GSD workflow enforcement** -- no direct repo edits outside GSD workflow
- **No Co-Authored-By trailers** in git commits

## Sources

### Primary (HIGH confidence)
- [Apple Developer: WKUserScript](https://developer.apple.com/documentation/webkit/wkuserscript) -- Injection API, timing options
- [Apple Developer: WKUserScriptInjectionTime.atDocumentStart](https://developer.apple.com/documentation/webkit/wkuserscriptinjectiontime/atdocumentstart) -- "After the creation of the webpage's document element, but before loading any other content"
- [Apple Developer: WKUserContentController](https://developer.apple.com/documentation/webkit/wkusercontentcontroller) -- Script management
- Existing codebase: `WebViewConfiguration.swift`, `Platform.swift`, `Color+ZenSocial.swift` -- Phase 1 integration points

### Secondary (MEDIUM confidence)
- [Project Wallace: A deep dive into the CSS of Instagram.com](https://www.projectwallace.com/blog/analyzing-instagram-css) -- Instagram CSS variable analysis (548 custom properties, --fds-* prefix, __ig-dark-mode class)
- [GitHub: vednoc/dark-instagram](https://github.com/vednoc/dark-instagram) -- Community dark theme using CSS variables
- [GitHub: Doquanggvii/dqv](https://github.com/Doquanggvii/dqv) -- YouTube --yt-spec-* variable reference
- [GitHub: RaitaroH/YouTube-DeepDark](https://github.com/RaitaroH/YouTube-DeepDark) -- YouTube dark theme patterns
- [GitHub: shirakaba/WKWebView-stylesheet-injection](https://gist.github.com/shirakaba/e89b7d055c57a48bab100ab6f2bee9e9) -- atDocumentStart + document.documentElement.appendChild pattern
- [Swift Senpai: JavaScript Injection in WKWebView](https://swiftsenpai.com/development/web-view-javascript-injection/) -- Injection patterns
- [Medium: Injecting CSS and JavaScript into WKWebView](https://medium.com/@mahdi.mahjoobi/injection-css-and-javascript-in-wkwebview-eabf58e5c54e) -- CSS injection via style element creation

### Tertiary (LOW confidence)
- [Greasyfork: Instagram Dark Mode](https://greasyfork.org/en/scripts/389845-instagram-dark-mode/code) -- Older Instagram dark theme (uses class selectors, not variables)
- [XDA: Instagram dark theme URL parameter](https://www.xda-developers.com/instagram-dark-theme-website/) -- `?theme=dark` parameter (needs validation for SPA persistence)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All first-party Apple APIs; well-documented, stable since iOS 11+
- Architecture: HIGH -- WKUserScript + WKUserContentController is the only viable path per CLAUDE.md constraints; pattern is well-established
- CSS variable names: MEDIUM -- Instagram/YouTube variable names derived from community analysis, not official documentation; may change
- Pitfalls: HIGH -- FOUC prevention, document.head null, iframe coverage are well-documented community knowledge

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (30 days -- stack is stable; CSS variable names may shift sooner if platforms deploy updates)
