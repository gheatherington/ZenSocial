---
phase: 3
name: push-notifications
status: planning
created: 2026-03-27
---

# Phase 3: Push Notifications — Context

## Goal

Enable Instagram web push notifications within the WKWebView context. Users should receive Instagram push notifications when the app is running in the foreground, and ideally when it is suspended in the background. The "force-quit" (closed app) scenario is the hardest case and requires live testing to determine the correct approach before committing to a full APNs bridge.

<domain>
Instagram push notifications in WKWebView. This phase is architecturally orthogonal to CSS/JS injection (Phase 2) — it touches native iOS notification infrastructure, service worker registration, and potentially APNs entitlements. It does not require modifying any injection scripts, only ensuring Phase 2 scripts do not break the prerequisites. Scope is Instagram only; YouTube push is not in scope for this phase.
</domain>

<decisions>

## Decisions Already Made

### D-01: Push notifications extracted from Phase 2 into a dedicated phase
Push notification support was originally scoped inside Phase 2 (Injection Engine + Dark Theme) but extracted because it is architecturally independent. Phase 2 is about CSS/JS injection. Push is about service workers, WKWebView notification permissions, and potentially APNs entitlements. Mixing them would bloat Phase 2 and make it harder to test each concern in isolation.

**Consequence:** Phase 2 has a hard prerequisite constraint — it must not break Instagram's PWA or service worker. See Phase 2 Note in ROADMAP.md.

### D-02: Phase 2 must preserve Instagram's service worker and PWA compatibility
Phase 2 CSS injection scripts must not:
- Block or redirect requests to service worker paths (e.g. `/sw.js`, Instagram's SW endpoint)
- Strip or rewrite `<link rel="manifest">` elements in the DOM
- Override or disable `navigator.serviceWorker`, `Notification`, or `PushManager` on the `window` object

This is a non-negotiable prerequisite for Phase 3 to work at all. Verify via Safari Web Inspector before closing Phase 2.

### D-03: Visual cohesion (dark theme) belongs to Phase 2 only
The dark theme and Phase 3 are separate concerns. Phase 3 has no UI deliverables — it delivers a system capability (push delivery), not a visible interface change.

### D-04: Investigate Option A before committing to Option B
The implementation approach is undecided — live testing is required. Start with Option A (iOS 16.4+ Web Push in WKWebView) because it has the lowest complexity. Only escalate to Option B (APNs bridge) if Option A cannot deliver background push when the app is suspended.

### D-05: Force-quit push delivery is a nice-to-have, not a hard requirement
If Option A handles foreground + background (suspended) but not force-quit, that is an acceptable v1 outcome. Document the limitation. Force-quit delivery requires Option B infrastructure which may involve a backend relay — that is a significant scope increase and should only be built if there is confirmed user demand.

</decisions>

<specifics>

## Implementation Approaches

Three options were evaluated during planning. Pick the best based on live testing:

### Option A: iOS 16.4+ Web Push in WKWebView (investigate first)

**How it works:** Apple added Web Push support to WKWebView in iOS 16.4. When Instagram's service worker calls `PushManager.subscribe()`, the browser-level infrastructure handles delivery via APNs transparently. No custom native code needed beyond granting notification permission via `UNUserNotificationCenter`.

**Trade-offs:**
- Low complexity — no entitlements, no background modes, no backend
- Works in foreground confirmed
- Background (suspended) delivery: likely works, needs verification
- Force-quit delivery: uncertain — this is the key unknown to test
- Apple may impose restrictions specific to WKWebView vs Safari that are not documented

**Verification:** Use Safari Web Inspector to confirm service worker registers successfully and `PushManager.subscribe()` resolves without error.

### Option B: APNs bridge (use only if Option A is insufficient)

**How it works:** Instagram's backend sends a push to APNs. The native app receives a silent APNs push (background mode), wakes the app process, triggers the WKWebView to execute a message into the service worker, which surfaces a `UNUserNotificationCenter` local notification.

**Trade-offs:**
- High complexity — requires APNs entitlements, Background Modes capability (remote-notification), and possibly a backend relay if Instagram's pushes do not reach WKWebView APNs directly
- Handles force-quit case (iOS will wake the app for silent pushes if Background App Refresh is on)
- Adds infrastructure dependency (backend relay)
- More reliable delivery guarantee

**Entitlements needed:**
- `aps-environment` (development / production)
- `UIBackgroundModes`: `remote-notification`

**Native APIs:**
- `UNUserNotificationCenter` — request permission, present local notifications
- `PKPushRegistry` with `.voIP` type (alternative for guaranteed wake, but App Store scrutiny is high for VoIP misuse — avoid unless necessary)
- `WKScriptMessageHandler` — bridge from native to WKWebView service worker

### Option C: In-app only (last resort)

**How it works:** Accept that notifications only work while the app is in the foreground. No service worker integration. Optionally poll for notification counts via the web page DOM and surface a badge.

**Trade-offs:**
- Minimal — no infrastructure changes
- Severely limited UX — notifications are the whole point of this phase
- Choose only if Options A and B are both technically blocked

## Native iOS Context

**Minimum deployment target:** iOS 17 (Web Push APIs available since iOS 16.4 — we are covered)

**Existing infrastructure relevant to this phase:**
- `WebViewConfiguration.swift` — `WKUserContentController` is already wired; notification permission injection script can be added here
- `DataStoreManager` — separate `WKWebsiteDataStore` per platform; service worker data is stored here; do not use ephemeral data store for Instagram or service worker registration will not persist
- `UNUserNotificationCenter` — not yet wired in the app; Phase 3 must request permission at app launch or on first Instagram session

**Permission request timing:** Request `UNUserNotificationCenter` permission when the user first visits Instagram, not at app launch. Requesting at launch before context is established reduces grant rate.

## Instagram PWA Specifics

- Instagram registers a service worker at document load (path varies; verify in Web Inspector)
- Instagram uses the Push API (`PushManager`) and Notification API — both must be accessible from WKWebView
- The PWA manifest (`<link rel="manifest">`) must survive Phase 2 injection untouched
- Service worker scope and registration URL must be verified before closing Phase 2

## Key Uncertainty to Investigate

**The closed-app question:** Does iOS 16.4+ Web Push in WKWebView automatically deliver notifications after force-quit, or does it require an APNs bridge?

This is the critical unknown. The answer determines whether Phase 3 is a small feature or a significant infrastructure build. Test with a physical device (simulator does not reliably test APNs delivery).

**Research before starting Phase 3 plans:**
1. Can `PushManager.subscribe()` succeed in WKWebView on iOS 17+?
2. Do notifications arrive when the app is backgrounded (suspended)?
3. Do notifications arrive after force-quit?
4. Is a backend relay required for Option B, or does WKWebView APNs registration work end-to-end with Instagram's existing push backend?

## Deferred Questions

1. **Backend relay necessity:** If Option B is required, does it need a ZenSocial-controlled backend to relay push tokens, or does Instagram's APNs send directly to the device? This is unknown until the push token flow is traced.

2. **Force-quit as hard requirement:** Is force-quit push delivery a launch requirement? Current position (D-05): it is a nice-to-have. If user research or early feedback indicates it is a blocker, escalate to Option B.

3. **Notification content:** Can Instagram's push payload (title, body, badge count) be read from the service worker push event and surfaced natively? Verify that the payload is not encrypted in a way that prevents bridging.

</specifics>

<canonical_refs>
- Apple Developer: UNUserNotificationCenter — https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
- Apple Developer: Web Push for Web Apps on iOS — https://webkit.org/blog/13152/webkit-features-in-safari-16-4/ (iOS 16.4 Web Push announcement)
- Apple Developer: Enabling the Push Notifications Capability — https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns
- W3C Push API — https://www.w3.org/TR/push-api/ (PushManager, PushSubscription)
- W3C Service Workers — https://www.w3.org/TR/service-workers/ (service worker lifecycle)
- WWDC 2023: What's new in Web Inspector — relevant for verifying service worker registration via Safari Web Inspector
</canonical_refs>
