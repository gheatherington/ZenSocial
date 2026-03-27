import SwiftUI

struct FloatingPillButton: View {
    @Bindable var nav: NavigationState
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint = .zero
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
                        .offset(x: expandsLeft
                            ? -(expandedPillWidth / 2 - pillSize / 2)
                            : (expandedPillWidth / 2 - pillSize / 2))
                } else {
                    collapsedPill
                }
            }
            .position(nav.pillPosition)
        }
    }

    /// Whether the expanded pill should expand leftward (pill is on right side of screen)
    private var expandsLeft: Bool {
        nav.pillPosition.x > UIScreen.main.bounds.width / 2
    }

    // MARK: - Collapsed State

    private var collapsedPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            togglePill(expanded: true)
        } label: {
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
        }
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
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
            .onChanged { value in
                if !isDragging {
                    dragStartPosition = nav.pillPosition
                    isDragging = true
                }
                nav.pillPosition = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
            }
            .onEnded { _ in
                isDragging = false
                let clamped = clampedPosition(nav.pillPosition)

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
