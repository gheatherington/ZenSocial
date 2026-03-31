---
phase: 3
name: push-notifications
status: planning
created: 2026-03-27
updated: 2026-03-31
---

# Phase 3: Push Notifications — Context

## Goal

Enable Instagram web push notifications within the WKWebView context. Users must receive Instagram push notifications in the foreground, when the app is suspended in the background, and after force-quit. Force-quit delivery is a hard requirement — this commits Phase 3 to Option B (APNs bridge) rather than Option A (iOS 16.4+ Web Push alone).

<domain>
Instagram push notifications in WKWebView. This phase is architecturally orthogonal to CSS/JS injection (Phase 2) — it touches native iOS notification infrastructure, service worker registration, APNs entitlements, and potentially a backend relay server. Scope is Instagram only; YouTube push is not in scope for this phase.
</domain>

<decisions>

## Implementation Decisions

### Architecture

- **D-01:** Push notifications extracted from Phase 2 into a dedicated phase — architecturally independent concern; mixing would bloat Phase 2 and make it harder to test each concern in isolation.

- **D-02:** Phase 2 must preserve Instagram's service worker and PWA compatibility. Phase 2 injection scripts must not block service worker paths, strip `<link rel="manifest">`, or override `navigator.serviceWorker`, `Notification`, or `PushManager`. Confirmed by Phase 2 D-11 — this prerequisite is locked in.

- **D-03:** Dark theme (Phase 2) and push notifications (Phase 3) are separate concerns. Phase 3 has no UI deliverables beyond the permission prompt and notification banner.

### Implementation Approach

- **D-04 (UPDATED):** Commit to Option B — APNs bridge. Option A (iOS 16.4+ Web Push in WKWebView) does not guarantee force-quit delivery. Phase 3 must handle the force-quit case, so Option B is the target from the start. Research should still verify whether iOS handles APNs registration transparently before building a relay, but the success bar is: all three states (foreground, suspended, force-quit) must deliver.

- **D-05 (UPDATED):** Force-quit push delivery is a **hard requirement**, not a nice-to-have. If a user force-quits the app, Instagram push notifications must still arrive. This is what distinguishes ZenSocial as a real replacement for the native Instagram app, not a browser tab.

- **D-06:** A backend relay server is acceptable if required for force-quit delivery. Also opens the door to future features (notification filtering, cross-device sync). Research should determine whether a relay is strictly necessary or whether the APNs bridge can work end-to-end without one.

### Option B: APNs Bridge (Target Architecture)

**How it works:** Instagram's backend sends a push to APNs. The native app receives a silent APNs push (Background Modes: remote-notification), wakes the app process, triggers the WKWebView to execute a message into the service worker, which surfaces a `UNUserNotificationCenter` local notification.

**Entitlements needed:**
- `aps-environment` (development / production)
- `UIBackgroundModes`: `remote-notification`

**Native APIs:**
- `UNUserNotificationCenter` — request permission, present local notifications, foreground handling delegate
- `WKScriptMessageHandler` — bridge from native to WKWebView service worker
- `PKPushRegistry` — only if silent APNs delivery proves unreliable; avoid VoIP type (App Store scrutiny)

**Backend relay (if needed):**
- Receives Instagram's Web Push payload
- Forwards to APNs using device token registered by the native app
- Lightweight — no user accounts, no storage; stateless relay

### Permission UX

- **D-07:** Permission prompt triggers after the user's first successful Instagram login (not at app launch, not cold). Requesting permission before the user has established context reduces grant rate.

- **D-08:** A Settings toggle allows the user to disable or re-enable Instagram push notifications after initial grant or denial. If the user denied the iOS system prompt, the Settings toggle links to iOS Settings to re-enable.

- **D-09:** A brief native pre-prompt (alert or modal) appears before the iOS system permission dialog. Sets context for why ZenSocial is requesting notifications. Copy TBD at implementation — keep it intentional and calm, aligned with ZenSocial's brand (not "never miss a moment" style urgency).

### Foreground & Tap Behavior

- **D-10:** When a push arrives while the app is in the foreground, intercept it and surface a native `UNUserNotificationCenter` banner. Do not rely on Instagram's in-page notification UI — native banner provides consistent iOS feel across all app states.

- **D-11:** Tapping a notification (from any state — foreground banner, background, or force-quit) deep-links Instagram to the relevant content by loading the URL extracted from the push payload. Switch to the Instagram tab if needed.

### Claude's Discretion

- Exact payload parsing strategy for extracting deep-link URLs
- Whether to use `UNNotificationServiceExtension` or handle payload in the main app delegate
- Silent push vs background fetch for waking the app
- Notification grouping/threading behavior
- Badge count handling

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Apple Notifications
- Apple Developer: UNUserNotificationCenter — https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
- Apple Developer: Registering Your App with APNs — https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns
- Apple Developer: Handling Notifications and Notification-Related Actions — https://developer.apple.com/documentation/usernotifications/handling_notifications_and_notification-related_actions

### Web Push in WKWebView
- WebKit Blog: Web Push for Web Apps on iOS — https://webkit.org/blog/13152/webkit-features-in-safari-16-4/ (iOS 16.4 Web Push announcement — relevant even though we're going Option B)
- W3C Push API — https://www.w3.org/TR/push-api/ (PushManager, PushSubscription)
- W3C Service Workers — https://www.w3.org/TR/service-workers/ (service worker lifecycle)

### Project Context
- `.planning/REQUIREMENTS.md` — Note: "Push notifications from platforms" is currently listed as Out of Scope. REQUIREMENTS.md should be updated before Phase 3 planning closes — push notifications are in scope as of Phase 3 commitment.
- `.planning/phases/02-injection-engine-dark-theme/02-CONTEXT.md` — D-11 confirms Phase 2 injection scripts do not interfere with service worker, PWA manifest, or web push APIs.
- `CLAUDE.md` (project-level) — Canonical stack decisions (WKWebView via UIViewRepresentable, WKUserContentController injection pattern).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ZenSocial/Services/DataStoreManager.swift` — manages separate `WKWebsiteDataStore` per platform; service worker registration data lives here. Phase 3 must NOT use ephemeral data store for Instagram or service worker registration will not persist.
- `ZenSocial/WebView/WebViewConfiguration.swift` — `WKUserContentController` already wired; notification permission injection script can be added here alongside existing theme scripts.
- `ZenSocial/Services/ScriptLoader.swift` — existing script loading pattern; Phase 3 may need a small JS bridge script injected at `atDocumentStart` to communicate service worker state to native.

### Established Patterns
- Script injection via `WKUserContentController` + `WKUserScript` — Phase 3 uses same mechanism for any JS bridge needed between service worker and native
- Platform-specific script directories (`Scripts/Instagram/`, `Scripts/YouTube/`) — any Phase 3 JS files follow same convention

### Integration Points
- `UNUserNotificationCenter` is not yet wired anywhere in the app — Phase 3 adds it fresh
- App delegate or `ZenSocialApp.swift` — notification delegate registration needed at launch
- Instagram tab / `PlatformTabView.swift` — post-login trigger for permission prompt

</code_context>

<specifics>

## Specific Requirements

- Force-quit delivery is non-negotiable — this is what makes ZenSocial a real Instagram replacement, not a browser tab
- Backend relay is acceptable; can serve as foundation for future notification features
- Permission flow: login detected → brief pre-prompt → iOS system dialog → Settings toggle available
- Foreground behavior: always show native banner, never rely on in-page UI
- Notification tap: always deep-link, always switch to Instagram tab

## Key Uncertainties to Investigate (Pre-Planning)

1. Can `PushManager.subscribe()` succeed in WKWebView on iOS 17+, and does it register a device token that the native app can intercept?
2. Is a ZenSocial backend relay strictly required, or does iOS transparently bridge the Web Push → APNs registration?
3. Does `UIBackgroundModes: remote-notification` wake the app after force-quit reliably for Instagram's push payloads?
4. Can the push payload be read without decryption (or does the native side receive a pointer to Instagram's encrypted payload)?
5. What URL format does Instagram include in push payloads for deep-link targets?

</specifics>

<deferred>
## Deferred Ideas

- YouTube push notifications — separate phase; out of scope for Phase 3
- Notification filtering / quiet hours — future feature enabled by backend relay
- Cross-device sync of notification preferences — future; depends on backend relay

### Reviewed Todos (not folded)
- "Stop playing videos after platform has been closed" — matched by keyword but is a media/tab-switching concern, not a push notification concern. Belongs in a polish/bug-fix phase.

### Note on REQUIREMENTS.md
"Push notifications from platforms" is currently listed as Out of Scope in REQUIREMENTS.md with the rationale "Core driver of compulsive usage; contradicts intentional-use value prop." This entry predates Phase 3 being added to the roadmap and should be removed or moved to Active requirements before Phase 3 planning starts. Downstream agents should treat ROADMAP.md Phase 3 as authoritative.

</deferred>

---

*Phase: 03-push-notifications*
*Context gathered: 2026-03-31*
