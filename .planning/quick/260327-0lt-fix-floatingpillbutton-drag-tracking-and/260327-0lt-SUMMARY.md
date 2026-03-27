---
type: quick
scope: single-file
files_modified:
  - ZenSocial/Views/FloatingPillButton.swift
completed: "2026-03-27T04:30:02Z"
duration: "2min"
tasks_completed: 2
tasks_total: 2
---

# Quick Task 260327-0lt: Fix FloatingPillButton Drag Tracking and Expansion Summary

**One-liner:** Real-time drag tracking via direct pillPosition updates, centered pill expansion with edge-aware offset fallback.

## Changes Made

### Task 1: Fix drag tracking to follow finger in real time
**Commit:** a787cb6

- Removed `@State private var dragOffset: CGSize` and `.offset(dragOffset)` indirection
- Added `@State private var isDragging: Bool` and `@State private var dragStartPosition: CGPoint`
- Drag `.onChanged` now captures start position on first event, then updates `nav.pillPosition` directly each frame
- Drag `.onEnded` clears dragging state, clamps position, spring-animates to clamped, saves

### Task 2: Center expanded pill by default, offset only near edges
**Commit:** 5bc0376

- Removed `expandsLeft: Bool` computed property (always expanded left or right based on screen half)
- Added `expandedPillOffset: CGFloat` computed property that returns 0 when centered expansion fits within screen
- Only applies a positive (shift right) or negative (shift left) offset when expanded pill would clip past `edgeMargin`
- Expanded pill body uses `.offset(x: expandedPillOffset)` instead of the binary left/right calculation

## Verification

- `xcodebuild` BUILD SUCCEEDED on both task commits
- No references to `dragOffset` or `expandsLeft` remain in FloatingPillButton.swift
- All success criteria met

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
