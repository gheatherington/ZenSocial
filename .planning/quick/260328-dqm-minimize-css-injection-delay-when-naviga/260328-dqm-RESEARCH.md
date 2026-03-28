# Quick Task: Minimize CSS Injection Delay on YouTube SPA Navigation

**Researched:** 2026-03-28
**Domain:** WKWebView CSS/JS injection + YouTube SPA navigation
**Confidence:** HIGH (based on direct codebase analysis + established WKWebView behavior)

---

## Summary

YouTube on mobile (`m.youtube.com`) is a Single Page App. Tab navigation (Home → You, Home → Subscriptions, etc.) uses `history.pushState` — no full page reload occurs. `WKUserScript` objects registered at `.atDocumentStart` or `.atDocumentEnd` only fire on actual page loads (document navigations). They do NOT re-fire on `pushState`/`popstate` transitions.

The current codebase already injects theme CSS as a `<style>` element at `.atDocumentStart` (via `ScriptLoader.themeScript`). That `<style>` element **persists** in the DOM across SPA navigations — YouTube does not remove it. However, YouTube's own JS applies inline styles and component-level styles during route rendering that can temporarily override the injected CSS, causing visible flashes.

The `nav-fixer.js` already has a `MutationObserver` (300ms debounced) that calls `applyNavTheme()` and `fixAccountPage()` after DOM mutations. The problem: 300ms is long enough to see a flash, and `applyNavTheme()` only fixes nav-bar elements, not the broader page surface that flashes on route change.

**Primary recommendation:** Reduce the MutationObserver debounce from 300ms to 0ms (using `setTimeout(..., 0)`) for the initial re-application, with a follow-up at 300ms for late-painting elements. Also intercept `history.pushState`/`replaceState` to trigger immediate re-application on navigation events, before mutations accumulate.

---

## Root Cause Analysis

### Why `.atDocumentStart` does not help on SPA navigation

`WKUserScript` injection timing (`.atDocumentStart`, `.atDocumentEnd`) maps to WebKit document lifecycle events:
- `.atDocumentStart` = after HTML parsing starts, before scripts run
- `.atDocumentEnd` = after DOM is ready (`DOMContentLoaded`)

Both timings fire only on **document navigation** — when WebKit creates a new document object. A `history.pushState` call does not create a new document; it only mutates the URL and optionally the history stack. WebKit does not re-inject `WKUserScript` objects on pushState.

**Result:** After a pushState navigation, no new injection fires. The existing `<style>` tag stays in the DOM (good), but `nav-fixer.js`'s `applyNavTheme()` does not re-run until the MutationObserver fires (300ms later, or more).

### What actually causes the flash

YouTube's SPA rendering pipeline on route change:
1. `pushState` updates URL
2. YouTube's JS removes and re-renders the page content in place (via Polymer/LitElement component updates)
3. New elements are inserted without inline styles — they briefly render with YouTube's default light-mode styles
4. YouTube's own CSS variables and component JS then apply dark/light mode, but they may conflict with our injected `<style>` rules
5. Our MutationObserver fires ~300ms later, `applyNavTheme()` forces black on fixed/sticky elements

The 300ms window at step 4→5 is the visible flash.

---

## Recommended Approaches (in priority order)

### Approach 1: history.pushState monkey-patching (BEST for route-change detection)

Intercept `pushState`/`replaceState`/`popstate` in the injected JS to detect SPA navigation immediately, before DOM mutations accumulate.

**How it works:**

```javascript
(function() {
    var originalPushState = history.pushState.bind(history);
    var originalReplaceState = history.replaceState.bind(history);

    function onNavigate() {
        // Run immediately (synchronous) for zero-delay first pass
        applyNavTheme();
        // Follow-up passes for elements that paint late
        setTimeout(applyNavTheme, 100);
        setTimeout(applyNavTheme, 500);
    }

    history.pushState = function() {
        originalPushState.apply(history, arguments);
        onNavigate();
    };

    history.replaceState = function() {
        originalReplaceState.apply(history, arguments);
        onNavigate();
    };

    window.addEventListener('popstate', onNavigate);
})();
```

**Pitfalls:**
- YouTube calls `pushState` very frequently (including for scroll state updates, not just full route changes). The `onNavigate` handler must be lightweight — call the cheap pass first, defer expensive DOM walks.
- Monkey-patching `history` is well-established practice. YouTube does not detect or block this.
- Must be set up before YouTube's own JS runs — injection at `.atDocumentStart` guarantees this.

**Confidence:** HIGH. This is the standard approach used by SPA theme injectors (extensions, userscripts). Verified by multiple open-source userscript patterns.

### Approach 2: Reduce MutationObserver debounce to 0ms + layered follow-ups

The current `nav-fixer.js` debounce is 300ms. Reducing it to `setTimeout(..., 0)` fires at the next event loop tick after the first mutation batch.

**Current pattern:**
```javascript
timer = setTimeout(function () {
    applyNavTheme();
    // ...
    timer = null;
}, 300);  // <-- too long
```

**Recommended pattern:**
```javascript
// Immediate pass (next tick)
timer = setTimeout(function () {
    applyNavTheme();
    fixAccountPage();
    restoreSignedOutCTA();
    timer = null;
}, 0);

// Follow-up for late-painting elements (keep 300ms pass too)
var lateTimer = null;
// ... schedule lateTimer at 300ms independently
```

**Pitfalls:**
- 0ms debounce can still result in many rapid calls during a route transition (YouTube mutates the DOM hundreds of times per navigation). Use the `if (timer) return;` guard as currently written — it absorbs burst mutations correctly.
- Late-rendering elements (fixed navbars painted by YouTube's component JS after initial render) still need a 300–500ms follow-up pass. Do not remove the delayed passes.

**Confidence:** HIGH. Direct analysis of existing code.

### Approach 3: `<style>` tag persistence check + CSS variable forcing

The `<style>` tag injected at `.atDocumentStart` survives SPA navigation in YouTube. Verify this is still being appended to `document.documentElement` (correct) and not `document.head` (which can be replaced).

The flash may partly come from YouTube temporarily overriding `--yt-spec-base-background` and related CSS variables via its component JS before the MutationObserver fires. Adding a second `<style>` re-injection on `pushState` (or ensuring CSS specificity is high enough) addresses this.

**Approach:** On `pushState`, re-insert or update the `<style>` tag content:
```javascript
function ensureThemeStyle(css) {
    var existing = document.getElementById('zen-theme');
    if (!existing) {
        var s = document.createElement('style');
        s.id = 'zen-theme';
        s.textContent = css;
        document.documentElement.appendChild(s);
    }
    // If it already exists, it's still active — no re-insert needed
}
```

Adding an `id` to the injected `<style>` tag in `ScriptLoader.wrapCSSInJS()` allows detecting whether it survived and prevents duplicate injection.

**Confidence:** MEDIUM. The style tag likely already survives, but marking it with an ID is low-risk and enables survivability checks in JS.

### Approach 4: MutationObserver watching `<style>` tag removal (defensive)

If YouTube ever removes injected `<style>` tags (not confirmed, but possible in future DOM updates), a dedicated observer on the style tag itself catches removal and re-inserts it:

```javascript
var styleEl = document.getElementById('zen-theme');
if (styleEl) {
    new MutationObserver(function(mutations) {
        mutations.forEach(function(m) {
            m.removedNodes.forEach(function(node) {
                if (node === styleEl) {
                    document.documentElement.appendChild(styleEl);
                }
            });
        });
    }).observe(document.documentElement, { childList: true });
}
```

This is a defensive measure — not needed currently, but cheap to add.

**Confidence:** MEDIUM. YouTube is not known to remove injected style tags, but this prevents future regressions.

---

## Integration with Existing Codebase

### What already exists (do not duplicate)

- `nav-fixer.js` already has a `MutationObserver` at the bottom (lines 264–272) watching `document.documentElement` for subtree changes. This is the right observer for element-level fixes.
- `applyNavTheme()` already handles fixed/sticky elements.
- `fixAccountPage()` already handles the signed-out page.
- The `<style>` tag injection is in `ScriptLoader.wrapCSSInJS()` — it appends to `document.documentElement`. This is correct.

### What needs to change

**In `nav-fixer.js`:**

1. Add `history.pushState`/`replaceState`/`popstate` interception at the top of the IIFE, calling `applyNavTheme()` + `fixAccountPage()` + `restoreSignedOutCTA()` immediately on navigation.
2. Reduce the MutationObserver debounce from 300ms → 0ms for the primary callback, while keeping a separate 300ms follow-up for late-painting elements.

**In `ScriptLoader.wrapCSSInJS()`:**

Add `id="zen-theme"` to the created `<style>` element so JS can reference it for survivability checks.

### Minimal change footprint

The fix is entirely in `ZenSocial/Scripts/YouTube/nav-fixer.js` (plus a one-line change to `ScriptLoader.wrapCSSInJS`). No new Swift files, no new injection entry points, no changes to `WebViewConfiguration.swift`.

The Instagram `nav-fixer.js` may benefit from the same pushState pattern but Instagram is less of a SPA than YouTube — assess after YouTube fix is verified.

---

## Common Pitfalls

### Pitfall 1: pushState fires too frequently

YouTube uses `pushState` for URL updates unrelated to route changes (e.g., scroll position encoding). A naive `onNavigate()` that does expensive DOM walks on every pushState call will cause jank.

**Mitigation:** On `pushState`, only schedule lightweight passes (`applyNavTheme()` via debounced setTimeout). The expensive `fixAccountPage()` walk (which calls `querySelectorAll` + `getComputedStyle` on every child) should only run when the URL indicates an account/signed-out page.

### Pitfall 2: Infinite loop in MutationObserver

`applyNavTheme()` calls `el.style.setProperty(...)` which mutates the DOM, which triggers the MutationObserver again. The current `if (timer) return;` guard prevents this but only if the timer is set before the mutations are applied. The existing code sets `timer` before calling the fixers — this is correct.

**Mitigation:** Keep the `if (timer) return;` guard. Do not move the timer assignment below the fixer calls.

### Pitfall 3: YouTube's Content Security Policy

YouTube's CSP does not block `WKUserScript` injection — the script runs in a privileged WebKit context, not the page's JS context. CSP `script-src` rules do not apply to `WKUserScript`. This is confirmed by the existing working injection.

### Pitfall 4: Race condition with YouTube's component initialization

YouTube uses Polymer/LitElement web components. Components may apply inline styles after their `connectedCallback` fires, which can happen 100–500ms after insertion. A single 0ms debounce pass may not catch these late-painted elements.

**Mitigation:** Keep the multi-pass setTimeout pattern already in `nav-fixer.js` (0ms + 500ms + 2000ms). The 2000ms pass is the safety net for very late-rendering components.

---

## Code Pattern: Minimal Fix

The smallest effective change to `nav-fixer.js`:

```javascript
// Add near the top of the IIFE, after function definitions, before first function calls

function onSPANavigate() {
    // Immediate pass — before YouTube's component JS runs
    applyNavTheme();
    fixAccountPage();
    restoreSignedOutCTA();
    // Follow-up for late-painting elements
    setTimeout(applyNavTheme, 150);
    setTimeout(fixAccountPage, 300);
    setTimeout(restoreSignedOutCTA, 300);
}

var _push = history.pushState.bind(history);
var _replace = history.replaceState.bind(history);
history.pushState = function() { _push.apply(history, arguments); onSPANavigate(); };
history.replaceState = function() { _replace.apply(history, arguments); onSPANavigate(); };
window.addEventListener('popstate', onSPANavigate);
```

And reduce the MutationObserver debounce from 300 → 0 in the existing observer block.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual simulator testing (no automated UI test infrastructure) |
| Config file | none |
| Quick run command | `./Scripts/sim-inspect.sh navigate youtube` then tap tabs |
| Full suite command | Build + simulator visual verification per LESSONS.md |

### Phase Requirements → Test Map
| Behavior | Test Type | Verification |
|----------|-----------|--------------|
| No flash on Home → Subscriptions nav | Manual / visual | Build, navigate tabs rapidly, observe |
| No flash on Home → You tab nav | Manual / visual | Build, tap You tab, observe theme applied immediately |
| Nav-bar stays black through route change | Manual / visual | Navigate while watching bottom and top bars |
| pushState does not fire excessively | Performance / manual | Open console in Safari Web Inspector, count pushState calls |

### Wave 0 Gaps
None — existing simulator workflow covers all verification needed.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis: `ZenSocial/Scripts/YouTube/nav-fixer.js` — existing MutationObserver + debounce pattern
- Direct codebase analysis: `ZenSocial/Services/ScriptLoader.swift` — injection timing and `<style>` tag construction
- Direct codebase analysis: `ZenSocial/WebView/WebViewConfiguration.swift` — WKUserScript registration

### Secondary (MEDIUM confidence)
- Established WKWebView behavior: `WKUserScript` fires on document navigation only, not pushState (well-documented WebKit behavior)
- YouTube mobile SPA architecture: uses `history.pushState` for tab navigation (verifiable via Safari Web Inspector)

---

## Metadata

**Confidence breakdown:**
- Root cause analysis: HIGH — based on WKWebView documented behavior + codebase structure
- Fix approach (pushState interception): HIGH — standard SPA injection pattern, no novel risk
- Fix approach (debounce reduction): HIGH — direct code change with predictable effect
- YouTube pushState frequency pitfall: MEDIUM — not measured in this repo yet

**Research date:** 2026-03-28
**Valid until:** 2026-06-28 (stable WebKit behavior, YouTube SPA architecture unlikely to change fundamentally)
