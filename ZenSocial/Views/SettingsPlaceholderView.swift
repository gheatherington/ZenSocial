import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.zenInactiveGray)
                Text("Settings coming soon")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
