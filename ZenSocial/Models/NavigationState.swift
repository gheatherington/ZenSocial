import Foundation
import Observation
import SwiftUI
import UIKit

// MARK: - Deep-Link Notification Names

extension Notification.Name {
    /// Posted by NavigationState.navigateToInstagram(url:) after switching to the Instagram tab.
    /// ContentView observes this to load the URL in the existing Instagram WKWebView.
    /// userInfo: ["url": URL, "platform": String]
    static let zenDeepLinkNavigation = Notification.Name("zenDeepLinkNavigation")
}

@Observable
@MainActor
class NavigationState {
    enum Screen: String {
        case home
        case instagram
        case youtube
    }

    @ObservationIgnored
    @AppStorage("lastPlatform") private var lastPlatformRaw: String = ""

    var activeScreen: Screen = .home
    var isPillExpanded: Bool = false
    var pillPosition: CGPoint = .zero

    var activePlatform: Platform? {
        switch activeScreen {
        case .home: return nil
        case .instagram: return .instagram
        case .youtube: return .youtube
        }
    }

    init() {
        loadPillPosition()
    }

    func navigate(to screen: Screen) {
        activeScreen = screen
        isPillExpanded = false
        if screen != .home {
            lastPlatformRaw = screen.rawValue
        }
    }

    /// Switches to Instagram tab and posts .zenDeepLinkNavigation for ContentView to load the URL.
    /// Used by notification tap deep-linking (D-11): tapping a notification routes here,
    /// which navigates to Instagram and signals the WKWebView to load the target URL.
    func navigateToInstagram(url: URL) {
        navigate(to: .instagram)
        NotificationCenter.default.post(
            name: .zenDeepLinkNavigation,
            object: nil,
            userInfo: ["url": url, "platform": "instagram"]
        )
    }

    func restoreLastPlatform() {
        guard !lastPlatformRaw.isEmpty,
              let screen = Screen(rawValue: lastPlatformRaw),
              screen != .home else {
            return
        }
        activeScreen = screen
    }

    func savePillPosition() {
        UserDefaults.standard.set(pillPosition.x, forKey: "pillPositionX")
        UserDefaults.standard.set(pillPosition.y, forKey: "pillPositionY")
    }

    func loadPillPosition() {
        let x = UserDefaults.standard.double(forKey: "pillPositionX")
        let y = UserDefaults.standard.double(forKey: "pillPositionY")
        if x != 0 || y != 0 {
            pillPosition = CGPoint(x: x, y: y)
        } else {
            pillPosition = CGPoint(
                x: UIScreen.main.bounds.width - 44,
                y: UIScreen.main.bounds.height - 120
            )
        }
    }
}
