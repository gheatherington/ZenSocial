import Foundation

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

    func isOwnDomain(_ host: String) -> Bool {
        switch self {
        case .instagram:
            return host.hasSuffix("instagram.com") || host.hasSuffix("cdninstagram.com")
        case .youtube:
            return host.hasSuffix("youtube.com") || host.hasSuffix("googlevideo.com")
                || host.hasSuffix("ytimg.com")
        }
    }
}
