# Roadmap: ZenSocial

## Overview

ZenSocial delivers a calm, intentional social media experience on iOS by wrapping Instagram and YouTube in a native shell, injecting a dark theme, and blocking short-form video distractions. The build follows a strict dependency chain: a native shell that passes App Store review (Phase 1), then the injection engine proven with theme CSS (Phase 2), then push notifications through the WKWebView context (Phase 3), then feature blocking through the injection engine (Phase 4), and finally user-facing settings to control blocks (Phase 5). Each phase produces a working, testable app -- not partial layers.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Native Shell + WKWebView Foundation** - Working iOS app that loads Instagram and YouTube in a native tab bar with persistent sessions and correct WebView configuration
- [ ] **Phase 2: Injection Engine + Dark Theme** - CSS/JS injection pipeline proven end-to-end by applying ZenSocial's dark theme to both platforms (push notifications deferred to Phase 3)
- [ ] **Phase 3: Push Notifications** - Instagram push notifications via native APNs infrastructure with backend relay for all app states including force-quit
- [ ] **Phase 4: Feature Blocking** - Instagram Reels and YouTube Shorts hidden via two-layer blocking (content rules + DOM injection)
- [ ] **Phase 5: Settings UI** - Native settings screen where users toggle Reels and Shorts blocking per platform

## Phase Details

### Phase 1: Native Shell + WKWebView Foundation
**Goal**: Users can browse Instagram and YouTube in a native-feeling iOS app with persistent login, smooth navigation, and proper error handling
**Depends on**: Nothing (first phase)
**Requirements**: SHELL-01, SHELL-02, SHELL-03, WEB-01, WEB-02, WEB-03, WEB-04, WEB-05, BLOCK-03
**Success Criteria** (what must be TRUE):
  1. User can switch between Instagram and YouTube using a native tab bar at the bottom of the screen
  2. User can browse Instagram feed, profiles, and DMs with full functionality (login, scroll, tap, interact)
  3. User can browse YouTube subscriptions, channels, and videos with full functionality including video playback
  4. User remains logged in to both platforms after force-quitting and relaunching the app
  5. User sees a native loading indicator while pages load and a native error screen when offline or when a platform fails
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project + models, services, and configuration foundation
- [x] 01-02-PLAN.md — WKWebView wrapper, navigation coordinator, and auth modal
- [x] 01-03-PLAN.md — App shell UI (TabView, loading/error states) + human verification

**UI hint**: yes

### Phase 01.1: Native Shell Polish (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 1
**Plans:** 2/2 plans complete

Plans:
- [x] TBD (run /gsd:plan-phase 01.1 to break down) (completed 2026-03-26)

### Phase 01.2: Fixes for features implement over phase 1 and 1.1 (INSERTED)

**Goal:** Fix five interaction bugs from Phase 1/1.1: video audio persisting on platform switch, pill button visibility on wrong screens, pill drag teleport, expanded pill off-screen overflow, and platform content not edge-to-edge
**Requirements**: Captured in 01.2-CONTEXT.md (D-01 through D-09)
**Depends on:** Phase 01.1
**Plans:** 1/2 plans executed

Plans:
- [x] 01.2-01-PLAN.md — Video pause on switch, pill visibility gating, edge-to-edge layout
- [x] 01.2-02-PLAN.md — Pill drag spring animation and direction-aware expansion

### Phase 2: Injection Engine + Dark Theme
**Goal**: ZenSocial's dark, minimal theme is visibly applied to both Instagram and YouTube, proving the injection pipeline works end-to-end
**Depends on**: Phase 1
**Requirements**: INJ-01, INJ-02, INJ-03, INJ-04
**Success Criteria** (what must be TRUE):
  1. User sees ZenSocial's dark theme applied to Instagram pages with no flash of the original light theme (FOUC-free)
  2. User sees ZenSocial's dark theme applied to YouTube pages with no flash of the original light theme
  3. Theme persists correctly across SPA navigations within each platform (navigating between feed, profile, settings does not revert to default styling)
  4. Injection scripts are loaded from external bundle files (not hardcoded Swift strings), verifiable by inspecting the built app bundle
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — ScriptLoader service + Instagram/YouTube theme CSS + WebViewConfiguration integration
- [x] 02-02-PLAN.md — Script failure alert UI (D-10) + human visual verification of dark theme
- [ ] 02-03-PLAN.md — Gap closure: YouTube accent color on custom elements + unauthenticated page theming (awaiting human-verify)

**Note on Push Notifications:** Push notification support is intentionally deferred to Phase 3. Phase 2 CSS/JS injection MUST NOT interfere with Instagram's service worker registration, PWA manifest, or the Push/Notification web APIs — this is a hard prerequisite for Phase 3 to work. Specifically, Phase 2 scripts must not block requests to service worker paths (e.g. `/sw.js`), must not strip `<link rel="manifest">` elements, and must not override or disable `navigator.serviceWorker`, `Notification`, or `PushManager`.

### Phase 3: Push Notifications
**Goal**: Users receive Instagram push notifications as native iOS banners in all app states (foreground, background, force-quit) via APNs infrastructure with a backend relay server
**Depends on**: Phase 2 (injection pipeline must not interfere with Instagram's service worker/PWA APIs)
**Requirements**: PUSH-01, PUSH-02, PUSH-03
**Success Criteria** (what must be TRUE):
  1. User receives Instagram push notifications while the app is running in the foreground (native iOS banner)
  2. User receives Instagram push notifications while the app is suspended in the background
  3. User receives Instagram push notifications after force-quitting the app (requires visible APNs, not silent push)
  4. Native iOS permission prompt appears (preceded by a ZenSocial pre-prompt after first Instagram login)
  5. Tapping a notification deep-links to the relevant Instagram content
**Plans**: 4 plans

Plans:
- [ ] 03-00-PLAN.md — Wave 0: XCTest target + test stubs for notification permission and APNs registration
- [ ] 03-01-PLAN.md — Native notification infrastructure (AppDelegate, NotificationManager, permission flow, entitlements, deep-link routing, Settings toggle, REQUIREMENTS.md update)
- [ ] 03-02-PLAN.md — Architecture decision checkpoint: backend notification monitoring approach (cookie polling, FBNS, or on-device only)
- [ ] 03-03-PLAN.md — Backend relay server implementation + APNs integration + end-to-end human verification

**Key research finding:** Web Push does NOT work in WKWebView (confirmed by Apple). The architecture uses native APNs with a backend relay that independently monitors Instagram notifications and sends visible APNs pushes to the device. This delivers in all three states because visible APNs notifications are handled at the OS level regardless of app process state.

### Phase 4: Feature Blocking
**Goal**: Instagram Reels and YouTube Shorts are completely hidden from the user experience, with blocking that survives SPA navigation
**Depends on**: Phase 3
**Requirements**: BLOCK-01, BLOCK-02
**Success Criteria** (what must be TRUE):
  1. User does not see the Reels tab in Instagram's bottom navigation bar on any page
  2. User does not see the Shorts tab or Shorts shelf on YouTube's interface on any page
  3. Blocking remains active after navigating within each platform (SPA navigation does not restore blocked elements)
**Plans**: TBD

### Phase 5: Settings UI
**Goal**: Users can control which features are blocked through a native settings screen
**Depends on**: Phase 4
**Requirements**: SET-01, SET-02
**Success Criteria** (what must be TRUE):
  1. User can open a native settings screen from the app (not a web page)
  2. User can toggle Instagram Reels blocking on and off, and the change takes effect on the next page load or refresh
  3. User can toggle YouTube Shorts blocking on and off, and the change takes effect on the next page load or refresh
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Native Shell + WKWebView Foundation | 0/3 | Planning complete | - |
| 2. Injection Engine + Dark Theme | 2/3 | Plan 03 awaiting human-verify | 2026-03-27 |
| 3. Push Notifications | 0/4 | Planning complete | - |
| 4. Feature Blocking | 0/TBD | Not started | - |
| 5. Settings UI | 0/TBD | Not started | - |
