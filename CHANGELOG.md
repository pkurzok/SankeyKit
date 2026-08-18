# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-18

First public release.

### Added

- **Marks and a result builder.** `SankeyChart` takes `SankeyLink` and `SankeyNode` marks through
  `SankeyContentBuilder`, where `if`, `if`/`else` and `for` work exactly as they do in a
  `ViewBuilder`.
- **A data-driven initializer.** `SankeyChart(data) { … }` builds the same chart from a collection,
  one group of marks per element.
- **Labelled values.** `SankeyValue` mirrors `PlottableValue`; its labels become the descriptions
  VoiceOver reads.
- **Implicit nodes and inferred columns.** Naming a node in a link creates it; columns follow from
  longest-path layering, with per-node overrides. A cyclic graph names the cycle instead of
  crashing.
- **Chart modifiers.** `sankeyNodeWidth(_:)`, `sankeyNodeSpacing(_:)`, `sankeyNodeCornerRadius(_:)`,
  `sankeyLinkSpacing(_:)`, `sankeyLinkCurvature(_:)`, `sankeyLinkOpacity(_:)` and
  `sankeyColorScale(_:)` — environment-backed and composable, like `chartXAxis` and friends.
- **Selection.** Bind a `SankeySelection?` with `sankeySelection(_:)`; a tap or an accessibility
  activation lights one flow while the rest dims.
- **Animation.** Changing a value inside `withAnimation` morphs the ribbons rather than jumping
  them: each ribbon interpolates through its endpoints and rebuilds its curve every frame.
- **Accessibility.** Every node and every ribbon is its own element, read in column order, with
  labels, values and selection traits.
- **A pure layout engine.** `SankeyGraph` and `SankeyLayout` are view-free value-type computations
  covered by 112 unit tests.

[1.0.0]: https://github.com/pkurzok/SankeyKit/releases/tag/1.0.0
