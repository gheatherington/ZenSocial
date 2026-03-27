# Phase 2: Injection Engine + Dark Theme - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the CSS/JS injection pipeline using the `WKUserContentController` already wired in Phase 1 (`WebViewConfiguration.swift`), and prove it end-to-end by applying ZenSocial's dark theme to both Instagram and YouTube. Scripts are stored as external bundle files. No feature blocking — that is Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Theme Depth
- **D-01:** Theme targets structural elements — backgrounds, navigation bars, toolbars, text color — plus ZenSocial brand accents (#4DA6FF / `zenAccent`) applied to interactive elements (links, active states, focus rings, selected indicators).
- **D-02:** Individual content (photos, video thumbnails, post cards) is NOT re-themed. Only the platform "chrome" is darkened.
- **D-03:** This is v1 scope. Color theme system (user-selectable themes) is explicitly deferred to a future phase.

### Dark Mode Enforcement
- **D-04:** Dark theme is **always forced** — ZenSocial enforces dark regardless of the user's system dark/light mode setting. `prefers-color-scheme` is ignored.
- **D-05:** ZenSocial's accent layer is **always injected** on top of the platform's own styling.

### CSS Architecture
- **D-06:** **Hybrid approach** — CSS variable overrides first (`:root {}` block targeting platform CSS custom properties such as Instagram's `--ig-*` and YouTube's `--yt-spec-*` variables), then targeted direct property overrides with `!important` for elements that don't respond to variable overrides.
- **D-07:** Instagram and YouTube each get their own CSS file. Claude's discretion on exact file naming within `Scripts/Instagram/` and `Scripts/YouTube/` bundle directories (per CLAUDE.md Stack Patterns).
- **D-08:** Injection timing is `atDocumentStart` for CSS to prevent FOUC (flash of unstyled/light content). This satisfies success criteria 1 and 2.

### Script Loading Failure Handling
- **D-09:** **Debug builds:** `assertionFailure` (or `preconditionFailure`) when a script bundle file cannot be loaded. Catches build misconfiguration immediately during development.
- **D-10:** **Release builds:** Skip injection for the failed script, log the failure via `os_log`. Show an **in-app alert** notifying the user that theming failed to load, with a **"Report" button** that opens the iOS share sheet pre-populated with diagnostic info (platform, iOS version, app build version, and which script failed). No backend required — user sends via whatever channel they choose from the share sheet.

### Push Notification Safety (Hard Constraint)
- **D-11:** Phase 2 injection scripts MUST NOT interfere with Instagram's service worker, PWA manifest, or web push APIs. Specifically:
  - Do not block or redirect requests to service worker paths (e.g. `/sw.js`, `serviceworker`)
  - Do not strip or modify `<link rel="manifest">` elements
  - Do not override or disable `navigator.serviceWorker`, `Notification`, or `PushManager`
  - This is a prerequisite for Phase 3 (Push Notifications) to work.

### Claude's Discretion
- Exact CSS file names within the bundle directories
- Which specific CSS variables each platform exposes (research at implementation time — they change)
- Specificity strategy for `!important` overrides (use judiciously, only where variables don't work)
- Whether a thin Swift `ScriptLoader` service is warranted or inline loading in `WebViewConfiguration` is sufficient
- `os_log` subsystem/category naming conventions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Technology Stack
- `CLAUDE.md` (project-level) — Canonical stack decisions. Confirms WKWebView via UIViewRepresentable, `WKUserContentController` + `WKUserScript` for injection, `atDocumentStart` timing for FOUC prevention, and script bundle file organization pattern (`Scripts/Instagram/`, `Scripts/YouTube/`).

### Requirements
- `.planning/REQUIREMENTS.md` — Phase 2 requirements: INJ-01, INJ-02, INJ-03, INJ-04.

### Existing Integration Point
- `ZenSocial/WebView/WebViewConfiguration.swift` — `WKUserContentController` is already initialized here and attached to the config. Phase 2 adds `WKUserScript` objects to this controller. No new config object needed.

### Existing Color Palette
- `ZenSocial/Extensions/Color+ZenSocial.swift` — Native app color tokens. Web theme CSS must use the same color values: zenAccent `#4DA6FF` (rgb 77,166,255), zenSecondaryBackground `#1C1C1E` (rgb 28,28,30), zenInactiveGray `#8E8E93` (rgb 142,142,147).

### Prior Phase Architecture
- `.planning/phases/01-native-shell-wkwebview-foundation/01-CONTEXT.md` — D-03/D-04: process pool and per-platform data store decisions. D-05/D-06: per-platform autoplay policy. Confirms `WKWebViewConfiguration` is immutable after init.

### Project Context
- `.planning/PROJECT.md` — Vision, constraints, App Store compliance notes.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ZenSocial/WebView/WebViewConfiguration.swift` — `WKUserContentController` already created and attached at line 33. Phase 2 adds scripts here before the config is returned.
- `ZenSocial/Models/Platform.swift` — `Platform` enum used to select platform-specific scripts.
- `ZenSocial/Extensions/Color+ZenSocial.swift` — Color values to replicate in CSS.

### Established Patterns
- Per-platform configuration already established (Phase 1 D-05/D-06). Script selection by `Platform` enum follows the same pattern.
- `Bundle.main.url(forResource:withExtension:)` is the standard for loading bundle files at runtime.

### Integration Points
- `WebViewConfiguration.make(for:)` is the single place where `WKUserContentController` is configured. All `WKUserScript` additions happen here.
- Scripts added to `WKUserContentController` persist for the lifetime of the `WKWebView` — no need to re-inject on navigation (SPA navigation within the same WebView re-fires document start scripts automatically).

</code_context>

<specifics>
## Specific Ideas

- Dark theme is ZenSocial's identity — it should always be dark, not dependent on the user's system setting. "For now" means this is a v1 simplification; a theme picker is a future feature.
- The report flow via share sheet is deliberately infrastructure-free — no backend, no analytics endpoint. The user (developer) receives the diagnostic info through whatever channel the app user chooses (email, message, etc.).

</specifics>

<deferred>
## Deferred Ideas

- **Color theme system** — User-selectable color themes beyond dark (e.g., OLED black, sepia, custom). Explicitly out of scope for v1. Own phase when the time comes.

</deferred>

---

*Phase: 02-injection-engine-dark-theme*
*Context gathered: 2026-03-27*
