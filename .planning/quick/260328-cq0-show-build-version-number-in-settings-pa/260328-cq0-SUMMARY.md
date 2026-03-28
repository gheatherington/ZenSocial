---
phase: quick
plan: 260328-cq0
subsystem: settings-ui
tags: [settings, build-number, ui]
dependency_graph:
  requires: []
  provides: [build-number-display-in-settings]
  affects: [ZenSocial/Views/SettingsPlaceholderView.swift]
tech_stack:
  added: []
  patterns: [Bundle.main.infoDictionary CFBundleVersion runtime read]
key_files:
  modified:
    - ZenSocial/Views/SettingsPlaceholderView.swift
decisions:
  - Read CFBundleVersion from Bundle at runtime — no hardcoded values, auto-updates via prepare-commit-msg hook
metrics:
  duration: 3min
  completed_date: "2026-03-28"
  tasks: 1
  files: 1
---

# Quick 260328-cq0: Show Build Number in Settings Summary

**One-liner:** Reads CFBundleVersion from Bundle at runtime and renders "Build N" in subtle caption2 text beneath "Settings coming soon".

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add build number display to SettingsPlaceholderView | 82baa44 | ZenSocial/Views/SettingsPlaceholderView.swift |

## What Was Built

Added a `buildNumber` computed property to `SettingsPlaceholderView` that reads `CFBundleVersion` from `Bundle.main.infoDictionary`, defaulting to "–" if nil. A `Text("Build \(buildNumber)")` view with `.font(.caption2)` and `.foregroundStyle(.white.opacity(0.3))` was added below the existing "Settings coming soon" label inside the existing `VStack(spacing: 16)`.

Current build is 4 (VERSION file = 4 after this commit incremented it via the prepare-commit-msg hook).

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] `ZenSocial/Views/SettingsPlaceholderView.swift` — modified and committed
- [x] Commit 82baa44 exists in git log
- [x] Build succeeded with `** BUILD SUCCEEDED **`
