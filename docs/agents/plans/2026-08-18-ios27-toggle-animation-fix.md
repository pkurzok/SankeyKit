---
date: 2026-08-18T11:26:28.685316+00:00
git_commit: ""
branch: main
topic: "Restore toggle-driven chart animations on iOS 27"
tags: [plan, sankey-demo, docs, animation, ios27]
status: ready
---

# PLAN: Restore toggle-driven chart animations on iOS 27

On iOS 27 (beta, simulator runtime `24A5408d`), tapping the toggles in the demo app's Finance
and Playground tabs re-lays out the chart in a single frame instead of morphing. Sliders, the
shuffle button, and selection dimming still animate.

**Root cause (verified experimentally, not a SankeyKit regression):** iOS 27 drops the
transaction that `Binding.animation(_:)` attaches to a `Toggle`-initiated write. The switch
thumb still animates, but every downstream view update — here the structural add/remove of a
`SankeyLink` mark — runs without animation. Evidence:

- The toggle-accessibility commit (the suspected cause) and its parent show the **identical**
  single-frame jump on iOS 27; the same build morphs smoothly on iOS 26.5. So the latest change
  did not introduce the bug — the OS did.
- Writing through the very same `$flag.animation(.snappy)` binding programmatically (from a
  `.task`) animates correctly on iOS 27; only the Toggle's own write path loses the transaction.
- Replacing the binding with one whose setter wraps the write in `withAnimation(.snappy)`
  restores the smooth morph on iOS 27 (verified frame-by-frame from a screen recording driven
  by real XCUITest taps).
- Neither the iOS 27 nor the Xcode 27 release notes mention this; no forum reports found.
  It is an unreported OS beta regression.

## Acceptance Criteria

- Tapping "Put money aside" (Finance tab) and "Side gig" (Playground tab) animates the chart
  re-layout on the iOS 27 simulator — ribbons morph, no single-frame jump.
- The same toggles still animate on iOS 26 and macOS (no behavior change on unaffected
  platforms).
- Slider, shuffle-button, and selection animations remain unchanged.
- The workaround is explained at both call sites and in the DocC "Animate value changes"
  section, so a future cleanup does not reintroduce `Binding.animation` on a Toggle.
- A self-contained minimal repro (no SankeyKit dependency) plus drafted Feedback text exists
  under `docs/feedback/` for submission via Feedback Assistant.
- `swift build`, `swift test`, and `swiftlint --strict` stay green.

## Technical Key Decisions and Tradeoffs

1. **Demo-only fix; the library stays untouched:** change the two demo toggles, nothing in
   `Sources/SankeyKit`.
   - Why: the library is provably not at fault (parent commit jumps identically), and a
     library-side implicit `.animation(_, value: graph)` would make every data change animate
     even when the caller did not ask, diverging from Swift Charts conventions.
   - Impact: two small view edits in `Examples/SankeyDemo/Sources/`.
2. **`withAnimation` in a custom `Binding` setter instead of `Binding.animation(_:)`:**
   - Why: verified to restore the morph on iOS 27; the setter runs synchronously inside the
     write, so the transaction cannot be dropped by the Toggle's write path. Behaves
     identically on iOS 26/macOS (it is the pattern the sliders used before PR #3).
   - Impact: the toggles and the sliders intentionally use *different* animation patterns;
     the comments must say why so the asymmetry survives review.
3. **Sliders keep `Binding.animation(_:)`:** the OS bug is specific to Toggle's write path;
   `Slider` writes animate correctly on iOS 27.
   - Why: no reason to churn working code; `ValueSlider`'s doc comment explains why the
     binding-animation pattern is right for sliders (drag *and* keyboard writes).
   - Impact: none.
4. **Comments + DocC note, no API change:** a why-comment at each toggle plus a paragraph in
   `GettingStarted.md`.
   - Why: the demo is the reference example people copy; the DocC article is where a library
     user animating with toggles will look.
   - Impact: doc-only additions.
5. **Manual verification for the animation itself:** the smoothness of a render-loop animation
   is not assertable from the pure layers (`SankeyGraph`/`SankeyLayout`), and the diagnostic
   XCUITest + ffmpeg frame-diff harness used during root-causing is too heavyweight and
   beta-OS-pinned for CI.
   - Impact: the plan's automated checks cover build/tests/lint; a human taps the toggles once
     per affected runtime.
6. **Prepare an Apple Feedback package:** minimal repro + drafted text under `docs/feedback/`.
   - Why: unreported OS beta regression; the analogous iOS 26 beta 3 Form-animation regression
     was fixed one beta later after reports.
   - Impact: one new docs directory; the user files the FB manually.

## Current State

Both broken toggles drive an `if` inside the `SankeyContentBuilder`, so a tap adds/removes a
`SankeyLink` mark and the whole chart re-lays out:

```
Toggle tap (iOS 27)
   │
   ├─ UISwitch thumb animation                       ✓ animates
   └─ write through $flag.animation(.snappy)  ──X──  transaction dropped by iOS 27
        └─ builder `if` adds/removes a link
             └─ SankeyChart re-layout                ✗ jumps in one frame

Slider drag ($value.animation) / Button (withAnimation) / programmatic write
        └─ SankeyChart re-layout                     ✓ animates
```

- `Examples/SankeyDemo/Sources/FinanceDemoView.swift:35` —
  `Toggle("Put money aside", isOn: $showsSavings.animation(.snappy))`
- `Examples/SankeyDemo/Sources/PlaygroundView.swift:35` —
  `Toggle("Side gig", isOn: $showsSideGig.animation(.snappy))`
- `Sources/SankeyKit/Documentation.docc/GettingStarted.md:151` — "Animate value changes"
  section currently shows only the `withAnimation` + Button pattern.

## Desired End State

Both toggles write through a `Binding` whose setter animates explicitly; comments and the DocC
article explain the asymmetry; a Feedback package exists under `docs/feedback/`.

```
Toggle tap (iOS 27)
   │
   ├─ UISwitch thumb animation                       ✓ animates
   └─ Binding setter: withAnimation(.snappy) { … }   ✓ transaction applied synchronously
        └─ SankeyChart re-layout                     ✓ morphs
```

## Abstractions and Code Reuse

No new abstractions; the fix reuses the plain `Binding(get:set:)` + `withAnimation` pattern
that `valueSlider` used before PR #3.

- `Examples/SankeyDemo/Sources/`
  - `FinanceDemoView.swift` — replace the toggle's binding; add why-comment
  - `PlaygroundView.swift` — same replacement; add why-comment
- `Sources/SankeyKit/Documentation.docc/`
  - `GettingStarted.md` — extend "Animate value changes" with the toggle caveat
- `docs/feedback/2026-08-18-ios27-toggle-binding-animation/`
  - `ToggleBindingAnimationRepro.swift` — new, self-contained SwiftUI repro
  - `feedback.md` — new, drafted Feedback Assistant text

## Logging & Observability

None — no library code changes, nothing to log.

## Implementation

### Phase 1: Fix the demo toggles and document the pitfall

Dependencies: None

Replace the two `Binding.animation` toggle bindings with `withAnimation`-setter bindings,
explain the workaround at each call site, and extend the DocC animation section.

**Tasks**:
- [x] `Examples/SankeyDemo/Sources/FinanceDemoView.swift` — replace the toggle binding:
  ```swift
  // Not `$showsSavings.animation(.snappy)`: iOS 27 drops the transaction that
  // Binding.animation attaches to a Toggle's write, so the chart would jump.
  // Animating in the setter keeps the morph on every OS version.
  Toggle("Put money aside", isOn: Binding(
      get: { showsSavings },
      set: { newValue in withAnimation(.snappy) { showsSavings = newValue } }
  ))
  .toggleStyle(.switch)
  ```
- [x] `Examples/SankeyDemo/Sources/PlaygroundView.swift` — same replacement for the
  "Side gig" toggle (`$showsSideGig`), same comment (may reference the Finance one in
  shortened form).
- [x] `Sources/SankeyKit/Documentation.docc/GettingStarted.md` — extend the
  "Animate value changes" section (after the `withAnimation` example) with a short paragraph:
  animating a chart from a `Toggle` should wrap the write in `withAnimation` inside a custom
  `Binding` setter, because iOS 27 drops the transaction `Binding.animation(_:)` attaches to a
  Toggle's write (sliders and buttons are unaffected). Include the small code snippet.
- [x] Verify the caption texts in both demo views still match the code (they describe the
  toggle behavior, not the binding mechanics — expected to need no change; confirm).

**Automated Verification**:
- [x] `swift build` succeeds
- [x] `swift test` passes
- [x] `swiftlint --strict` reports no violations
- [x] `cd Examples/SankeyDemo && xcodegen generate && xcodebuild -project SankeyDemo.xcodeproj
  -scheme SankeyDemo -destination 'platform=iOS Simulator,name=iPhone-27-Test' build` succeeds
- [x] `swift package generate-documentation --target SankeyKit` succeeds (DocC edit is valid)

**Manual Verification**:
- [x] iOS 27 simulator (`iPhone-27-Test`, runtime 27.0): tap "Put money aside" on the Finance
  tab and "Side gig" on the Playground tab — the ribbons morph over ~0.3 s in both directions,
  no single-frame jump
- [ ] iOS 26 simulator (`iPhone-26-Test`, runtime 26.5 — already created; recreate with
  `xcrun simctl create "iPhone-26-Test" com.apple.CoreSimulator.SimDeviceType.iPhone-17
  com.apple.CoreSimulator.SimRuntime.iOS-26-5` if deleted): same taps still morph
- [ ] macOS demo app: both toggles still animate
- [x] Playground tab on iOS 27: sliders and the Shuffle button still animate (unchanged)

### Phase 2: Apple Feedback package

Dependencies: None (independent of Phase 1)

Produce a minimal repro and drafted Feedback text so the OS bug can be reported upstream.

**Tasks**:
- [x] `docs/feedback/2026-08-18-ios27-toggle-binding-animation/ToggleBindingAnimationRepro.swift`
  — a single self-contained SwiftUI file (no SankeyKit): one `@State` flag, a `Toggle` bound
  via `$flag.animation(.snappy)`, and a `VStack`/`ForEach` whose membership and frames change
  with the flag (e.g. bars that appear/resize). Side-by-side controls demonstrating the
  contrast: a `Button` using `withAnimation` (works) and a second `Toggle` using the
  `withAnimation`-setter binding (works). Comments state expected vs. actual per OS.
- [x] `docs/feedback/2026-08-18-ios27-toggle-binding-animation/feedback.md` — drafted Feedback
  Assistant text: title, area (SwiftUI), summary of the regression (Toggle-initiated
  `Binding.animation(_:)` writes lose their transaction on iOS 27; switch thumb still
  animates; programmatic writes through the same binding animate), steps to reproduce with the
  repro file, expected vs. actual, environment (iOS 27.0 simulator `24A5408d`, Xcode 27.0
  `27A5237l`, works on iOS 26.5 and macOS), and a note that `Slider`/`Button` paths are
  unaffected.
- [x] `.swiftlint.yml` — add `docs` to the `excluded:` list. The config has no `included:` key,
  so today SwiftLint lints the whole tree and would lint the new repro file under
  `docs/feedback/`.
- [x] Confirm the repro compiles by dropping it into a scratch single-view app or compiling
  with `swiftc -parse` against the iOS SDK (it is documentation, not a build target — it must
  not join any repo build).

**Automated Verification**:
- [x] `swiftlint --strict` still passes with the new file present
- [x] `swift build` and `swift test` still pass (repro file is not part of any target)

**Manual Verification**:
- [ ] Run the repro in the iOS 27 simulator once and confirm it shows the jump (so the FB
  ships with a verified repro)

## Implementation Notes

During implementation, document user feedback, problems, and decisions here.

- The diagnostic harness from root-causing (XCUITest tap driver + ffmpeg frame-diff analysis)
  is intentionally **not** part of this plan's deliverables. A copy is parked in the session
  scratchpad (`UITests-harness/`, `project-with-uitests.yml`, `uitest-measure.sh`,
  `analyze.py`) and can be resurrected for re-verification if needed.
- Implementation environment hiccup (not code-related): `swift build` hung for ~1 h with no
  output. `sample` showed `swift-frontend` wedged in `LockFileManager::tryLock()` inside an
  implicit `.swiftinterface` rebuild — stale module-cache locks left by earlier killed compiles,
  compounded by ~30 orphaned `swift-frontend` processes (PPID 1) and a load average above 20. A
  machine restart cleared it; afterwards `swift build` completes in ~40 s. Nothing in the
  repository needed changing.
- RocketSim note: after a RocketSim restart, the iOS 27 simulator's accessibility became
  unavailable (`sandbox_restriction`, Xcode 27 remote-automation socket). If element-based
  interaction fails during manual verification, tap by hand or via XCUITest.

## References

- Root-cause evidence: frame-by-frame recordings analyzed in this planning session — iOS 27
  jump on the toggle-accessibility commit and its parent; smooth on iOS 26.5; smooth on iOS 27 with the
  `withAnimation`-setter binding.
- `Examples/SankeyDemo/Sources/FinanceDemoView.swift`, `PlaygroundView.swift` — affected views
- `Sources/SankeyKit/Documentation.docc/GettingStarted.md` — "Animate value changes" section
- iOS 27 release notes (no mention of the regression):
  https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- Analogous fixed regression (iOS 26 beta 3 Form row animations):
  https://developer.apple.com/forums/thread/793278
- PR #3 (the toggle-accessibility commit) — the change that was suspected but is not the cause; it moved the demo
  *sliders* onto `Binding.animation`, which iOS 27 does not break
