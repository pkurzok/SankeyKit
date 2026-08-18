# Feedback Assistant draft — iOS 27: Toggle drops the transaction from `Binding.animation(_:)`

Submit at <https://feedbackassistant.apple.com>. Attach
`ToggleBindingAnimationRepro.swift` (this directory) — or a scratch app containing it — plus a
screen recording of the iOS 27 run.

- **Area:** SwiftUI
- **Type:** Incorrect/Unexpected Behavior
- **Reproducibility:** Always

## Title

SwiftUI: on iOS 27, a `Toggle` writing through `Binding.animation(_:)` loses its transaction — dependent view updates are not animated

## Summary

On iOS 27.0 (simulator build 24A5408d), a state write initiated by a `Toggle` bound with
`Binding.animation(_:)` no longer carries the animation transaction into the resulting view
update. The switch thumb itself still animates, but every view that depends on the written value
updates in a single frame.

The regression is specific to `Toggle`'s write path, not to the binding:

- Writing the *same* `$flag.animation(.snappy)` binding programmatically (e.g. from a `.task`)
  animates correctly on iOS 27.
- `Slider` writes through `Binding.animation(_:)` animate correctly on iOS 27.
- A `Button` calling `withAnimation(.snappy)` animates correctly on iOS 27.
- Replacing the toggle's binding with a custom `Binding(get:set:)` whose setter wraps the write in
  `withAnimation(.snappy)` restores the animation on iOS 27.

The same code animates correctly on iOS 26.5 and on macOS, so this is a regression in iOS 27.

## Steps to Reproduce

1. Create a new iOS App (SwiftUI) project in Xcode 27.0 (27A5237l).
2. Add the attached `ToggleBindingAnimationRepro.swift` and make `ReproView` the root view.
3. Run on the iOS 27.0 simulator (iPhone 17, runtime 24A5408d).
4. Tap the first toggle, labelled "Binding.animation (broken on iOS 27)".
5. Tap the button and the second toggle, which flip the same state through
   `withAnimation` instead.

## Expected Results

In step 4, the bars resize and the extra bar inserts over roughly 0.3 s, the same as in step 5 and
the same as on iOS 26.5.

## Actual Results

In step 4 the switch thumb animates but the bars change in a single frame — no interpolation. In
step 5 both controls animate as expected on the same run, so the difference is the write path, not
the view hierarchy.

## Environment

- iOS 27.0 simulator, runtime build 24A5408d (iPhone 17)
- Xcode 27.0 (27A5237l), macOS 26
- Not reproducible on iOS 26.5 (same binary) or on macOS
- Not mentioned in the iOS 27 or Xcode 27 release notes; no forum reports found as of 2026-08-18

## Notes

Real-world impact: any chart or structural layout driven by a `Toggle` stops animating on iOS 27
without a code change. Observed while animating a Sankey diagram whose marks are added and removed
by a builder `if`; verified frame-by-frame from a screen recording driven by XCUITest taps, on both
the current and the preceding commit of the affected project, ruling out an app-side change.

A behaviourally analogous regression (`Form` row animations) appeared in the iOS 26 beta 3 seed and
was fixed one beta later: <https://developer.apple.com/forums/thread/793278>
