import SwiftUI

struct ContentView: View {
    @State private var nav = NavigationState()
    @State private var instagramState = WebViewState()
    @State private var youtubeState = WebViewState()

    var body: some View {
        ZStack {
            // Layer 0: Dark background (D-16 -- native chrome matches web content)
            Color.black.ignoresSafeArea()

            // Layer 1: Both platform web views ALWAYS rendered (session preservation)
            // CRITICAL: Never use if/else for these -- opacity+allowsHitTesting only
            PlatformTabView(platform: .instagram, state: instagramState)
                .opacity(nav.activePlatform == .instagram ? 1 : 0)
                .allowsHitTesting(nav.activePlatform == .instagram)

            PlatformTabView(platform: .youtube, state: youtubeState)
                .opacity(nav.activePlatform == .youtube ? 1 : 0)
                .allowsHitTesting(nav.activePlatform == .youtube)

            // Layer 2: Home screen (shown when activeScreen == .home)
            if nav.activeScreen == .home {
                HomeScreenView(
                    onSelectPlatform: { platform in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            switch platform {
                            case .instagram: nav.navigate(to: .instagram)
                            case .youtube: nav.navigate(to: .youtube)
                            }
                        }
                    },
                    onOpenSettings: {
                        // Settings navigation handled internally by HomeScreenView's NavigationStack
                    }
                )
                .transition(.opacity)
            }

            // Layer 3: Floating pill button (always on top)
            FloatingPillButton(nav: nav)
        }
        .preferredColorScheme(.dark)
        .onChange(of: nav.activeScreen) { oldValue, _ in
            // Pause videos on the platform being left (D-01, D-02)
            switch oldValue {
            case .instagram:
                instagramState.pauseAllVideos()
            case .youtube:
                youtubeState.pauseAllVideos()
            case .home:
                break
            }
        }
        .onAppear {
            nav.restoreLastPlatform()
        }
    }
}
