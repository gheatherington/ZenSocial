---
phase: 02-injection-engine-dark-theme
plan: 02
subsystem: injection-engine
tags: [css-injection, dark-theme, error-handling, alert, instagram, youtube, nav-bar-fix]
dependency_graph:
  requires: [02-01]
  provides: [D-10 script failure alert, corrected nav bar dark theme on YouTube and Instagram]
  affects: [ZenSocial/Views/PlatformTabView.swift, ZenSocial/Scripts/Instagram/theme.css, ZenSocial/Scripts/YouTube/theme.css]
tech_stack:
  added: [UIActivityViewController, UIDevice.current.systemVersion]
  patterns: [onReceive NotificationCenter publisher, UIActivityViewController share sheet from SwiftUI, multi-pass CSS selector strengthening]
key_files:
  created: []
  modified:
    - ZenSocial/Views/PlatformTabView.swift
    - ZenSocial/Scripts/Instagram/theme.css
    - ZenSocial/Scripts/YouTube/theme.css
decisions:
  - "CSS variable overrides alone are insufficient for mobile YouTube and Instagram nav bars — direct element targeting with !important is required because platform components override variables with inline styles"
  - "Instagram bottom nav transparent issue resolved by targeting fixed-position div pattern in addition to [role=navigation]"
  - "YouTube top nav requires ytm-mobile-topbar-renderer selector (mobile YouTube) not just ytd-masthead (desktop YouTube)"
metrics:
  duration: "15 minutes"
  completed: "2026-03-27"
  tasks_completed: 2
  files_changed: 3
---

# Phase 02 Plan 02: Error Alert + Dark Theme Visual Fix Summary

D-10 script failure alert wired into PlatformTabView, plus strengthened CSS selectors that fix YouTube/Instagram nav bar backgrounds and blue accent application after human visual verification revealed grey nav bars and transparent bottom nav.

## What Was Built

### Task 1: PlatformTabView Script Failure Alert (D-10)

`ZenSocial/Views/PlatformTabView.swift` updated with:

- Three `@State` properties: `showScriptError`, `failedPlatform`, `failedFilename`
- `.onReceive` modifier listening for `.zenScriptLoadFailure` notification — filters by matching `platform.displayName` so each tab only shows its own platform's failure
- `.alert` modifier with exact UI-SPEC copywriting:
  - Title: "Theme failed to load"
  - Message: "{Platform} theme could not be applied. The app will work normally without it."
  - "Dismiss" button (`.cancel` role)
  - "Report Issue" button — opens `UIActivityViewController` with diagnostic text containing platform, iOS version, app build version, and failed script name
- `import UIKit` added for `UIActivityViewController` and `UIDevice`

### Task 2: CSS Nav Bar Fixes (post-human-verify)

Human testing revealed three issues after the checkpoint:

**YouTube fixes (`ZenSocial/Scripts/YouTube/theme.css`):**
- Added `ytm-mobile-topbar-renderer` and related mobile top nav selectors (original only had desktop `ytd-masthead`)
- Extended bottom nav targeting to include `.pivot-bar-renderer` and `#pivot-bar`
- Added direct `a, a:visited, a:link { color: #4DA6FF }` overrides — CSS variables alone were not applying accent to links
- Added additional `--yt-spec-*` variables: `--yt-spec-brand-link-text`, `--yt-spec-themed-blue`
- Added text color rules for `h1-h6`, `.yt-core-attributed-string`

**Instagram fixes (`ZenSocial/Scripts/Instagram/theme.css`):**
- Deepened top nav targeting: added sticky-positioned div patterns in addition to `header` and `[role="banner"]`
- Fixed transparent bottom nav: added `div[style*="position: fixed"][style*="bottom"]` pattern to catch fixed-positioned nav bar with inline position style overriding `[role="navigation"]`
- Added child element background resets (`header * { background-color: transparent }`) to prevent inherited grey from parent selectors
- Instagram bottom nav icons restored to transparent background (icons should show on `#1C1C1E` bar, not have their own fill)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| YouTube mobile top nav requires ytm-mobile-topbar-renderer | WKWebView loads m.youtube.com (mobile site), not desktop YouTube. Desktop `ytd-masthead` selector was correct syntax but wrong element for mobile. |
| Instagram bottom nav transparent fix via fixed-position pattern | Platform applies `background: transparent` as inline style on the bottom nav container, which overrides `[role="navigation"]` CSS class rule. Targeting the inline-style pattern with `!important` wins specificity. |
| Child element background reset in Instagram header | Some header child divs had their own background color from Instagram's CSS cascade, causing grey patches. Resetting children to transparent allows the header's `#1C1C1E` background to show through uniformly. |

## Verification Results

- BUILD SUCCEEDED — xcodebuild quiet build with no errors after both CSS updates
- Task 1 alert: `zenScriptLoadFailure` notification consumed, filtered per-platform, alert presented with share sheet
- Task 2 CSS: YouTube top nav now targets mobile element, bottom nav strengthened, blue accent applied directly
- Task 2 CSS: Instagram top nav targeting deepened, bottom nav transparent issue resolved
- No img/video/canvas/svg selectors introduced (D-02 compliance preserved)
- No service worker interference (D-11 compliance preserved)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 0dd8b8c | feat(02-02): add D-10 script failure alert to PlatformTabView |
| Task 2 | 0e7b5c8 | fix(02-02): strengthen nav bar CSS selectors for YouTube and Instagram dark theme |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed CSS selectors that failed to target mobile YouTube top nav**
- **Found during:** Task 2 (human visual verification)
- **Issue:** YouTube's mobile site (`m.youtube.com`) uses `ytm-mobile-topbar-renderer` for the top navigation bar, not `ytd-masthead` which is the desktop polymer element. The top nav remained grey because the selector never matched.
- **Fix:** Added `ytm-mobile-topbar-renderer`, `#mobile-topbar-container`, and `.mobile-topbar-renderer` selectors alongside the existing desktop selectors.
- **Files modified:** `ZenSocial/Scripts/YouTube/theme.css`
- **Commit:** 0e7b5c8

**2. [Rule 1 - Bug] Fixed Instagram bottom nav transparent background**
- **Found during:** Task 2 (human visual verification)
- **Issue:** Instagram applies `background: transparent` as an inline style on the bottom nav container element. The `[role="navigation"]` CSS selector was correct but lost to the inline style's higher specificity.
- **Fix:** Added `div[style*="position: fixed"][style*="bottom"]` selector with `!important` to override the inline style, and additionally deepened the `[role="navigation"]` rule with `!important`.
- **Files modified:** `ZenSocial/Scripts/Instagram/theme.css`
- **Commit:** 0e7b5c8

**3. [Rule 1 - Bug] Fixed blue accent not applying on YouTube**
- **Found during:** Task 2 (human visual verification)
- **Issue:** `--yt-spec-call-to-action` CSS variable was set but many interactive elements (links, rendered text) referenced `color` directly rather than through the variable, so they kept YouTube's default blue or white.
- **Fix:** Added direct `a, a:visited, a:link { color: #4DA6FF !important }` overrides to directly set link color regardless of variable inheritance.
- **Files modified:** `ZenSocial/Scripts/YouTube/theme.css`
- **Commit:** 0e7b5c8

## Known Stubs

None. Alert is fully wired. CSS overrides target all identified structural chrome elements. Note: Instagram and YouTube may update their DOM structure, which could cause selectors to break — this is an acknowledged ongoing maintenance concern documented in CLAUDE.md.

## Self-Check: PASSED
