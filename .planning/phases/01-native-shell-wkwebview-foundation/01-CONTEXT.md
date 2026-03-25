# Phase 1: Native Shell + WKWebView Foundation - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a working iOS app shell that loads Instagram and YouTube in a native tab bar, with persistent sessions, proper WKWebView configuration, Safari UA spoofing, smooth navigation, and error/loading states. No injection, no blocking — this phase proves the container works and sets the immutable architectural foundation that all later phases build on.

</domain>

<decisions>
## Implementation Decisions

### User Agent (BLOCK-03)
- **D-01:** Use mobile iOS Safari UA — loads the touch-optimized mobile web app experience for both platforms.
- **D-02:** UA is **dynamic** — read the actual Safari UA from a temporary WKWebView at launch and apply it. Never hardcoded. Always matches the iOS version on the device with zero maintenance.

### WKWebView Configuration
- **D-03:** **Shared `WKProcessPool`** across both platform WebViews — single web content process, lower memory footprint, better performance on all devices.
- **D-04:** **Separate `WKWebsiteDataStore` per platform** — Instagram and YouTube each get their own cookie/session/localStorage store. Clean isolation: clearing one platform's data doesn't touch the other. This is an immutable-at-init decision.

### Video Autoplay
- **D-05:** **Instagram:** `mediaTypesRequiringUserActionForPlayback = .all` — no video plays without a user tap. Intentional, calm, reduces data usage.
- **D-06:** **YouTube:** `mediaTypesRequiringUserActionForPlayback = []` — autoplay allowed. Preserves YouTube's navigate-to-video autoplay behavior, which the user considers an important feature (video preview on tap).
- **Rationale:** Per-platform config (enabled by D-03/D-04) makes this clean — no extra complexity.

### Auth Redirect Handling
- **D-07:** When `WKNavigationDelegate` detects navigation to a non-platform domain (e.g., `accounts.google.com` for YouTube login), **present a modal sheet containing a new WKWebView** configured with the same `WKWebsiteDataStore` as the originating platform. Auth cookies are written to the correct store.
- **D-08:** The modal sheet toolbar includes an **"Open in Safari" button** (`UIApplication.shared.open(url)`) as a fallback for cases where OAuth blocks WebView-based login.
- **D-09:** The modal **auto-dismisses** when navigation returns to the platform domain (e.g., back to `instagram.com` or `youtube.com`).

### Claude's Discretion
- External link handling (non-auth external URLs): already decided in UI-SPEC — open in system browser.
- WKWebView media configuration beyond autoplay (e.g., `allowsInlineMediaPlayback`, `allowsAirPlayForMediaPlayback`) — Claude picks sensible defaults.
- Specific URL allowlist for "known auth domains" that trigger the modal vs. other external domains that open in system browser — Claude defines based on Instagram/YouTube login flow research.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI Design Contract
- `.planning/phases/01-native-shell-wkwebview-foundation/01-UI-SPEC.md` — Approved visual and interaction contract for Phase 1. Defines tab bar, loading indicator, error screen, pull-to-refresh, color system, typography, animations, accessibility, and copywriting. All native UI must match this spec.

### Requirements
- `.planning/REQUIREMENTS.md` — Full v1 requirement set. Phase 1 requirements: SHELL-01, SHELL-02, SHELL-03, WEB-01, WEB-02, WEB-03, WEB-04, WEB-05, BLOCK-03.

### Project Context
- `.planning/PROJECT.md` — Vision, constraints, key decisions, and out-of-scope items.

### Technology Stack
- `CLAUDE.md` (project-level) — Canonical technology stack with rationale. Defines why WKWebView via UIViewRepresentable (not iOS 26 SwiftUI WebView/WebPage), Swift 6, SwiftUI iOS 17+, and all supporting tooling decisions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — this is the first phase; no existing codebase.

### Established Patterns
- None yet — this phase establishes the foundational patterns all later phases will follow.

### Integration Points
- `WKWebViewConfiguration` is immutable after init. All configuration decisions (process pool, data store, autoplay policy, UA) must be set here and cannot change in Phases 2–4.
- `WKUserContentController` (attached to the configuration) is the integration point for Phase 2 (CSS/JS injection) and Phase 3 (content rules). Phase 1 sets this up even if no scripts are injected yet.
- Phase 2 will add `WKUserScript` objects and `WKContentRuleList` to the `WKUserContentController` already wired in Phase 1.

</code_context>

<specifics>
## Specific Ideas

- Auth modal behavior: user described it as a "modal sort of view where it pops out from the main app they are on" — should feel like a sheet sliding up over Instagram/YouTube, not a full navigation push.
- YouTube autoplay: user specifically called out navigate-to-video autoplay as "an important feature" — the preview-on-navigate behavior must be preserved.
- Performance is a stated priority: "I want the app to feel responsive and quick" — informed the shared process pool decision and the tap-to-play default for Instagram (reduces background media activity).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-native-shell-wkwebview-foundation*
*Context gathered: 2026-03-24*
