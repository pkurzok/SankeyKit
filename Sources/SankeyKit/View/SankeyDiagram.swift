import SwiftUI

/// Draws one laid-out Sankey graph into a canvas of a known size.
///
/// Everything here is a pure function of the graph, the size and the metrics — the view holds no
/// state of its own, which is what lets ``SankeyChart`` recompute it on every geometry change.
struct SankeyDiagram: View {
    var graph: SankeyGraph
    var size: CGSize
    var metrics: SankeyMetrics
    var scale: [Color]?

    var body: some View {
        let layout = SankeyLayout.compute(graph: graph, size: size, metrics: metrics)
        let resolver = SankeyStyleResolver(scale: scale, canvasSize: size)

        ZStack(alignment: .topLeading) {
            RibbonLayer(layout: layout, resolver: resolver, opacity: metrics.linkOpacity)
            NodeLayer(layout: layout, resolver: resolver, cornerRadius: metrics.cornerRadius)
            LabelLayer(layout: layout, slotWidth: Self.labelSlotWidth(
                size: size,
                layerCount: layout.layerCount,
                metrics: metrics
            ))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Horizontal room a label may use: the gap between two columns, within sensible bounds.
    static func labelSlotWidth(size: CGSize, layerCount: Int, metrics: SankeyMetrics) -> CGFloat {
        guard layerCount > 1 else { return max(0, size.width - metrics.nodeWidth - NodeLabel.gap) }
        let stride = (size.width - metrics.nodeWidth) / CGFloat(layerCount - 1)
        let room = stride - metrics.nodeWidth - 2 * NodeLabel.gap
        return min(max(room, 32), 160)
    }
}

/// All link ribbons, drawn below the nodes.
private struct RibbonLayer: View {
    var layout: SankeyLayoutResult
    var resolver: SankeyStyleResolver
    var opacity: Double

    var body: some View {
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        ForEach(layout.links) { laidOut in
            let fill = resolver.linkFill(
                laidOut,
                from: nodesByID[laidOut.id.source],
                to: nodesByID[laidOut.id.target]
            )
            RibbonShape(geometry: laidOut.geometry)
                .fill(resolver.shapeStyle(for: fill, spanning: laidOut.geometry))
                .opacity(resolver.linkOpacity(laidOut, default: opacity))
        }
    }
}

/// All node rectangles, drawn above the ribbons.
private struct NodeLayer: View {
    var layout: SankeyLayoutResult
    var resolver: SankeyStyleResolver
    var cornerRadius: CGFloat

    var body: some View {
        ForEach(layout.nodes) { node in
            NodeShape(frame: node.frame, cornerRadius: cornerRadius)
                .fill(resolver.shapeStyle(for: resolver.nodeFill(node)))
        }
    }
}

/// All node labels, drawn on top.
private struct LabelLayer: View {
    var layout: SankeyLayoutResult
    var slotWidth: CGFloat

    var body: some View {
        ForEach(layout.nodes) { node in
            NodeLabel(
                node: node,
                isTrailingColumn: node.layer == layout.layerCount - 1,
                slotWidth: slotWidth
            )
        }
    }
}
