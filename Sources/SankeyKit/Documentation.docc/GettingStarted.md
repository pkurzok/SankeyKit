# Getting started

Build a monthly budget diagram, one step at a time.

## Overview

This article starts from four numbers and ends with a styled, selectable, animated chart. Every
step compiles on its own, so you can stop wherever the diagram already says what you need.

## Describe the flows

A Sankey diagram is a list of flows. Each ``SankeyLink`` names where the flow comes from, where it
goes, and how big it is.

```swift
import SankeyKit
import SwiftUI

struct BudgetChart: View {
    var body: some View {
        SankeyChart {
            SankeyLink(from: "Salary", to: "Budget", value: 4800)
            SankeyLink(from: "Side gig", to: "Budget", value: 700)
            SankeyLink(from: "Budget", to: "Rent", value: 1900)
            SankeyLink(from: "Budget", to: "Groceries", value: 800)
            SankeyLink(from: "Budget", to: "Savings", value: 2800)
        }
    }
}
```

@Image(source: "sankey-hero", alt: "The budget diagram this code produces.")

That is the whole chart. Six nodes appeared without being declared: a link creates whichever of its
two endpoints does not exist yet. `Budget` is named by five links and still becomes one node, as
tall as the larger of what flows in and what flows out.

The columns come from the flow direction. `Salary` and `Side gig` have nothing feeding them, so
they start on the left; `Budget` sits one column further right because something feeds it; the
expenses sit one further still. A node always ends up to the right of everything that feeds it.

> Important: The flows must not form a cycle. If `A` feeds `B` and `B` feeds `A`, there is no
> left-to-right order to lay them out in. The chart then draws a short diagnostic naming the cycle
> instead of a broken diagram, and logs it to the `de.peterkurzok.SankeyKit` subsystem.

## Build from your own data

Real numbers rarely arrive as literals. ``SankeyChart/init(_:content:)`` takes a collection and
builds marks for each element, the way `Chart(data)` does in Swift Charts.

```swift
struct Flow: Identifiable {
    let id = UUID()
    var source: String
    var target: String
    var amount: Double
}

SankeyChart(flows) { flow in
    SankeyLink(
        from: .value("Source", flow.source),
        to: .value("Target", flow.target),
        value: .value("Amount", flow.amount)
    )
}
```

The ``SankeyValue/value(_:_:)`` spelling is optional — `SankeyLink(from:to:value:)` takes plain
strings and a `Double` too. What the labels buy you is accessibility: this chart tells VoiceOver
`"Amount: 4,800"` instead of just `"4,800"`.

The builder understands control flow, so conditions and loops work inline:

```swift
SankeyChart {
    for expense in expenses {
        SankeyLink(from: "Budget", to: expense.name, value: expense.amount)
    }
    if isSaving {
        SankeyLink(from: "Budget", to: "Savings", value: 2800)
    }
}
```

## Customize a node

Nodes are derived, but they are not fixed. A ``SankeyNode`` mark reaches back into a node the links
already created and changes how it looks or where it sits.

```swift
SankeyChart {
    SankeyLink(from: "Salary", to: "Budget", value: 4800)
    // …

    SankeyNode("Budget")
        .label("Monthly Budget")
        .foregroundStyle(.blue)
}
```

Giving a node a plain `Color` also changes the ribbons that touch it, because a ribbon blends from
its source node's color into its target node's color. Pass `layer:` to pin a node to a specific
column when the inferred one is not the one you want.

## Style the chart

The `sankey…` modifiers work like the `chart…` modifiers in Swift Charts: they travel through the
environment, and each one changes a single thing, so they compose.

```swift
SankeyChart { /* … */ }
    .sankeyNodeWidth(14)
    .sankeyNodeSpacing(12)
    .sankeyNodeCornerRadius(4)
    .sankeyLinkSpacing(4)
    .sankeyLinkCurvature(0.5)
    .sankeyLinkOpacity(0.8)
    .sankeyColorScale([.blue, .cyan, .teal, .green, .yellow, .orange])
```

Ribbons always leave and enter their nodes horizontally; the curvature number only says where the
bend sits between them — `0` draws a straight diagonal, `0.5` the classic S-curve, and `1` packs the
whole bend into a step halfway across.

Colors are handed to nodes column by column, top to bottom, and cycle when the diagram has more
nodes than colors. A scale ordered by hue gives the cleanest ribbons, because neighbouring nodes
then blend through neighbouring hues.

Three levels decide a fill, and the most specific wins: a style set on the mark itself, then the
color scale, then the built-in palette.

## Let people select a flow

Bind an optional ``SankeySelection`` and the chart becomes interactive. The selected element and
everything it connects to stay lit; the rest fades back.

```swift
@State private var selection: SankeySelection?

SankeyChart { /* … */ }
    .sankeySelection($selection)
```

@Image(source: "sankey-selection", alt: "The budget diagram with the Groceries node selected; unrelated nodes and ribbons are dimmed.")

Tapping a node selects `.node("Budget")`; tapping a ribbon selects
`.link(source: "Budget", target: "Rent")`. Tapping the same element again, or tapping the
background, clears it. Without the modifier the chart is read-only and lets taps pass through to
whatever is underneath.

## Animate value changes

The chart animates whatever SwiftUI tells it to animate. Change your data inside `withAnimation`
and the ribbons flow into their new shape.

```swift
Button("Save more") {
    withAnimation(.snappy) {
        savings = 2800
    }
}
```

Ribbons interpolate through their endpoints, and the curve is recomputed on every frame, so an
intermediate frame is always a real ribbon rather than a bent approximation of one.

### Driving a chart from a Toggle

Wrap the write in `withAnimation` inside a custom `Binding` setter rather than reaching for
`Binding.animation(_:)`:

```swift
Toggle("Put money aside", isOn: Binding(
    get: { showsSavings },
    set: { newValue in withAnimation(.snappy) { showsSavings = newValue } }
))
```

On iOS 27 the transaction that `Binding.animation(_:)` attaches to a `Toggle`-initiated write is
dropped: the switch thumb animates, but the chart re-lays out in a single frame. Animating in the
setter runs inside the write itself, so the transaction survives — and it behaves identically on
older releases. `Slider` and `Button` writes are unaffected, so `Binding.animation(_:)` remains the
right choice for a slider, where both the drag and keyboard adjustments should animate.

## Where to go next

The package ships a sample app under `Examples/SankeyDemo` with three screens — a budget, a
national energy balance, and a playground with live sliders. Generate and open it with:

```bash
cd Examples/SankeyDemo
xcodegen generate
open SankeyDemo.xcodeproj
```
