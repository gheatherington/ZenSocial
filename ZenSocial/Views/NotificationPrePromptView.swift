import SwiftUI

struct NotificationPrePromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onEnable: () async -> Void
    var onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Stay in the loop", isPresented: $isPresented) {
                Button("Enable Notifications") {
                    Task { await onEnable() }
                }
                Button("Not Now", role: .cancel) {
                    onDismiss()
                }
            } message: {
                Text("ZenSocial can show you Instagram notifications as native banners \u{2014} no distractions, just what matters.")
            }
    }
}

extension View {
    func notificationPrePrompt(
        isPresented: Binding<Bool>,
        onEnable: @escaping () async -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(NotificationPrePromptModifier(
            isPresented: isPresented,
            onEnable: onEnable,
            onDismiss: onDismiss
        ))
    }
}
