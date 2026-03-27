import SwiftUI
import UIKit

struct FloatingPillButton: View {
    @Bindable var nav: NavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pillSize: CGFloat = 56
    private let iconSize: CGFloat = 22
    private let expandedIconSize: CGFloat = 20
    private let tapTargetSize: CGFloat = 44
    private let edgeMargin: CGFloat = 8
    private let expandedPillWidth: CGFloat = 172

    var body: some View {
        ZStack {
            if nav.isPillExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { togglePill(expanded: false) }
                    .accessibilityHidden(true)
            }

            Group {
                if nav.isPillExpanded {
                    expandedPill
                        .offset(x: expandedPillOffset)
                } else {
                    collapsedPill
                }
            }
            .position(nav.pillPosition)
        }
    }

    // MARK: - Expanded pill offset

    private var expandedPillOffset: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let halfExpanded = expandedPillWidth / 2
        let leftEdge = nav.pillPosition.x - halfExpanded
        let rightEdge = nav.pillPosition.x + halfExpanded
        if leftEdge < edgeMargin { return edgeMargin - leftEdge }
        if rightEdge > screenWidth - edgeMargin { return (screenWidth - edgeMargin) - rightEdge }
        return 0
    }

    // MARK: - Collapsed pill

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
        // UIKit pan gesture overlay — bypasses SwiftUI animation pipeline entirely
        .overlay(
            PillDragView(
                getPosition: { nav.pillPosition },
                onDragChanged: { newPosition in
                    // Called from UIKit pan handler — no SwiftUI animation context active.
                    // disablesAnimations cancels any in-flight spring so it can't contaminate.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { nav.pillPosition = newPosition }
                },
                onDragEnded: { finalPosition in
                    let clamped = clampedPosition(finalPosition)
                    if reduceMotion {
                        nav.pillPosition = clamped
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            nav.pillPosition = clamped
                        }
                    }
                    nav.savePillPosition()
                },
                onTap: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    togglePill(expanded: true)
                }
            )
        )
        .accessibilityLabel("Navigation")
        .accessibilityHint("Double-tap to expand navigation options")
    }

    // MARK: - Expanded pill

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
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.zenSecondaryBackground.opacity(0.95))
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

    // MARK: - Safe area clamping

    private func clampedPosition(_ point: CGPoint) -> CGPoint {
        let insets = currentSafeAreaInsets()
        let half = pillSize / 2
        let bounds = UIScreen.main.bounds
        return CGPoint(
            x: min(max(point.x, insets.left + half + edgeMargin), bounds.width - insets.right - half - edgeMargin),
            y: min(max(point.y, insets.top + half + edgeMargin), bounds.height - insets.bottom - half - edgeMargin)
        )
    }

    private func currentSafeAreaInsets() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets ?? .zero
    }

    // MARK: - Expand/collapse animation

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

// MARK: - UIKit pan gesture overlay

/// Transparent UIView that tracks touch via UIPanGestureRecognizer.
/// Runs completely outside SwiftUI's gesture and animation pipeline —
/// each `.changed` callback fires synchronously on the main thread with
/// no SwiftUI transaction context, so position updates are frame-perfect.
private struct PillDragView: UIViewRepresentable {
    let getPosition: () -> CGPoint
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onTap: () -> Void

    nonisolated static let tapThreshold: CGFloat = 5

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update coordinator callbacks on every SwiftUI render so closures
        // always capture the latest nav / reduceMotion values.
        context.coordinator.getPosition = getPosition
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(getPosition: getPosition, onDragChanged: onDragChanged, onDragEnded: onDragEnded, onTap: onTap)
    }

    @MainActor
    final class Coordinator: NSObject {
        var getPosition: () -> CGPoint
        var onDragChanged: (CGPoint) -> Void
        var onDragEnded: (CGPoint) -> Void
        var onTap: () -> Void
        private var startPosition: CGPoint = .zero
        private var isDragging = false

        init(getPosition: @escaping () -> CGPoint,
             onDragChanged: @escaping (CGPoint) -> Void,
             onDragEnded: @escaping (CGPoint) -> Void,
             onTap: @escaping () -> Void) {
            self.getPosition = getPosition
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
            self.onTap = onTap
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            // UIKit gesture callbacks are always on the main thread.
            // MainActor.assumeIsolated lets us call @MainActor closures synchronously.
            MainActor.assumeIsolated {
                handlePanOnMain(gesture)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            MainActor.assumeIsolated {
                onTap()
            }
        }

        private func handlePanOnMain(_ gesture: UIPanGestureRecognizer) {
            let t = gesture.translation(in: nil)

            switch gesture.state {
            case .began:
                startPosition = getPosition()
                isDragging = true

            case .changed:
                guard isDragging else { return }
                onDragChanged(CGPoint(x: startPosition.x + t.x, y: startPosition.y + t.y))

            case .ended:
                guard isDragging else { return }
                isDragging = false
                let dist = hypot(t.x, t.y)
                if dist < PillDragView.tapThreshold {
                    onTap()
                } else {
                    onDragEnded(CGPoint(x: startPosition.x + t.x, y: startPosition.y + t.y))
                }

            case .cancelled:
                if isDragging {
                    onDragChanged(startPosition)
                }
                isDragging = false

            case .failed:
                isDragging = false

            default:
                break
            }
        }
    }
}
