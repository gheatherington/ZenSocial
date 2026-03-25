import SwiftUI

struct ErrorView: View {
    let platform: Platform
    let errorKind: WebViewState.ErrorKind
    let isOffline: Bool
    let onRetry: () -> Void

    private var iconName: String {
        // Use offline icon if actually offline, regardless of error kind
        isOffline ? "wifi.slash" : "exclamationmark.triangle"
    }

    private var heading: String {
        isOffline ? "You're Offline" : "Something Went Wrong"
    }

    private var bodyText: String {
        isOffline
            ? "Check your internet connection and try again."
            : "\(platform.displayName) couldn't load. Try again in a moment."
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.zenInactiveGray)  // #8E8E93 per UI-SPEC
                    .accessibilityHidden(true)

                Spacer().frame(height: 24)  // lg spacing per UI-SPEC

                Text(heading)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)  // White in dark mode

                Spacer().frame(height: 8)  // sm spacing

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)  // 60% white in dark mode
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)  // md padding

                Spacer().frame(height: 32)  // xl spacing per UI-SPEC

                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(Color.zenAccent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Try again")
                .accessibilityHint("Reloads \(platform.displayName)")
            }
        }
    }
}
