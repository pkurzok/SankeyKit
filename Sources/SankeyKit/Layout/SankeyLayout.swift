import CoreGraphics

/// The tunable numbers of a Sankey diagram.
///
/// Every value has a chart modifier counterpart, for example ``SwiftUICore/View/sankeyNodeWidth(_:)``.
struct SankeyMetrics: Equatable, Sendable {
    /// Width of a node rectangle in points.
    var nodeWidth: CGFloat = 12
    /// Vertical gap between two stacked nodes in points.
    var nodeSpacing: CGFloat = 8
    /// Corner radius of a node rectangle in points.
    var cornerRadius: CGFloat = 3
    /// How strongly ribbons bend, `0` (straight) to `1` (maximum).
    var curvature: Double = 0.5
    /// Default opacity of a ribbon, `0`–`1`.
    var linkOpacity: Double = 0.75

    static let `default` = SankeyMetrics()
}

/// A node placed on the canvas.
struct LaidOutNode: Identifiable, Sendable {
    var id: String
    var node: ResolvedNode
    var frame: CGRect
    var layer: Int
    /// Position within the layer, top to bottom, starting at zero.
    var indexInLayer: Int
    /// Position in overall `(layer, y)` order — the index used for color-scale cycling.
    var paletteIndex: Int
}

/// A link placed on the canvas.
struct LaidOutLink: Identifiable, Sendable {
    var id: LinkID
    var link: ResolvedLink
    var geometry: RibbonGeometry
}

/// Pure geometry, ready to be turned into shapes. Contains no view types.
struct SankeyLayoutResult: Sendable {
    /// Nodes in `(layer, y)` order.
    var nodes: [LaidOutNode] = []
    /// Links in declaration order.
    var links: [LaidOutLink] = []
    /// Frames by node id, for hit testing and label placement.
    var nodeFrames: [String: CGRect] = [:]
    /// The number of layers the diagram was laid out with.
    var layerCount: Int = 0

    var isEmpty: Bool { nodes.isEmpty }
}

/// Turns a validated ``SankeyGraph`` into plain geometry.
enum SankeyLayout {
    /// Computes node frames and ribbon geometry for the given canvas size.
    ///
    /// The vertical scale is chosen so that the busiest layer exactly fills the available height
    /// minus the spacing between its nodes. All other layers use the same scale, which is what
    /// makes ribbon thickness comparable across the whole diagram.
    static func compute(
        graph: SankeyGraph,
        size: CGSize,
        metrics: SankeyMetrics = .default
    ) -> SankeyLayoutResult {
        guard !graph.isEmpty, size.width > 0, size.height > 0 else { return SankeyLayoutResult() }

        let buckets = graph.nodesByLayer()
        let layerCount = buckets.count
        guard layerCount > 0 else { return SankeyLayoutResult() }

        let scale = verticalScale(buckets: buckets, height: size.height, spacing: metrics.nodeSpacing)
        let frames = nodeFrames(buckets: buckets, size: size, metrics: metrics, scale: scale)

        var laidOutNodes: [LaidOutNode] = []
        laidOutNodes.reserveCapacity(graph.nodes.count)
        var frameByID: [String: CGRect] = [:]
        var paletteIndex = 0
        for (layer, bucket) in buckets.enumerated() {
            for (indexInLayer, node) in bucket.enumerated() {
                let frame = frames[node.id] ?? .zero
                frameByID[node.id] = frame
                laidOutNodes.append(
                    LaidOutNode(
                        id: node.id,
                        node: node,
                        frame: frame,
                        layer: layer,
                        indexInLayer: indexInLayer,
                        paletteIndex: paletteIndex
                    )
                )
                paletteIndex += 1
            }
        }

        let ribbons = ribbonGeometry(
            graph: graph,
            frames: frameByID,
            scale: scale,
            curvature: metrics.curvature
        )

        return SankeyLayoutResult(
            nodes: laidOutNodes,
            links: ribbons,
            nodeFrames: frameByID,
            layerCount: layerCount
        )
    }

    /// Points per unit of value. Driven by the layer that needs the most vertical room.
    private static func verticalScale(
        buckets: [[ResolvedNode]],
        height: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        var scale = CGFloat.greatestFiniteMagnitude
        for bucket in buckets {
            let total = bucket.reduce(0) { $0 + $1.magnitude }
            guard total > 0 else { continue }
            let available = height - spacing * CGFloat(bucket.count - 1)
            scale = min(scale, max(0, available) / CGFloat(total))
        }
        return scale == .greatestFiniteMagnitude ? 0 : scale
    }

    private static func nodeFrames(
        buckets: [[ResolvedNode]],
        size: CGSize,
        metrics: SankeyMetrics,
        scale: CGFloat
    ) -> [String: CGRect] {
        let layerCount = buckets.count
        let span = max(0, size.width - metrics.nodeWidth)
        var frames: [String: CGRect] = [:]

        for (layer, bucket) in buckets.enumerated() {
            let originX = layerCount > 1 ? span * CGFloat(layer) / CGFloat(layerCount - 1) : 0
            var originY: CGFloat = 0
            for node in bucket {
                let height = max(Self.minimumNodeHeight, CGFloat(node.magnitude) * scale)
                frames[node.id] = CGRect(x: originX, y: originY, width: metrics.nodeWidth, height: height)
                originY += height + metrics.nodeSpacing
            }
        }
        return frames
    }

    /// Stacks ribbons at both of their endpoints and builds the resulting geometry.
    ///
    /// At each node the attached ribbons are ordered by the vertical position of the node on the
    /// other end. That single heuristic removes most avoidable crossings.
    private static func ribbonGeometry(
        graph: SankeyGraph,
        frames: [String: CGRect],
        scale: CGFloat,
        curvature: Double
    ) -> [LaidOutLink] {
        var startY: [LinkID: CGFloat] = [:]
        var endY: [LinkID: CGFloat] = [:]

        for node in graph.nodes {
            guard let frame = frames[node.id] else { continue }

            var used: CGFloat = 0
            let outgoing = graph.outgoingLinks(of: node.id).sorted {
                (frames[$0.targetID]?.midY ?? 0, $0.targetID) < (frames[$1.targetID]?.midY ?? 0, $1.targetID)
            }
            for link in outgoing {
                let thickness = CGFloat(link.value) * scale
                startY[link.id] = frame.minY + used + thickness / 2
                used += thickness
            }

            used = 0
            let incoming = graph.incomingLinks(of: node.id).sorted {
                (frames[$0.sourceID]?.midY ?? 0, $0.sourceID) < (frames[$1.sourceID]?.midY ?? 0, $1.sourceID)
            }
            for link in incoming {
                let thickness = CGFloat(link.value) * scale
                endY[link.id] = frame.minY + used + thickness / 2
                used += thickness
            }
        }

        return graph.links.compactMap { link in
            guard
                let sourceFrame = frames[link.sourceID],
                let targetFrame = frames[link.targetID],
                let top = startY[link.id],
                let bottom = endY[link.id]
            else { return nil }

            let geometry = RibbonGeometry(
                start: CGPoint(x: sourceFrame.maxX, y: top),
                end: CGPoint(x: targetFrame.minX, y: bottom),
                thickness: CGFloat(link.value) * scale,
                curvature: curvature
            )
            return LaidOutLink(id: link.id, link: link, geometry: geometry)
        }
    }

    /// Nodes never collapse to an invisible sliver.
    static let minimumNodeHeight: CGFloat = 2
}
