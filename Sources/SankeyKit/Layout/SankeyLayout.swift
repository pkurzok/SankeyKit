import CoreGraphics

/// The tunable numbers of a Sankey diagram.
///
/// Every value has a chart modifier counterpart, for example ``SwiftUICore/View/sankeyNodeWidth(_:)``.
/// The properties clamp themselves on assignment, so a caller cannot push the layout into a state
/// it has no sensible answer for.
struct SankeyMetrics: Equatable, Sendable {
    /// Width of a node rectangle in points. Never negative.
    var nodeWidth: CGFloat = 12 { didSet { nodeWidth = max(0, nodeWidth) } }
    /// Vertical gap between two stacked nodes in points. Never negative.
    var nodeSpacing: CGFloat = 8 { didSet { nodeSpacing = max(0, nodeSpacing) } }
    /// Vertical gap between two ribbons where they meet the same node, in points.
    ///
    /// The gap is taken out of the node edge the ribbons share, so a ribbon can be a little
    /// thinner at a busy node than at a quiet one. Never negative.
    var linkSpacing: CGFloat = 3 { didSet { linkSpacing = max(0, linkSpacing) } }
    /// Corner radius of a node rectangle in points. Never negative.
    var cornerRadius: CGFloat = 3 { didSet { cornerRadius = max(0, cornerRadius) } }
    /// How strongly ribbons bend, `0` (straight) to `1` (maximum).
    var curvature: Double = 0.5 { didSet { curvature = min(max(curvature, 0), 1) } }
    /// Default opacity of a ribbon, `0`–`1`.
    var linkOpacity: Double = 0.75 { didSet { linkOpacity = min(max(linkOpacity, 0), 1) } }

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

        let ribbons = ribbonGeometry(graph: graph, frames: frameByID, scale: scale, metrics: metrics)

        return SankeyLayoutResult(
            nodes: laidOutNodes,
            links: ribbons,
            nodeFrames: frameByID,
            layerCount: layerCount
        )
    }

    /// The gap actually used between the nodes of one layer.
    ///
    /// A crowded column would otherwise ask for more spacing than the canvas is tall, leaving no
    /// room for the nodes themselves. The gaps never take more than half of the height.
    static func effectiveNodeSpacing(count: Int, height: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        return min(spacing, height / 2 / CGFloat(count - 1))
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
            let gap = effectiveNodeSpacing(count: bucket.count, height: height, spacing: spacing)
            let available = height - gap * CGFloat(bucket.count - 1)
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
            let gap = effectiveNodeSpacing(count: bucket.count, height: size.height, spacing: metrics.nodeSpacing)
            var originY: CGFloat = 0
            for node in bucket {
                let height = max(Self.minimumNodeHeight, CGFloat(node.magnitude) * scale)
                frames[node.id] = CGRect(x: originX, y: originY, width: metrics.nodeWidth, height: height)
                originY += height + gap
            }
        }
        return frames
    }

    /// Where a ribbon meets a node: the vertical center and the thickness it has there.
    private struct Attachment {
        var center: CGFloat
        var thickness: CGFloat
    }

    /// Stacks ribbons at both of their endpoints and builds the resulting geometry.
    ///
    /// At each node the attached ribbons are ordered by the vertical position of the node on the
    /// other end. That single heuristic removes most avoidable crossings.
    private static func ribbonGeometry(
        graph: SankeyGraph,
        frames: [String: CGRect],
        scale: CGFloat,
        metrics: SankeyMetrics
    ) -> [LaidOutLink] {
        var sourceSide: [LinkID: Attachment] = [:]
        var targetSide: [LinkID: Attachment] = [:]

        for node in graph.nodes {
            guard let frame = frames[node.id] else { continue }

            let outgoing = graph.outgoingLinks(of: node.id).sorted {
                (frames[$0.targetID]?.midY ?? 0, $0.targetID) < (frames[$1.targetID]?.midY ?? 0, $1.targetID)
            }
            stack(outgoing, at: frame, scale: scale, spacing: metrics.linkSpacing, into: &sourceSide)

            let incoming = graph.incomingLinks(of: node.id).sorted {
                (frames[$0.sourceID]?.midY ?? 0, $0.sourceID) < (frames[$1.sourceID]?.midY ?? 0, $1.sourceID)
            }
            stack(incoming, at: frame, scale: scale, spacing: metrics.linkSpacing, into: &targetSide)
        }

        return graph.links.compactMap { link in
            guard
                let sourceFrame = frames[link.sourceID],
                let targetFrame = frames[link.targetID],
                let from = sourceSide[link.id],
                let to = targetSide[link.id]
            else { return nil }

            let geometry = RibbonGeometry(
                start: CGPoint(x: sourceFrame.maxX, y: from.center),
                end: CGPoint(x: targetFrame.minX, y: to.center),
                startThickness: from.thickness,
                endThickness: to.thickness,
                curvature: metrics.curvature
            )
            return LaidOutLink(id: link.id, link: link, geometry: geometry)
        }
    }

    /// Distributes one side of a node among the ribbons attached to it.
    ///
    /// The ribbons together span `total · scale` points — the same extent they would have without
    /// gaps — so a node's two sides stay proportional to its in- and outflow. The gaps are taken
    /// out of that extent rather than added to it, which keeps the stack inside the node.
    private static func stack(
        _ links: [ResolvedLink],
        at frame: CGRect,
        scale: CGFloat,
        spacing: CGFloat,
        into attachments: inout [LinkID: Attachment]
    ) {
        guard !links.isEmpty else { return }
        let total = links.reduce(0) { $0 + $1.value }
        guard total > 0 else { return }

        let extent = CGFloat(total) * scale
        let gaps = spacing * CGFloat(links.count - 1)
        // Never let the gaps eat more than half of the available extent.
        let usableGaps = min(gaps, extent / 2)
        let available = extent - usableGaps
        let gap = links.count > 1 ? usableGaps / CGFloat(links.count - 1) : 0

        var offset = frame.minY
        for link in links {
            let thickness = CGFloat(link.value / total) * available
            attachments[link.id] = Attachment(center: offset + thickness / 2, thickness: thickness)
            offset += thickness + gap
        }
    }

    /// Nodes never collapse to an invisible sliver.
    static let minimumNodeHeight: CGFloat = 2
}
