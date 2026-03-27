---
quick_id: 260327-ioe
description: Insert Phase 3 push notifications, renumber phases, update roadmap, create context
date: 2026-03-27
mode: quick
---

# Quick Task 260327-ioe: Insert Phase 3 (Push Notifications), Renumber Phases

## Objective

Restructure the roadmap to insert a new Phase 3 (Push Notifications) between current Phase 2 (Injection Engine + Dark Theme) and current Phase 3 (Feature Blocking). Renumber all downstream phases. Create a CONTEXT.md for the new phase from planning conversation context.

## Tasks

### Task 1: Update ROADMAP.md

**Files:** `.planning/ROADMAP.md`

**Action:**
1. In the Overview paragraph, update the phase sequence description to reference 5 phases instead of 4, noting the push notification phase between injection and feature blocking
2. Update the phase list bullets to reflect the new numbering:
   - Phase 2: Injection Engine + Dark Theme (unchanged goal, add note about push deferred to Phase 3)
   - Phase 3: Push Notifications (NEW)
   - Phase 4: Feature Blocking (was Phase 3)
   - Phase 5: Settings UI (was Phase 4)
3. Add full Phase Details section for Phase 3 (Push Notifications)
4. Update Phase 2 details to note push notifications are intentionally deferred to Phase 3 and that Phase 2 CSS injection must not interfere with Instagram's service worker/PWA registration
5. Update Phase 4 (Feature Blocking) header/number
6. Update Phase 5 (Settings UI) header/number
7. Update the Progress table at the bottom to add Phase 3 row and renumber Phases 4 and 5
8. Update the Execution Order to reference phases 1→2→3→4→5

**Phase 3 details to add:**
- Goal: Enable Instagram web push notifications within the WKWebView context — users receive Instagram push notifications even when the app is suspended (background) or ideally when closed
- Depends on: Phase 2 (injection pipeline must be in place; Instagram PWA/service worker must not be broken by Phase 2 CSS injection)
- Requirements: PUSH-01, PUSH-02, PUSH-03
- Success Criteria:
  1. User receives Instagram push notifications while the app is running in the foreground
  2. User receives Instagram push notifications while the app is suspended in the background
  3. The WKWebView correctly requests notification permission from the user (native iOS permission prompt appears)
  4. Instagram's service worker registers successfully — verifiable via Safari Web Inspector
- Implementation approach to investigate (three options, pick best based on research):
  a. **iOS 16.4+ Web Push in WKWebView** — native support, works foreground/background but not after force-quit
  b. **APNs bridge** — native app receives silent APNs push, wakes WKWebView service worker, surfaces local notification. Requires APNs entitlements, background mode, potentially a backend relay
  c. **Scope to in-app only** — accept that notifications only work while app is running; document limitation
- Key constraint: Phase 2 MUST NOT block service worker registration or strip Instagram's PWA manifest — this is a prerequisite for this phase to work at all

### Task 2: Create Phase 3 CONTEXT.md

**Files:** `.planning/phases/03-push-notifications/03-CONTEXT.md` (create directory too)

**Action:** Create the directory `.planning/phases/03-push-notifications/` and write a CONTEXT.md capturing the full planning conversation context for the push notifications phase.

CONTEXT.md should include:
- Task boundary / goal statement
- Key decisions already made:
  - Push notifications extracted from Phase 2 into own phase
  - Phase 2 must preserve Instagram PWA/service worker compatibility
  - Visual cohesion (dark theme) is Phase 2 only; push is Phase 3
- Three implementation approaches with trade-offs
- Uncertainty flag: need to verify whether closed-app push is achievable without APNs bridge before committing to approach
- Native requirements: iOS notification permissions (UNUserNotificationCenter), potentially APNs entitlements and Background Modes
- Deferred questions: whether a backend relay is acceptable, whether force-quit notification delivery is a hard requirement vs nice-to-have

**done:** Directory `.planning/phases/03-push-notifications/` exists with `03-CONTEXT.md` inside
