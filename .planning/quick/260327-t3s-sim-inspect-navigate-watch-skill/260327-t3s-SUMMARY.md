---
phase: quick
plan: 260327-t3s
subsystem: tooling
tags: [simulator, debugging, workflow, skills]
dependency_graph:
  requires: []
  provides: [sim-inspect-navigate, sim-inspect-watch, sim-inspect-skill]
  affects: [Scripts/sim-inspect.sh, .claude/skills/sim-inspect.md]
tech_stack:
  added: []
  patterns: [xcrun-simctl-spawn-defaults-write, UserDefaults-navigation]
key_files:
  created:
    - .claude/skills/sim-inspect.md
  modified:
    - Scripts/sim-inspect.sh
decisions:
  - "navigate command uses xcrun simctl spawn booted defaults write (not simctl launch flags) to write to app's UserDefaults domain directly"
  - ".claude/skills/sim-inspect.md is gitignored by design — lives on disk for Claude session access, not in git"
metrics:
  duration: 5min
  completed_date: 2026-03-27
  tasks: 2
  files: 2
---

# Quick Task 260327-t3s Summary

**One-liner:** Extended sim-inspect.sh with navigate (UserDefaults + relaunch) and watch (screenshot loop) commands; created .claude/skills/sim-inspect.md reference for future Claude sessions.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add navigate and watch commands to sim-inspect.sh | 676e10f | Scripts/sim-inspect.sh |
| 2 | Create .claude/skills/sim-inspect.md skill file | (disk only — gitignored) | .claude/skills/sim-inspect.md |

## What Was Built

### Task 1: navigate and watch commands

Added to `Scripts/sim-inspect.sh` before the `build|*` catch-all:

**navigate:** Writes `lastPlatform` to the app's UserDefaults domain via `xcrun simctl spawn booted defaults write com.zensocial.app lastPlatform <value>`, then terminates and relaunches the app. On relaunch, `NavigationState.restoreLastPlatform()` reads the key and switches tabs automatically. Returns a screenshot path. Valid values: `instagram`, `youtube`, `home`.

**watch:** Loops `xcrun simctl io booted screenshot` at a configurable interval (default 3s), printing each file path. Ctrl+C to stop. Useful for live CSS iteration.

Updated usage comment block at top of file to document both new commands.

### Task 2: Skill file

Created `.claude/skills/sim-inspect.md` at the project root `.claude/` directory. Documents all seven commands (build, screenshot, navigate, watch, tap, swipe, winpos) with usage examples, explains the UserDefaults/restoreLastPlatform mechanism, and includes key facts and troubleshooting notes.

The `.claude/` directory is gitignored by design — the skill file lives on disk and is accessible to all future Claude sessions running from this project directory.

## Deviations from Plan

**1. [Rule 2 - Deviation] Skill file not git-committed**
- **Found during:** Task 2
- **Issue:** `.claude/` is listed in `.gitignore` as "Claude Code internal state." The plan's `files_modified` includes `.claude/skills/sim-inspect.md` but the directory is intentionally untracked.
- **Resolution:** File created at the correct canonical location (`/Users/gavin/Documents/Projects/ZenSocial/.claude/skills/sim-inspect.md`) on disk. Future Claude sessions will find it via the project_context skill-discovery mechanism without needing git tracking.
- **No code changes required** — the file's purpose (being readable by future Claude sessions) is fully achieved.

## Known Stubs

None.

## Self-Check

- [x] `bash -n Scripts/sim-inspect.sh` exits 0
- [x] `grep -c "navigate\|watch" Scripts/sim-inspect.sh` returns 5 (>= 4)
- [x] `.claude/skills/sim-inspect.md` exists at project root
- [x] `grep "restoreLastPlatform" .claude/skills/sim-inspect.md` returns match
- [x] Task 1 commit 676e10f verified in git log

## Self-Check: PASSED
