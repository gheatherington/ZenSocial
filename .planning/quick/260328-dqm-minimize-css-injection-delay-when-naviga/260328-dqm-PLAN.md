---
phase: quick
plan: 260328-dqm
type: execute
wave: 1
depends_on: []
files_modified:
  - ZenSocial/Scripts/YouTube/nav-fixer.js
  - ZenSocial/Services/ScriptLoader.swift
autonomous: false
requirements: [QUICK-260328-dqm]
must_haves:
  truths:
    - "No visible flash of light/unstyled content when tapping between YouTube tabs (Home, Subscriptions, You)"
    - "Nav bars (top and bottom) stay black through SPA route changes"
    - "Signed-out CTA still renders correctly on the You tab when not logged in"
  artifacts:
    - path: "ZenSocial/Scripts/YouTube/nav-fixer.js"
      provides: "history.pushState/replaceState interception + reduced MutationObserver debounce"
      contains: "history.pushState"
    - path: "ZenSocial/Services/ScriptLoader.swift"
      provides: "Style tag with zen-theme ID for survivability checks"
      contains: "zen-theme"
  key_links:
    - from: "nav-fixer.js pushState intercept"
      to: "applyNavTheme + fixAccountPage + restoreSignedOutCTA"
      via: "onSPANavigate function called synchronously after pushState"
      pattern: "onSPANavigate"
---

<objective>
Minimize CSS injection delay when navigating between YouTube pages (SPA tab switches).

Purpose: YouTube uses history.pushState for tab navigation (Home, Subscriptions, You) without full page reloads. The current MutationObserver has a 300ms debounce, creating a visible flash of unstyled/light content on every tab switch. Adding pushState interception triggers immediate re-application of the dark theme, and reducing the debounce closes the remaining gap.

Output: Updated nav-fixer.js with pushState/replaceState/popstate hooks and faster MutationObserver. One-line ScriptLoader change to ID the injected style tag.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ZenSocial/Scripts/YouTube/nav-fixer.js
@ZenSocial/Services/ScriptLoader.swift
@LESSONS.md
@.planning/quick/260328-dqm-minimize-css-injection-delay-when-naviga/260328-dqm-RESEARCH.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add pushState interception and reduce MutationObserver debounce in nav-fixer.js</name>
  <files>ZenSocial/Scripts/YouTube/nav-fixer.js</files>
  <action>
Two changes to nav-fixer.js, both inside the existing IIFE:

**Change A: Add history.pushState/replaceState/popstate interception**

After the existing function definitions (after `restoreSignedOutCTA` function, before the initial `applyNavTheme()` call around line 253), add:

```javascript
// SPA navigation interception — YouTube uses pushState for tab switches.
// Fires theme fixers immediately on route change, before DOM mutations accumulate.
function onSPANavigate() {
    applyNavTheme();
    fixAccountPage();
    restoreSignedOutCTA();
    // Follow-up for late-painting Polymer/LitElement components
    setTimeout(applyNavTheme, 150);
    setTimeout(fixAccountPage, 300);
    setTimeout(restoreSignedOutCTA, 300);
}

var _pushState = history.pushState.bind(history);
var _replaceState = history.replaceState.bind(history);
history.pushState = function() { _pushState.apply(history, arguments); onSPANavigate(); };
history.replaceState = function() { _replaceState.apply(history, arguments); onSPANavigate(); };
window.addEventListener('popstate', onSPANavigate);
```

Note per RESEARCH pitfall 1: `applyNavTheme()` iterates all `body *` elements — this is the existing behavior and runs synchronously in < 10ms on mobile YouTube's DOM. The `if (timer) return;` guard on the MutationObserver prevents infinite loops from style mutations triggered by the fixers. The pushState intercept calls are outside the observer so they are not guarded — this is intentional (they fire at most once per navigation event).

**Change B: Reduce MutationObserver debounce from 300ms to 0ms**

In the MutationObserver callback (currently around line 266), change:
```javascript
timer = setTimeout(function () {
    ...
}, 300);
```
to:
```javascript
timer = setTimeout(function () {
    ...
}, 0);
```

This fires at the next event loop tick after the first mutation batch instead of waiting 300ms. The `if (timer) return;` guard already absorbs burst mutations correctly — no infinite loop risk.

Keep the existing initial calls (lines 253-261) and the existing 500ms/2000ms setTimeout passes unchanged. They handle the initial page load case.

Update the file header comment (line 6) to mention pushState interception:
"Runs at atDocumentEnd; re-runs on SPA mutations via MutationObserver and pushState interception."
  </action>
  <verify>
    <automated>cd /Users/gavin/Documents/Projects/ZenSocial && grep -c "history.pushState" ZenSocial/Scripts/YouTube/nav-fixer.js | grep -q "^[2-9]" && grep -c "onSPANavigate" ZenSocial/Scripts/YouTube/nav-fixer.js | grep -q "^[3-9]" && grep ", 0)" ZenSocial/Scripts/YouTube/nav-fixer.js | grep -q "timer" && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>nav-fixer.js contains pushState/replaceState monkey-patching with onSPANavigate callback, popstate listener, and MutationObserver debounce reduced to 0ms</done>
</task>

<task type="auto">
  <name>Task 2: Add id="zen-theme" to injected style tag in ScriptLoader</name>
  <files>ZenSocial/Services/ScriptLoader.swift</files>
  <action>
In `ScriptLoader.wrapCSSInJS(_:)` (around line 94-100), add `s.id = 'zen-theme';` after the `document.createElement('style')` line.

Change from:
```javascript
var s = document.createElement('style');
s.textContent = `...`;
```

To:
```javascript
var s = document.createElement('style');
s.id = 'zen-theme';
s.textContent = `...`;
```

This allows nav-fixer.js (or future scripts) to check whether the style tag survived SPA navigation via `document.getElementById('zen-theme')`. Low-risk, one-line addition.
  </action>
  <verify>
    <automated>cd /Users/gavin/Documents/Projects/ZenSocial && grep "zen-theme" ZenSocial/Services/ScriptLoader.swift | grep -q "id" && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>ScriptLoader.wrapCSSInJS produces a style element with id="zen-theme"</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>pushState interception and reduced MutationObserver debounce to eliminate visible flash on YouTube SPA tab navigation</what-built>
  <how-to-verify>
    1. Build and run in Simulator
    2. Navigate to YouTube tab
    3. Rapidly tap between tabs: Home -> Subscriptions -> You -> Home
    4. Watch for any flash of white/light background during transitions
    5. Expected: Dark theme persists through all tab switches with no visible flash
    6. Also verify: If signed out of YouTube, tap the "You" tab and confirm the blue "Sign in" CTA still renders correctly
    7. Also verify: Top and bottom nav bars stay black through all transitions
  </how-to-verify>
  <resume-signal>Type "approved" or describe any remaining flash/issues</resume-signal>
</task>

</tasks>

<verification>
- `grep "onSPANavigate" ZenSocial/Scripts/YouTube/nav-fixer.js` returns multiple matches
- `grep "history.pushState" ZenSocial/Scripts/YouTube/nav-fixer.js` shows both the original save and the override
- `grep "zen-theme" ZenSocial/Services/ScriptLoader.swift` shows the ID assignment
- Build succeeds with no warnings in the modified files
- Visual verification in Simulator shows no flash on YouTube tab switches
</verification>

<success_criteria>
- YouTube SPA tab navigation (Home/Subscriptions/You) shows no visible flash of light/unstyled content
- Nav bars remain black through all route changes
- Signed-out CTA still works correctly
- No performance regression (no jank from excessive pushState calls)
</success_criteria>

<output>
After completion, create `.planning/quick/260328-dqm-minimize-css-injection-delay-when-naviga/260328-dqm-SUMMARY.md`
</output>
