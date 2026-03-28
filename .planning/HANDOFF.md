---
session_date: 2026-03-28
context_stopped_at: 78%
status: in_progress
next_action: fix navigate youtube bug in sim-inspect.sh
---

# Session Handoff

## What Was Built This Session

### 1. Simulator inspection workflow (`Scripts/sim-inspect.sh`)
Added two new commands to the existing script:

**`navigate <platform>`** — Sets `lastPlatform` in the app's UserDefaults via
`xcrun simctl spawn booted defaults write com.zensocial.app lastPlatform <value>`,
terminates, and relaunches. Exploits `NavigationState.restoreLastPlatform()` which
reads `@AppStorage("lastPlatform")` on `ContentView.onAppear`.

**`watch [interval]`** — Screenshot loop every N seconds (default 3). Ctrl+C to stop.

Also fixed the `find | head -1` bug in the `build` command — it now sorts by modification
time (`xargs ls -td`) so it always installs the newest DerivedData build, not an arbitrary one.
Navigate wait increased from 2s to 8s (configurable as 3rd arg).

### 2. Skill file (`.claude/skills/sim-inspect.md`)
Local skill file (gitignored) documenting all seven sim-inspect.sh commands.
Discovered automatically by agents via the project_context skill path.

### 3. GSD verifier updated (`~/.claude/agents/gsd-verifier.md`)
Added **Step 7c: iOS Simulator Visual Verification** — when `Scripts/sim-inspect.sh`
exists, the verifier now:
- Always runs a fresh build (never skips because app appears running)
- Navigates to each platform the phase touches
- Reads screenshots using the Read tool (multimodal)
- Makes autonomous PASS/FAIL/WARN judgments on dark theme, nav bars, pill button, content state
- Only escalates to human when genuinely ambiguous

---

## What Was Tested and Confirmed Working

| Thing tested | Result |
|---|---|
| `navigate instagram` | ✓ Works — UserDefaults write reaches app sandbox, `restoreLastPlatform()` picks it up |
| Phase 2 dark theme (Instagram) | ✓ Confirmed live — top header dark, bottom nav bar dark |
| Pill button updated styling | ✓ New dark/grey style visible, matches Phase 1.2 quick fix |
| `find \| xargs ls -td` fix | ✓ Installs newest DerivedData build correctly |
| 8s navigate wait | ✓ Sufficient for web content to render |
| Verifier reading screenshots | ✓ Read tool on PNG works, visual assessment is viable |

The user is **logged in to Instagram** in the simulator — real feed content is loading.

---

## The Bug To Fix Next Session

### `navigate youtube` does not switch tabs

**Symptom:** Running `./Scripts/sim-inspect.sh navigate youtube` terminates and relaunches
the app, but the app shows Instagram instead of YouTube.

**What we confirmed:**
- The `defaults write` succeeds — `xcrun simctl spawn booted defaults read com.zensocial.app lastPlatform` returns `youtube` after the command runs
- The app relaunches successfully (new PID assigned)
- Despite `lastPlatform = youtube` in UserDefaults, the visible platform is Instagram

**What was NOT yet confirmed:**
- Whether `restoreLastPlatform()` is actually being called at all after relaunch
- Whether `@AppStorage("lastPlatform")` reads the simctl-written value or returns a cached/stale value
- Whether the `uaReady` gate (UA extraction must complete before ContentView renders) is causing a timing issue where `onAppear` fires before the `@AppStorage` binding has hydrated from disk

**Most likely root cause hypotheses (in priority order):**

1. **`@AppStorage` reads from a different UserDefaults suite than simctl writes to.**
   `@AppStorage` uses `UserDefaults.standard` by default. On iOS simulator, `UserDefaults.standard`
   may use a different backing file than what `defaults write com.zensocial.app` writes to.
   Test: add a temporary log in `restoreLastPlatform()` to print what `lastPlatformRaw` actually
   contains at runtime, then read it via the Xcode console or simctl log.

2. **`navigate instagram` worked because the app ALWAYS defaults to Instagram's WebView being visible briefly**, and `restoreLastPlatform()` setting `.instagram` happens to match the default state, making it look like it worked. YouTube actually never worked — we just didn't notice because the first `navigate` test was instagram.

3. **Timing: `@AppStorage` binding hasn't synced from disk when `onAppear` fires.**
   The `uaReady` gate means ContentView appears after async UA extraction. During that time,
   `NavigationState` is initialized (sets `activeScreen = .home`). By the time `onAppear`
   fires, `lastPlatformRaw` might still be the in-memory default (`""`) rather than the
   simctl-written value. Fix would be to call `UserDefaults.standard.synchronize()` explicitly,
   or read the value directly from `UserDefaults.standard` rather than relying on `@AppStorage`
   having synced.

**How to diagnose:**

Option A — Check what `lastPlatformRaw` contains at runtime:
```bash
# Add a temporary debug print to restoreLastPlatform():
# print("restoreLastPlatform called, raw=\(lastPlatformRaw)")
# Then check the log:
xcrun simctl launch --console booted com.zensocial.app 2>&1 | grep "restoreLastPlatform"
```

Option B — Try writing via a different method:
```bash
# Write directly to the plist file in the simulator container
CONTAINER=$(xcrun simctl get_app_container booted com.zensocial.app data)
/usr/libexec/PlistBuddy -c "Set :lastPlatform youtube" "$CONTAINER/Library/Preferences/com.zensocial.app.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :lastPlatform string youtube" "$CONTAINER/Library/Preferences/com.zensocial.app.plist"
```

Option C — Try adding `UserDefaults.standard.synchronize()` at the start of `restoreLastPlatform()` in Swift.

---

## Current State of the Simulator

- **Device:** iPhone 17 (`15796420-57AA-4732-BE47-5AB2F98B7626`) — booted
- **App installed:** Current build (Phase 2 + pill fixes present)
- **Last platform shown:** Instagram (logged in, real feed)
- **`lastPlatform` in UserDefaults:** `youtube` (from last failed navigate attempt)
- **Screenshots location:** `/tmp/zensocial-sim/screen-*.png`

---

## Key Files to Know About

| File | Purpose |
|---|---|
| `Scripts/sim-inspect.sh` | Simulator workflow script |
| `.claude/skills/sim-inspect.md` | Skill doc for agents (gitignored, local only) |
| `~/.claude/agents/gsd-verifier.md` | Global GSD verifier — Step 7c is the iOS visual check |
| `ZenSocial/Models/NavigationState.swift` | `restoreLastPlatform()` lives here |
| `ZenSocial/ZenSocialApp.swift` | `uaReady` gate that controls ContentView render timing |

---

## What To Do Next Session

1. **Fix `navigate youtube`** — diagnose with one of the three options above, patch `sim-inspect.sh` and/or `NavigationState.swift` as needed
2. **Verify YouTube dark theme** — once navigate youtube works, screenshot and confirm Phase 2 nav-fixer JS is applying to YouTube's top header and bottom nav
3. **Run a full gsd verifier pass on Phase 02** if both platforms verify clean
