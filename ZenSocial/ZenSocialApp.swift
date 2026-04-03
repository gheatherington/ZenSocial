import SwiftUI
import UserNotifications

@main
struct ZenSocialApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var networkMonitor = NetworkMonitor()
    @State private var uaReady = false

    var body: some Scene {
        WindowGroup {
            Group {
                if uaReady {
                    ContentView()
                        .environment(networkMonitor)
                } else {
                    // Loading gate: block tab rendering until UA extraction completes.
                    // Prevents PlatformWebView.makeUIView from running with a nil
                    // customUserAgent, which would fail BLOCK-03 on the first load.
                    Color.black.ignoresSafeArea()
                }
            }
            .task {
                // BLOCK-03: Must complete before any WKWebView is created
                await UserAgentProvider.shared.extractUserAgent()
                networkMonitor.start()
                // Read notification authorization state without triggering permission dialog.
                // Per D-07: permission is requested after first Instagram login, not at launch.
                await NotificationManager.shared.refreshAuthorizationStatus()
                uaReady = true
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register NotificationManager as the UNUserNotificationCenter delegate
        // so it can intercept foreground notifications (D-10) and handle taps (D-11).
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Phase 3 is on-device only; log token for debugging.
        // A backend relay (Phase 3.1+) would send this token to the server.
        print("[APNs] Device token: \(token)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }
}
