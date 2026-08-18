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
        let inset = Self.labelInset(for: size)
        let layout = SankeyLayout.compute(
            graph: graph,
            size: size,
            metrics: metrics,
            horizontalInset: inset
        )
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
                overlap: metrics.nodeWidth / 2,
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
                outerSlotWidth: max(0, inset - NodeLabel.gap),
                innerSlotWidth: Self.innerSlotWidth(
                    size: size,
                    inset: inset,
                    layerCount: layout.layerCount,
                    metrics: metrics
                )
            )
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(selection != nil)
        .animation(.snappy, value: selection?.wrappedValue)
    }

    /// Room reserved on each side for the labels of the first and last column.
    ///
    /// The text width is not known until it is laid out, so the diagram reserves room rather than
    /// measuring. Label text does not grow with the canvas, so this is mostly a constant — a floor
    /// wide enough for a word or two, a ceiling so a wide chart does not waste half its width, and
    /// a share-of-width cap so a narrow one still has a diagram left in the middle.
    static func labelInset(for size: CGSize) -> CGFloat {
        let width = max(0, size.width)
        return min(min(max(64, width * 0.12), 140), width * 0.22)
    }

    /// Room a label between the outer columns may use, bounded by the gap between two columns.
    static func innerSlotWidth(
        size: CGSize,
        inset: CGFloat,
        layerCount: Int,
        metrics: SankeyMetrics
    ) -> CGFloat {
        guard layerCount > 1 else { return min(160, max(0, size.width)) }
        let stride = (size.width - 2 * inset - metrics.nodeWidth) / CGFloat(layerCount - 1)
        return min(max(stride - NodeLabel.gap, 32), 160)
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
    /// How far each ribbon end tucks under its node, hiding the seam at the node's rounded corners.
    var overlap: CGFloat
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

            RibbonShape(geometry: laidOut.geometry, overlap: overlap)
                .fill(resolver.shapeStyle(for: fill, spanning: laidOut.geometry))
                .opacity(resolver.linkOpacity(laidOut, default: opacity) * SankeyDiagram.dimming(isRelated))
                // Without this the ribbon would swallow taps across the whole canvas.
                .contentShape(RibbonShape(geometry: laidOut.geometry, overlap: overlap))
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
struct LabelLayer: View {
    var layout: SankeyLayoutResult
    var highlight: SankeyHighlight?
    /// Room for the labels of the first and last column, which sit outside the diagram.
    var outerSlotWidth: CGFloat
    /// Room for the labels in between, which sit on top of their node.
    var innerSlotWidth: CGFloat

    var body: some View {
        ForEach(layout.nodes) { node in
            let placement = Self.placement(for: node, layerCount: layout.layerCount)
            NodeLabel(
                node: node,
                placement: placement,
                slotWidth: placement == .over ? innerSlotWidth : outerSlotWidth
            )
            .opacity(SankeyDiagram.dimming(highlight?.contains(node: node.id) ?? true))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The first column reads outward to the left, the last outward to the right, and anything in
    /// between has no free margin to use, so it sits on its own node.
    static func placement(for node: LaidOutNode, layerCount: Int) -> NodeLabel.Placement {
        if node.layer == 0 { return .leading }
        if node.layer == layerCount - 1 { return .trailing }
        return .over
    }
}
