import SwiftUI

@main
struct ZenSocialApp: App {
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
                uaReady = true
            }
            .preferredColorScheme(.dark)
        }
    }
}
