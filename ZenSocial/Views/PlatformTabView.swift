import SwiftUI

struct PlatformTabView: View {
    let platform: Platform
    @Bindable var state: WebViewState
    @Environment(NetworkMonitor.self) private var networkMonitor

    var body: some View {
        ZStack {
            // Base: always render PlatformWebView (keeps WKWebView alive)
            // Hidden behind error screen when in error state
            PlatformWebView(platform: platform, state: state)

            // Loading overlay (SHELL-02, per UI-SPEC Loading Indicator)
            if state.loadingState == .loading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                ProgressView()
                    .tint(Color.zenAccent)
                    .scaleEffect(1.2)
                    .accessibilityLabel("Loading \(platform.displayName)")
            }

            // Error screen (SHELL-03, per UI-SPEC Error/Offline Screen)
            if case .error(let errorKind) = state.loadingState {
                ErrorView(
                    platform: platform,
                    errorKind: errorKind,
                    isOffline: !networkMonitor.isConnected
                ) {
                    // Retry action: reload via notification
                    state.loadingState = .loading
                    NotificationCenter.default.post(
                        name: .zenSocialReload,
                        object: platform.rawValue
                    )
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: state.loadingState == .loading)
        .animation(.easeOut(duration: 0.3), value: isErrorState)
        .sheet(item: $state.pendingAuthURL) { url in
            AuthModalView(platform: platform, url: url)
        }
    }

    private var isErrorState: Bool {
        if case .error = state.loadingState { return true }
        return false
    }
}

// Make URL conform to Identifiable for .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// Notification for reload requests
extension Notification.Name {
    static let zenSocialReload = Notification.Name("zenSocialReload")
}
