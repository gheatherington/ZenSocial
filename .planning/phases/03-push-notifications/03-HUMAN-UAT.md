---
status: partial
phase: 03-push-notifications
source: [03-VERIFICATION.md]
started: 2026-04-03T10:00:00Z
updated: 2026-04-03T10:00:00Z
---

## Current Test

[awaiting human testing on device]

## Tests

### 1. Foreground banner appears when Instagram has unseen notifications
expected: When ZenSocial is open (foreground) and Instagram has unread notifications, a native iOS banner appears within 30 seconds of the badge state changing
result: [pending]

### 2. Background polling fires after app is suspended
expected: When ZenSocial is suspended (not force-quit) and Instagram has new activity, BGAppRefreshTask fires and delivers a local notification banner
result: [pending]

### 3. Notification tap deep-links to Instagram tab
expected: Tapping a ZenSocial notification dismisses the banner and navigates to the Instagram tab in the app
result: [pending]

### 4. Settings toggle disables notification delivery
expected: Disabling the "Instagram Notifications" toggle in Settings prevents both foreground banners and background notifications from appearing
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
