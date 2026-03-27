---
phase: 02-injection-engine-dark-theme
plan: 01
subsystem: injection-engine
tags: [css-injection, dark-theme, wkwebview, scriptloader, instagram, youtube]
dependency_graph:
  requires: []
  provides: [ScriptLoader.themeScript, Instagram dark theme CSS, YouTube dark theme CSS]
  affects: [WebViewConfiguration, WKUserContentController, all platform web views]
tech_stack:
  added: [os.Logger, Notification.Name extension]
  patterns: [IIFE JS wrapper for CSS injection, folder reference for bundle resources, assertionFailure in DEBUG for missing resources]
key_files:
  created:
    - ZenSocial/Services/ScriptLoader.swift
    - ZenSocial/Scripts/Instagram/theme.css
    - ZenSocial/Scripts/YouTube/theme.css
  modified:
    - ZenSocial/WebView/WebViewConfiguration.swift
    - ZenSocial.xcodeproj/project.pbxproj
decisions:
  - "Used Xcode folder reference (blue folder) for Scripts/ directory to preserve subdirectory structure in bundle — individual file references flatten to root, causing naming conflicts"
  - "CSS files loaded via Bundle.main.url(forResource:withExtension:subdirectory:) with subdirectory=Scripts/{Platform.displayName}"
  - "JS IIFE appends to document.documentElement (not document.head) because head is null at atDocumentStart"
metrics:
  duration: "4 minutes"
  completed: "2026-03-27T22:37:33Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 02 Plan 01: CSS Injection Pipeline and Dark Theme Summary

CSS injection pipeline built end-to-end: ScriptLoader service reads platform CSS from app bundle, wraps in JS IIFE for FOUC-free atDocumentStart injection, wired into WebViewConfiguration — delivering ZenSocial dark theme on Instagram and YouTube from first paint.

## What Was Built

### ScriptLoader.swift (`ZenSocial/Services/ScriptLoader.swift`)

A `@MainActor enum ScriptLoader` (stateless namespace) that:
- Loads `theme.css` from `Scripts/{Platform.displayName}/` via `Bundle.main.url(forResource:withExtension:subdirectory:)`
- Wraps CSS in a JS IIFE that creates a `<style>` element and appends to `document.documentElement` (not `document.head` — null at atDocumentStart)
- Escapes backslashes, backticks, and `$` signs for JS template literal safety
- Returns `WKUserScript` with `injectionTime: .atDocumentStart, forMainFrameOnly: false`
- In DEBUG: `assertionFailure` immediately if CSS file is missing from bundle (D-09)
- In Release: `logger.error` + `NotificationCenter` post with `zenScriptLoadFailure` (D-10)

### Instagram Dark Theme (`ZenSocial/Scripts/Instagram/theme.css`)

Two-pass approach:
- Pass 1: CSS variable overrides in `:root, .__ig-light-mode, .__ig-dark-mode` — forces dark regardless of system mode
- Pass 2: Direct property overrides for `body`, `nav`, `header`, `[role="banner"]`, input fields, links, scrollbars
- FDS (Facebook Design System) variables overridden separately
- Palette: `#000000`, `#1C1C1E`, `#2C2C2E`, `#4DA6FF`, `#FFFFFF`, `#8E8E93`

### YouTube Dark Theme (`ZenSocial/Scripts/YouTube/theme.css`)

- Pass 1: `--yt-spec-*` variable overrides targeting `html[dark]` and `html:not([dark])`
- Pass 2: Direct overrides for `ytm-app`, `ytm-pivot-bar-renderer`, `ytm-searchbox`, links, scrollbars
- YouTube brand red preserved: `--yt-spec-brand-icon-active: #FF0000`

### WebViewConfiguration Integration

Three-line addition after `contentController` creation:
```swift
// Phase 2: Inject platform-specific dark theme CSS
if let themeScript = ScriptLoader.themeScript(for: platform) {
    contentController.addUserScript(themeScript)
}
```

### project.pbxproj

- Added `ScriptLoader.swift` to Services group + Sources build phase
- Added `Scripts/` as a **folder reference** (not individual file references) to preserve subdirectory structure in bundle — both CSS files copy as `Scripts/Instagram/theme.css` and `Scripts/YouTube/theme.css`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Folder reference for Scripts/ in Xcode | Individual file references flatten to bundle root, causing "multiple commands produce theme.css" build error. Folder reference preserves subdirectory hierarchy so Bundle.main.url(subdirectory:) works correctly. |
| Append to document.documentElement, not document.head | document.head is null at atDocumentStart injection time. documentElement is always available at this stage. |
| assertionFailure in DEBUG for missing CSS | Catches misconfigured bundle resources immediately during development — silent failures would be hard to trace. |

## Verification Results

- BUILD SUCCEEDED with no errors
- CSS files confirmed in bundle at `Scripts/Instagram/theme.css` and `Scripts/YouTube/theme.css`
- No service worker / push notification references in any injected content (D-11 compliance)
- No `img, video, canvas, svg` selectors in CSS files (D-02 compliance)
- No `@media (prefers-color-scheme)` queries — comment references only (D-04 compliance)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | cc6161e | feat(02-01): ScriptLoader service and platform CSS files |
| Task 2 | ac43dbd | feat(02-01): wire ScriptLoader into WebViewConfiguration |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Resolved "multiple commands produce theme.css" build error from duplicate file names**
- **Found during:** Task 1 verification (xcodebuild)
- **Issue:** Both `Scripts/Instagram/theme.css` and `Scripts/YouTube/theme.css` have the same filename. Adding them as individual file references in the Resources build phase caused Xcode to try to copy both to `ZenSocial.app/theme.css`, producing a conflict.
- **Fix:** Changed to a single folder reference (`PBXFileReference; lastKnownFileType = folder`) for the `Scripts/` directory. Xcode copies the entire directory tree, preserving `Scripts/Instagram/theme.css` and `Scripts/YouTube/theme.css` paths in the bundle.
- **Files modified:** `ZenSocial.xcodeproj/project.pbxproj`
- **Commit:** cc6161e (included in Task 1 commit)

## Known Stubs

None. All functionality is fully wired: CSS files exist in bundle, ScriptLoader loads them, WebViewConfiguration injects them on every page load.

## Self-Check: PASSED
