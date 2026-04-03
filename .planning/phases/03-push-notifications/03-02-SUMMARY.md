---
phase: 03-push-notifications
plan: 02
subsystem: notifications
tags: [WKScriptMessageHandler, BGAppRefreshTask, URLSession, UNUserNotificationCenter, BackgroundTasks, NotificationPoller, DeepLink]

requires:
  - phase: 03-01
    provides: NotificationManager singleton, AppDelegate bridge, UNUserNotificationCenter delegate, zenNotificationTapped Notification.Name

provides:
  - NotificationPoller singleton: WKScriptMessageHandler (foreground badge detection) + BGAppRefreshTask (background cookie-based polling)
  - notification-bridge.js: MutationObserver + 30s polling for Instagram notification badge changes
  - Deep-link routing: zenNotificationTapped -> NavigationState.navigateToInstagram -> zenDeepLinkNavigation -> WKWebView.load
  - Info.plist with BGTaskSchedulerPermittedIdentifiers: com.zensocial.notification-check
  - INFOPLIST_ADDITIONS_FILE set in project.pbxproj (both Debug and Release configs)

affects: [03-03]

tech-stack:
  added: [BackgroundTasks framework (BGAppRefreshTask), URLSession (ephemeral config with exported cookies)]
  patterns:
    - MainActor.assumeIsolated in WKScriptMessageHandler for Swift 6 concurrency with WKScriptMessage properties
    - Cookie export via WKHTTPCookieStore.allCookies() -> HTTPCookieStorage injection into URLSession
    - HTML parsing via String.range(of:options:.regularExpression) for badge_count/has_unseen/unseen_count
    - INFOPLIST_ADDITIONS_FILE to merge BGTaskSchedulerPermittedIdentifiers without disabling GENERATE_INFOPLIST_FILE

key-files:
  created:
    - ZenSocial/Scripts/Instagram/notification-bridge.js
    - ZenSocial/Services/NotificationPoller.swift
    - ZenSocial/Info.plist
  modified:
    - ZenSocial/Services/ScriptLoader.swift
    - ZenSocial/WebView/WebViewConfiguration.swift
    - ZenSocial/ZenSocialApp.swift
    - ZenSocial/Models/NavigationState.swift
    - ZenSocial/Views/ContentView.swift
    - ZenSocial.xcodeproj/project.pbxproj

key-decisions:
  - "MainActor.assumeIsolated used in WKScriptMessageHandler -- iOS 26 SDK marks WKScriptMessage.name/.body as @MainActor; WebKit guarantees delivery on main thread so assumeIsolated is safe"
  - "INFOPLIST_ADDITIONS_FILE = ZenSocial/Info.plist chosen over disabling GENERATE_INFOPLIST_FILE -- preserves all INFOPLIST_KEY_* build settings, adds BGTaskSchedulerPermittedIdentifiers array cleanly"
  - "60-second debounce on foreground notifications -- prevents rapid-fire notifications from MutationObserver or polling firing in quick succession"
  - "Multiple HTML parse strategies in detectNotificationsInHTML (badge_count, unseen_count, has_unseen, notification_count) -- resilience against Instagram serialization format changes"
  - "WKScriptMessageHandler extension separated from main class body -- clean Swift 6 pattern for protocol conformance that requires nonisolated context"

requirements-completed: [PUSH-01, PUSH-02]

duration: ~6 min
completed: 2026-04-03
---

# Phase 03-02: Notification Detection and Delivery Pipeline Summary

**JS bridge (foreground badge DOM detection), NotificationPoller with cookie-based BGAppRefreshTask background polling, and notification tap deep-link routing to Instagram tab**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-03T13:52:21Z
- **Completed:** 2026-04-03
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- `notification-bridge.js`: MutationObserver on Instagram nav for real-time badge detection + 30-second polling fallback. Uses 3 DOM strategies (nav link href matching, red dot background-color check, notification count text). Sends `{ type: "badge_change", hasNew: true, count: N, timestamp: ms }` to native via `window.webkit.messageHandlers.zenNotification.postMessage`.
- `NotificationPoller.swift`: Singleton `@MainActor` class implementing `WKScriptMessageHandler`. Foreground path receives JS bridge messages via `userContentController(_:didReceive:)` with `MainActor.assumeIsolated` for Swift 6 safety. Background path: `BGAppRefreshTask` exports Instagram session cookies from `DataStoreManager.dataStore(for: .instagram).httpCookieStore`, injects into `URLSession` ephemeral config, fetches `instagram.com`, parses HTML for notification indicators.
- `detectNotificationsInHTML`: 4-strategy parser (`badge_count`, `unseen_count`, `has_unseen`, `notification_count`) with regex extraction. Only fires local notification on state change from false->true (diffed via `lastKnownStateKey` in `UserDefaults`).
- `ScriptLoader.notificationBridgeScript(for:)`: Loads `notification-bridge.js` at `.atDocumentEnd` for Instagram only.
- `WebViewConfiguration`: Registers `notificationBridgeScript` as a user script and `NotificationPoller.shared` as `WKScriptMessageHandler` for `zenNotification` message channel.
- `ZenSocialApp`: `registerBackgroundTask()` in `AppDelegate.didFinishLaunchingWithOptions`; `scheduleBackgroundRefresh()` on `UIApplication.didEnterBackgroundNotification`.
- `Info.plist`: Standalone plist with `BGTaskSchedulerPermittedIdentifiers: [com.zensocial.notification-check]`; `INFOPLIST_ADDITIONS_FILE` set in both Debug/Release build configurations.
- `NavigationState.navigateToInstagram(url:)`: Switches `activeScreen` to `.instagram` and posts `zenDeepLinkNavigation`.
- `ContentView`: `.onReceive(zenNotificationTapped)` routes to `nav.navigateToInstagram(url:)`; `.onReceive(zenDeepLinkNavigation)` calls `instagramState.webView?.load(URLRequest(url:))` on the existing WKWebView instance.

## Task Commits

1. **Task 1: JS notification bridge, NotificationPoller, BGAppRefreshTask, Info.plist** — `6ef64a4`
   - Files: notification-bridge.js, NotificationPoller.swift, Info.plist, ScriptLoader.swift, WebViewConfiguration.swift, ZenSocialApp.swift, project.pbxproj
2. **Task 2: Deep-link routing on notification tap** — `fc2013a`
   - Files: NavigationState.swift, ContentView.swift

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed WKScriptMessage @MainActor isolation in Swift 6 context**
- **Found during:** Task 1, swiftc type-check
- **Issue:** iOS 26 SDK marks `WKScriptMessage.name` and `.body` as `@MainActor`-isolated. The plan's `nonisolated func handleNotificationMessage` that accessed these properties directly was flagged as a concurrency violation by the Swift 6 compiler.
- **Fix:** Used `MainActor.assumeIsolated` in the `WKScriptMessageHandler.userContentController` implementation. WebKit guarantees this callback fires on the main thread, making `assumeIsolated` safe. Moved notification message logic directly into the extension.
- **Files modified:** ZenSocial/Services/NotificationPoller.swift
- **Commit:** 6ef64a4

**2. [Rule 2 - Missing functionality] Used INFOPLIST_ADDITIONS_FILE instead of replacing generated plist**
- **Found during:** Task 1, examining project.pbxproj
- **Issue:** The plan said to create `ZenSocial/Info.plist` and register it as `INFOPLIST_FILE`. However, the project uses `GENERATE_INFOPLIST_FILE = YES` with many `INFOPLIST_KEY_*` settings that would have been lost if switching to a custom plist.
- **Fix:** Created `ZenSocial/Info.plist` as an additions-only plist and set `INFOPLIST_ADDITIONS_FILE = ZenSocial/Info.plist` in both Debug and Release configurations. This merges the BGTaskSchedulerPermittedIdentifiers array into the generated Info.plist without disrupting existing settings.
- **Files modified:** ZenSocial.xcodeproj/project.pbxproj, ZenSocial/Info.plist
- **Commit:** 6ef64a4

## Known Stubs

None. All pipeline components are fully wired. The `detectNotificationsInHTML` parser uses best-effort HTML patterns that may need selector updates when Instagram changes their page format — this is an inherent risk documented in the plan.

## Deferred Items

- Pre-existing `ScriptLoader.swift` swiftc warning: `binary operator '+' cannot be applied to two 'OSLogMessage' operands` on lines 150-152. This is a pre-existing issue (from Phase 2) in the `handleLoadFailure` logger call — not caused by Plan 02 changes. The Xcode build handles this correctly; swiftc standalone does not. Logged but not fixed (out of scope).

---
*Phase: 03-push-notifications*
*Completed: 2026-04-03*
