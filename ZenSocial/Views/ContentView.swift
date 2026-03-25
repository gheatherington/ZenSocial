import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Platform = .instagram

    // Hold WebViewState per platform outside view lifecycle (RESEARCH Pitfall 7)
    @State private var instagramState = WebViewState()
    @State private var youtubeState = WebViewState()

    var body: some View {
        TabView(selection: $selectedTab) {
            PlatformTabView(platform: .instagram, state: instagramState)
                .tabItem {
                    Label(Platform.instagram.displayName,
                          systemImage: Platform.instagram.iconName)
                }
                .tag(Platform.instagram)

            PlatformTabView(platform: .youtube, state: youtubeState)
                .tabItem {
                    Label(Platform.youtube.displayName,
                          systemImage: Platform.youtube.iconName)
                }
                .tag(Platform.youtube)
        }
        .tint(Color.zenAccent)  // Active tab tint per UI-SPEC: #4DA6FF
    }
}
