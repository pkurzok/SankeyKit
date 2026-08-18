---
date: 2026-08-17T20:57:14.662388+00:00
git_commit: ""
branch: main
topic: "Curved ribbons — adopt D3's bumpX control points"
tags: [plan, RibbonGeometry, RibbonShape, SankeyLayout, documentation]
status: ready
---

# PLAN: Curved ribbons — adopt D3's bumpX control points

Ribbons currently render as near-straight trapezoids instead of the S-curves a Sankey diagram is
supposed to have. The cause is the control-point formula in ``RibbonGeometry``: it slides both
control points along *both* axes, so at the default curvature of `0.5` they land on the same point —
the midpoint of the straight line between the endpoints. A cubic Bézier whose control points sit on
its chord *is* that chord.

This plan replaces the formula with the one `d3-sankey` uses, so a ribbon leaves its source node and
enters its target node with a horizontal tangent and bends in between.

## Acceptance Criteria

- A ribbon leaves its source node and enters its target node with a horizontal tangent:
  `topCurve.control1.y == topCurve.start.y` and `topCurve.control2.y == topCurve.end.y`, for sloped
  and tapered ribbons alike.
- At the default curvature of `0.5` the control points sit at `x = (start.x + end.x) / 2`, matching
  `d3-shape`'s `bumpX` exactly.
- A curvature of `0` still produces a straight diagonal — the control points collapse onto the
  endpoints.
- The 24 pt minimum control offset, the taper between the two ends, the animatable component vector
  and the clamping of curvature to `0...1` are all unchanged.
- `swift build`, `swift test` and `swiftlint --strict` pass.
- README and DocC no longer describe curvature as "how hard ribbons bend", and the seven screenshots
  in `Documentation.docc/Resources/` show the new curves.

## Technical Key Decisions and Tradeoffs

1. **Control-point formula:** drop the two `rise · v` terms, so
   `c1 = (start.x + offset · v, start.y)` and `c2 = (end.x − offset · v, end.y)`.
   - Why: horizontal tangents at both nodes are what `d3-sankey` draws. Verified from source rather
     than memory — `d3-sankey/src/sankeyLinkHorizontal.js` feeds `(source.x1, y0) → (target.x0, y1)`
     into `d3-shape`'s `linkHorizontal`, whose `bumpX` curve
     (`d3-shape/src/curve/bump.js`) emits `bezierCurveTo((x0+x1)/2, y0, (x0+x1)/2, y1, x1, y1)`.
   - Impact: two lines in `RibbonGeometry.controlPoints`. Nothing else in the source tree reads the
     control points, so `RibbonShape`, hit testing, animation and the layout inherit the new shape.

2. **Default and range:** curvature keeps its default of `0.5` and its `0...1` clamp.
   - Why: `0.5` with the new formula is byte-for-byte `d3-sankey`, and no existing call site changes
     meaning.
   - Impact: the prose must stop calling `1` "bends as hard as possible". At `1` the control points
     cross horizontally (`c1.x = end.x`, `c2.x = start.x`) and the bend concentrates into a
     near-vertical step in the middle.

3. **Minimum control offset:** keep the 24 pt floor (`RibbonGeometry.minimumControlOffset`).
   - Why: it matters more under the new formula, not less. When `span` collapses on a narrow canvas
     the columns can overlap by one node width (`SankeyLayout.nodeFrames`, `SankeyLayout.swift:154`),
     and the floor is the only thing that still gives such a link room to leave the node
     horizontally instead of drawing a diagonal stub.
   - Impact: none — the behaviour and its test stand as they are.

4. **Taper:** keep it rather than switching to `d3-sankey`'s constant link width.
   - Why: link spacing is taken *out of* the busier node edge (`SankeyLayout.stack`), so the two
     ends of a ribbon genuinely differ in thickness. A constant width would visibly miss the gaps at
     that node.
   - Impact: none — `curve(direction:)` already offsets each end by its own half-thickness, and with
     horizontal tangents the two edges stay parallel wherever the thickness is equal, which is
     exactly a stroked `d3` path.

5. **Screenshots:** the seven JPGs are re-captured by hand rather than by a new capture harness.
   - Why: they were captured by hand in commit `7d5fa06` with a framing, background and dark-mode
     setup that only their author knows; an `ImageRenderer`-based harness would restyle all seven.
   - Impact: the only manual verification item in this plan.

## Current State

`RibbonGeometry.controlPoints` (`Sources/SankeyKit/Layout/RibbonGeometry.swift:34`):

```swift
let offset = controlOffset          // max(24, end.x - start.x)
let factor = CGFloat(curvature)     // 0.5 by default
let rise = end.y - start.y
return (
    CGPoint(x: start.x + offset * factor, y: start.y + rise * factor),
    CGPoint(x: end.x - offset * factor,   y: end.y - rise * factor)
)
```

Both control points travel along the chord. At `factor = 0.5` they coincide at its midpoint, which
the current test asserts outright (`Tests/SankeyKitTests/RibbonGeometryTests.swift:23`):

```swift
// dx = 100, v = 0.5, rise = 60
#expect(first  == CGPoint(x: 60, y: 50))
#expect(second == CGPoint(x: 60, y: 50))   // identical → the cubic degenerates to a line
```

```
        today (v = 0.5)                       d3 bumpX (v = 0.5)

  start ●                                start ●━━━━━━━● c1
         ╲                                              ╲
          ╳  c1 = c2, on the chord                       ╲
           ╲                                              ╲
            ● end                            c2 ●━━━━━━━━━━● end
```

Data flow, all of it downstream of that one computed property:

```
SankeyLayout.ribbonGeometry (SankeyLayout.swift:211)
        │  builds RibbonGeometry(start:end:startThickness:endThickness:curvature:)
        ▼
RibbonGeometry.controlPoints (RibbonGeometry.swift:34)      ← the only change
        │
        ├─► topCurve / bottomCurve  (curve(direction:), :50) — offsets each end by ±t/2
        │           │
        │           ▼
        │   RibbonShape.path(in:) (RibbonShape.swift:20) — fill path *and* hit-test path
        │
        └─► animatableComponents (:77) does NOT carry the control points; they are
            recomputed from the interpolated endpoints on every frame, so animation
            inherits the new shape for free
```

## Desired End State

```swift
let offset = controlOffset
let factor = CGFloat(curvature)
return (
    CGPoint(x: start.x + offset * factor, y: start.y),
    CGPoint(x: end.x - offset * factor,   y: end.y)
)
```

Behaviour across the range, with `offset = end.x − start.x`:

| curvature | `c1` | `c2` | shape |
|---|---|---|---|
| `0` | `start` | `end` | straight diagonal (unchanged) |
| `0.5` | `(mid.x, start.y)` | `(mid.x, end.y)` | the classic S — identical to `d3-sankey` |
| `1` | `(end.x, start.y)` | `(start.x, end.y)` | control points cross; a near-vertical step in the middle |

A useful property that falls out of the symmetric offsets and is worth pinning down in a test: the
curve passes exactly through the midpoint of the connection, since
`B(0.5).y = (y₀ + 3y₀ + 3y₁ + y₁) / 8 = (y₀ + y₁) / 2`.

## Abstractions and Code Reuse

No new abstractions. `RibbonGeometry.Curve`, `AnimatableVector`, `RibbonShape` and the whole layout
stay as they are; only the body of one computed property changes.

- `Sources/SankeyKit/Layout`
  - `RibbonGeometry.swift` — the formula and the prose describing it
    - `controlPoints` — drop the two `rise * factor` terms
    - type doc comment / `curvature` doc comment — describe horizontal tangents and D3 parity
- `Sources/SankeyKit/View`
  - `SankeyConfiguration.swift` — `sankeyLinkCurvature(_:)` doc comment: what `0`, `0.5` and `1` do
- `Tests/SankeyKitTests`
  - `RibbonGeometryTests.swift` — rewrite `controlPointFormula`, add four tangent/parity tests
- `Sources/SankeyKit/Documentation.docc`
  - `GettingStarted.md` — one sentence on what the curvature number means
  - `Resources/*.jpg` — seven re-captured screenshots
- `README.md` — the `.sankeyLinkCurvature(_:)` row of the styling table

Deliberately left alone: `docs/agents/plans/2026-08-17-sankeykit-package.md:179` records the old
formula. It is the historical record of a completed plan, not live documentation.

## Logging & Observability

No changes. The only logging in this area is `SankeyDiagnosticView`'s cycle report, which this plan
does not touch.

## Implementation

Dependencies: None.

Replace the control-point formula, pin the new behaviour down with tests, and bring every place that
describes the curvature knob in line with what it now does.

**Tasks**:

- [x] `Sources/SankeyKit/Layout/RibbonGeometry.swift` — rewrite `controlPoints` so both control
      points keep their endpoint's `y`. Remove the now-unused `rise` local.
      ```swift
      var controlPoints: (first: CGPoint, second: CGPoint) {
          let offset = controlOffset
          let factor = CGFloat(curvature)
          return (
              CGPoint(x: start.x + offset * factor, y: start.y),
              CGPoint(x: end.x - offset * factor, y: end.y)
          )
      }
      ```
- [x] `Sources/SankeyKit/Layout/RibbonGeometry.swift` — update the doc comments: the type comment
      gains a sentence that a ribbon leaves and enters its nodes horizontally, and the `curvature`
      property comment says "how far the control points travel *horizontally* along the connection".
      Note on `controlPoints` that at `0.5` this is `d3-shape`'s `bumpX`.
- [x] `Tests/SankeyKitTests/RibbonGeometryTests.swift` — rewrite `controlPointFormula`. Keep the
      fixture, replace the expectation, and rename the `@Test` display name — it currently reads
      "Control points follow the article formula", which no longer describes what is being checked:
      ```swift
      @Test("Control points keep their endpoint's y, as in d3-shape's bumpX")
      // start (10, 20) → end (110, 80), dx = 100, v = 0.5
      #expect(first  == CGPoint(x: 60, y: 20))   // keeps the source's y
      #expect(second == CGPoint(x: 60, y: 80))   // keeps the target's y
      ```
- [x] `Tests/SankeyKitTests/RibbonGeometryTests.swift` — add "Both ends leave their node
      horizontally", covering a sloped *and* tapered ribbon, which is where the old formula pulled
      the control points off the node edge:
      ```swift
      let geometry = ribbon(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 60),
                            thickness: 20, endThickness: 10)
      #expect(geometry.topCurve.control1.y == geometry.topCurve.start.y)      // -10
      #expect(geometry.topCurve.control2.y == geometry.topCurve.end.y)        //  55
      #expect(geometry.bottomCurve.control1.y == geometry.bottomCurve.start.y) //  10
      #expect(geometry.bottomCurve.control2.y == geometry.bottomCurve.end.y)   //  65
      ```
- [x] `Tests/SankeyKitTests/RibbonGeometryTests.swift` — add "The default curvature matches
      d3-shape's bumpX": for `start (0, 0) → end (200, 100)` at `v = 0.5`, both control points sit at
      `x == 100`, the horizontal midpoint, with `c1.y == 0` and `c2.y == 100`.
- [x] `Tests/SankeyKitTests/RibbonGeometryTests.swift` — add the regression guard "A sloped ribbon's
      control points never coincide", the exact symptom of the old formula:
      ```swift
      let geometry = ribbon(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80))
      #expect(geometry.controlPoints.first != geometry.controlPoints.second)
      ```
- [x] `Tests/SankeyKitTests/RibbonGeometryTests.swift` — add "The curve is symmetric about the
      middle of the connection" with a small local cubic evaluator, asserting `B(0.5)` equals the
      midpoint of `start` and `end` for a sloped ribbon.
- [x] `Sources/SankeyKit/View/SankeyConfiguration.swift` — rewrite the `sankeyLinkCurvature(_:)` doc
      comment. It must state that the ribbon always leaves and enters its nodes horizontally, that
      the parameter decides how far along the connection the bend sits, and what `0`, `0.5` and `1`
      each produce. Drop "1 bends as hard as possible".
- [x] `README.md:148` — replace the styling-table cell "How hard ribbons bend, `0`–`1`. Clamped."
      with wording that matches: `0` a straight diagonal, `0.5` the classic S, `1` a step in the
      middle.
- [x] `Sources/SankeyKit/Documentation.docc/GettingStarted.md` — add one sentence under
      "Style the chart" explaining the curvature number, since it is the least self-evident modifier
      in that code block.
- [x] Re-capture the seven screenshots in `Sources/SankeyKit/Documentation.docc/Resources/`, keeping
      the existing framing and file names: `sankey-hero@2x.jpg`, `sankey-hero~dark@2x.jpg`,
      `sankey-energy@2x.jpg`, `sankey-energy~dark@2x.jpg`, `sankey-selection@2x.jpg`,
      `sankey-selection~dark@2x.jpg`, `sankey-demo@2x.jpg`.

**Automated Verification**:

- [x] `swift build` succeeds.
- [x] `swift test` passes — in particular the whole `Ribbon geometry` suite, including the tests
      that must keep passing untouched: `zeroCurvature`, `controlOffsetIsClamped`,
      `curvatureIncreasesOffset`, `edgeCurvesAreOffsetByHalfTheThickness`, `taperingEnds`,
      `animatableComponents`.
- [x] `swift test --filter RibbonGeometryTests` passes on its own. (Swift Testing matches `--filter`
      against the test ID, which uses the *type* name — not the `@Suite` display name.)
- [x] `swiftlint --strict` reports no violations.

**Manual Verification**:

- [x] Open the `Finance`, `Styled` and `Interactive` previews in
      `Sources/SankeyKit/View/SankeyChart.swift` and confirm every ribbon leaves and enters its node
      flat and bends in between, with no kink or overshoot at the node edge.
- [x] In the `Interactive` preview, press "Save more" and confirm the animated transition stays a
      clean S on every intermediate frame.
- [x] Run the `SankeyDemo` app and confirm the diagram still reads correctly on a phone-width
      canvas, where the columns are closest together and the 24 pt offset floor takes over.
- [x] The seven re-captured screenshots show the new curves, in both colour schemes.

## Implementation Notes

- The formula change landed exactly as planned; no mismatch between the plan and the code.
- The symmetry test needs a cubic evaluator, added as a `private func cubic(at:_:_:_:_:)` helper on
  the suite, and compares with a `1e-9` tolerance rather than `==`.
- **Toolchain trap.** `swift` on `PATH` is swiftly's Swift 6.2.3, while `xcode-select` points at
  Xcode 27 Beta 5 (Swift 6.4). The 6.4 binary `.swiftmodule`s are unreadable by 6.2.3, so SwiftPM
  falls back to recompiling `.swiftinterface`s and a plain `swift build` never finishes (>70 min,
  killed). Building with Xcode's own toolchain, which is what CI does
  (`.github/workflows/ci.yml` selects the newest Xcode), takes 14 s:
  ```bash
  export PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
  swift build && swift test
  ```
  A killed `swift-build` also keeps holding the `.build` lock, which makes the next run look like it
  hangs too.
- **Demo app window (found during manual verification).** On macOS the demo window opened ~2800 pt
  tall on a 1692 pt screen, with its resize handle below the screen edge and zoom unable to shrink
  it. `SankeyKit` was not involved — a `SankeyChart` measures `0 x 0` minimum in every configuration.
  The cause was `DemoScreen`: its caption is `.fixedSize(horizontal: false, vertical: true)` and the
  screen had no minimum width, so AppKit took the content's minimum width (86 pt), asked how tall
  the caption wraps at that width (2691 pt), and made that the window's minimum height. Fixed with
  `.frame(minWidth: 480, ...)` on `DemoScreen`, measured with `NSHostingController` + `NSWindow`:

  | DemoScreen | minimum size |
  |---|---|
  | before | 86 x 2691 |
  | `minWidth: 480` | 480 x 273 |

  Measure this kind of thing with `NSHostingController`, the way `WindowGroup` does. A bare
  `NSHostingView` cannot measure a `NavigationSplitView` and reports `0 x 0`, which sent the first
  two attempts at this after the wrong causes (the chart's `minHeight`, then a stale saved window
  frame — the latter a symptom, since every launch saved the forced-huge frame back).

## References

- `d3-sankey/src/sankeyLinkHorizontal.js` — <https://github.com/d3/d3-sankey/blob/master/src/sankeyLinkHorizontal.js>
- `d3-shape/src/curve/bump.js` — <https://github.com/d3/d3-shape/blob/main/src/curve/bump.js>
- `docs/agents/plans/2026-08-17-sankeykit-package.md` — the original package plan, which records the
  formula being replaced here (line 179)
