import SwiftUI

struct HomeScreenView: View {
    let onSelectPlatform: (Platform) -> Void
    let onOpenSettings: () -> Void

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 48) {
                    // Branding
                    VStack(spacing: 8) {
                        Text("ZenSocial")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Social media, without the noise.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Platform launcher cards + settings
                    VStack(spacing: 16) {
                        ForEach(Platform.allCases) { platform in
                            PlatformLauncherCard(platform: platform) {
                                onSelectPlatform(platform)
                            }
                        }
                        SettingsLauncherCard {
                            showSettings = true
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsPlaceholderView()
            }
        }
    }
}

// MARK: - Platform Launcher Card

private struct PlatformLauncherCard: View {
    let platform: Platform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left identity stripe
                platform.identityColor
                    .frame(width: 4)

                HStack(spacing: 24) {
                    Image(systemName: platform.filledIconName)
                        .font(.system(size: 28))
                        .foregroundStyle(platform.identityColor)
                    Text(platform.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.zenInactiveGray)
                }
                .padding(24)
            }
            .frame(height: 120)
            .background(Color.zenSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Open \(platform.displayName)")
        .accessibilityHint("Loads \(platform.displayName) in the web viewer")
    }
}

// MARK: - Settings Launcher Card

private struct SettingsLauncherCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.zenInactiveGray)
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.zenInactiveGray)
            }
            .padding(24)
            .frame(height: 120)
            .background(Color.zenSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Open Settings")
    }
}
