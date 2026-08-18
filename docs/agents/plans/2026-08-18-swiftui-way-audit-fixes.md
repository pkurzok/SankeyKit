---
date: 2026-08-18T09:11:23+00:00
git_commit: 9b8c414c17dfe0a9ce459c1677b486d037fd17e1
branch: main
topic: "SwiftUI-way audit fixes: accessible selection and demo cleanup"
tags: [plan, sankey-diagram, accessibility, sankey-demo]
status: ready
---

# PLAN: SwiftUI-way audit fixes

An audit of the SwiftUI layer against the swiftui-way-audit guidelines surfaced four genuine
violations. This plan fixes exactly those four; every other flagged pattern (graph resolution in
`body`, the environment configuration struct, the inline `nodesByID` dictionary, fixed point
values vs. Dynamic Type) was reviewed and deliberately accepted as out of scope.

1. Chart selection is tap-only — nodes and ribbons expose no accessibility action or button
   trait, so VoiceOver/Switch Control users can never select anything.
2. `PlaygroundView.valueSlider` builds a `Binding(get:set:)` in `body` — fresh closures every
   evaluation, when `Binding.animation(_:)` does the same job comparably.
3. `EnergyDemoView.Flow` carries `let id = UUID()` (regenerated on every view init, and the
   `Identifiable` conformance is never consumed) and the constant `flows`/`scale` arrays are
   stored per view instance, making them part of the compared view value.
4. `PlaygroundView` splits its body with a `@ViewBuilder` computed property and a
   `func … -> some View` instead of standalone `View` structs, so the helpers re-run on every
   slider tick with no skip boundary.

## Acceptance Criteria

- A VoiceOver/Switch Control user can select and deselect any node or ribbon on a chart that
  has `.sankeySelection(_:)` set; elements announce as buttons and carry `.isSelected` when
  chosen. Read-only charts (no selection binding) expose no action and no button trait.
- `PlaygroundView` contains no `Binding(get:set:)`; slider changes still animate the ribbon
  morph exactly as before.
- `EnergyDemoView`'s dataset is no longer part of the view value (`static let`) and `Flow`
  carries no unused `UUID` identity.
- `PlaygroundView`'s helper views are standalone `View` structs, not `@ViewBuilder`
  properties / funcs returning `some View`.
- `swift build`, `swift test`, and `swiftlint --strict` all pass.

## Technical Key Decisions and Tradeoffs

1. **Accessibility mechanism — explicit action + trait:** add
   `.accessibilityAction { toggle }` and the `.isButton` trait, applied only when a selection
   binding exists.
   - Why: VoiceOver's synthesized activation tap targets the element's *center point*, which
     lies outside a curved ribbon's `contentShape`, so the `.isButton` trait alone would
     produce a control that announces but does not work. The explicit action calls the same
     `SankeyDiagram.toggle(_:in:)` the tap gesture uses.
   - Impact: `sankeyNodeAccessibility` / `sankeyLinkAccessibility` gain an optional
     `selectAction: (() -> Void)?` parameter; `NodeLayer`/`RibbonLayer` pass the toggle
     closure. Side benefit: selection becomes reachable via assistive tech on tvOS, where
     `onTapGesture` never fires — the doc note on `sankeySelection(_:)` is updated.
2. **Animated slider binding — `Binding.animation(_:)`:** replace the hand-built
   `Binding(get:set:)` with `$value.animation(.smooth(duration: 0.2))` on the extracted
   struct's `@Binding`.
   - Why: it is the built-in equivalent and already the file's idiom
     (`$showsSideGig.animation(.snappy)`), and it removes the uncomparable closure pair.
   - Impact: `ValueSlider` stays a dumb view; animation behavior is unchanged.
3. **Energy dataset — `static let`, no `Identifiable`:** `flows` and `scale` become
   `static let`; `Flow` drops `Identifiable` and `id`.
   - Why: `SankeyForEachContent` only iterates the collection — the identity is never read —
     and per-instance storage makes the arrays part of the deep-compared view value with fresh
     UUIDs each time.
   - Impact: pure demo change; chart output is identical.
4. **View extraction — real structs:** `SelectionReadout` (takes
   `Binding<SankeySelection?>`) and `ValueSlider` (title, `Binding<Double>`, range) become
   private `View` structs in `PlaygroundView.swift`.
   - Why: a `@ViewBuilder` property / `some View` func is not a node in the view tree — its
     logic re-runs on every parent update. A struct boundary lets SwiftUI skip it when its
     inputs are unchanged.
   - Impact: `PlaygroundView.body` shrinks to composition; no behavior change.

## Current State

```
SankeyDiagram (Sources/SankeyKit/View/SankeyDiagram.swift)
 ├─ RibbonLayer → RibbonShape
 │    .onTapGesture { SankeyDiagram.toggle(value, in: selection) }   (line 127)
 │    .sankeyLinkAccessibility(…)          label/value/.isSelected — NO action, NO trait
 ├─ NodeLayer → NodeShape
 │    .onTapGesture { … }                                            (line 157)
 │    .sankeyNodeAccessibility(…)          label/value/.isSelected — NO action, NO trait
 └─ a11y modifiers live in SankeyChart+Accessibility.swift:44,60

PlaygroundView (Examples/SankeyDemo/Sources/PlaygroundView.swift)
 ├─ @ViewBuilder private var selectionReadout: some View             (line 50)
 └─ private func valueSlider(…) -> some View                         (line 71)
      └─ Binding(get:set:) wrapping withAnimation                    (line 76)

EnergyDemoView (Examples/SankeyDemo/Sources/EnergyDemoView.swift)
 ├─ struct Flow: Identifiable { let id = UUID() … }                  (line 9)
 └─ private let flows: [Flow], private let scale: [Color]            (lines 16, 38)
```

## Desired End State

```
SankeyDiagram
 ├─ RibbonLayer / NodeLayer unchanged visually; each element additionally gets
 │    .accessibilityAddTraits(.isButton)      — only when selection binding exists
 │    .accessibilityAction { toggle }         — same closure as the tap gesture
 └─ read-only charts: accessibility output identical to today

PlaygroundView
 ├─ SelectionReadout(selection: $selection)          private struct
 └─ ValueSlider(title:value:range:)                  private struct,
      Slider(value: $value.animation(.smooth(duration: 0.2)), in: range)

EnergyDemoView
 ├─ struct Flow { var source/target/energy }         no Identifiable, no id
 └─ static let flows / static let scale
```

## Abstractions and Code Reuse

No new public API. The selection toggle reuses the existing pure, already-tested
`SankeyDiagram.toggle(_:in:)` (covered by `Tests/SankeyKitTests/SelectionTests.swift:72-93`),
so the accessibility action and the tap gesture cannot drift apart.

- `Sources/SankeyKit/View/`
  - `SankeyChart+Accessibility.swift` — extend both modifiers
    - `sankeyNodeAccessibility(_:isSelected:sortPriority:selectAction:)` — new optional
      `selectAction: (() -> Void)? = nil`; when non-nil adds `.isButton` trait and
      `.accessibilityAction`
    - `sankeyLinkAccessibility(…selectAction:)` — same
  - `SankeyDiagram.swift` — pass the action from `NodeLayer`/`RibbonLayer`
  - `SankeyConfiguration.swift` — doc note update on `sankeySelection(_:)`
- `Examples/SankeyDemo/Sources/`
  - `PlaygroundView.swift` — extract `SelectionReadout` and `ValueSlider` structs, drop
    `Binding(get:set:)`
  - `EnergyDemoView.swift` — `static let` dataset, `Flow` loses `Identifiable`/`id`

## Logging & Observability

None — no changes to the `de.peterkurzok.SankeyKit` logging paths.

## Implementation

### Phase 1: Accessible selection in the library

Dependencies: None

Nodes and ribbons become operable accessibility elements whenever the chart has a selection
binding, using the same toggle path as the tap gesture.

**Tasks**:
- [x] `Sources/SankeyKit/View/SankeyChart+Accessibility.swift`: add an optional
  `selectAction: (() -> Void)? = nil` parameter to `sankeyNodeAccessibility` and
  `sankeyLinkAccessibility`. When non-nil, add `.accessibilityAddTraits(.isButton)` and
  `.accessibilityAction { selectAction() }`; when nil, output must be exactly today's.
  Extend the doc comments (parameter docs for `selectAction`, and note that read-only charts
  stay non-interactive).
  ```swift
  @ViewBuilder
  func sankeyNodeAccessibility(
      _ node: LaidOutNode,
      isSelected: Bool,
      sortPriority: Double,
      selectAction: (() -> Void)? = nil
  ) -> some View {
      let element = accessibilityElement()
          .accessibilityLabel(Text(node.node.label))
          .accessibilityValue(Text(SankeyAccessibility.nodeValue(node)))
          .accessibilitySortPriority(sortPriority)
      if let selectAction {
          element
              .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
              .accessibilityAction { selectAction() }
      } else {
          element
              .accessibilityAddTraits(isSelected ? [.isSelected] : [])
      }
  }
  ```
  The action must be the *default* activation (`accessibilityAction(_:_:)` with
  `AccessibilityActionKind.default` — available since iOS 13/macOS 10.15, well within our
  platform floor), **not** a named custom action buried in the VoiceOver rotor, so a plain
  double-tap triggers it. There is no conditional form of that modifier, hence the explicit
  `if let` branch (`@ViewBuilder`); when `selectAction` is nil the output is exactly today's.
- [x] `Sources/SankeyKit/View/SankeyDiagram.swift`: in `NodeLayer` (line ~158) and
  `RibbonLayer` (line ~128), pass
  `selectAction: selection == nil ? nil : { SankeyDiagram.toggle(value, in: selection) }`
  so gesture and accessibility action share one code path.
- [x] `Sources/SankeyKit/View/SankeyConfiguration.swift`: update the `> Note:` on
  `sankeySelection(_:)` (line ~104) — per-element taps still never arrive on tvOS, but
  selection is now reachable through assistive technologies there.
- [x] `Tests/SankeyKitTests/SelectionTests.swift`: add a test that exercises the exact closure
  shape the layers pass (toggle-through-action on a binding: select, re-select clears,
  cross-select replaces), guarding the shared toggle path the action relies on.

**Automated Verification**:
- [x] `swift test --filter SelectionTests` passes, including the new case
- [x] `swift build` succeeds
- [x] `swiftlint --strict` reports no violations

**Manual Verification**:
- [x] In the demo app (Playground screen) with VoiceOver on: focus a node → it announces as a
  button; double-tap → it becomes selected and announces `.isSelected`; double-tap again →
  selection clears. On the Energy screen (no selection binding): elements announce label and
  value but not as buttons.

### Phase 2: Demo app cleanup

Dependencies: None (independent of Phase 1)

`PlaygroundView` gets real child views and the built-in animated binding; `EnergyDemoView`
loses the per-instance dataset and the dead `UUID` identity.

**Tasks**:
- [x] `Examples/SankeyDemo/Sources/PlaygroundView.swift`: replace the
  `@ViewBuilder private var selectionReadout` (line 50) with a
  `private struct SelectionReadout: View { @Binding var selection: SankeySelection? }`
  holding the same HStack (readout text, conditional Clear button, `.animation(.snappy,
  value: selection)`).
- [x] `Examples/SankeyDemo/Sources/PlaygroundView.swift`: replace
  `private func valueSlider(…)` (line 71) with a
  `private struct ValueSlider: View { var title: String; @Binding var value: Double;
  var range: ClosedRange<Double> }` whose body uses
  `Slider(value: $value.animation(.smooth(duration: 0.2)), in: range)` — no
  `Binding(get:set:)`, no `withAnimation` in the setter. Update the three call sites and the
  struct's doc comment.
- [x] `Examples/SankeyDemo/Sources/EnergyDemoView.swift`: remove `Identifiable` and
  `let id = UUID()` from `Flow` (line 10); change `private let flows` and `private let scale`
  (lines 16, 38) to `private static let`, adjusting the two `flows`/`scale` uses in `body`
  and the footer text (`Self.flows` where needed).

**Automated Verification**:
- [x] `cd Examples/SankeyDemo && xcodegen generate` succeeds and
  `xcodebuild -project SankeyDemo.xcodeproj -scheme SankeyDemo -destination 'platform=macOS' build`
  compiles (the multi-destination target generates a single `SankeyDemo` scheme)
- [x] `swift build` and `swift test` still pass at the package root
- [x] `swiftlint --strict` reports no violations
- [x] `grep -c 'Binding(get:' Examples/SankeyDemo/Sources/PlaygroundView.swift` returns 0
  matches (exit code 1)

**Manual Verification**:
- [x] In the demo app: dragging the Playground sliders still morphs the ribbons smoothly
  (no jump), Shuffle still animates, and the Energy screen renders identically to before.

## Implementation Notes

During implementation, document user feedback, problems, and decisions here.

**2026-08-18 — toolchain detour.** The swiftly-managed `swift-6.2.3-RELEASE` toolchain on this
machine wedges: even a two-line `print("hi")` never finishes compiling, and `swift build` stalls
forever compiling the `swift-docc-plugin` manifest. Xcode's own toolchain (`/usr/bin/swift`)
builds the package in ~2 s, so every verification below was run with `/usr/bin/swift` instead of
the `swift` on `PATH`. Nothing about the code changed because of this.

**Dropped an over-specified test.** A second new case asserting that a read-only chart passes
`nil` as `selectAction` only restated the ternary in `SankeyDiagram`, not any behaviour the
library owns, so it was left out. The `nil` path is covered by the existing
`togglingWithoutBinding` case and by the compiler (`selectAction` defaults to `nil`).

**Caption text.** `PlaygroundView`'s caption claimed the sliders write "inside withAnimation",
which stopped being true with the animated binding; it now describes the binding.

**Reported animation regression — investigated, not a regression.** After Phase 1 the toggles on
the Finance and Playground screens appeared to stop animating. Two hypotheses were wrong: first
that the `@ViewBuilder` `if`/`else` wrapped every element in a `_ConditionalContent` and broke
interpolation, then that the `Toggle` tap path differed from a programmatic write. Both were
disproved by measurement: the demo was built for an iPhone 16 Pro simulator and the toggle
recorded at 20 fps, showing ~0.5 s of continuous frame-to-frame change with an ease-out ramp, and
filmstrips confirming the node labels walk to their new positions rather than snapping. A fresh
build on an iPhone 17 Pro Max then confirmed both VoiceOver selection and the animations behave
correctly on device. No library change was needed.

**Kept from that investigation:** the accessibility modifiers compute their traits through
`SankeyAccessibility.traits(isSelected:isSelectable:)` instead of branching, so each element stays
a single static view type and the announcement rule is unit-tested. This was originally made as a
fix; it is retained on its own merits, and the comments that credited it with fixing an animation
bug were corrected.

**Device signing.** `project.yml` sets no `DEVELOPMENT_TEAM` (ad-hoc signing), so a device build
needs `DEVELOPMENT_TEAM=<your team ID>` passed to `xcodebuild` — the team the installed app is signed
with. Passing a different team fails with `MismatchedApplicationIdentifierEntitlement`.

## References

- Audit guideline source: swiftui-way-audit skill (distilled from *The SwiftUI Way*,
  N. Panferova, 2026)
- Toggle-path tests: `Tests/SankeyKitTests/SelectionTests.swift:72-93`
- Accepted-as-is findings and their rationale: see plan intro; discussed and descoped on
  2026-08-18 (originally full-scope, narrowed to findings 1-4 by user decision)
