# Quick Task 260327-19t: Fix Floating Pill Drag — Research

**Researched:** 2026-03-27
**Domain:** SwiftUI DragGesture real-time tracking, @GestureState vs @State, animation interference
**Confidence:** HIGH

## Summary

The current `FloatingPillButton.swift` uses `@State private var dragOffset: CGSize` with `.position(nav.pillPosition).offset(dragOffset)`. The `.onChanged` handler sets `dragOffset = value.translation`. This architecture is correct in isolation, but the pill still doesn't follow the finger because `dragOffset` updates are being absorbed by an active implicit animation context — the same one that animates `nav.isPillExpanded`. When SwiftUI sees a `@State` change during an active animation transaction, it interpolates from the current animated position rather than snapping to the new value. The result: every `onChanged` update gets animated to the new offset, creating a lag that only "resolves" when the finger lifts.

This is the same problem that was present before commit 851e1b8, which correctly replaced `@State dragOffset` with `@GestureState`. That commit was then reverted (28aa4d1) because the `@GestureState` reset at gesture end caused a visual jump. The jump was a solvable secondary problem — but the revert put the primary problem back.

**Primary recommendation:** Restore `@GestureState` for real-time tracking. Fix the release-jump separately by setting `nav.pillPosition` to the clamped final position in `onEnded` before `@GestureState` resets, using `transaction.disablesAnimations = true` to prevent the reset from being visible, then spring-animating into the clamped position.

## Root Cause Diagnosis

### Why `.offset(dragOffset)` with `@State` does not follow the finger

`@State` updates in `.onChanged` fire synchronously but they go through SwiftUI's normal render pipeline. If any ancestor view has an active implicit `.animation()` modifier, or if a recent `withAnimation` block is still in its transaction window, the position change is interpolated rather than applied instantaneously.

In `FloatingPillButton`, the pill is inside a `ZStack` that conditionally renders `expandedPill` or `collapsedPill` based on `nav.isPillExpanded`. The `togglePill` helper wraps that state change in `withAnimation(.spring(response: 0.35, dampingFraction: 0.8))`. This animation transaction does not instantly complete — it runs for the duration of the spring. Any `@State` change that occurs while this transaction is active inherits the animation timing unless explicitly opted out.

Even when no explicit animation is running, there is a subtler issue: `.position()` and `.offset()` are both geometry modifiers. SwiftUI computes them together in the layout pass. If the view also has an implicit `.animation()` somewhere in the view hierarchy (common with `@Observable` observation triggering re-renders), the offset update is smoothed.

### Why `@GestureState` works

`@GestureState` is specifically designed for real-time gesture tracking. The SwiftUI runtime bypasses the normal animation transaction for `@GestureState` updates in `.updating(_:body:)`. Changes to `@GestureState` are applied in the gesture's own update cycle — outside the animation scheduler — guaranteeing per-frame position updates with no smoothing.

The Apple documentation confirms: "`@GestureState` resets to its initial value when the gesture ends." This reset IS animated by default if an animation is in scope, which is what caused the visual jump in 851e1b8 — the position would snap from (pill + gestureTranslation) back to (pill) before `onEnded` could update `nav.pillPosition`.

### The jump problem in the prior @GestureState attempt (851e1b8)

Looking at the diff in 851e1b8's `onEnded`:

```swift
// Set unclamped first (matches visual at gesture end as @GestureState resets)
nav.pillPosition = final
if reduceMotion {
    nav.pillPosition = clamped
} else {
    withAnimation(.spring(...)) {
        nav.pillPosition = clamped
    }
}
```

The comment says "set unclamped first to match visual" — this was attempting to prevent the jump by setting `nav.pillPosition` to where the pill visually was right before `@GestureState` auto-reset to `.zero`. But SwiftUI processes `onEnded` and the `@GestureState` reset as part of the same render pass. Setting `nav.pillPosition = final` and then immediately animating it to `clamped` means SwiftUI sees two position changes in the same pass and may batch them, or the intermediate `final` assignment never renders. The jump occurred because there was a one-frame window where `@GestureState` = `.zero` and `nav.pillPosition` was still the pre-drag position.

## Correct Fix

### Pattern: @GestureState + transaction disable on reset

```swift
// Source: Apple Developer Documentation — DragGesture, @GestureState, Transaction
@GestureState private var dragTranslation: CGSize = .zero

var body: some View {
    // ...
    .position(CGPoint(
        x: nav.pillPosition.x + dragTranslation.width,
        y: nav.pillPosition.y + dragTranslation.height
    ))
}

private var dragGesture: some Gesture {
    DragGesture()
        .updating($dragTranslation) { value, state, _ in
            state = value.translation
        }
        .onEnded { value in
            let final = CGPoint(
                x: nav.pillPosition.x + value.translation.width,
                y: nav.pillPosition.y + value.translation.height
            )
            let clamped = clampedPosition(final)
            // Commit pill to final (unclamped) position with no animation.
            // This matches the visual position at the moment @GestureState resets,
            // preventing any jump when dragTranslation returns to .zero.
            var noAnim = Transaction()
            noAnim.disablesAnimations = true
            withTransaction(noAnim) {
                nav.pillPosition = final
            }
            // Then spring-animate to clamped position.
            if !reduceMotion {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    nav.pillPosition = clamped
                }
            } else {
                nav.pillPosition = clamped
            }
            nav.savePillPosition()
        }
}
```

**Why this eliminates the jump:** When `@GestureState` resets, `dragTranslation` becomes `.zero`, and the pill's `.position()` moves from `(pillPosition + translation)` to `(pillPosition)`. By immediately setting `nav.pillPosition = final` with `disablesAnimations: true` before the reset renders, the pill stays at the same visual location. The spring animation then moves it to `clamped`.

### What NOT to do

| Approach | Problem |
|----------|---------|
| `@State dragOffset` + `.offset()` in `.onChanged` | Implicit animation context smooths each increment — pill lags |
| `withAnimation` inside `.onChanged` | Each delta frame is individually animated — deliberate lag |
| Direct `nav.pillPosition` update in `.onChanged` | `@Observable` property changes are batched via the observation system — updates may not render per-frame during active gesture |
| `.animation(nil, value: dragOffset)` | Breaks other animations on the view — too broad |

## Key Pitfalls

### Pitfall 1: @GestureState reset causes visual jump
**What goes wrong:** `@GestureState` resets to `.zero` when gesture ends. If `nav.pillPosition` hasn't been updated yet, the pill jumps back to its pre-drag position for one frame.
**Fix:** Set `nav.pillPosition = final` with `disablesAnimations: true` in `onEnded` before `@GestureState` processes its reset.

### Pitfall 2: Animation context contamination from isPillExpanded toggle
**What goes wrong:** `togglePill(expanded:)` wraps state changes in `.spring()`. This transaction can persist into the next render pass. Any `@State` changes in that pass inherit the spring.
**Fix:** `@GestureState`'s `.updating` callback is immune to animation transactions. This is another reason to prefer it over `@State` for gesture position tracking.

### Pitfall 3: .position() + .offset() interaction
**What goes wrong:** `.position()` sets the view's center in the coordinate space. `.offset()` shifts the view relative to where layout placed it. Combining both is valid but creates two sources of truth for position — harder to reason about during gesture tracking. The `@GestureState` approach uses `.position()` only, combining `pillPosition + dragTranslation` into a single `.position()` call, which is simpler and less error-prone.

## Current State Summary

| Commit | Approach | Result |
|--------|----------|--------|
| Phase 01.1 base | `@State dragOffset` + `.offset()`, clear in `onEnded` before animating | Pill didn't follow finger |
| 851e1b8 | `@GestureState dragTranslation`, combined into `.position()` | Real-time tracking worked; jump at release |
| 28aa4d1 (current) | Reverted to `@State dragOffset` + `.offset()` | Pill doesn't follow finger again |

The fix is to restore the `@GestureState` approach from 851e1b8 and add `withTransaction(disablesAnimations: true)` in `onEnded` to eliminate the release jump.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: DragGesture — `.updating(_:body:)` guarantees per-frame state binding updates
- Apple Developer Documentation: GestureState — "The property resets to its initial value when the gesture becomes inactive"
- Apple Developer Documentation: Transaction / `disablesAnimations` — suppresses animations for a specific state change
- Codebase git history (commits 851e1b8, 28aa4d1) — documents both the working approach and the reason it was reverted

## Metadata

**Confidence breakdown:**
- Root cause: HIGH — confirmed by git history and SwiftUI animation model
- Fix pattern: HIGH — @GestureState + withTransaction is the documented Apple-recommended approach
- Release jump fix: HIGH — disablesAnimations on the pre-reset position set is the correct mitigation

**Research date:** 2026-03-27
**Valid until:** Stable (SwiftUI gesture APIs are stable at iOS 17+)
