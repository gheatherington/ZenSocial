# Requirements: ZenSocial

**Defined:** 2026-03-24
**Core Value:** A native-feeling iOS shell that loads Instagram and YouTube while blocking their short-form video features — making social media intentional, not addictive.

## v1 Requirements

### App Shell

- [ ] **SHELL-01**: User can switch between Instagram and YouTube via a native tab bar
- [ ] **SHELL-02**: User sees a native loading indicator while web content loads per platform
- [ ] **SHELL-03**: User sees a native offline/error screen when a platform fails to load

### Web Rendering

- [x] **WEB-01**: User can browse Instagram via WKWebView with full platform functionality
- [x] **WEB-02**: User can browse YouTube via WKWebView with full platform functionality
- [ ] **WEB-03**: User stays logged in to both platforms across app launches (persistent sessions)
- [x] **WEB-04**: User can navigate within each platform (back/forward swipe, back button)
- [x] **WEB-05**: User can pull-to-refresh to reload the current platform page

### Injection Engine

- [ ] **INJ-01**: CSS/JS injection system executes platform-specific scripts at page load for Instagram and YouTube
- [ ] **INJ-02**: ZenSocial's dark/minimal theme is applied to Instagram via CSS injection
- [ ] **INJ-03**: ZenSocial's dark/minimal theme is applied to YouTube via CSS injection
- [ ] **INJ-04**: Injection scripts are stored as externalized bundle files (not hardcoded strings) for maintainability and easy updates

### Feature Blocking

- [ ] **BLOCK-01**: Instagram Reels tab is hidden on initial load and across SPA navigation
- [ ] **BLOCK-02**: YouTube Shorts tab is hidden on initial load and across SPA navigation
- [ ] **BLOCK-03**: User-agent is spoofed to a Safari UA to prevent Instagram/YouTube from detecting WKWebView

### Settings

- [ ] **SET-01**: User can toggle Instagram Reels blocking on/off from a native settings screen
- [ ] **SET-02**: User can toggle YouTube Shorts blocking on/off from a native settings screen

## v2 Requirements

### Feature Blocking (Extended)

- **BLOCK-04**: Instagram Explore tab hidden (algorithmic discovery feed)
- **BLOCK-05**: YouTube homepage recommendations hidden (only Subscriptions feed visible)
- **BLOCK-06**: Injection selector health-check system detects when platform DOM changes break blocks
- **BLOCK-07**: Remote-updatable selector config (over-the-air selector updates without App Store review)

### Settings (Extended)

- **SET-03**: Settings screen organizes blocks by platform with per-platform sections
- **SET-04**: User can add custom CSS rules for a platform

### Wellbeing

- **WELL-01**: User sees per-platform time-in-app tracking (daily/weekly stats)
- **WELL-02**: User receives a gentle session nudge after a configurable time threshold
- **WELL-03**: User can share content from ZenSocial via iOS share sheet

### Platforms

- **PLAT-01**: TikTok support (re-evaluate once clear zen use case identified)
- **PLAT-02**: Facebook support

## Out of Scope

| Feature | Reason |
|---------|--------|
| Push notifications from platforms | Core driver of compulsive usage; contradicts intentional-use value prop |
| Multi-account switching | Significant session management complexity; defer entirely |
| Backend / user accounts / cloud sync | No server infrastructure needed; settings stored locally |
| Gamification (streaks, leaderboards) | Creates its own compulsion loop; contradicts calm brand |
| AI-powered content filtering | Massive complexity, false positives, privacy concerns; use deterministic selectors |
| Strict mode with password lock | Paternalistic; trust the user |
| Browser chrome (URL bar, bookmarks) | Destroys native app illusion; triggers App Store 4.2 rejection |
| Android | iOS only to keep scope tight |
| In-app onboarding screens | Not needed for v1; add when onboarding hypothesis needs testing |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Pending |
| SHELL-02 | Phase 1 | Pending |
| SHELL-03 | Phase 1 | Pending |
| WEB-01 | Phase 1 | Complete |
| WEB-02 | Phase 1 | Complete |
| WEB-03 | Phase 1 | Pending |
| WEB-04 | Phase 1 | Complete |
| WEB-05 | Phase 1 | Complete |
| BLOCK-03 | Phase 1 | Pending |
| INJ-01 | Phase 2 | Pending |
| INJ-02 | Phase 2 | Pending |
| INJ-03 | Phase 2 | Pending |
| INJ-04 | Phase 2 | Pending |
| BLOCK-01 | Phase 3 | Pending |
| BLOCK-02 | Phase 3 | Pending |
| SET-01 | Phase 4 | Pending |
| SET-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

---
*Requirements defined: 2026-03-24*
*Last updated: 2026-03-24 after roadmap creation*
