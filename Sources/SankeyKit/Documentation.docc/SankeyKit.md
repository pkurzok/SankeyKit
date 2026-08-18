# ``SankeyKit``

Sankey diagrams for SwiftUI, written the way you write a Swift Chart.

## Overview

@Image(source: "sankey-hero", alt: "A Sankey diagram of a monthly budget: Salary and Side gig flow into Monthly Budget, which flows out to Rent, Groceries and Savings.")

A Sankey diagram shows how a quantity splits and recombines on its way from left to right: where
a salary goes, how primary energy reaches a socket, where visitors drop out of a funnel. SankeyKit
draws one from a description of the flows alone.

```swift
SankeyChart {
    SankeyLink(from: "Salary", to: "Budget", value: 4800)
    SankeyLink(from: "Side gig", to: "Budget", value: 700)
    SankeyLink(from: "Budget", to: "Rent", value: 1900)
    SankeyLink(from: "Budget", to: "Savings", value: 3600)
}
```

There is no node list, and no layout to describe. Naming a node in a link creates it, its size
follows from the flows that touch it, and its column follows from the direction they run in. Add a
``SankeyNode`` mark only when you want to change a node's color, its printed label, or the column
it sits in.

Ribbons blend from the color of the node they leave to the color of the node they enter, so a
single flow reads as one continuous band all the way across the diagram. Labels place themselves:
the first column reads outward to the left, the last outward to the right, and any column in
between sits on its own node.

### What you get

- **Marks and a result builder** — `if`, `if`/`else` and `for` work inside ``SankeyChart`` exactly
  as they do in a `ViewBuilder`.
- **A data-driven initializer** — ``SankeyChart/init(_:content:)`` builds the same chart from a
  collection, one group of marks per element.
- **Labelled values** — ``SankeyValue`` mirrors `PlottableValue`, and its labels become the
  descriptions VoiceOver reads.
- **Chart modifiers** — environment-backed and composable, from
  ``SwiftUICore/View/sankeyNodeWidth(_:)`` to ``SwiftUICore/View/sankeyColorScale(_:)``.
- **Selection** — bind a ``SankeySelection`` and a tap lights up one flow and dims the rest.
- **Animation** — change a value inside `withAnimation` and the ribbons morph instead of jumping.
- **Accessibility** — every node and every ribbon is its own element, read in column order.

### Requirements

iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, and Swift 6. Selection is driven by taps and by
accessibility activation. tvOS has no pointer, so there a chart is selectable through VoiceOver but
not by remote alone.

## Topics

### Essentials

- <doc:GettingStarted>
- ``SankeyChart``

### Marks

- ``SankeyLink``
- ``SankeyNode``
- ``SankeyValue``

### Building content

- ``SankeyContentBuilder``
- ``SankeyContent``
- ``AnySankeyContent``

### Styling

- ``SwiftUICore/View/sankeyNodeWidth(_:)``
- ``SwiftUICore/View/sankeyNodeSpacing(_:)``
- ``SwiftUICore/View/sankeyNodeCornerRadius(_:)``
- ``SwiftUICore/View/sankeyLinkSpacing(_:)``
- ``SwiftUICore/View/sankeyLinkCurvature(_:)``
- ``SwiftUICore/View/sankeyLinkOpacity(_:)``
- ``SwiftUICore/View/sankeyColorScale(_:)``

### Interaction

- ``SwiftUICore/View/sankeySelection(_:)``
- ``SankeySelection``
