---
phase: quick
plan: 260328-cwd
subsystem: youtube-theme
tags: [youtube, theme, auth, cta]
dependency_graph:
  requires: []
  provides: [signed-out-sign-in-cta-restored]
  affects: [ZenSocial/Scripts/YouTube/theme.css, ZenSocial/Scripts/YouTube/nav-fixer.js]
tech_stack:
  added: []
  patterns: [scoped CSS specificity override, DOM-aware JS fallback overlay]
key_files:
  modified:
    - ZenSocial/Scripts/YouTube/theme.css
    - ZenSocial/Scripts/YouTube/nav-fixer.js
decisions:
  - Exclude button renderers from the broad unauthenticated surface darkening rules before restoring the CTA locally
  - When YouTube's rendered CTA did not expose a stable styleable DOM target, fall back to a signed-out-page-only injected CTA in nav-fixer.js wired to YouTube's sign-in URL
metrics:
  duration: 24min
  completed_date: "2026-03-28"
  tasks: 1
  files: 2
---

# Quick 260328-cwd: Restore YouTube Signed-Out Sign In CTA Summary

**One-liner:** Restored a visible blue `Sign in` button on YouTube's signed-out page by combining the earlier scoped CSS change with a DOM-aware JS fallback in the injected YouTube fixer script.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Restore blue styling for the signed-out YouTube Sign in CTA | f171ec7 | ZenSocial/Scripts/YouTube/theme.css |
| 2 | Add DOM-aware signed-out CTA fallback in YouTube nav fixer | 23b394a | ZenSocial/Scripts/YouTube/nav-fixer.js |

## What Was Built

Updated the unauthenticated YouTube section in `theme.css` so the broad `ytm-account-controller` and `[class*="sign-in"]` dark-surface selectors no longer catch button renderers directly. Added a late, container-scoped restore block for `ytm-account-controller`, `ytm-inline-message-renderer`, `yt-upsell-dialog-renderer`, and `ytm-upsell-dialog-renderer` that reapplies the blue CTA background/border and white text to rendered button descendants (`yt-button-shape`, `ytm-button-renderer`, `yt-button-renderer`, and native `button`).

When that CSS-only path still failed against YouTube's live signed-out CTA markup, `nav-fixer.js` was extended with a signed-out-page-only fallback: it detects the `You're not signed in` screen, preserves the dark account-page background logic, injects a blue CTA overlay wired to YouTube's real sign-in URL, and suppresses the centered native plain-text label so the final page presents a single visible blue button.

## Deviations from Plan

The plan targeted a `theme.css`-only fix. That was insufficient against YouTube's live signed-out CTA rendering, so the final solution added a scoped JS fallback in `ZenSocial/Scripts/YouTube/nav-fixer.js`. This was a deliberate deviation to restore the visible button state without broadening accent styling across unrelated YouTube UI.

## Self-Check: PASSED

- [x] `ZenSocial/Scripts/YouTube/theme.css` contains a signed-out CTA-specific override in the unauthenticated YouTube section
- [x] `ZenSocial/Scripts/YouTube/nav-fixer.js` contains the signed-out CTA fallback and fixed-element exemption
- [x] Commits `f171ec7` and `23b394a` exist in git log
- [x] `xcodebuild -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded
- [x] Human-verified in Simulator that the signed-out YouTube page shows a blue `Sign in` button again: `/tmp/zensocial-sim/screen-094105.png`
