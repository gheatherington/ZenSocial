import SwiftUI
import UIKit

struct PlatformTabView: View {
    let platform: Platform
    @Bindable var state: WebViewState
    @Environment(NetworkMonitor.self) private var networkMonitor

    // D-10: Script load failure alert state
    @State private var showScriptError = false
    @State private var failedPlatform = ""
    @State private var failedFilename = ""

    var body: some View {
        ZStack {
            // Base: always render PlatformWebView (keeps WKWebView alive)
            // Hidden behind error screen when in error state
            PlatformWebView(platform: platform, state: state)

            // Loading overlay (D-13, D-14: context-aware loading screens)
            if state.loadingState == .loading {
                LoadingScreenView(variant: platform == .instagram ? .instagram : .youtube)
                    .transition(.opacity)
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
        // D-10: Script load failure alert (release builds only)
        .onReceive(NotificationCenter.default.publisher(for: .zenScriptLoadFailure)) { notification in
            guard let notifPlatform = notification.userInfo?["platform"] as? String,
                  notifPlatform == platform.rawValue else { return }
            failedPlatform = platform.displayName
            failedFilename = notification.userInfo?["filename"] as? String ?? "unknown"
            showScriptError = true
        }
        .alert("Theme failed to load", isPresented: $showScriptError) {
            Button("Dismiss", role: .cancel) { }
            Button("Report Issue") {
                let version = UIDevice.current.systemVersion
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                let diagnosticText = """
                    ZenSocial theme loading failed
                    Platform: \(failedPlatform)
                    iOS: \(version)
                    App: \(appVersion)
                    Script: \(failedFilename)
                    """
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    let activityVC = UIActivityViewController(
                        activityItems: [diagnosticText],
                        applicationActivities: nil
                    )
                    rootVC.present(activityVC, animated: true)
                }
            }
        } message: {
            Text("\(failedPlatform) theme could not be applied. The app will work normally without it.")
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
