---
phase: 1
slug: native-shell-wkwebview-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in, Xcode) |
| **Config file** | ZenSocialTests/ target in Xcode project |
| **Quick run command** | `xcodebuild test -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing ZenSocialTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | SHELL-01 | build | `xcodebuild build -scheme ZenSocial` | ✅ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | SHELL-02 | unit | `xcodebuild test -only-testing ZenSocialTests/TabBarTests` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 1 | SHELL-03 | unit | `xcodebuild test -only-testing ZenSocialTests/NavigationTests` | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | WEB-01 | unit | `xcodebuild test -only-testing ZenSocialTests/WebViewTests` | ❌ W0 | ⬜ pending |
| 1-02-02 | 02 | 1 | WEB-02 | unit | `xcodebuild test -only-testing ZenSocialTests/UserAgentTests` | ❌ W0 | ⬜ pending |
| 1-02-03 | 02 | 2 | WEB-03 | unit | `xcodebuild test -only-testing ZenSocialTests/DataStoreTests` | ❌ W0 | ⬜ pending |
| 1-02-04 | 02 | 2 | WEB-04 | manual | N/A — login persistence requires device session | — | ⬜ pending |
| 1-03-01 | 03 | 2 | WEB-05 | unit | `xcodebuild test -only-testing ZenSocialTests/LoadingStateTests` | ❌ W0 | ⬜ pending |
| 1-03-02 | 03 | 2 | BLOCK-03 | unit | `xcodebuild test -only-testing ZenSocialTests/ErrorHandlingTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ZenSocialTests/TabBarTests.swift` — stubs for SHELL-01, SHELL-02
- [ ] `ZenSocialTests/NavigationTests.swift` — stubs for SHELL-03
- [ ] `ZenSocialTests/WebViewTests.swift` — stubs for WEB-01
- [ ] `ZenSocialTests/UserAgentTests.swift` — stubs for WEB-02
- [ ] `ZenSocialTests/DataStoreTests.swift` — stubs for WEB-03
- [ ] `ZenSocialTests/LoadingStateTests.swift` — stubs for WEB-05
- [ ] `ZenSocialTests/ErrorHandlingTests.swift` — stubs for BLOCK-03
- [ ] XCTest framework already available — no install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Login persists after force-quit and relaunch | WEB-04 | Requires real/simulated session cookies; no API to inspect WKHTTPCookieStore state in unit tests | 1. Log in to Instagram in simulator, 2. Force-quit app, 3. Relaunch, 4. Verify still logged in |
| YouTube video playback | WEB-01 | Video playback requires real media pipeline; XCTest UI automation does not handle video player | 1. Navigate to YouTube, 2. Tap a video, 3. Verify it plays without crash |
| Instagram "Open in App" interstitial dismissed | WEB-02 | Requires live Instagram response to Safari UA; depends on network/server state | 1. Open Instagram tab, 2. Observe no hard "Open in App" blocker preventing browsing |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
