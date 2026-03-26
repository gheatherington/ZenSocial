import Foundation
import SwiftUI

enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        }
    }

    var homeURL: URL {
        switch self {
        case .instagram: return URL(string: "https://www.instagram.com/")!
        case .youtube: return URL(string: "https://m.youtube.com/")!
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera"
        case .youtube: return "play.rectangle"
        }
    }

    var identityColor: Color {
        switch self {
        case .instagram: return .zenInstagramPink
        case .youtube: return .zenYouTubeRed
        }
    }

    var filledIconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .youtube: return "play.rectangle.fill"
        }
    }

    func isOwnDomain(_ host: String) -> Bool {
        switch self {
        case .instagram:
            return host.hasSuffix("instagram.com") || host.hasSuffix("cdninstagram.com")
                || host.hasSuffix("facebook.com") || host.hasSuffix("fbsbx.com")
                || host.hasSuffix("fbcdn.net")
        case .youtube:
            return host.hasSuffix("youtube.com") || host.hasSuffix("googlevideo.com")
                || host.hasSuffix("ytimg.com") || host.hasSuffix("google.com")
                || host.hasSuffix("googleapis.com") || host.hasSuffix("gstatic.com")
                || host.hasSuffix("ggpht.com")
        }
    }
}
