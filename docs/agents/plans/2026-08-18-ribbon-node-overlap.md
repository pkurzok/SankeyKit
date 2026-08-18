---
date: 2026-08-18T07:23:57+00:00
git_commit: 96546264cc13440c8a6b0404ca1d24169a6a656d
branch: curved-ribbons
topic: "Tuck ribbon ends under the node capsules"
tags: [plan, ribbon-shape, sankey-diagram, rendering]
status: ready
---

# PLAN: Tuck ribbon ends under the node capsules

Ribbons currently butt against the flat edge of their node exactly at `frame.maxX` /
`frame.minX`. Because the node rectangles have rounded corners, the capsule curves away
from that line near a node's top and bottom, leaving a white wedge between the ribbon's
squared-off end and the node. The shared edge also produces a faint antialiasing hairline.
This plan removes both by extending each ribbon end horizontally *under* its node, which
is drawn on top.

## Acceptance Criteria

- No white gap between a ribbon end and its node capsule, including at the rounded corners.
- No antialiasing hairline along the shared node/ribbon edge.
- The node silhouette stays rounded; layout geometry (`RibbonGeometry`, `SankeyLayout`)
  and all existing tests are unchanged.
- Both ribbon ends are covered: the source node's trailing edge and the target node's
  leading edge.
- Animation still works: the overlap is constant per layout and does not distort the
  morphing of `RibbonShape`.
- A ribbon whose two thicknesses are both zero still draws nothing.

## Technical Key Decisions and Tradeoffs

1. **Fix in `RibbonShape`, not in the layout:** the ribbon path gains straight horizontal
   extension segments drawn before and after the existing Bézier curves.
   - Why: this is purely a rendering concern. `RibbonGeometry`, its animatable vector and
     the layout tests stay untouched, and the curve still meets the node edge with the
     same flat tangent.
   - Impact: `RibbonShape` gains an `overlap` property; `SankeyDiagram` threads
     `metrics.nodeWidth / 2` through `RibbonLayer`.
2. **Overlap = `nodeWidth / 2`, not configurable:** each ribbon end reaches the center
   line of its node.
   - Why: `Path(roundedRect:)` caps the corner radius at half the node width, so the
     corner wedge is never deeper than `nodeWidth / 2` horizontally. This overlap always
     covers the wedge completely and can never emerge from the node's far side.
   - Impact: no new public API, no new metric.
3. **Overlap stays out of `animatableData`:** it only changes when the user changes
   `nodeWidth`, which already re-renders; interpolating it would add a vector component
   for no visual gain.
4. **Accepted tradeoff — dimmed nodes are translucent:** an unrelated node renders at
   `SankeyDiagram.dimmedOpacity` (`0.25`) while a selection is active, so its own dimmed
   ribbons tucked underneath show through faintly and tint the node's halves. Both
   elements are equally dimmed, so this is subtle; verified manually below rather than
   engineered around.
5. **Accepted tradeoff — animated `nodeWidth` changes:** `overlap` snaps to the new
   `nodeWidth / 2` instantly while frames interpolate if a caller animates a metrics
   change, so a ribbon could transiently poke out of the node's far side. The diagram
   itself only animates selection changes, so this cannot happen without an explicit
   caller-side `withAnimation` on metrics.
6. **Accepted tradeoff — wedge opacity:** the wedge fills with the ribbon at its normal
   opacity (default `0.75`) over the background, so it is a slightly lighter tint than
   the node itself. The gradient already matches the node's hue at the attachment point
   (the gradient is anchored at `geometry.start.x` / `end.x` in canvas space and clamps
   beyond its endpoints, `SankeyStyle.swift:114-137`), so this reads as seamless.

## Current State

Rendering order in `Sources/SankeyKit/View/SankeyDiagram.swift`: `RibbonLayer` first,
then the opaque `NodeLayer` on top, then labels.

- `SankeyLayout.swift:212-213` anchors each ribbon exactly on the node edge:
  `start: CGPoint(x: sourceFrame.maxX, …)`, `end: CGPoint(x: targetFrame.minX, …)`.
- `NodeShape.swift:15` draws `Path(roundedRect: frame, cornerRadius: min(cornerRadius, frame.height / 2))`.
- `RibbonShape.path(in:)` draws: move to `top.start`, top curve to `top.end`, line down
  to `bottom.end`, bottom curve back to `bottom.start`, close.

```
      node        ribbon
   ╭────────╮
   │        │▓▓  ← corner arcs away → white wedge
   │        │▓▓▓▓▓▓▓▓▓▓▓
   │        │▓▓▓▓▓▓▓▓▓▓▓▓▓
   │        │▓▓▓▓▓▓▓▓▓▓▓
   │        │▓▓  ← same wedge at the bottom
   ╰────────╯
       ↑ ribbon stops exactly at frame.maxX
```

## Desired End State

The ribbon outline runs `overlap` points into each node with straight horizontal
segments. The opaque capsule hides the overlap along its flat edge; in the corner wedge
the ribbon shows through in the node's own hue.

```
      node        ribbon
   ╭────────╮
   │      ▓▓│▓▓▓ ← wedge filled by the tucked-under ribbon
   │      ▓▓│▓▓▓▓▓▓▓▓▓▓▓
   │      ▓▓│▓▓▓▓▓▓▓▓▓▓▓▓▓   (▓ left of │ is hidden by the node)
   │      ▓▓│▓▓▓▓▓▓▓▓▓▓▓
   │      ▓▓│▓▓▓
   ╰────────╯
       ↑ ribbon now starts at frame.maxX − nodeWidth/2
```

New path outline (source end shown; target end mirrors it):
move to `(top.start.x − overlap, top.start.y)` → line to `top.start` → top curve →
line to `(top.end.x + overlap, top.end.y)` → line to `(bottom.end.x + overlap,
bottom.end.y)` → line to `bottom.end` → bottom curve → line to
`(bottom.start.x − overlap, bottom.start.y)` → close.

## Abstractions and Code Reuse

No new abstractions. The existing `geometry` + shape split is kept: `RibbonGeometry`
remains the pure layout artifact, `RibbonShape` owns the rendering detail.

- `Sources/SankeyKit/View`
  - `RibbonShape.swift` — add the overlap
    - `RibbonShape` — new `var overlap: CGFloat = 0`; extend `path(in:)` with the
      straight segments (skipped when `overlap == 0` falls out naturally from the math,
      no branch needed); update the outline description in the type's doc comment
    - `animatableData` — unchanged (decision 3)
  - `SankeyDiagram.swift` — thread the value through
    - `RibbonLayer` — new `var overlap: CGFloat`; pass it to both the fill
      `RibbonShape` and the `contentShape` `RibbonShape`
    - `SankeyDiagram.body` — pass `overlap: metrics.nodeWidth / 2`
- `Tests/SankeyKitTests`
  - `RibbonShapeTests.swift` — new file, `@Suite("Ribbon shape")`, style as in
    `RibbonGeometryTests.swift`; additionally needs its own `import SwiftUI` for `Path`
    (`RibbonGeometryTests` itself only imports `CoreGraphics`)

Hit testing: `contentShape` grows by the overlap, but `NodeLayer` sits above the ribbons
in the `ZStack`, so taps on the node still select the node; only the visible wedge area
newly selects the ribbon, which is the ribbon's own color anyway.

## Logging & Observability

None — pure geometry/rendering change, no failure modes to log.

## Implementation

Dependencies: None.

Single phase: extend the ribbons under their nodes, cover with tests, verify in the demo.

**Tasks**:
- [x] `RibbonShape.swift`: add `var overlap: CGFloat = 0` and draw the extended outline
  in `path(in:)`:
  ```swift
  path.move(to: CGPoint(x: top.start.x - overlap, y: top.start.y))
  path.addLine(to: top.start)
  path.addCurve(to: top.end, control1: top.control1, control2: top.control2)
  path.addLine(to: CGPoint(x: top.end.x + overlap, y: top.end.y))
  path.addLine(to: CGPoint(x: bottom.end.x + overlap, y: bottom.end.y))
  path.addLine(to: bottom.end)
  path.addCurve(to: bottom.start, control1: bottom.control2, control2: bottom.control1)
  path.addLine(to: CGPoint(x: bottom.start.x - overlap, y: bottom.start.y))
  path.closeSubpath()
  ```
  Keep the existing zero-thickness guard. Update `RibbonShape`'s type doc comment —
  its outline description ("straight down the target node's leading edge …, closes up
  the source node's trailing edge") becomes a description of the tucked-under ends.
  Do not touch `RibbonGeometry.swift`'s similar wording; that type stays unchanged.
- [x] `SankeyDiagram.swift`: give `RibbonLayer` an `overlap: CGFloat` property, use it in
  both `RibbonShape(geometry:overlap:)` call sites (fill and `contentShape`), and pass
  `overlap: metrics.nodeWidth / 2` from `SankeyDiagram.body`.
- [x] `Tests/SankeyKitTests/RibbonShapeTests.swift`: new suite covering
  - the path's bounding rect spans `start.x - overlap` to `end.x + overlap`,
  - `overlap = 0` reproduces the old span (`start.x` to `end.x`),
  - a ribbon with both thicknesses `0` still produces an empty path even with overlap.

  Fixture note: use `end.x - start.x >= 24` (`RibbonGeometry.minimumControlOffset`);
  for narrower ribbons the control points overshoot the endpoints horizontally and the
  curve's bounding rect exceeds the `start.x…end.x` span, which would break the span
  assertions for reasons unrelated to the overlap.

**Automated Verification**:
- [x] `swift test` passes, including the new `RibbonShapeTests`.
- [x] `swift build` succeeds without warnings in the touched files.

**Manual Verification**:
- [x] Run the demo app (`Examples/SankeyDemo`), zoom into a node in the Energy demo:
  no white wedge at the rounded corners and no hairline along the node edge, on both
  sides of a middle-column node.
- [x] With a selection active, check a dimmed (unrelated) node: the translucent node over
  its tucked-under dimmed ribbons must not look objectionably uneven.

## Implementation Notes

- Implemented exactly as planned: `RibbonShape` gained `overlap`, `RibbonLayer` threads it
  through both call sites, `SankeyDiagram.body` passes `metrics.nodeWidth / 2`.
- `RibbonShapeTests` covers the two span assertions from the plan plus two extras that fell
  out while writing them: the overlap must not change the *vertical* span, and a ribbon that
  tapers to zero at one end must still be drawn (the zero-thickness guard is an `||`, so this
  pins the boundary the empty-path test sits next to).
- Screenshots: all seven JPGs in `Documentation.docc/Resources` were re-captured afterwards
  (they still showed the pre-curve straight ribbons, so the re-capture task left open in
  `2026-08-17-curved-ribbons.md` is now done too). The six chart shots come from a throwaway
  `ImageRenderer` harness at the original framing — 28 pt padding, `scale = 2`, 144 dpi JPEG,
  white / `#171717` backgrounds, 900×480 / 1000×560 / 900×440 pt. The demo shot is an
  iPhone 17 Pro simulator screenshot scaled to 644×1400.
- While taking the demo screenshot: the `minWidth: 480` added in 9654626 to fix the macOS
  window height also applied on iOS, where it overflowed a 402 pt phone and clipped the caption
  and the outer labels on both sides. Scoped it to `#if os(macOS)` in `SankeyDemoApp.swift`.
- Toolchain note, unrelated to this change: `swift build` with the `swift` on `PATH`
  (the `swift-6.2.3-RELEASE` toolchain in `~/Library/Developer/Toolchains`) spins forever at
  100% CPU compiling `swift-docc-plugin`'s `Package.swift` against the Xcode 27 beta SDK.
  Building and testing with Xcode's own toolchain (`env -u TOOLCHAINS /usr/bin/swift`,
  Swift 6.4) completes in ~11 s. Only the manifest compile is affected, not this code.

## References

- `Sources/SankeyKit/View/RibbonShape.swift` — shape to extend
- `Sources/SankeyKit/View/SankeyDiagram.swift` — `RibbonLayer` / z-order
- `Sources/SankeyKit/View/NodeShape.swift:15` — corner radius clamp
- `Sources/SankeyKit/Layout/SankeyLayout.swift:212-213` — ribbon anchors on node edges
- `Sources/SankeyKit/View/SankeyStyle.swift:114-137` — gradient anchored at ribbon endpoints
- `docs/agents/plans/2026-08-17-curved-ribbons.md` — prior plan that introduced the
  current ribbon geometry
