# Phase 1: Native Shell + WKWebView Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Areas discussed:** User agent strategy, WKWebView session isolation, Video autoplay, Auth redirect handling

---

## User Agent Strategy

**Question:** Which Safari UA to spoof for BLOCK-03?

| Option | Selected |
|--------|----------|
| Mobile iOS Safari UA | ✓ |
| Desktop Safari UA | |

**Follow-up:** Should the UA be hardcoded or dynamic?

| Option | Selected |
|--------|----------|
| Dynamic — mirror device Safari UA | ✓ |
| Hardcoded iOS 17 Safari UA | |

---

## WKWebView Session Isolation

**Context provided by user:** "I want our app to feel responsive and quick. Will running them with a shared one increase performance or decrease it?"

Explanation given: `WKProcessPool` (process/performance) and `WKWebsiteDataStore` (cookies/sessions) are independent concerns. Shared process pool = lower memory. Separate data stores = clean session isolation. Both can be true simultaneously.

**Question:** Which configuration approach?

| Option | Selected |
|--------|----------|
| Shared pool + shared data store | |
| Shared pool + separate data stores | ✓ |
| Fully separate configurations | |

---

## Video Autoplay

**User context:** "I want to go with require tap to play. I don't want videos to start playing without the user choosing to play it. With the one exception being YouTube's play on navigate — which I find to be an important feature."

**Question:** Autoplay policy?

| Option | Selected |
|--------|----------|
| Require tap to play | ✓ (Instagram) |
| Allow autoplay | ✓ (YouTube) |

**Note:** Per-platform config (already decided) enables different policies per WebView cleanly.

---

## Auth Redirect Handling

**User context:** "I want to go with allow in-WebView. When the user gets redirected to a separate site to sign in, can we make it appear in a modal sort of view where it pops out from the main app they are on, with the option to open it in their default browser instead (Safari) in case it breaks because of OAuth blocking."

**Decision:** In-app modal sheet (custom WKWebView sharing the platform's data store) + "Open in Safari" toolbar button fallback + auto-dismiss on return to platform domain.

| Option | Selected |
|--------|----------|
| Allow in-WebView (modal sheet) | ✓ |
| Intercept to SFSafariViewController | |
| You decide | |
