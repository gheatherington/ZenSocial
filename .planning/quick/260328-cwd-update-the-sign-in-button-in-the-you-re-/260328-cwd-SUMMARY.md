---
phase: quick
plan: 260328-cwd
subsystem: youtube-theme
tags: [youtube, theme, auth, cta]
dependency_graph:
  requires: []
  provides: [signed-out-sign-in-cta-restored]
  affects: [ZenSocial/Scripts/YouTube/theme.css]
tech_stack:
  added: []
  patterns: [scoped CSS specificity override, container-level selector exclusions]
key_files:
  modified:
    - ZenSocial/Scripts/YouTube/theme.css
decisions:
  - Exclude button renderers from the broad unauthenticated surface darkening rules before restoring the CTA locally
  - Scope the blue CTA restore to ytm-account-controller / ytm-inline-message-renderer / upsell containers so other YouTube buttons keep their existing styling
metrics:
  duration: 8min
  completed_date: "2026-03-28"
  tasks: 1
  files: 1
---

# Quick 260328-cwd: Restore YouTube Signed-Out Sign In CTA Summary

**One-liner:** Re-scoped the YouTube unauthenticated dark-surface rules so the signed-out `Sign in` CTA can render blue again without recoloring unrelated buttons.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Restore blue styling for the signed-out YouTube Sign in CTA | f171ec7 | ZenSocial/Scripts/YouTube/theme.css |

## What Was Built

Updated the unauthenticated YouTube section in `theme.css` so the broad `ytm-account-controller` and `[class*="sign-in"]` dark-surface selectors no longer catch button renderers directly. Added a late, container-scoped restore block for `ytm-account-controller`, `ytm-inline-message-renderer`, `yt-upsell-dialog-renderer`, and `ytm-upsell-dialog-renderer` that reapplies the blue CTA background/border and white text to rendered button descendants (`yt-button-shape`, `ytm-button-renderer`, `yt-button-renderer`, and native `button`).

This keeps the fix local to the signed-out YouTube upsell flow rather than changing the generic global button rules or Google sign-in page styling.

## Deviations from Plan

No code-scope deviations. The blocking human visual verification step is still pending; only automated selector inspection and an Xcode simulator build were completed in this run.

## Self-Check: BUILD PASSED, VISUAL VERIFY PENDING

- [x] `ZenSocial/Scripts/YouTube/theme.css` contains a signed-out CTA-specific override in the unauthenticated YouTube section
- [x] Commit `f171ec7` exists in git log
- [x] `xcodebuild -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded
- [ ] Human-verify in Simulator that the signed-out YouTube `Sign in` CTA is visibly blue again and that unrelated YouTube buttons remain unchanged
