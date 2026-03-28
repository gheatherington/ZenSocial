---
phase: quick
plan: 260328-cwd
type: execute
wave: 1
depends_on: []
files_modified:
  - ZenSocial/Scripts/YouTube/theme.css
autonomous: false
requirements: [QUICK-YT-SIGNED-OUT-CTA]
must_haves:
  truths:
    - "The primary `Sign in` CTA on YouTube's `You're not signed in` page shows ZenSocial blue again instead of blending into the dark surface"
    - "If the CTA uses an outlined variant, its border is blue again on the signed-out page"
    - "Other YouTube buttons outside the signed-out upsell flow keep their existing colors"
  artifacts:
    - path: "ZenSocial/Scripts/YouTube/theme.css"
      provides: "A signed-out CTA-specific override block scoped to YouTube's unauthenticated page containers"
      contains: "ytm-account-controller"
  key_links:
    - from: "ZenSocial/Scripts/YouTube/theme.css unauthenticated page selectors"
      to: "The rendered Sign in CTA descendants inside ytm-account-controller / ytm-inline-message-renderer / ytm-upsell-dialog-renderer"
      via: "Later, container-scoped CSS override that beats the broad sign-in surface rules without changing global button styling"
      pattern: "ytm-account-controller.*yt-button|ytm-inline-message-renderer.*yt-button|ytm-upsell-dialog-renderer.*yt-button"
---

<objective>
Restore the blue background and visible blue border for the YouTube signed-out page's primary `Sign in` CTA without broadening the accent color change to unrelated YouTube buttons.

Purpose: The prior unauthenticated/sign-in theming work added broad dark-surface selectors that likely also catch the signed-out CTA. This quick fix should stay inside the signed-out YouTube surface and reassert the CTA styling at the end of that section.
Output: An updated `ZenSocial/Scripts/YouTube/theme.css` with a narrow signed-out CTA override plus build and visual verification.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/debug/youtube-accent-color-not-visible.md
@.planning/phases/02-injection-engine-dark-theme/02-03-SUMMARY.md
@ZenSocial/Scripts/YouTube/theme.css

Use the diagnosis and prior summary as constraints:
- The accent issue is a selector/specificity problem, not an injection failure.
- Prior work intentionally broadened sign-in page coverage with wildcard selectors; this quick fix must not become another global recolor.
- Keep the change inside the unauthenticated YouTube section. Do not touch the Google `accounts.google.com` (`c-wiz`) rules unless the signed-out YouTube CTA actually reuses them, which is unlikely.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reassert blue styling for the signed-out YouTube Sign in CTA only</name>
  <files>ZenSocial/Scripts/YouTube/theme.css</files>
  <action>
Update the existing unauthenticated/sign-in area in `ZenSocial/Scripts/YouTube/theme.css` so the `You're not signed in` page's primary `Sign in` CTA gets its blue fill and blue border back.

Implementation constraints:
1. Work only in the YouTube unauthenticated page block around `ytm-account-controller`, `ytm-inline-message-renderer`, `yt-upsell-dialog-renderer`, and `ytm-upsell-dialog-renderer`.
2. Add a late, container-scoped selector block that targets the CTA's rendered button descendants (`yt-button-shape`, `ytm-button-renderer`, native `button`, or the filled/outlined button-shape classes actually present there) and restores:
   - blue background/fill
   - blue border/border-color
   - legible CTA text color
3. If the current broad wildcard sign-in surface selectors (`[class*="sign-in"]`, `[class*="signin"]`, etc.) are painting the CTA itself, narrow or exclude that effect only enough to stop overriding the button. Preserve their dark-surface coverage for containers/cards.
4. Do not change generic global button rules, pivot bar rules, link colors, chip colors, or Google sign-in page styling.
5. Keep the fix additive and local, following the Phase 02-03 pattern of extending `theme.css` rather than replacing prior blocks.
  </action>
  <verify>
    <automated>cd /Users/gavin/Documents/Projects/ZenSocial && rg -n "ytm-account-controller|ytm-inline-message-renderer|ytm-upsell-dialog-renderer|yt-upsell-dialog-renderer" ZenSocial/Scripts/YouTube/theme.css && xcodebuild -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 17' build</automated>
  </verify>
  <done>
    - `theme.css` contains a signed-out CTA-specific override located in the unauthenticated YouTube section
    - The change is limited to the signed-out `Sign in` CTA path and does not broaden accent styling elsewhere
    - The project builds successfully after the CSS update
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Scoped YouTube signed-out CTA styling so the `You're not signed in` page's `Sign in` button regains its blue background and visible blue border.</what-built>
  <how-to-verify>
    1. Launch the app in Simulator and open the YouTube tab while signed out
    2. Navigate to the YouTube view that shows `You're not signed in`
    3. Confirm the primary `Sign in` button now has a blue background and visible blue border again
    4. Confirm the surrounding page/card surfaces remain dark
    5. Spot-check another YouTube page with buttons to confirm no unrelated global recolor was introduced
  </how-to-verify>
  <resume-signal>Type "approved" or describe what still looks wrong</resume-signal>
</task>

</tasks>

<verification>
- The signed-out CTA override exists below the broader unauthenticated surface rules so it wins by scope/order.
- `xcodebuild` succeeds after the CSS change.
- Visual verification confirms only the signed-out YouTube CTA changed back to blue.
</verification>

<success_criteria>
- The `Sign in` button on YouTube's `You're not signed in` page is visibly blue again.
- The button border is blue where that CTA variant exposes a border.
- No broader YouTube recolor regression is introduced.
</success_criteria>

<output>
After completion, create `.planning/quick/260328-cwd-update-the-sign-in-button-in-the-you-re-/260328-cwd-SUMMARY.md`
</output>
