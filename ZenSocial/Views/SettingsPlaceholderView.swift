import SwiftUI

struct SettingsPlaceholderView: View {
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

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
                Text("Build \(buildNumber)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
