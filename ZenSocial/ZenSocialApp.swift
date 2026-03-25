import SwiftUI

@main
struct ZenSocialApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}
