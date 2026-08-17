---
date: 2026-08-17T18:16:04+00:00
git_commit: ""
branch: ""
topic: "SankeyKit — Swift Charts-style Sankey diagram package"
tags: [plan, sankeykit, swiftui, swift-package, layout-engine, sample-app]
status: complete
---

# PLAN: SankeyKit — a Swift Charts-style Sankey Diagram Package

Build a new Swift Package `SankeyKit` that renders Sankey diagrams in SwiftUI with an API that looks and feels like Apple's Swift Charts (`Chart` / `ChartContent` / marks / `.value()` / chained modifiers). Includes a multi-screen sample app (iOS + macOS), Swift Testing unit tests, SwiftLint enforcement, DocC documentation, GitHub Actions CI, and a private GitHub repo `pkurzok/SankeyKit` with a detailed README (MIT-licensed, ready to go public later).

## Acceptance Criteria

- `swift build` and `swift test` pass on the package (Swift 6 language mode, strict concurrency).
- `swiftlint --strict` passes with a committed `.swiftlint.yml`.
- API mirrors Swift Charts: `SankeyChart { ... }` container with `@SankeyContentBuilder`, `SankeyLink` marks with both simple and `.value("Label", x)`-style parameters, a data-driven `SankeyChart(data) { element in ... }` init, and chained styling modifiers.
- Nodes are derived implicitly from link endpoints; layers are inferred via longest-path topological ordering; optional `SankeyNode` marks override style, display label, or layer.
- Cyclic graphs never crash: layout reports the cycle and the view renders a developer-readable diagnostic instead of a broken diagram.
- Link ribbons are single cubic-Bézier `Path`s with control points offset in both x and y (curvature ≈ 0.45–0.6, `dx` clamped to ≥ 24 pt) per the referenced article, so curves bend immediately at node edges with no overshoot.
- v1 features: node labels, styling modifiers (node width / spacing / corner radius / link curvature / link opacity / color scale), tap selection via `Binding<SankeySelection?>` with dimming of unrelated elements, animated transitions when values change, VoiceOver accessibility for nodes and links.
- Sample app `Examples/SankeyDemo` (iOS 17+ & macOS 14+, generated with XcodeGen) with three screens: Finance, Energy, Playground (live value sliders + selection + animation).
- Private GitHub repo `pkurzok/SankeyKit` exists with detailed README, MIT `LICENSE`, DocC catalog, and a CI workflow running lint + tests on a macOS runner.

## Technical Key Decisions and Tradeoffs

1. **Mark-style builder API (`SankeyChart` + `@SankeyContentBuilder` + `SankeyLink`/`SankeyNode`):** chosen over a plain data-array view.
   - Why: the explicit goal is "feels like Swift Charts".
   - Impact: needs a result builder, a `SankeyContent` protocol, and a `SankeyValue` type mimicking `PlottableValue`'s `.value("Label", x)` spelling. `SankeyContent` is *not* designed for external conformance — its single requirement is underscored (`func _resolve(into:)`), same spirit as Apple's hidden protocol requirements.
2. **Own `SankeyValue<Value>` instead of importing `Charts.PlottableValue`:** a tiny struct with a static `.value(_:_:)` factory.
   - Why: importing the Charts framework just for one type couples us to it needlessly; labels are ours to use.
   - Impact: `.value()` labels feed accessibility descriptions ("Salary to Budget: 4.800").
3. **Implicit nodes + automatic layer assignment (longest-path topological ordering), with `SankeyNode` overrides:**
   - Why: Swift Charts derives structure from data; zero boilerplate for the common case.
   - Impact: layout engine contains a small graph algorithm incl. cycle detection; overrides merge into derived nodes by name.
4. **Pure layout engine separated from SwiftUI:** `SankeyLayout.compute(graph:size:metrics:)` returns value-type geometry (`CGRect` per node, ribbon control points per link) with no view dependencies.
   - Why: the math (scaling, stacking, Bézier control points) becomes trivially unit-testable with Swift Testing.
   - Impact: rendering layer is a thin mapping from geometry to shapes.
5. **Rendering with per-element SwiftUI shapes (one `Path` per link, one `RoundedRectangle` per node), not `Canvas`:**
   - Why: free hit-testing for tap selection, per-element accessibility, and `Animatable` shape interpolation. `Canvas` would require hand-rolling all three.
   - Impact: fine for realistic Sankey sizes (tens of nodes/links). A custom `AnimatableVector` (fixed-size `CGFloat` container conforming to `VectorArithmetic`) drives ribbon path animation.
6. **Chart configuration via `View` extensions backed by SwiftUI `Environment`:** `.sankeyNodeWidth(_:)`, `.sankeySelection(_:)`, etc.
   - Why: exactly how `chartXAxis`/`chartXSelection` work; composes naturally.
   - Impact: one internal `SankeyConfiguration` environment value; selection binding travels the same way.
7. **Platforms iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1, `swift-tools-version: 6.0`:** modern SwiftUI era matching `SectorMark`'s availability; all platforms are nearly free with pure SwiftUI.
8. **SwiftLint via config file + CLI (locally and in CI), not the SPM build plugin:**
   - Why: the build plugin triggers Xcode trust prompts and slows every build; CI enforcement gives the same guarantee.
   - Impact: `swiftlint --strict` is a verification step in every phase; CI installs it via Homebrew.
9. **XcodeGen for the sample app project** (installed at `/opt/homebrew/bin/xcodegen`): `project.yml` is committed, `*.xcodeproj` is gitignored and regenerated on demand.
10. **MIT license + DocC catalog from day one:** the repo is private now but may go public; license and docs should not be an afterthought.

## Current State

`the package root` is empty (greenfield, not yet a git repository). Tooling verified: Xcode 27.0 (beta), SwiftLint 0.65.0, XcodeGen, `gh` authenticated as `pkurzok` with `repo` scope. Apple ships no Sankey API (verified via cupertino) — no naming collisions.

## Desired End State

```
SankeyKit/
├── Package.swift                      swift-tools-version: 6.0, all Apple platforms
├── .swiftlint.yml
├── .gitignore
├── LICENSE                            MIT
├── README.md                          detailed, with usage examples
├── .github/workflows/ci.yml           lint + test on macOS runner
├── Sources/SankeyKit/
│   ├── Model/
│   │   ├── SankeyValue.swift          .value("Label", x) — PlottableValue analog
│   │   ├── SankeyResolution.swift     flat resolution output: links + node overrides
│   │   ├── SankeyGraph.swift          resolved graph: nodes, links, validation
│   │   └── SankeySelection.swift      .node(String) / .link(source:target:)
│   ├── Layout/
│   │   ├── LayerAssignment.swift      longest-path layering + cycle detection
│   │   ├── SankeyLayout.swift         scale, stacking, node frames
│   │   ├── RibbonGeometry.swift       Bézier control-point math → Path
│   │   └── AnimatableVector.swift     VectorArithmetic over [CGFloat]
│   ├── Content/
│   │   ├── SankeyContent.swift        protocol + composite builder types
│   │   ├── SankeyContentBuilder.swift @resultBuilder
│   │   ├── SankeyLink.swift           link mark + per-link modifiers
│   │   └── SankeyNode.swift           node customization mark
│   ├── View/
│   │   ├── SankeyChart.swift          container view, resolution, GeometryReader
│   │   ├── SankeyConfiguration.swift  environment plumbing + View modifiers
│   │   ├── RibbonShape.swift          animatable link shape
│   │   ├── NodeShape.swift            node rect + label placement
│   │   └── SankeyChart+Accessibility.swift
│   └── Documentation.docc/
│       ├── SankeyKit.md               landing page
│       └── GettingStarted.md          tutorial article
├── Tests/SankeyKitTests/              Swift Testing (@Test / #expect)
│   ├── LayerAssignmentTests.swift
│   ├── SankeyGraphTests.swift
│   ├── SankeyLayoutTests.swift
│   ├── RibbonGeometryTests.swift
│   ├── AnimatableVectorTests.swift
│   ├── ContentBuilderTests.swift
│   ├── StyleResolutionTests.swift
│   └── SelectionTests.swift
├── Examples/SankeyDemo/
│   ├── project.yml                    XcodeGen spec (iOS + macOS destinations)
│   └── Sources/
│       ├── SankeyDemoApp.swift        TabView / sidebar navigation
│       ├── FinanceDemoView.swift      income → budget → expenses
│       ├── EnergyDemoView.swift       4+ layers, many nodes
│       └── PlaygroundView.swift       sliders, selection readout, animations
└── docs/agents/plans/                 this plan
```

Target API (the contract every phase builds toward):

```swift
// Explicit marks
SankeyChart {
    SankeyLink(from: "Salary", to: "Budget", value: 4800)
    SankeyLink(from: "Side gig", to: "Budget", value: 700)
    SankeyLink(from: "Budget", to: "Rent", value: 1900)
        .foregroundStyle(.orange)
    if showSavings {
        SankeyLink(from: "Budget", to: "Savings", value: 900)
    }
    SankeyNode("Budget")                       // optional customization
        .foregroundStyle(.blue)
        .label("Monthly Budget")
}
.sankeyNodeWidth(12)
.sankeyLinkCurvature(0.5)
.sankeySelection($selection)                   // Binding<SankeySelection?>

// Data-driven, like Chart(data) { }
SankeyChart(flows) { flow in
    SankeyLink(
        from: .value("Source", flow.from),
        to: .value("Target", flow.to),
        value: .value("Amount", flow.amount)
    )
}
```

## Abstractions and Code Reuse

Greenfield — all abstractions are new; the reuse story is *internal* layering:

- `SankeyContent` resolution produces a flat `SankeyResolution` (links + node overrides) — consumed by `SankeyGraph`, never by views directly.
- `SankeyGraph` (validated, deduplicated) is the only input to `SankeyLayout` — views never touch raw marks.
- `SankeyLayout` output (`SankeyLayoutResult`) is plain geometry — `RibbonShape`/`NodeShape` only translate it to `Path`s. Every phase-4 feature (selection, animation, accessibility) reads from this same result.

## Logging & Observability

- Invalid graphs (cycles, self-links, non-positive values) are reported via `os.Logger(subsystem: "de.peterkurzok.SankeyKit", category: "layout")` at `.error`, and the chart renders a compact diagnostic overlay (e.g. `⚠︎ SankeyChart: cycle involving "Budget" → "Salary"`), so developers see the problem instead of an empty view.
- No logging in the hot layout path.

## Implementation

### Phase 1: Package Scaffold + Pure Layout Engine

Dependencies: None

Create the package, git repository, lint config, and the complete math core — graph resolution, layer inference, scaling, stacking, ribbon geometry — fully unit-tested before any pixel is drawn.

**Tasks**:
- [x] `git init`; create `.gitignore` (`.build/`, `DerivedData/`, `xcuserdata/`, `Examples/**/*.xcodeproj`, `.DS_Store`, `.swiftpm/`)
- [x] Create `Package.swift`: `swift-tools-version: 6.0`, name `SankeyKit`, platforms `.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)`, library target `SankeyKit`, test target `SankeyKitTests`, dependency `swift-docc-plugin` (docs built in Phase 6, dependency declared once here)
- [x] Create `.swiftlint.yml`: excluded `.build`, `Examples` (temporary — Phase 5 brings example sources into linting); `identifier_name: allowed_symbols: ["_"]` (the public-but-hidden `_resolve` requirement needs it); sensible defaults (`line_length` warning 140, opt-in rules like `sorted_imports`); zero violations required (`--strict` in CI)
- [x] `Model/SankeyValue.swift`: `public struct SankeyValue<Value: Sendable>: Sendable { let label: String; let value: Value; public static func value(_ label: String, _ value: Value) -> Self }`
- [x] `Model/SankeyResolution.swift`: `public struct SankeyResolution: Sendable` — the flat output of content resolution: `var links: [ResolvedLink]`, `var nodeOverrides: [NodeOverride]` plus mutating `append` helpers. Public because it appears in the `SankeyContent` protocol requirement (Phase 2)
- [x] `Model/SankeyGraph.swift`: internal resolved model —
  - `ResolvedLink` (sourceID, targetID, value, labels, optional style/opacity payload)
  - `ResolvedNode` (id/name, optional display label, optional style, optional pinned layer; computed inflow/outflow totals; magnitude = `max(inflow, outflow)`)
  - `SankeyGraph.init(resolution:)` derives nodes from link endpoints, merges `SankeyNode` overrides by name, validates: drops links with `value <= 0` and self-links (logged), detects cycles → `SankeyGraphError.cycle(path: [String])`
- [x] `Model/SankeySelection.swift`: `public enum SankeySelection: Hashable, Sendable { case node(String); case link(source: String, target: String) }`
- [x] `Layout/LayerAssignment.swift`: longest-path topological layering (Kahn's algorithm computing distance from sources); pinned layers from overrides win; sinks-only nodes keep computed layer (no right-alignment pass in v1)
- [x] `Layout/SankeyLayout.swift`: `struct SankeyMetrics` (nodeWidth, nodeSpacing, cornerRadius, curvature, linkOpacity — with defaults 12 / 8 / 3 / 0.5 / 0.75); `SankeyLayout.compute(graph:size:metrics:) -> SankeyLayoutResult`:
  - scale = `min over layers of (size.height − spacing·(n−1)) / Σ magnitude(layer)`
  - node height = `magnitude · scale`, min visible height 2 pt; nodes stacked top-aligned per layer, layers spread evenly across width (first column at x=0, last at `size.width − nodeWidth`)
  - per-node ribbon stacking: links sorted by counterpart node's y (crossing-reduction heuristic); track used outgoing thickness per source and used incoming thickness per target; ribbon center at `minY + used + thickness/2`
  - result: `nodeFrames: [String: CGRect]`, `ribbons: [RibbonGeometry]` (ordered), echoes per-element style payloads
- [x] `Layout/RibbonGeometry.swift`: start = source `maxX`, end = target `minX`; `dx = max(24, end.x − start.x)`; control points `c1 = (start.x + dx·v, start.y + (end.y − start.y)·v)`, `c2 = (end.x − dx·v, end.y − (end.y − start.y)·v)` with `v = curvature`; exposes top & bottom curve point tuples for a closed ribbon path of thickness `t`
- [x] `Layout/AnimatableVector.swift`: `struct AnimatableVector: VectorArithmetic` over `[CGFloat]` (element-wise ops, `magnitudeSquared`, zero-padding for length mismatch)
- [x] Tests (Swift Testing, `@Test`/`#expect`/`#require`):
  - `LayerAssignmentTests`: linear chain → 0,1,2; diamond graph; pinned-layer override wins; disconnected components; cycle → `SankeyGraphError.cycle` with correct path
  - `SankeyGraphTests`: implicit node derivation & dedupe ("Budget" appears once given 3 links touching it); override merge by name (label/layer/style); links with `value <= 0` and self-links dropped
  - `SankeyLayoutTests`: node heights proportional to magnitude; tallest layer fills available height minus spacing; ribbons at a node never overlap (sum of thicknesses + offsets consistent); zero-size and empty-graph inputs return empty result without crash
  - `RibbonGeometryTests`: endpoints on node edges; control-point formula matches article (incl. `dx` clamp at 24 for close/overlapping columns); curvature 0 vs 0.6 differ as expected
  - `AnimatableVectorTests`: arithmetic + interpolation midpoint

**Automated Verification**:
- [x] `swift build` succeeds
- [x] `swift test` passes (all suites above)
- [x] `swiftlint --strict` reports no violations
- [x] Commit phase result

### Phase 2: Core Rendering — SankeyChart, Builder, Marks, Labels

Dependencies: Phase 1

The declarative API and a first rendered diagram: container view, result builder, `SankeyLink`/`SankeyNode` marks, both initializers, node rectangles, ribbons, and node labels.

**Tasks**:
- [x] `Content/SankeyContent.swift`: `public protocol SankeyContent { func _resolve(into resolution: inout SankeyResolution) }` (doc-commented as not for external conformance); composite types `SankeyTupleContent<each C>` (parameter pack, not N overloads), `SankeyOptionalContent`, `SankeyConditionalContent`, `SankeyForEachContent<Data, C>` (generic over the collection and per-element content), `EmptySankeyContent`, and type-erasing `AnySankeyContent`
- [x] `Content/SankeyContentBuilder.swift`: `@resultBuilder public enum SankeyContentBuilder` with `buildBlock` (variadic via `SankeyTupleContent<each C>`), `buildOptional`, `buildEither(first:/second:)`, `buildArray`, `buildExpression`, `buildLimitedAvailability` (returns `AnySankeyContent` to drop the availability-constrained generic)
- [x] `Content/SankeyLink.swift`: `public struct SankeyLink: SankeyContent`
  - `init(from: String, to: String, value: Double)`
  - `init(from: SankeyValue<String>, to: SankeyValue<String>, value: SankeyValue<Double>)` (labels retained for accessibility)
  - per-link modifiers returning `Self`: `.foregroundStyle(_ style: some ShapeStyle)` (stored as `AnyShapeStyle`), `.opacity(_ value: Double)`
- [x] `Content/SankeyNode.swift`: `public struct SankeyNode: SankeyContent` — `init(_ name: String, layer: Int? = nil)`, modifiers `.foregroundStyle(...)`, `.label(_ text: String)`
- [x] `View/SankeyChart.swift`: `public struct SankeyChart<Content: SankeyContent>: View`
  - `init(@SankeyContentBuilder content: () -> Content)`
  - data-driven init in an extension, Swift Charts-style, with a *named* generic (an opaque `some SankeyContent` parameter cannot be referenced in a `where` clause):
    ```swift
    extension SankeyChart {
        public init<Data: RandomAccessCollection, C: SankeyContent>(
            _ data: Data,
            @SankeyContentBuilder content: @escaping (Data.Element) -> C
        ) where Content == SankeyForEachContent<Data, C>
    }
    ```
  - body: resolve content → `SankeyGraph` → `GeometryReader` → `SankeyLayout.compute` → ZStack of ribbon shapes (below) and node shapes + labels (above), `.clipped()`
  - graph error → diagnostic overlay + `os.Logger` error (per Logging section)
- [x] `View/RibbonShape.swift`: `Shape` producing the closed ribbon path from `RibbonGeometry` (top curve → line down at target → bottom curve back → close); filled with per-link style or the node color scale color of the *source* node; default link opacity from metrics
- [x] `View/NodeShape.swift`: `RoundedRectangle(cornerRadius:)` per node frame + `Text` label — trailing side of node for all layers except the last, which labels on the leading side; label font `.caption`, node color from default palette cycling per node in (layer, y) order
- [x] Tests:
  - `ContentBuilderTests`: block with 3 links resolves to 3 resolved links in order; `if` (optional) and `if/else` (either) branches; `for`-loop (`buildArray`); data-driven init flattens collection; `SankeyNode` marks land in overrides, not links
  - Extend `SankeyGraphTests` (Phase 1 file): end-to-end resolution through the builder — marks in a builder closure produce the same graph as hand-built `SankeyResolution`
- [x] Add a minimal `#Preview` in `SankeyChart.swift` with the finance example (compiles on all platforms)

**Automated Verification**:
- [x] `swift build` succeeds (macOS)
- [x] `xcodebuild build -scheme SankeyKit -destination 'generic/platform=iOS Simulator'` succeeds (xcodebuild auto-generates the scheme from `Package.swift`; catches platform-only API misuse)
- [x] Same `xcodebuild build` for `generic/platform=tvOS Simulator`, `generic/platform=watchOS Simulator`, and `generic/platform=visionOS Simulator` — all five declared platforms compile
- [x] `swift test` passes
- [x] `swiftlint --strict` passes
- [x] Commit phase result

**Manual Verification**:
- [x] Open the package in Xcode and confirm the `#Preview` renders a correct finance Sankey (proportional ribbons, labels readable, curves bend at node edges without overshoot)
      (rendered through Xcode's preview renderer on iOS 27; two bugs found and fixed, see Implementation Notes)

### Phase 3: Styling — Chart Modifiers and Color Scale

Dependencies: Phase 2

The "public knobs", Swift Charts-style: environment-backed `View` modifiers plus a color scale, with clear precedence (per-element mark modifier > color scale > default palette).

**Tasks**:
- [x] `View/SankeyConfiguration.swift`: internal `SankeyConfiguration` struct (metrics + optional `[Color]` scale + selection binding placeholder for Phase 4) as an `@Entry` environment value; public `View` extensions:
  - `.sankeyNodeWidth(_ width: CGFloat)`
  - `.sankeyNodeSpacing(_ spacing: CGFloat)`
  - `.sankeyNodeCornerRadius(_ radius: CGFloat)`
  - `.sankeyLinkCurvature(_ curvature: Double)` — clamped to `0...1`
  - `.sankeyLinkOpacity(_ opacity: Double)` — clamped to `0...1`
  - `.sankeyColorScale(_ colors: [Color])` — assigned to nodes in (layer, y) order, cycling
- [x] `SankeyChart` reads the environment configuration and feeds `SankeyMetrics` into layout; style resolution helper decides final node/link fill with documented precedence
- [x] Tests (`StyleResolutionTests`): scale cycling over more nodes than colors; `SankeyNode.foregroundStyle` beats scale; `SankeyLink.foregroundStyle` beats source-node color; curvature/opacity clamping; default metrics used when no modifier present
- [x] Extend `#Preview` with a styled variant exercising every modifier

**Automated Verification**:
- [x] `swift build` && `swift test` pass
- [x] `swiftlint --strict` passes
- [x] Commit phase result

### Phase 4: Interaction, Animation, Accessibility

Dependencies: Phase 3

Tap selection with dimming, animated layout transitions, and VoiceOver support.

**Tasks**:
- [x] `.sankeySelection(_ selection: Binding<SankeySelection?>)` modifier storing the binding in `SankeyConfiguration`
- [x] Hit handling in `SankeyChart`: `.onTapGesture` on each node/ribbon shape sets the binding (`nil` on tapping the selected element again or the background). tvOS caveat: `onTapGesture` compiles on tvOS 17 but per-shape taps are effectively non-functional without focus — document selection as iOS/macOS/visionOS/watchOS; tvOS renders read-only
- [x] Dimming: pure helper `relatedElements(to selection: SankeySelection, in graph: SankeyGraph) -> (nodes: Set<String>, links: Set<LinkID>)` — a selected node keeps itself + all adjacent links + their counterpart nodes at full opacity; a selected link keeps itself + its two nodes; everything else drops to 0.25 opacity via `.opacity` with `.animation(.snappy, value: selection)`
- [x] Animation: `RibbonShape` conforms to `Animatable` with `animatableData: AnimatableVector` built from the 8 geometry points + thickness; `NodeShape` frames animate via standard frame animation; document that callers animate data changes with `withAnimation` (matching SwiftUI convention)
- [x] `View/SankeyChart+Accessibility.swift`:
  - each node: `.accessibilityElement()`, label = display label, value = formatted total magnitude
  - each link: label "\(sourceLabel) to \(targetLabel)", value = formatted value; uses `SankeyValue` labels when provided ("Amount: 4.800")
  - reading order sorted by (layer, y) via `.accessibilitySortPriority`
  - selected element gets `.accessibilityAddTraits(.isSelected)`
- [x] Tests (`SelectionTests`): related-element computation for node selection (middle node of a chain), link selection, `nil` selection returns everything; `AnimatableVector` interpolation of two `RibbonGeometry` snapshots stays monotonic (midpoint between endpoints)

**Automated Verification**:
- [x] `swift build` && `swift test` pass
- [x] `swiftlint --strict` passes
- [x] Commit phase result

**Manual Verification**:
- [x] In the Xcode preview: tapping a node dims unrelated flows smoothly; tapping again deselects
      (verified in the iOS simulator instead: tapping the "Groceries" node dims everything except
      it, its ribbon and "Monthly Budget"; a second tap restores; tapping a ribbon selects the link)
- [ ] Changing a link value inside `withAnimation` morphs ribbons smoothly (no jumps)
- [x] VoiceOver (or Accessibility Inspector) announces nodes and links with meaningful labels and values
      (verified from the simulator's accessibility hierarchy: one element per node — `Monthly Budget`
      value `5.500` — and per link — `Salary to Monthly Budget` value `4.800`)

### Phase 5: Sample App — SankeyDemo

Dependencies: Phase 4

A multiplatform (iOS + macOS) demo app in `Examples/SankeyDemo`, generated with XcodeGen, showcasing the full API.

**Tasks**:
- [x] `Examples/SankeyDemo/project.yml`: app target `SankeyDemo`, `supportedDestinations: [iOS, macOS]`, deployment targets iOS 17 / macOS 14, local package dependency `../..`, bundle id `de.peterkurzok.SankeyDemo`, generated project gitignored
- [x] `SankeyDemoApp.swift`: `TabView` (iOS) / `NavigationSplitView` sidebar (macOS) with the three demos
- [x] `FinanceDemoView.swift`: classic income → budget → expense flow using the *explicit-marks* init + `SankeyNode` customization + styling modifiers
- [x] `EnergyDemoView.swift`: 4+ layer energy-flow dataset (sources → conversion → distribution → consumption) using the *data-driven* init + `.sankeyColorScale`
- [x] `PlaygroundView.swift`: sliders bound to link values (wrapped in `withAnimation`), a `SankeySelection?` state with a readout of the current selection, toggle for an optional link (exercises `buildOptional`)
- [x] Verify SwiftLint covers the example sources or keep them excluded (decision: include `Examples/**/Sources` in linting; regenerate `.swiftlint.yml` includes accordingly)

**Automated Verification**:
- [x] `cd Examples/SankeyDemo && xcodegen generate` succeeds
- [x] `xcodebuild build -project Examples/SankeyDemo/SankeyDemo.xcodeproj -scheme SankeyDemo -destination 'generic/platform=iOS Simulator'` succeeds
- [x] `xcodebuild build -project Examples/SankeyDemo/SankeyDemo.xcodeproj -scheme SankeyDemo -destination 'platform=macOS'` succeeds
- [x] `swiftlint --strict` passes
- [x] Commit phase result

**Manual Verification**:
- [x] Run SankeyDemo on the iOS simulator: all three screens render; Playground sliders animate ribbons live; tapping selects and dims
- [ ] Run SankeyDemo on macOS: sidebar navigation works, diagrams render correctly

### Phase 6: Release Readiness — Docs, CI, GitHub Repo

Dependencies: Phase 5

DocC catalog, detailed README, license, CI workflow, and the private GitHub repository.

**Tasks**:
- [x] `Sources/SankeyKit/Documentation.docc/SankeyKit.md`: landing page — overview, feature list, curated topics (Essentials / Marks / Styling / Interaction)
- [x] `Sources/SankeyKit/Documentation.docc/GettingStarted.md`: article building the finance example step by step
- [x] Audit all public symbols for `///` doc comments (every public type, init, and modifier)
- [x] `LICENSE`: MIT, copyright 2026 Peter Kurzok
- [x] `README.md` (detailed, public-ready): what it is + hero code sample; feature list; requirements (platforms/Swift); SPM installation (`.package(url:)` snippet); usage — explicit marks, data-driven init, styling modifiers table, selection, animation; sample app instructions (`xcodegen generate` + open); architecture note (pure layout engine); license & credits (link to the jc_builds article for the ribbon math); CI badge
- [x] `.github/workflows/ci.yml`: on push/PR to `main`; jobs on `macos-latest`: **lint** (`brew install swiftlint && swiftlint --strict`), **test** (select newest Xcode via `xcode-select`, `swift build`, `swift test`)
- [x] Verify DocC builds: `swift package generate-documentation --target SankeyKit` (plugin dependency added in Phase 1)
- [x] Create repo & push: `gh repo create pkurzok/SankeyKit --private --source . --description "Swift Charts-style Sankey diagrams for SwiftUI" --push`
- [x] Confirm CI run is green on GitHub: `gh run list --limit 1` shows status `completed` / conclusion `success`
- [x] Update this plan's frontmatter `status` to `complete` and record any deviations in Implementation Notes

**Automated Verification**:
- [x] `swift package generate-documentation --target SankeyKit` succeeds
- [x] `swift build` && `swift test` && `swiftlint --strict` pass locally
- [x] `gh repo view pkurzok/SankeyKit --json visibility` reports `PRIVATE`
- [x] `gh run list --limit 1` shows a successful CI run

**Manual Verification**:
- [x] README renders correctly on GitHub (code blocks, badge, tables)
      (checked the rendered HTML from the API: 2 tables, 10 code blocks with swift/shell highlighting,
      4 badges, working LICENSE link. The CI badge needs auth while the repo is private.)
- [ ] DocC documentation browsable in Xcode (Product → Build Documentation)

### Phase 6 note

The first `gh repo create` attempt was denied by the sandbox classifier. After the user asked for it
explicitly, the same command succeeded — the denial was on the write action, not on network access.

## Implementation Notes

During implementation, document user feedback, problems, and decisions here.

### Toolchain

- The `swift` on `PATH` is swiftly's **6.2.3**, and it hangs indefinitely compiling
  `swift-docc-plugin`'s `swift-tools-version:5.7` manifest (killed after 9 minutes at 100% CPU).
  Xcode 27's toolchain (Swift 6.4) resolves the same package in ~4 s. **All local commands are run
  through `xcrun swift …`.** CI on `macos-latest` has no swiftly, so plain `swift build` is fine
  there.

### User feedback after Phase 2 — prettier ribbons (folded into Phase 3)

The first render was correct but plain. Requested: colors that gradually merge into each other,
and more spacing between the links. Resulting deviations from the plan:

- `RibbonGeometry` carries **a thickness per end** (`startThickness` / `endThickness`) instead of a
  single `thickness`, so a node can insert a gap between the ribbons attached to it. The gaps are
  taken out of the node's own extent rather than added to it, so each side still matches the node's
  in- or outflow; a ribbon tapers when its two nodes carry different numbers of links.
  `animatableComponents` is therefore **10 scalars, not 9**.
- New metric `SankeyMetrics.linkSpacing` (default 3 pt) with a matching
  `.sankeyLinkSpacing(_:)` modifier — one more knob than the plan listed. Clamped so gaps never
  consume more than half of a node edge.
- Ribbons are filled with a **gradient from source-node color to target-node color**, interpolated
  in `Gradient.ColorSpace.perceptual` (available from iOS 16 / macOS 13, below all our minimums, so
  no availability gating). `SankeyNode.foregroundStyle` also records a `tint` when the style is a
  plain `Color`, so a customized node blends its ribbons too.
- The **default palette was replaced** by a hue-ordered ramp, so neighbouring nodes get
  neighbouring hues and their gradients stay saturated instead of passing through grey.
- Node spacing is clamped per layer, so a crowded column no longer collapses the vertical scale to
  zero and renders nothing.

### Structural deviations found with Xcode's preview renderer

Both of these were found by rendering the `#Preview` through the Xcode MCP server, not by the
compiler:

- The data-driven initializer originally delegated with `self.init(resolvedContent:)`. Xcode's
  preview instrumentation wraps every expression in `__designTimeSelection(…)` and cannot nest
  `self.init` inside it, which broke **every** `#Preview` in that file. The initializer now assigns
  the stored property directly, and `init(resolvedContent:)` is gone.
- The diagram was assembled in a `@ViewBuilder` method on `SankeyChart`. That rendered blank on iOS
  and segfaulted the preview agent inside `ForEachState.item(at:offset:)`. It is now built from
  real `View` structs in **`View/SankeyDiagram.swift`** (`SankeyDiagram` + `RibbonLayer` /
  `NodeLayer` / `LabelLayer`) — a file the plan did not list.

### Other additions

- **`View/SankeyStyle.swift`** (not in the plan) holds the `SankeyFill` enum and
  `SankeyStyleResolver`. Resolving to a `SankeyFill` rather than straight to `AnyShapeStyle` keeps
  the precedence rules unit-testable, since `AnyShapeStyle` cannot be compared.
- `SankeyMetrics` clamps its own properties on assignment (`didSet`), so clamping is intrinsic and
  testable rather than duplicated across the modifiers.

## References

- Ribbon math & layout approach: https://medium.com/@jc_builds/easily-add-a-clean-swiftui-sankey-diagram-to-your-app-c4972b55d0c1
- Swift Charts API patterns (via cupertino): `apple-docs://charts/chart`, `apple-docs://charts/chartcontent`, `apple-docs://charts/chartcontentbuilder`, `apple-docs://charts/sectormark` (non-cartesian mark precedent)
- Layer assignment reference: d3-sankey longest-path layering (conceptual)
