import SwiftUI

struct FloatingPillButton: View {
    @Bindable var nav: NavigationState
    @GestureState private var dragTranslation: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pillSize: CGFloat = 56
    private let iconSize: CGFloat = 22
    private let expandedIconSize: CGFloat = 20
    private let tapTargetSize: CGFloat = 44
    private let edgeMargin: CGFloat = 8
    private let expandedPillWidth: CGFloat = 172  // 3 * 44 + 2 * 8 + 2 * 12

    var body: some View {
        ZStack {
            // Tap-away dismiss layer (only when expanded)
            if nav.isPillExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        togglePill(expanded: false)
                    }
                    .accessibilityHidden(true)
            }

            // Pill button
            Group {
                if nav.isPillExpanded {
                    expandedPill
                        .offset(x: expandedPillOffset)
                } else {
                    collapsedPill
                }
            }
            .position(CGPoint(
                x: nav.pillPosition.x + dragTranslation.width,
                y: nav.pillPosition.y + dragTranslation.height
            ))
        }
    }

    /// Offset to apply when expanded pill would clip past screen edges.
    /// Returns 0 when centered expansion fits; shifts left/right near edges.
    private var expandedPillOffset: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let halfExpanded = expandedPillWidth / 2  // 86
        let leftEdge = nav.pillPosition.x - halfExpanded
        let rightEdge = nav.pillPosition.x + halfExpanded

        if leftEdge < edgeMargin {
            return edgeMargin - leftEdge  // positive, shift right
        } else if rightEdge > screenWidth - edgeMargin {
            return (screenWidth - edgeMargin) - rightEdge  // negative, shift left
        } else {
            return 0  // centered, no offset needed
        }
    }

    // MARK: - Collapsed State

    private var collapsedPill: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: pillSize, height: pillSize)

            Circle()
                .fill(Color.zenSecondaryBackground.opacity(0.9))
                .frame(width: pillSize, height: pillSize)

            Image(systemName: "house.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.zenAccent)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            togglePill(expanded: true)
        }
        .gesture(dragGesture)
        .accessibilityLabel("Navigation")
        .accessibilityHint("Double-tap to expand navigation options")
    }

    // MARK: - Expanded State

    private var expandedPill: some View {
        HStack(spacing: 8) {
            pillItem(screen: .home, icon: "house.fill", label: "Home")
            pillItem(screen: .instagram, icon: "camera.fill", label: "Instagram")
            pillItem(screen: .youtube, icon: "play.rectangle.fill", label: "YouTube")
        }
        .padding(.horizontal, 12)
        .frame(height: pillSize)
        .background {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)

                Capsule()
                    .fill(Color.zenSecondaryBackground.opacity(0.95))
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
    }

    private func pillItem(screen: NavigationState.Screen, icon: String, label: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                nav.navigate(to: screen)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: expandedIconSize))
                .foregroundStyle(nav.activeScreen == screen ? Color.zenAccent : Color.zenInactiveGray)
                .frame(width: tapTargetSize, height: tapTargetSize)
        }
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, transaction in
                state = value.translation
                transaction.disablesAnimations = true
            }
            .onEnded { value in
                let final = CGPoint(
                    x: nav.pillPosition.x + value.translation.width,
                    y: nav.pillPosition.y + value.translation.height
                )
                let clamped = clampedPosition(final)
                // Set pill to its current visual position with NO animation.
                // This matches where the pill is at the moment @GestureState resets
                // dragTranslation to .zero, preventing any visible jump.
                var noAnim = Transaction()
                noAnim.disablesAnimations = true
                withTransaction(noAnim) {
                    nav.pillPosition = final
                }
                // Then spring-animate to the clamped edge position.
                if reduceMotion {
                    nav.pillPosition = clamped
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        nav.pillPosition = clamped
                    }
                }
                nav.savePillPosition()
            }
    }

    // MARK: - Safe Area Clamping

    private func clampedPosition(_ point: CGPoint) -> CGPoint {
        let safeAreaInsets = currentSafeAreaInsets()
        let halfPill = pillSize / 2
        let screenBounds = UIScreen.main.bounds

        let minX = safeAreaInsets.left + halfPill + edgeMargin
        let maxX = screenBounds.width - safeAreaInsets.right - halfPill - edgeMargin
        let minY = safeAreaInsets.top + halfPill + edgeMargin
        let maxY = screenBounds.height - safeAreaInsets.bottom - halfPill - edgeMargin

        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    private func currentSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.keyWindow
        else {
            return .zero
        }
        return window.safeAreaInsets
    }

    // MARK: - Animation Helper

    private func togglePill(expanded: Bool) {
        if reduceMotion {
            nav.isPillExpanded = expanded
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                nav.isPillExpanded = expanded
            }
        }
    }
}
