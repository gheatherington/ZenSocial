import Foundation
import WebKit
import UserNotifications
import BackgroundTasks
import os

// MARK: - NotificationPoller

/// Handles Instagram notification detection for both foreground (via JS bridge/WKScriptMessageHandler)
/// and background (via BGAppRefreshTask + URLSession with exported session cookies) scenarios.
///
/// Foreground flow: notification-bridge.js detects DOM badge changes -> posts to zenNotification
/// message handler -> scheduleLocalNotification if genuinely new.
///
/// Background flow: BGAppRefreshTask wakes the app -> exportInstagramCookies() from DataStoreManager
/// -> URLSession with those cookies fetches Instagram -> detectNotificationsInHTML() parses response
/// -> only fires local notification if new activity detected vs. last-known state in UserDefaults.
@MainActor
class NotificationPoller: NSObject {

    // MARK: - Singleton

    static let shared = NotificationPoller()

    // MARK: - Constants

    static let bgTaskIdentifier = "com.zensocial.notification-check"

    private let logger = Logger(subsystem: "com.zensocial.app", category: "NotificationPoller")

    // MARK: - State

    /// Tracks the timestamp of the last foreground notification fired to prevent duplicates
    /// within a short polling window.
    private var lastForegroundNotificationEpoch: TimeInterval = 0

    /// Key for UserDefaults: whether Instagram had an unread notification badge last time we checked.
    private let lastKnownStateKey = "instagramLastKnownNotificationState"

    // MARK: - Local Notification Scheduling

    /// Schedules an immediate local notification with the given content.
    /// Uses a unique identifier per notification (timestamp-based) to avoid collisions.
    func scheduleLocalNotification(title: String, body: String, url: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["instagram_url": url]
        content.threadIdentifier = "instagram_activity"

        let request = UNNotificationRequest(
            identifier: "instagram-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // nil trigger = deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Scheduled local notification: \(body)")
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Instagram Cookie Export

    /// Exports all Instagram session cookies from the WKHTTPCookieStore used by DataStoreManager.
    ///
    /// This is the mechanism that enables background polling: WKWebView cannot run JS while
    /// suspended, but its session cookies can be exported and used with a regular URLSession
    /// to make authenticated HTTP requests to Instagram from a BGAppRefreshTask.
    func exportInstagramCookies() async -> [HTTPCookie] {
        let dataStore = DataStoreManager.dataStore(for: .instagram)
        let cookies = await dataStore.httpCookieStore.allCookies()
        return cookies.filter { $0.domain.contains("instagram.com") }
    }

    // MARK: - Background Instagram Notification Check

    /// Checks Instagram for new notification activity using URLSession with exported session cookies.
    ///
    /// Returns true if new activity was detected that has not been seen before (compared via
    /// lastKnownStateKey in UserDefaults). Returns false if no new activity or if the check fails.
    ///
    /// This implements on-device cookie-based polling (PUSH-02) without any backend relay.
    func checkInstagramNotifications() async -> Bool {
        let cookies = await exportInstagramCookies()
        guard !cookies.isEmpty else {
            logger.warning("No Instagram cookies available for background poll -- user may not be logged in")
            return false
        }

        // Build a URLSession with Instagram's session cookies injected
        let sessionConfig = URLSessionConfiguration.ephemeral
        let cookieStorage = HTTPCookieStorage()
        for cookie in cookies {
            cookieStorage.setCookie(cookie)
        }
        sessionConfig.httpCookieStorage = cookieStorage
        sessionConfig.timeoutIntervalForRequest = 15
        sessionConfig.timeoutIntervalForResource = 20

        let session = URLSession(configuration: sessionConfig)

        guard let url = URL(string: "https://www.instagram.com/") else { return false }

        var request = URLRequest(url: url)
        // Use a mobile Safari user-agent so Instagram serves the mobile web page format
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8)
            else {
                logger.warning("Instagram background fetch returned non-200 or unreadable response")
                return false
            }

            let hasNotifications = detectNotificationsInHTML(html)
            let lastKnownState = UserDefaults.standard.bool(forKey: lastKnownStateKey)

            if hasNotifications && !lastKnownState {
                // Genuinely new notifications detected -- update state and report
                UserDefaults.standard.set(true, forKey: lastKnownStateKey)
                logger.info("Background poll: new Instagram notifications detected")
                return true
            } else if !hasNotifications {
                // Notifications cleared -- update state (user viewed them)
                UserDefaults.standard.set(false, forKey: lastKnownStateKey)
            }

            return false
        } catch {
            logger.error("Instagram background fetch error: \(error.localizedDescription)")
            return false
        }
    }

    /// Parses Instagram's HTML response for notification badge indicators.
    ///
    /// Instagram embeds serialized JSON in its initial page HTML that includes notification state.
    /// We use multiple strategies for resilience against DOM/serialization changes.
    private func detectNotificationsInHTML(_ html: String) -> Bool {
        // Strategy 1: badge_count in serialized JSON (common in Instagram's embedded page data)
        if html.contains("\"badge_count\":") {
            if let range = html.range(of: #""badge_count":\s*(\d+)"#, options: .regularExpression) {
                let match = String(html[range])
                let digits = match.filter { $0.isNumber }
                if let count = Int(digits), count > 0 {
                    return true
                }
            }
        }

        // Strategy 2: unseen_count (used in some Instagram API response formats)
        if html.contains("\"unseen_count\":") {
            if let range = html.range(of: #""unseen_count":\s*(\d+)"#, options: .regularExpression) {
                let match = String(html[range])
                let digits = match.filter { $0.isNumber }
                if let count = Int(digits), count > 0 {
                    return true
                }
            }
        }

        // Strategy 3: has_unseen boolean flag (simpler indicator)
        if html.contains("\"has_unseen\":true") {
            return true
        }

        // Strategy 4: notification_count in shared data
        if html.contains("\"notification_count\":") {
            if let range = html.range(of: #""notification_count":\s*(\d+)"#, options: .regularExpression) {
                let match = String(html[range])
                let digits = match.filter { $0.isNumber }
                if let count = Int(digits), count > 0 {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - BGAppRefreshTask Registration

    /// Registers the background refresh task handler with BGTaskScheduler.
    ///
    /// Must be called in AppDelegate.application(_:didFinishLaunchingWithOptions:)
    /// BEFORE the app finishes launching. Calling it later is a programming error
    /// that BGTaskScheduler will log as a warning.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.handleBackgroundRefresh(task: refreshTask)
            }
        }
        logger.info("BGAppRefreshTask registered: \(Self.bgTaskIdentifier)")
    }

    /// Schedules the next background refresh request.
    ///
    /// Call when the app enters the background. iOS will honor earliestBeginDate
    /// as a minimum delay — actual scheduling is at OS discretion based on usage patterns.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        // Request a refresh no sooner than 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled (earliest: 15 min)")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    /// Handles the BGAppRefreshTask when the OS wakes the app in the background.
    ///
    /// Pipeline: re-schedule next refresh -> check Settings toggle -> export cookies ->
    /// URLSession fetch Instagram -> diff against last-known state -> fire local notification
    /// if genuinely new activity detected.
    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        // Schedule next refresh first (before any async work, in case task is expired)
        scheduleBackgroundRefresh()

        // Respect the user's Settings toggle
        guard NotificationManager.shared.userWantsNotifications,
              NotificationManager.shared.authorizationStatus == .authorized
        else {
            logger.info("Background refresh: notifications disabled or not authorized, skipping")
            task.setTaskCompleted(success: true)
            return
        }

        // Set expiration handler -- iOS may terminate early if budget exceeded
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let hasNewActivity = await checkInstagramNotifications()

        if hasNewActivity {
            await scheduleLocalNotification(
                title: "Instagram",
                body: "You have new activity on Instagram",
                url: "https://www.instagram.com/accounts/activity/"
            )
        }

        task.setTaskCompleted(success: true)
    }
}

// MARK: - WKScriptMessageHandler Conformance

/// WKScriptMessageHandler is nonisolated in Swift 6 strict concurrency.
/// Although WebKit normally calls this on the main thread, edge cases (web process
/// crash recovery, cross-process navigation) may violate that guarantee.
/// We use Task { @MainActor in } to safely hop to the main actor without assuming
/// the current thread — avoiding a fatal trap from MainActor.assumeIsolated.
extension NotificationPoller: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Extract message data while still in the callback context.
        // WKScriptMessage.name and .body are safe to read here (same thread as caller).
        let messageName = message.name
        let messageBody = message.body

        Task { @MainActor in
            guard messageName == "zenNotification",
                  let body = messageBody as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            guard NotificationManager.shared.userWantsNotifications,
                  NotificationManager.shared.authorizationStatus == .authorized
            else { return }

            if type == "badge_change" {
                let timestamp = body["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970 * 1000
                let epochSeconds = timestamp / 1000.0
                guard epochSeconds > NotificationPoller.shared.lastForegroundNotificationEpoch + 30 else { return }
                NotificationPoller.shared.lastForegroundNotificationEpoch = epochSeconds

                let badgeType = body["badgeType"] as? String ?? "activity"
                let notifBody: String
                let notifURL: String
                if badgeType == "dm" {
                    notifBody = "You have a new direct message on Instagram"
                    notifURL = "https://www.instagram.com/direct/inbox/"
                } else {
                    notifBody = "You have new activity on Instagram"
                    notifURL = "https://www.instagram.com/accounts/activity/"
                }

                await NotificationPoller.shared.scheduleLocalNotification(
                    title: "Instagram",
                    body: notifBody,
                    url: notifURL
                )
            }
        }
    }
}
