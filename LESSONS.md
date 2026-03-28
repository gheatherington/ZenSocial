# ZenSocial Lessons

Read this at the start of any new session in this repo, especially before changing `ZenSocial/Scripts/*`, `WKWebView` behavior, or simulator verification flows.

## Startup Rules

- Review this file before editing YouTube or Instagram injection scripts.
- When a web-theme bug is reported, verify it in Simulator against the actual target screen, not just the platform home feed.
- Prefer small, page-scoped fixes over broad selectors because mobile platform DOMs change frequently.

## YouTube Theme / Injection Lessons

- CSS alone is not always enough on mobile YouTube. YouTube's own JS can repaint inline styles after the stylesheet lands, so `el.style.setProperty(..., 'important')` in `ZenSocial/Scripts/YouTube/nav-fixer.js` can be required even when `theme.css` already has `!important`.
- The signed-out YouTube account screen was a concrete example of that: `theme.css` could darken the page, but the visible `Sign in` CTA still did not expose a stable, styleable DOM target.
- For signed-out-page fixes, scope off the actual page state, not generic auth-looking selectors. The reliable signal here was the body text containing `You're not signed in` / `You’re not signed in`.
- Broad unauthenticated selectors like `ytm-account-controller > *` and `[class*="sign-in"]` can accidentally catch buttons. If they are needed for background coverage, explicitly exclude `yt-button-shape`, `ytm-button-renderer`, `yt-button-renderer`, native `button`, and `[role="button"]`.
- `applyNavTheme()` in `ZenSocial/Scripts/YouTube/nav-fixer.js` paints every fixed/sticky element black. Any intentionally colored fixed element must be explicitly exempted, or its background will be wiped back to black.
- For this repo, the current exemption marker is `data-zen-signed-out-cta`. If you add another intentionally styled fixed element in the webview, make sure `applyNavTheme()` and other darkening passes skip it.
- When YouTube does not expose a stable CTA host, a DOM-aware fallback overlay is acceptable if it is tightly scoped to one page state and wired to the platform's real sign-in URL. For YouTube, use `window.ytcfg.get('SIGNIN_URL')` first, then fall back to discovered sign-in anchors.
- The signed-out page has two separate `Sign in` labels: the top-left account-row label and the centered CTA. Position-aware filtering matters. Do not hide all `Sign in` text globally or you will break the account-row label too.

## Current Sign-In Button Fix

- The final working fix is split across:
  - `ZenSocial/Scripts/YouTube/theme.css`
  - `ZenSocial/Scripts/YouTube/nav-fixer.js`
- `theme.css` still contains the scoped signed-out CTA restore attempt and the button exclusions inside the unauthenticated block.
- The actual visible fix that passed Simulator verification is in `nav-fixer.js`:
  - detect the signed-out account page
  - preserve black account-page background logic
  - inject a blue fallback CTA overlay with white text
  - hide only the centered native plain-text CTA label
  - exempt the injected CTA from global fixed-element blackening
- If this bug regresses again, inspect `nav-fixer.js` before adding more CSS. The stable fix path here ended up being JS, not stylesheet specificity.

## Simulator Verification Lessons

- Use the project-local simulator workflow:
  - `.claude/skills/sim-inspect.md`
  - `Scripts/sim-inspect.sh`
- `./Scripts/sim-inspect.sh navigate youtube` only gets you to the YouTube tab/home state. It does not open the signed-out account page by itself.
- To verify the signed-out YouTube account view, you still need to open the bottom-right `You` tab after navigation.
- On this machine, `Scripts/sim-inspect.sh tap ...` is unreliable because its AppleScript window-size lookup currently fails. `cliclick` is installed and worked as a manual fallback.
- Screenshot outputs are written to `/tmp/zensocial-sim/`. Keep the verification screenshots for bug-fix evidence when a UI fix is subtle.

## SPA Navigation Flash (Injection Delay)

- YouTube and Instagram are SPAs. `WKUserScript` with `.atDocumentStart` only fires on a full page load — it does NOT re-fire on SPA tab/page switches that use `history.pushState`.
- This causes a ~300ms flash of original styles every time the user navigates between tabs/pages, because the injected styles are present but YouTube/Instagram's component JS repaints inline styles after each route change.
- The fix is to monkey-patch `history.pushState`, `history.replaceState`, and `window.popstate` in each `nav-fixer.js` to call the theme-application functions immediately on every SPA route change — before DOM mutations accumulate.
- The MutationObserver debounce was also reduced from 300ms → 0ms (uses `setTimeout(fn, 0)` — defers to next JS tick, preventing infinite observer loops while still being near-instant).
- The `onSPANavigate()` handler should be lightweight for the synchronous call. Expensive DOM walks go into short `setTimeout` follow-ups (150ms, 300ms) to catch late-painting components.
- This pattern applies to both YouTube (`Scripts/YouTube/nav-fixer.js`) and Instagram (`Scripts/Instagram/nav-fixer.js`). Any future platform added to the app will need the same pushState interception if it is a SPA.
- The `<style id="zen-theme">` tag injected by `ScriptLoader.wrapCSSInJS()` survives SPA navigation — it is not removed. The flash is caused by JS repainting, not the stylesheet disappearing.

## Practical Guardrails For Future Fixes

- Prefer resilient heuristics based on page text, position, and known platform config over brittle class-name-only targeting.
- Keep Google sign-in (`accounts.google.com`) rules separate from native YouTube signed-out-page rules. They are different problems.
- After any injection-script change, rebuild and re-check the exact broken screen in Simulator. A green `xcodebuild` is not enough for webview theme fixes.
- If a page shows the right background but the wrong interactive styling, suspect inline styles, post-load JS repainting, or inaccessible component markup before assuming the stylesheet failed to load.
