import SwiftUI

struct SettingsPlaceholderView: View {
    private var notificationManager = NotificationManager.shared

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                Section("Notifications") {
                    switch notificationManager.authorizationStatus {
                    case .authorized, .provisional, .ephemeral:
                        Toggle("Instagram Notifications", isOn: Binding(
                            get: { notificationManager.userWantsNotifications },
                            set: { notificationManager.userWantsNotifications = $0 }
                        ))
                    case .denied:
                        Button("Open Settings to Enable") {
                            notificationManager.openAppSettings()
                        }
                    case .notDetermined:
                        Button("Enable Notifications") {
                            Task { _ = await notificationManager.requestPermission() }
                        }
                    @unknown default:
                        EmptyView()
                    }
                }

                Section {
                    Text("Build \(buildNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }
}
