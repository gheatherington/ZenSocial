import SwiftUI

enum LoadingVariant {
    case instagram
    case youtube
    case auth
    case general

    var iconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .youtube: return "play.rectangle.fill"
        case .auth: return "person.crop.circle"
        case .general: return "globe"
        }
    }

    var iconColor: Color {
        switch self {
        case .instagram: return .zenInstagramPink
        case .youtube: return .red
        case .auth: return .zenAccent
        case .general: return .zenInactiveGray
        }
    }

    var heading: String {
        switch self {
        case .instagram: return "Loading Instagram"
        case .youtube: return "Loading YouTube"
        case .auth: return "Waiting for Sign In"
        case .general: return "Loading..."
        }
    }

    var subheading: String {
        switch self {
        case .auth: return "Complete login to continue."
        default: return "Just a moment..."
        }
    }
}

struct LoadingScreenView: View {
    let variant: LoadingVariant

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: variant.iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(variant.iconColor)
                    .accessibilityHidden(true)
                Text(variant.heading)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(variant.subheading)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                ProgressView()
                    .tint(.zenAccent)
                    .padding(.top, 16)
            }
        }
    }
}
