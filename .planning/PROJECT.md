# ZenSocial

## What This Is

ZenSocial is an iOS app that gives users a cleaner, calmer way to use their social media accounts. It renders the web versions of supported platforms (Instagram, YouTube) inside a native container, then strips out algorithmically-driven distractions — Reels, Shorts, and similar features — so users stay connected without the noise. The app applies ZenSocial's own dark, minimalist theme over the web content via CSS injection.

## Core Value

A native-feeling iOS shell that loads Instagram and YouTube while blocking their short-form video features — making social media intentional, not addictive.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] iOS app with WKWebView container hosting Instagram and YouTube
- [ ] Block Reels tab on Instagram (CSS/JS injection)
- [ ] Block YouTube Shorts tab on YouTube (CSS/JS injection)
- [ ] CSS injection to apply ZenSocial's dark/minimal theme over web content
- [ ] Native-feeling navigation and tab bar between supported apps
- [ ] Fast loading and responsive feel (no perceptible "web app" lag)
- [ ] Extensible feature-blocking system (designed for future per-platform settings)

### Out of Scope

- TikTok support — deprioritized; nearly all content is short-form video, unclear zen use case; add later
- Multi-account support — deferred to later milestone; adds auth/session complexity
- Push notifications from social platforms — deferred; requires native integration work
- Backend / user accounts / sync — deferred; not needed for core experience validation
- Android — iOS only for now; keeps scope tight

## Context

- **Approach**: WKWebView renders the mobile web versions of each platform. JavaScript and CSS are injected at page load to remove or hide unwanted UI elements (tabs, sections, components).
- **Feature blocking**: Start with Reels tab (Instagram) and Shorts tab (YouTube). The injection system should be architected to easily add new blocks per platform as the app grows.
- **Visual theming**: CSS injection applies ZenSocial's dark, minimal aesthetic over the platform's native web styles — creating visual consistency across apps.
- **Platform first**: Instagram is the primary focus for initial development. YouTube is in scope from the start but Instagram drives design and technical decisions.
- **No auth yet**: Users log in via the rendered web view itself (normal browser login). Native account management is a future feature.

## Constraints

- **Platform**: iOS only — Swift/SwiftUI or UIKit + WKWebView
- **Rendering**: Web-based (WKWebView) — not native app API integrations; platforms don't expose public APIs for this use case
- **Anti-blocking risk**: Instagram/YouTube may update their DOM, breaking CSS/JS selectors — injection scripts must be maintainable and easy to update
- **App Store**: CSS/JS injection into third-party web content must comply with Apple App Store guidelines

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| WKWebView for rendering | Platforms don't expose APIs; web rendering is the only viable path for feature control | — Pending |
| CSS + JS injection for feature blocking | Allows surgical removal of specific UI elements without breaking core functionality | — Pending |
| Instagram-first development | Most common use case; clear distracting feature (Reels) to block; sets the pattern for other platforms | — Pending |
| Dark theme via CSS injection | Keeps ZenSocial's aesthetic consistent across all hosted platforms | — Pending |
| Defer auth/multi-account | Validate core experience first before adding session management complexity | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-24 after initialization*
