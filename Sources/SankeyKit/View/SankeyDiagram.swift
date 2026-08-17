import SwiftUI

/// Draws one laid-out Sankey graph into a canvas of a known size.
///
/// Everything here is a pure function of the graph, the size, the metrics and the selection — the
/// view holds no state of its own, which is what lets ``SankeyChart`` recompute it on every
/// geometry change.
struct SankeyDiagram: View {
    var graph: SankeyGraph
    var size: CGSize
    var metrics: SankeyMetrics
    var scale: [Color]?
    var selection: Binding<SankeySelection?>?

    /// How far an element unrelated to the selection fades.
    static let dimmedOpacity: Double = 0.25

    var body: some View {
        let layout = SankeyLayout.compute(graph: graph, size: size, metrics: metrics)
        let resolver = SankeyStyleResolver(scale: scale, canvasSize: size)
        let highlight = SankeyHighlight.related(to: selection?.wrappedValue, in: graph)

        ZStack(alignment: .topLeading) {
            // Tapping empty canvas clears the selection.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selection?.wrappedValue = nil }
                .accessibilityHidden(true)

            RibbonLayer(
                layout: layout,
                resolver: resolver,
                opacity: metrics.linkOpacity,
                highlight: highlight,
                selection: selection
            )
            NodeLayer(
                layout: layout,
                resolver: resolver,
                cornerRadius: metrics.cornerRadius,
                highlight: highlight,
                selection: selection
            )
            LabelLayer(
                layout: layout,
                highlight: highlight,
                slotWidth: Self.labelSlotWidth(size: size, layerCount: layout.layerCount, metrics: metrics)
            )
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(selection != nil)
        .animation(.snappy, value: selection?.wrappedValue)
    }

    /// Horizontal room a label may use: the gap between two columns, within sensible bounds.
    static func labelSlotWidth(size: CGSize, layerCount: Int, metrics: SankeyMetrics) -> CGFloat {
        guard layerCount > 1 else { return max(0, size.width - metrics.nodeWidth - NodeLabel.gap) }
        let stride = (size.width - metrics.nodeWidth) / CGFloat(layerCount - 1)
        let room = stride - metrics.nodeWidth - 2 * NodeLabel.gap
        return min(max(room, 32), 160)
    }

    /// Selecting the element that is already selected clears the selection.
    static func toggle(_ value: SankeySelection, in selection: Binding<SankeySelection?>?) {
        guard let selection else { return }
        selection.wrappedValue = selection.wrappedValue == value ? nil : value
    }

    /// The opacity multiplier an element gets from the current selection.
    static func dimming(_ isRelated: Bool) -> Double {
        isRelated ? 1 : dimmedOpacity
    }
}

/// All link ribbons, drawn below the nodes.
private struct RibbonLayer: View {
    var layout: SankeyLayoutResult
    var resolver: SankeyStyleResolver
    var opacity: Double
    var highlight: SankeyHighlight?
    var selection: Binding<SankeySelection?>?

    var body: some View {
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        ForEach(layout.links) { laidOut in
            let source = nodesByID[laidOut.id.source]
            let target = nodesByID[laidOut.id.target]
            let fill = resolver.linkFill(laidOut, from: source, to: target)
            let value = SankeySelection.link(source: laidOut.id.source, target: laidOut.id.target)
            let isRelated = highlight?.contains(link: laidOut.id) ?? true

            RibbonShape(geometry: laidOut.geometry)
                .fill(resolver.shapeStyle(for: fill, spanning: laidOut.geometry))
                .opacity(resolver.linkOpacity(laidOut, default: opacity) * SankeyDiagram.dimming(isRelated))
                // Without this the ribbon would swallow taps across the whole canvas.
                .contentShape(RibbonShape(geometry: laidOut.geometry))
                .onTapGesture { SankeyDiagram.toggle(value, in: selection) }
                .sankeyLinkAccessibility(
                    laidOut,
                    from: source,
                    to: target,
                    isSelected: selection?.wrappedValue == value,
                    sortPriority: -1
                )
        }
    }
}

/// All node rectangles, drawn above the ribbons.
private struct NodeLayer: View {
    var layout: SankeyLayoutResult
    var resolver: SankeyStyleResolver
    var cornerRadius: CGFloat
    var highlight: SankeyHighlight?
    var selection: Binding<SankeySelection?>?

    var body: some View {
        ForEach(layout.nodes) { node in
            let shape = NodeShape(frame: node.frame, cornerRadius: cornerRadius)
            let value = SankeySelection.node(node.id)
            let isRelated = highlight?.contains(node: node.id) ?? true

            shape
                .fill(resolver.shapeStyle(for: resolver.nodeFill(node)))
                .opacity(SankeyDiagram.dimming(isRelated))
                .contentShape(shape)
                .onTapGesture { SankeyDiagram.toggle(value, in: selection) }
                .sankeyNodeAccessibility(
                    node,
                    isSelected: selection?.wrappedValue == value,
                    sortPriority: Double(layout.nodes.count - node.paletteIndex)
                )
        }
    }
}

/// All node labels, drawn on top. The node element already announces the label, so the text itself
/// is hidden from assistive technologies.
private struct LabelLayer: View {
    var layout: SankeyLayoutResult
    var highlight: SankeyHighlight?
    var slotWidth: CGFloat

    var body: some View {
        ForEach(layout.nodes) { node in
            NodeLabel(
                node: node,
                isTrailingColumn: node.layer == layout.layerCount - 1,
                slotWidth: slotWidth
            )
            .opacity(SankeyDiagram.dimming(highlight?.contains(node: node.id) ?? true))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
