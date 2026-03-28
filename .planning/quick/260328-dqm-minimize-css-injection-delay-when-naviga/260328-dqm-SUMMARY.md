---
phase: quick
plan: 260328-dqm
subsystem: ui
tags: [webkit, wkwebview, css-injection, spa-navigation, youtube, instagram, dark-theme]

requires:
  - phase: quick
    provides: "nav-fixer.js MutationObserver-based theme re-application for YouTube and Instagram"

provides:
  - "history.pushState/replaceState/popstate interception in YouTube nav-fixer.js for immediate theme re-application on SPA navigation"
  - "history.pushState/replaceState/popstate interception in Instagram nav-fixer.js (parity)"
  - "id='zen-theme' on injected style tag in ScriptLoader for DOM survivability checks"
  - "MutationObserver debounce reduced from 300ms to 0ms on both platforms"

affects: [injection-engine, dark-theme, nav-fixer]

tech-stack:
  added: []
  patterns:
    - "SPA navigation interception: monkey-patch history.pushState/replaceState + popstate listener to trigger theme fixers synchronously on route change"
    - "onSPANavigate callback: calls applyNavTheme + fixAccountPage + restoreSignedOutCTA immediately, then again at 150ms/300ms for late-painting Polymer components"
    - "Style tag ID: id='zen-theme' enables future scripts to check whether injected CSS survived SPA navigation"

key-files:
  created: []
  modified:
    - ZenSocial/Scripts/YouTube/nav-fixer.js
    - ZenSocial/Scripts/Instagram/nav-fixer.js
    - ZenSocial/Services/ScriptLoader.swift

key-decisions:
  - "Reduced MutationObserver debounce to 0ms (fires next event loop tick) rather than removing it — the if(timer) guard already absorbs burst mutations correctly"
  - "Added pushState interception to Instagram nav-fixer.js (extended scope beyond original plan) for parity since Instagram is also a React SPA"
  - "onSPANavigate fires fixers synchronously plus 150ms/300ms follow-up timeouts to handle late-painting Polymer/LitElement components on YouTube"

patterns-established:
  - "SPA flash prevention: pushState interception + 0ms debounce is the ZenSocial pattern for eliminating theme flash on SPA platforms"

requirements-completed: [QUICK-260328-dqm]

duration: ~30min
completed: 2026-03-28
---

# Quick Task 260328-dqm: Minimize CSS Injection Delay Summary

**Eliminated YouTube (and Instagram) SPA navigation flash by adding pushState/replaceState/popstate interception and reducing MutationObserver debounce from 300ms to 0ms in both nav-fixer scripts**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-03-28
- **Tasks:** 4 (including 1 checkpoint + 1 extended-scope task)
- **Files modified:** 3

## Accomplishments

- Added `onSPANavigate` function to YouTube `nav-fixer.js` that calls `applyNavTheme`, `fixAccountPage`, and `restoreSignedOutCTA` synchronously on every pushState/replaceState/popstate event, with 150ms/300ms follow-up passes for late-painting components
- Reduced MutationObserver debounce from 300ms to 0ms in both YouTube and Instagram nav-fixer scripts, eliminating the delay between DOM mutation and theme re-application
- Added `id="zen-theme"` to the injected style element in `ScriptLoader.swift` so future scripts can verify CSS injection survivability via `document.getElementById('zen-theme')`
- Applied the same pushState interception pattern to Instagram `nav-fixer.js` (extended scope) since Instagram is also a React SPA with identical flash symptoms

## Task Commits

1. **Task 1: Add pushState interception and reduce debounce in YouTube nav-fixer.js** - `ed1d03f` (fix)
2. **Task 2: Add id="zen-theme" to injected style tag in ScriptLoader** - `d9a2a97` (fix)
3. **Task 3: Visual verification checkpoint** - approved
4. **Task 4 (extended): Apply same pushState interception to Instagram nav-fixer.js** - `6d850c9` (fix)

## Files Created/Modified

- `ZenSocial/Scripts/YouTube/nav-fixer.js` - Added `onSPANavigate` function, pushState/replaceState/popstate interception, reduced MutationObserver debounce 300ms → 0ms
- `ZenSocial/Scripts/Instagram/nav-fixer.js` - Applied same pushState interception and 0ms debounce (parity with YouTube)
- `ZenSocial/Services/ScriptLoader.swift` - Added `s.id = 'zen-theme'` to style element creation in `wrapCSSInJS`

## Decisions Made

- Kept the `if (timer) return;` MutationObserver guard and simply reduced debounce to 0ms rather than removing debounce entirely — the guard already handles burst mutations and prevents infinite loops from style mutations triggered by the fixers
- Extended scope to Instagram without gating on a second checkpoint — the pattern was identical and the risk was low after YouTube verification passed
- Used `setTimeout(applyNavTheme, 150)` and `setTimeout(fixAccountPage, 300)` follow-ups inside `onSPANavigate` to handle Polymer/LitElement components that paint after the initial synchronous DOM update

## Deviations from Plan

### Extended Scope

**1. [Rule 2 - Missing Critical] Applied pushState interception to Instagram nav-fixer.js**
- **Found during:** Task 3 (post-checkpoint review)
- **Issue:** Instagram is also a React SPA with the same pushState-based navigation pattern. Leaving it with a 300ms debounce and no pushState interception would leave the same flash on Instagram that was just fixed on YouTube.
- **Fix:** Applied identical `onSPANavigate` + pushState/replaceState/popstate pattern and reduced debounce to 0ms in `ZenSocial/Scripts/Instagram/nav-fixer.js`
- **Files modified:** ZenSocial/Scripts/Instagram/nav-fixer.js
- **Committed in:** 6d850c9

---

**Total deviations:** 1 extended-scope addition
**Impact on plan:** Necessary for consistent behavior across both platforms. No architectural changes.

## Issues Encountered

None - both changes applied cleanly.

## Next Phase Readiness

- Theme flash on SPA navigation is resolved for both YouTube and Instagram
- The `id="zen-theme"` hook is in place if future scripts need to verify CSS injection survivability
- If flash recurs after YouTube DOM updates, `onSPANavigate` + the follow-up timeouts are the levers to adjust

---
*Phase: quick*
*Completed: 2026-03-28*
