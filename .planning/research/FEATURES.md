# Feature Landscape

**Domain:** iOS social media wrapper / digital wellbeing app
**Researched:** 2026-03-24

## Competitive Context

ZenSocial enters a growing space of digital wellbeing apps that block short-form video content. Direct competitors include:

- **ScrollGuard** -- free, uses the same web-wrapper approach on iOS (renders platforms in Safari/WebView and blocks feeds before they load). Supports Instagram, YouTube, Facebook. Has anti-scroll detection, strict mode with accountability partner, and premium per-app controls.
- **WallHabit** -- blocks Reels/Shorts via iOS Shortcuts automation. Requires iOS 18+. Uses a "hold to unlock" commitment device. Mixed reviews around subscription pricing and settings lockout bugs.
- **CloseReels** -- intercepts app opening with a "why are you opening this?" prompt. Deferred opening, focus mode. More of an interception layer than a wrapper.
- **One Sec** -- uses Shortcuts Automation to force a breathing pause before opening apps. Reduces usage by 57% (Max Planck study). Intention-setting and progress tracking. Free for one app, subscription for more.
- **Opal** -- general screen time control. App blocking, schedules, time limits, open limits. Gamified with streaks and leaderboards. $99.99/year for full features.
- **ScreenZen** -- delayed app opening with escalating wait times. Free and donation-supported. Configurable per-app, per-day settings.

**ZenSocial's differentiator:** None of these competitors combine a full in-app browsing experience (WKWebView rendering) with a custom dark/minimal visual theme. ScrollGuard is closest but lacks theming. Most competitors are interception/blocking layers, not replacement browsing experiences.

---

## Table Stakes

Features users expect. Missing any of these and the app feels broken or incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| WKWebView rendering of Instagram and YouTube | Core value prop -- users must be able to actually use the platforms | High | Login state persistence, cookie management, navigation handling |
| Block Instagram Reels tab | Primary use case; competitors all do this | Medium | CSS/JS injection to hide Reels tab and Reels content in feed |
| Block YouTube Shorts tab | Primary use case; competitors all do this | Medium | CSS/JS injection to hide Shorts shelf and Shorts tab |
| Native tab bar for switching platforms | App Store requirement (Guideline 4.2); feels native | Low | Tab bar with Instagram and YouTube icons |
| Persistent login sessions | Users will abandon if they must re-login constantly | Medium | WKWebView cookie/session persistence across app launches |
| Loading states and error handling | App Store requirement; blank screens = rejection | Low | Native loading indicators, offline state handling, retry UI |
| Pull-to-refresh | Standard iOS interaction pattern for web content | Low | WKWebView supports this natively with minor config |
| Back/forward navigation | Users expect browser-like navigation within each platform | Low | Native back button or swipe gesture tied to WKWebView history |
| Basic onboarding | Users need to understand what the app does and why | Low | 2-3 benefit-focused screens explaining the value proposition |

## Differentiators

Features that set ZenSocial apart from competitors. Not expected, but create competitive advantage.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Dark/minimal CSS theme overlay | Visual consistency and brand identity; no competitor does this well | Medium | CSS injection overriding platform colors. Must handle platform CSS updates gracefully |
| Per-platform block settings | Users control exactly what to hide per platform | Medium | Settings UI for toggling individual blocks (Reels, Shorts, Explore, etc.) |
| Explore/Discover feed blocking | Algorithmic discovery feeds are a major distraction vector beyond just Reels/Shorts | Medium | Hide Instagram Explore tab, YouTube homepage recommendations |
| Feed algorithm replacement (following-only) | Show only content from followed accounts, not algorithmic recommendations | High | Requires detecting and filtering recommended content vs followed content in the DOM |
| Usage time tracking (per-platform) | Users want to see how their behavior changes | Medium | Track time spent in each WKWebView; display daily/weekly stats |
| Session nudges / time reminders | Gentle reminders after X minutes of continuous use | Low | Timer-based alerts. Non-intrusive, dismissable |
| Scroll detection with intervention | Detect doom-scrolling patterns and interrupt | High | Requires monitoring scroll velocity/distance in WKWebView; ScrollGuard's key premium feature |
| Quick-switch between platforms | Fluid tab switching with state preservation | Medium | Each WKWebView maintains its state independently |
| Block comments sections | Comments are a known distraction/negativity vector | Medium | CSS injection to hide comment sections on both platforms |
| Selective story blocking | Some users want stories, others find them distracting | Low | Toggle to show/hide Instagram Stories tray |
| Share sheet integration | Users should be able to share content out of ZenSocial naturally | Low | iOS share sheet from WKWebView content |
| Haptic feedback on interactions | Reinforces native feel, distinguishes from "web wrapper" perception | Low | UIFeedbackGenerator on tab switches, pull-to-refresh |

## Anti-Features

Features to deliberately NOT build. Building these would undermine the core value proposition or add complexity that does not serve the mission.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Push notifications from platforms | Notifications are a core driver of compulsive usage; enabling them contradicts the "intentional usage" value prop | Let users check platforms on their own terms. Consider a badge count at most |
| Multi-account switching | Adds significant session management complexity for marginal value in MVP; encourages more time in-app | Defer entirely. Users log in once via the web view |
| In-app content creation (posting) | Web-based posting already works in WKWebView; building native creation tools is massive scope for zero differentiation | Let the web view handle posting natively |
| Gamification (streaks, leaderboards, rewards) | Gamification creates its own compulsion loop; contradicts "calm" brand. Opal does this and gets criticism for it | Show simple usage stats without gamifying them |
| Social/accountability features | Sharing usage data with friends adds social pressure and complexity | Keep the experience private and personal |
| AI-powered content filtering | Massive technical complexity, false positives, privacy concerns | Use deterministic CSS/JS selectors for blocking |
| TikTok support | Nearly all TikTok content is short-form video; there is no clear "zen" use case. Blocking Reels on TikTok leaves nothing | Re-evaluate only if TikTok adds significant long-form content |
| Backend / user accounts / cloud sync | No need for server infrastructure in MVP; settings can be local | Store all preferences in UserDefaults or local storage |
| Subscription pricing at launch | Competitors with aggressive subscriptions (WallHabit, Opal) get backlash in reviews | Launch free or with a one-time purchase. Evaluate subscription only after proving retention |
| "Strict mode" with password lock | Treating users like they cannot control themselves is paternalistic and leads to frustration when users legitimately need to change settings | Trust the user. Make settings always accessible |
| Browser chrome (URL bar, bookmarks) | Showing browser UI destroys the native app illusion and triggers App Store Guideline 4.2 rejection | Hide all browser UI; present as a native experience |

## Feature Dependencies

```
Persistent login sessions --> WKWebView rendering (foundation for everything)
Block Reels tab --> CSS/JS injection system (injection engine must exist first)
Block Shorts tab --> CSS/JS injection system
Dark theme overlay --> CSS/JS injection system
Per-platform block settings --> Block Reels + Block Shorts (settings toggle existing blocks)
Explore feed blocking --> CSS/JS injection system
Usage time tracking --> Tab bar platform switching (need to know which platform is active)
Session nudges --> Usage time tracking (need timer data to trigger nudges)
Scroll detection --> WKWebView scroll observation (UIScrollView delegate from WKWebView)
Feed algorithm replacement --> CSS/JS injection system (most complex injection task)
```

**Critical path:** WKWebView rendering --> CSS/JS injection system --> individual blocks --> settings UI --> tracking/nudges

## MVP Recommendation

**Prioritize (Phase 1):**

1. WKWebView container with Instagram and YouTube (table stakes)
2. CSS/JS injection engine -- architected for extensibility (table stakes, enables everything else)
3. Block Instagram Reels tab and Reels in feed (table stakes)
4. Block YouTube Shorts tab and Shorts shelf (table stakes)
5. Native tab bar for platform switching (table stakes, App Store requirement)
6. Dark/minimal CSS theme overlay (key differentiator, brand identity)
7. Persistent login sessions (table stakes)
8. Loading states and offline handling (table stakes, App Store requirement)
9. Basic onboarding (2-3 screens) (table stakes)

**Phase 2 candidates:**

- Per-platform block settings UI
- Explore/Discover feed blocking
- Usage time tracking
- Session time nudges
- Share sheet integration

**Defer (Phase 3+):**

- Feed algorithm replacement (following-only mode) -- HIGH complexity, fragile
- Scroll detection with intervention -- HIGH complexity
- Block comments sections
- Additional platform support (Facebook, Reddit)

**Do not build:** Push notifications, multi-account, gamification, backend, TikTok support, AI filtering.

## Sources

- [ScrollGuard](https://scrollguard.app/) -- Direct competitor, web-wrapper approach on iOS
- [ScrollGuard HN Discussion](https://news.ycombinator.com/item?id=44923520) -- Technical approach, user feature requests
- [WallHabit](https://apps.apple.com/us/app/wallhabit-block-shorts-reels/id6751423279) -- Competitor using Shortcuts automation
- [One Sec](https://one-sec.app/) -- Mindful pause intervention approach
- [Opal](https://www.opal.so/) -- General screen time control, gamification example
- [ScreenZen](https://screenzen.co/) -- Delayed opening approach
- [CloseReels](https://apps.apple.com/us/app/closereels-reduce-scrolling/id6739947824) -- Scrolling interception
- [App Store WebView Guidelines](https://www.mobiloud.com/blog/app-store-review-guidelines-webview-wrapper) -- Guideline 4.2 requirements
- [BreakTheScroll](https://breakthescroll.com/block-instagram-reels-and-youtube-shorts-with-this-free-app/) -- Competitor overview
