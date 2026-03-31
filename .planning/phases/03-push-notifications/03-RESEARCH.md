# Phase 3: Push Notifications - Research

**Researched:** 2026-03-31
**Domain:** iOS push notifications, Web Push protocol, WKWebView service worker limitations, APNs architecture
**Confidence:** MEDIUM (significant architectural constraints discovered; core approach from CONTEXT.md needs revision)

## Summary

Research reveals a fundamental constraint that materially affects the Phase 3 architecture described in CONTEXT.md: **Web Push does not work in WKWebView**. Apple explicitly limits Web Push (including the new Declarative Web Push in iOS 18.4) to Home Screen web apps and Safari -- not to WKWebView embedded in native apps. This means Instagram's service worker cannot register for push notifications inside ZenSocial's WKWebView, and Option B as described in CONTEXT.md (where "Instagram's backend sends a push to APNs" via the service worker) cannot work as specified.

Additionally, Web Push payloads are end-to-end encrypted between the push server (Instagram) and the browser's subscription keys. Even if a relay server received Instagram's push, it could not decrypt the payload without the subscription's private key, which the browser holds.

The viable path forward requires a **polling-based notification check** or **Instagram's private MQTT protocol** (FBNS) rather than a true push-from-Instagram architecture. The most realistic and maintainable approach is: (1) the native app registers for its own APNs token, (2) a lightweight backend periodically checks Instagram notification state (or uses FBNS), and (3) the backend sends a visible APNs push to the device with the notification content. This delivers in all three states (foreground, background, force-quit) because visible APNs notifications are delivered by iOS at the OS level regardless of app state.

**Primary recommendation:** Revise the architecture to a backend-driven notification relay that polls or subscribes to Instagram notifications independently, then sends visible APNs pushes to the device. This is the only path that satisfies the force-quit hard requirement without relying on APIs that WKWebView does not support.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Push notifications extracted from Phase 2 into a dedicated phase
- **D-02:** Phase 2 must preserve Instagram's service worker and PWA compatibility (confirmed by Phase 2 D-11)
- **D-03:** Dark theme (Phase 2) and push notifications (Phase 3) are separate concerns
- **D-04 (UPDATED):** Commit to Option B -- APNs bridge. Force-quit delivery required.
- **D-05 (UPDATED):** Force-quit push delivery is a hard requirement
- **D-06:** A backend relay server is acceptable if required for force-quit delivery
- **D-07:** Permission prompt triggers after user's first successful Instagram login
- **D-08:** Settings toggle for Instagram push notifications; links to iOS Settings if denied
- **D-09:** Brief native pre-prompt before iOS system permission dialog
- **D-10:** Foreground push surfaces native UNUserNotificationCenter banner
- **D-11:** Tapping notification deep-links to relevant Instagram content

### Claude's Discretion
- Exact payload parsing strategy for extracting deep-link URLs
- Whether to use UNNotificationServiceExtension or handle payload in main app delegate
- Silent push vs background fetch for waking the app
- Notification grouping/threading behavior
- Badge count handling

### Deferred Ideas (OUT OF SCOPE)
- YouTube push notifications
- Notification filtering / quiet hours
- Cross-device sync of notification preferences

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PUSH-01 | User receives Instagram push notifications while app is in foreground | Visible APNs push + UNUserNotificationCenter foreground delegate; well-documented pattern |
| PUSH-02 | User receives Instagram push notifications while app is suspended in background | Visible APNs push delivered by iOS at OS level regardless of app state; confirmed by Apple docs |
| PUSH-03 | User receives Instagram push notifications after force-quit | Visible APNs notifications ARE delivered after force-quit (OS handles delivery). Silent pushes are NOT. Architecture MUST use visible APNs notifications. |

**Note:** PUSH-01/02/03 are not yet defined in REQUIREMENTS.md (push is listed as Out of Scope). CONTEXT.md acknowledges this and states ROADMAP.md Phase 3 is authoritative.

</phase_requirements>

## Critical Finding: Web Push Does Not Work in WKWebView

**Confidence: HIGH** (confirmed by multiple Apple sources)

Web Push (both the original Service Worker-based approach and the new Declarative Web Push from iOS 18.4/WWDC25) is restricted to:
- Safari browser
- Home Screen web apps (PWAs added via "Add to Home Screen")

It is **explicitly not supported** in WKWebView embedded in native apps:

> "Web Push Notifications will not work in apps with a WKWebView. You can use native push notifications with an app that also happens to have a WKWebView, but not Web Push."
> -- Apple Developer Forums

This means:
1. `PushManager.subscribe()` will not succeed in ZenSocial's WKWebView
2. Instagram's service worker cannot register for web push inside the app
3. The CONTEXT.md Option B flow ("Instagram's backend sends a push to APNs" via service worker registration) is not feasible as described

### Impact on CONTEXT.md Architecture

The CONTEXT.md describes Option B as: "Instagram's backend sends a push to APNs. The native app receives a silent APNs push, wakes the WKWebView service worker, which surfaces a UNUserNotificationCenter local notification."

This breaks at step 1: Instagram's backend has no APNs token for ZenSocial because the service worker inside WKWebView cannot subscribe to web push.

### Service Worker Status in WKWebView

Service workers have partial support in WKWebView since iOS 14 when `limitsNavigationsToAppBoundDomains` is set to `true` in Info.plist and `WKWebViewConfiguration`. However:
- This enables basic offline caching, not push
- Push-related APIs (`PushManager`, `Notification`) remain unavailable
- Apple Developer Forums explicitly state there is "no supported way to explicitly support service workers in iOS WKWebView with the APIs currently available"

## Revised Architecture: Backend Notification Relay

Given the constraints above, the viable architecture is:

### Architecture Overview

```
Instagram -----> ZenSocial Backend -----> APNs -----> iOS Device
  (poll/FBNS)      (relay server)        (visible push)
```

1. **ZenSocial backend** monitors Instagram notifications for the user (via polling or FBNS protocol)
2. **Backend sends visible APNs push** to the user's device using the device's native APNs token
3. **iOS delivers the notification** at the OS level -- works in all three states (foreground, background, force-quit)
4. **UNNotificationServiceExtension** (optional) modifies notification content before display
5. **App handles tap** by loading the deep-link URL in the Instagram WKWebView

### Why This Satisfies D-05 (Force-Quit Hard Requirement)

- **Silent push (content-available:1):** Does NOT wake app after force-quit. Apple explicitly states: "An app will not be woken in the background by a silent push notification if the app had previously been force-quit."
- **Visible APNs push (with alert):** IS delivered after force-quit. iOS handles delivery at the OS level, independent of app process state.
- **UNNotificationServiceExtension:** Runs for visible push notifications even after force-quit (it runs in a separate extension process).

Therefore, the relay MUST send **visible** APNs pushes, not silent ones.

## Standard Stack

### Core (Native iOS)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| UNUserNotificationCenter | iOS 17+ | Permission request, notification presentation, foreground handling | Apple's unified notification framework; the only correct API for local+remote notifications |
| APNs (Apple Push Notification service) | Current | Remote notification delivery | Required for push delivery to iOS devices; works across all app states including force-quit |
| UNNotificationServiceExtension | iOS 17+ | Modify notification content before display | Runs in separate process; works even after force-quit; can enrich notifications with images |
| UIApplication.registerForRemoteNotifications() | iOS 17+ | Obtain APNs device token | Standard flow for native push registration |

### Backend Relay Server
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| APNSwift | 6.x | Send APNs pushes from server | Swift-native, async/await, HTTP/2, maintained by swift-server-community |
| Vapor or Hummingbird | Latest | Lightweight Swift server framework | If building relay in Swift; alternatively use Node.js/Python if simpler |
| web-push (Node.js) | 3.x | Web Push protocol utilities | Only if choosing to also implement Web Push subscription endpoint (not recommended for MVP) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom backend relay | Firebase Cloud Messaging (FCM) | FCM handles APNs bridging but requires Google dependency; custom relay gives full control over notification content and filtering |
| Polling Instagram | FBNS (Instagram MQTT) | FBNS is real-time but uses Instagram's private protocol; risk of breakage; polling is simpler and more maintainable |
| APNSwift (Swift server) | Node.js + web-push | Node.js has more web push ecosystem tooling; Swift keeps entire stack in one language |

## Architecture Patterns

### Recommended Project Structure
```
ZenSocial/
  Services/
    NotificationManager.swift       # UNUserNotificationCenter registration, permission, delegate
    APNsTokenManager.swift          # Device token storage and relay registration
  Extensions/
    NotificationServiceExtension/
      NotificationService.swift     # UNNotificationServiceExtension for content modification
      Info.plist
  Scripts/Instagram/
    (existing theme/nav-fixer scripts -- no changes needed)
  Views/
    NotificationPermissionView.swift  # Pre-prompt UI (D-09)
    SettingsPlaceholderView.swift      # Add notification toggle (D-08)
```

### Pattern 1: APNs Device Token Registration
**What:** Register for remote notifications at app launch, send device token to backend relay
**When to use:** Always -- this is the foundation of the push architecture

```swift
// In ZenSocialApp.swift or AppDelegate
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Send token to ZenSocial backend relay
        Task { await APNsTokenManager.shared.registerToken(token) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }
}
```

### Pattern 2: Foreground Notification Handling (D-10)
**What:** Show native banner when push arrives while app is in foreground
**When to use:** Always for foreground notifications

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        // D-10: Always show native banner in foreground
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // D-11: Deep-link to Instagram content
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["instagram_url"] as? String,
           let url = URL(string: urlString) {
            await MainActor.run {
                // Switch to Instagram tab and navigate to URL
                NavigationState.shared.navigateToInstagram(url: url)
            }
        }
    }
}
```

### Pattern 3: Permission Flow (D-07, D-09)
**What:** Two-stage permission request -- pre-prompt then system dialog
**When to use:** After first successful Instagram login detection

```swift
// Detect Instagram login via URL observation in WebViewCoordinator
// When URL transitions from login page to feed, trigger permission flow

func requestNotificationPermission() async -> Bool {
    // D-09: Show pre-prompt first (native SwiftUI alert/sheet)
    // If user taps "Enable", then:
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    guard settings.authorizationStatus == .notDetermined else {
        return settings.authorizationStatus == .authorized
    }

    do {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return granted
    } catch {
        return false
    }
}
```

### Pattern 4: AppDelegate in SwiftUI App (Required for Push)
**What:** SwiftUI lifecycle apps need UIApplicationDelegateAdaptor for push notification callbacks
**When to use:** Required -- SwiftUI @main does not have didRegisterForRemoteNotifications

```swift
@main
struct ZenSocialApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // ... existing code
}
```

### Anti-Patterns to Avoid
- **Using silent push for force-quit delivery:** Silent pushes are NOT delivered after force-quit. NEVER rely on content-available:1 for the force-quit case.
- **Trying to use PushManager.subscribe() in WKWebView:** Web Push APIs are not available in WKWebView. Do not inject JavaScript to call PushManager -- it will fail silently or throw.
- **Setting limitsNavigationsToAppBoundDomains for push:** This enables basic service worker caching but does NOT enable push APIs. It also limits navigation to 10 declared domains, which could break Instagram's auth flows.
- **Registering for notifications at app launch without login:** D-07 requires waiting until after Instagram login. Requesting too early reduces grant rate and is bad UX.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| APNs token formatting | Manual hex conversion with edge cases | Standard `Data.map { String(format: "%02.2hhx", $0) }.joined()` | This is the canonical pattern; no library needed |
| Notification permission state machine | Custom tracking of granted/denied/notDetermined | `UNUserNotificationCenter.current().notificationSettings()` | Apple manages the state; query it, don't shadow it |
| Push payload encryption | Custom AES/ECDH implementation | APNSwift or equivalent server library | Web Push encryption is complex (ECE, HKDF, P-256); server libraries handle it |
| Deep-link URL routing | Regex-based URL parser | Extract from push payload `userInfo` dictionary | Backend controls payload format; keep it simple |

## Common Pitfalls

### Pitfall 1: Assuming Web Push Works in WKWebView
**What goes wrong:** Developer injects JavaScript to call `PushManager.subscribe()` or `Notification.requestPermission()` in WKWebView. It fails silently or returns undefined.
**Why it happens:** Apple restricts Web Push to Safari and Home Screen web apps. WKWebView in native apps does not support it.
**How to avoid:** Use native APNs registration exclusively. Do not attempt any Web Push API calls inside WKWebView.
**Warning signs:** `PushManager` or `navigator.serviceWorker.ready.then(reg => reg.pushManager)` returns undefined or rejects in WKWebView.

### Pitfall 2: Using Silent Push for Force-Quit Delivery
**What goes wrong:** Backend sends content-available:1 silent push. Works in foreground/background but never arrives after force-quit.
**Why it happens:** Apple explicitly does not wake force-quit apps for silent pushes. This is by design -- force-quit is the user's "I don't want this app running" signal.
**How to avoid:** Always send visible APNs pushes with alert content. Visible notifications are delivered by iOS at the OS level regardless of app state.
**Warning signs:** Notifications work in testing (foreground/background) but users report missing notifications. They're force-quitting the app.

### Pitfall 3: AppDelegate vs SwiftUI Lifecycle Conflict
**What goes wrong:** Push notification callbacks (`didRegisterForRemoteNotificationsWithDeviceToken`) never fire because SwiftUI's `@main` App struct doesn't have UIApplicationDelegate methods.
**Why it happens:** SwiftUI lifecycle bypasses traditional AppDelegate.
**How to avoid:** Use `@UIApplicationDelegateAdaptor(AppDelegate.self)` in the SwiftUI App struct. This bridges UIApplicationDelegate callbacks into the SwiftUI lifecycle.
**Warning signs:** `registerForRemoteNotifications()` is called but the token callback never fires.

### Pitfall 4: UNNotificationServiceExtension Memory/Time Limits
**What goes wrong:** Notification Service Extension is killed before it can finish modifying the notification.
**Why it happens:** Extensions have ~30 seconds execution time and ~24MB memory limit.
**How to avoid:** Keep extension work lightweight. Download images asynchronously within the time budget. Implement `serviceExtensionTimeWillExpire()` with a reasonable fallback.
**Warning signs:** Notifications appear with placeholder content or missing images.

### Pitfall 5: Entitlements Missing for Push
**What goes wrong:** App builds but push registration silently fails or returns an invalid token.
**Why it happens:** Missing `aps-environment` entitlement or `UIBackgroundModes: remote-notification` in Info.plist.
**How to avoid:** Add Push Notifications capability in Xcode (Signing & Capabilities), which creates the entitlements file automatically. Also add Background Modes > Remote Notifications.
**Warning signs:** `didFailToRegisterForRemoteNotificationsWithError` fires with a descriptive error about missing entitlements.

### Pitfall 6: Separate WKWebsiteDataStore Prevents Cookie Sharing
**What goes wrong:** After tapping a notification, the WKWebView navigates to the Instagram URL but the user is not logged in.
**Why it happens:** DataStoreManager already uses separate per-platform data stores. The notification tap handler must navigate within the existing Instagram WKWebView instance, not create a new one.
**How to avoid:** D-11 implementation must route to the existing Instagram PlatformWebView and call `webView.load(URLRequest(url:))` on the already-configured instance.
**Warning signs:** Deep-link opens but user sees login page instead of the expected content.

## Code Examples

### APNs Push Payload Format (Backend -> Device)

```json
{
  "aps": {
    "alert": {
      "title": "Instagram",
      "body": "user123 liked your photo"
    },
    "sound": "default",
    "badge": 1,
    "mutable-content": 1
  },
  "instagram_url": "https://www.instagram.com/p/ABC123/",
  "notification_type": "like",
  "thread_id": "instagram_likes"
}
```

Key fields:
- `mutable-content: 1` enables UNNotificationServiceExtension processing
- `instagram_url` is the deep-link target for D-11
- `thread_id` enables notification grouping (Claude's discretion)

### Entitlements File (New)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

### Info.plist Additions

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Service Worker Web Push (iOS 16.4+) | Declarative Web Push (iOS 18.4+) | WWDC 2025 | Removes service worker requirement for web push, but still Safari/Home Screen only -- NOT WKWebView |
| Web Push for all web content | Web Push restricted to Home Screen web apps | iOS 16.4 (2023) | Native apps wrapping websites cannot use Web Push; must use native APNs |
| Custom APNS token-based auth | JWT-based APNs authentication | 2016+ | APNSwift and modern server libraries use JWT auth (p8 key); no need for certificate-based auth |

## Open Questions

1. **Backend architecture for Instagram notification monitoring**
   - What we know: Instagram's Graph API supports webhooks for business accounts. There's also the private FBNS (MQTT) protocol used by community libraries.
   - What's unclear: Whether the user's personal Instagram account can be monitored via webhooks (likely requires business account), and whether FBNS is stable enough for production use.
   - Recommendation: Start with periodic polling of Instagram's notification page via authenticated requests from the backend using the user's session cookies. This is the simplest approach and avoids API/protocol dependencies. Backend makes a GET request to instagram.com/accounts/activity/ equivalent and parses new notifications.

2. **User authentication with backend relay**
   - What we know: The backend needs to know which APNs device token maps to which Instagram session.
   - What's unclear: How to securely transfer the Instagram session from WKWebView to the backend without storing credentials. WKHTTPCookieStore can export cookies, but transmitting Instagram cookies to a third-party server raises privacy and ToS concerns.
   - Recommendation: This is the hardest architectural question. Consider generating a ZenSocial-specific pairing token -- the app registers its APNs token with the backend using a random device ID, and the backend's notification-check mechanism is implemented separately (not via the user's session cookies). Alternatively, implement an in-app notification polling approach that runs purely on-device (foreground/background only) and accept that force-quit requires a backend.

3. **Instagram Terms of Service compliance**
   - What we know: Instagram does not provide a public API for personal account notification subscriptions.
   - What's unclear: Whether scraping/polling Instagram's notification endpoints from a backend server violates Meta's ToS. This could result in account bans.
   - Recommendation: Investigate whether a purely on-device approach (background fetch + local notification) can satisfy enough of the use case to avoid a backend entirely. This sacrifices force-quit delivery but avoids ToS risk.

4. **Apple Developer Program membership**
   - What we know: APNs requires an Apple Developer account for push notification entitlements and provisioning profiles.
   - What's unclear: Whether the project already has an Apple Developer membership and push notification capability enabled.
   - Recommendation: Verify developer account status before planning implementation tasks.

5. **Push payload content -- what to show**
   - What we know: The backend would need to extract notification text (who liked, who commented, who followed, etc.) and a deep-link URL from Instagram's notification data.
   - What's unclear: Exact format of Instagram's web notification data. Instagram's web notifications are rendered client-side; the data comes from GraphQL API responses.
   - Recommendation: Research Instagram's GraphQL notification endpoints during implementation. The notification data structure will determine what can be shown in the push.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Push capability, entitlements | Verify | 16.x+ | -- (required) |
| Apple Developer Account | APNs entitlements, provisioning | Unknown | -- | Cannot use APNs without it |
| Backend server runtime | Notification relay | Not present | -- | On-device polling (loses force-quit) |
| APNSwift / Node.js web-push | Backend sending APNs | Not present | -- | Firebase Cloud Messaging |

**Missing dependencies with no fallback:**
- Apple Developer Program membership (required for APNs push entitlements)

**Missing dependencies with fallback:**
- Backend server infrastructure (could start with on-device polling for foreground/background, add backend later for force-quit)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | None -- needs creation in Wave 0 |
| Quick run command | `xcodebuild test -project ZenSocial.xcodeproj -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZenSocialTests` |
| Full suite command | `xcodebuild test -project ZenSocial.xcodeproj -scheme ZenSocial -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PUSH-01 | Foreground notification banner displayed | manual-only | Requires device/simulator with push | N/A |
| PUSH-02 | Background notification delivered | manual-only | Requires device with push provisioning | N/A |
| PUSH-03 | Force-quit notification delivered | manual-only | Requires device with push provisioning | N/A |
| -- | NotificationManager permission flow logic | unit | `xcodebuild test ... -only-testing:ZenSocialTests/NotificationManagerTests` | No -- Wave 0 |
| -- | APNs token formatting | unit | `xcodebuild test ... -only-testing:ZenSocialTests/APNsTokenTests` | No -- Wave 0 |
| -- | Deep-link URL parsing from payload | unit | `xcodebuild test ... -only-testing:ZenSocialTests/NotificationPayloadTests` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Unit tests only (permission flow, token formatting, payload parsing)
- **Per wave merge:** Full unit suite + manual simulator verification
- **Phase gate:** Manual verification of all three states on physical device

### Wave 0 Gaps
- [ ] `ZenSocialTests/NotificationManagerTests.swift` -- permission flow unit tests
- [ ] `ZenSocialTests/APNsTokenTests.swift` -- token formatting
- [ ] `ZenSocialTests/NotificationPayloadTests.swift` -- deep-link extraction
- [ ] XCTest target may need creation if not already in project

**Note:** PUSH-01/02/03 are inherently manual-verification requirements. Push notification delivery cannot be meaningfully tested in automated CI without a real APNs connection and device provisioning. Unit tests cover the logic layer; delivery verification requires physical device testing.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Forums: WKWebView push notification support](https://developer.apple.com/forums/thread/728537) -- Confirms Web Push not available in WKWebView
- [Apple Developer Forums: Web app push notifications on native WKWebView](https://developer.apple.com/forums/thread/760767) -- Same confirmation
- [WebKit Blog: Web Push for Web Apps on iOS and iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/) -- Web Push is for Home Screen web apps only
- [Apple Developer: UNNotificationServiceExtension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension) -- Extension runs for visible notifications after force-quit
- [Apple Developer Forums: Handle background notification in terminated status](https://developer.apple.com/forums/thread/744901) -- Silent push does not wake force-quit apps
- [WebKit Blog: Meet Declarative Web Push](https://webkit.org/blog/16535/meet-declarative-web-push/) -- iOS 18.4 Declarative Web Push; still Safari/Home Screen only

### Secondary (MEDIUM confidence)
- [MagicBell: PWA iOS Limitations and Safari Support 2026](https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide) -- Comprehensive overview of iOS web push limitations
- [GitHub: swift-server-community/APNSwift](https://github.com/swift-server-community/APNSwift) -- Server-side APNs library
- [GitHub: mochidev/swift-webpush](https://github.com/mochidev/swift-webpush) -- Server-side Web Push library in Swift
- [GitHub: hotwired/hotwire-native-ios Issue #188](https://github.com/hotwired/hotwire-native-ios/issues/188) -- Community confirmation of service worker limitations in WKWebView

### Tertiary (LOW confidence)
- [GitHub: Nerixyz/instagram_mqtt](https://github.com/Nerixyz/instagram_mqtt) -- FBNS (Instagram private push) protocol; undocumented, reverse-engineered, may break
- [Medium: iOS Silent Background Push Notifications](https://medium.com/@durgavundavalli/ios-silent-background-push-notifications-5bbadc5606cd) -- General background push guidance

## Project Constraints (from CLAUDE.md)

- **Platform**: iOS only, Swift/SwiftUI + WKWebView
- **WKWebView required**: iOS 26 SwiftUI WebView lacks WKUserContentController; must use UIViewRepresentable pattern
- **No external dependencies for MVP**: Entire stack uses Apple frameworks (but Phase 3 backend relay may require server-side dependencies)
- **Script organization**: Platform-specific scripts in `Scripts/Instagram/`, `Scripts/YouTube/`
- **State management**: `@Observable` macro, `@AppStorage` for preferences
- **Cookie persistence**: Default `WKWebsiteDataStore` (non-ephemeral) per platform via DataStoreManager
- **No Co-Authored-By trailers in git commits** (from user's global CLAUDE.md)
- **Push to GitHub after every commit**

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- UNUserNotificationCenter and APNs are well-documented Apple APIs
- Architecture: MEDIUM -- The revised architecture (backend relay) is sound but introduces open questions about Instagram notification monitoring and ToS compliance
- Pitfalls: HIGH -- Force-quit behavior, Web Push limitations, and entitlements requirements are well-documented by Apple
- Backend feasibility: LOW -- Instagram notification polling/monitoring from a backend is the weakest link; no official API exists for personal accounts

**Research date:** 2026-03-31
**Valid until:** 2026-04-30 (Apple APIs are stable; Instagram's notification data format may change)
