# Phase 3: Push Notifications — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 03-push-notifications
**Areas discussed:** Option A vs B, Permission UX, Foreground handling

---

## Option A vs B

| Option | Description | Selected |
|--------|-------------|----------|
| Not important | Foreground + suspended sufficient; document force-quit limitation | |
| Nice-to-have | Try Option A; escalate to Option B only if users report missed notifications | |
| Required | Force-quit delivery is a hard requirement; commit to Option B now | ✓ |

**User's choice:** Required — commit to Option B (APNs bridge)

**Follow-up: Backend relay appetite**

| Option | Description | Selected |
|--------|-------------|----------|
| No backend | Research must find path where iOS handles APNs transparently; reconsider requirement if not possible | |
| Backend if necessary | Willing to build relay only if no other path exists | |
| Backend is fine | Happy to stand up relay; enables future features | ✓ |

**User's choice:** Backend is fine — willing to build relay server; opens door to future notification features.

---

## Permission UX

**When to prompt**

| Option | Description | Selected |
|--------|-------------|----------|
| First Instagram visit | Prompt on first tab load | |
| Opt-in from Settings | No automatic prompt; user enables manually | |
| After first successful login | Wait until user has logged in, then prompt | ✓ |
| You decide | Standard approach | |

**User's choice:** After first successful Instagram login + Settings toggle for re-enable/disable

**Pre-prompt**

| Option | Description | Selected |
|--------|-------------|----------|
| No pre-prompt | iOS system dialog directly | |
| Brief pre-prompt | Modal/alert before system dialog with context | ✓ |
| You decide | Standard approach | |

**User's choice:** Brief pre-prompt before iOS system dialog. Copy TBD at implementation.

---

## Foreground Handling

**When push arrives while app is open**

| Option | Description | Selected |
|--------|-------------|----------|
| Let web handle it | Instagram's service worker shows in-page UI | |
| Native banner | Intercept and surface via UNUserNotificationCenter | ✓ |
| You decide | Standard for WKWebView push apps | |

**User's choice:** Native banner — always intercept, never rely on in-page UI.

**Notification tap behavior**

| Option | Description | Selected |
|--------|-------------|----------|
| Focus Instagram tab | Switch to Instagram tab, do nothing else | |
| Deep-link into Instagram | Navigate to relevant content from payload URL | ✓ |
| You decide | Standard tap behavior | |

**User's choice:** Deep-link into Instagram content from payload URL. Switch to Instagram tab if needed.

---

## Claude's Discretion

- Exact payload parsing strategy for deep-link URL extraction
- Whether to use UNNotificationServiceExtension or handle in main app delegate
- Silent push vs background fetch for waking the app
- Notification grouping/threading
- Badge count handling

## Deferred Ideas

- YouTube push notifications — separate phase
- Notification filtering / quiet hours — future feature
- Cross-device sync of notification preferences — depends on backend relay
