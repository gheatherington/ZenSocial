import Foundation
import UserNotifications
import Observation
import UIKit

@Observable
@MainActor
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Published State

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var hasCompletedPrePrompt: Bool = false

    // MARK: - Persisted Preferences

    // Has the pre-prompt been shown at least once?
    @ObservationIgnored
    private var prePromptShown: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationPrePromptShown") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationPrePromptShown") }
    }

    // User's in-app toggle preference (persisted, respected by Plan 02 polling)
    @ObservationIgnored
    var userWantsNotifications: Bool {
        get { UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    // MARK: - Singleton

    static let shared = NotificationManager()

    override init() {
        super.init()
        hasCompletedPrePrompt = prePromptShown
    }

    // MARK: - Authorization

    /// Call at app launch to read current authorization state without requesting permission.
    /// Per D-07: does NOT trigger the system permission dialog.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Two-stage permission flow: reads current state, then requests system dialog if undetermined.
    /// Per D-07: triggered after first Instagram login, not at launch.
    /// Returns true if permission was granted (or already authorized).
    func requestPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Pre-Prompt State

    func markPrePromptShown() {
        prePromptShown = true
        hasCompletedPrePrompt = true
    }

    /// True when the pre-prompt should be shown: first time, permission not yet determined.
    var shouldShowPrePrompt: Bool {
        !prePromptShown && authorizationStatus == .notDetermined
    }

    // MARK: - Settings Deep-Link

    /// Opens iOS Settings for this app (used in Settings screen when status is .denied).
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// D-10: Always show banner in foreground — native iOS feel regardless of app state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// D-11: Deep-link on tap — posts notification for ContentView to observe.
    /// Plan 02 wires navigation from this notification to the Instagram tab.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["instagram_url"] as? String,
           let url = URL(string: urlString) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .zenNotificationTapped,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let zenNotificationTapped = Notification.Name("zenNotificationTapped")
}
