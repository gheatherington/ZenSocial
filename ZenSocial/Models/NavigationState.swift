import Foundation
import Observation
import SwiftUI
import UIKit

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
