import CoreGraphics

/// The geometry of a single link ribbon: where it starts, where it ends, how thick it is at each
/// end and how strongly it bends.
///
/// A ribbon is drawn as two cubic Bézier curves — one along the top edge, one along the bottom —
/// joined by straight vertical caps at the two nodes.
///
/// A ribbon leaves its source node and enters its target node horizontally: both control points
/// stay level with the endpoint they belong to, so the curve meets each node edge at a right angle
/// and does all of its bending in between.
///
/// The two ends can differ in thickness. A node inserts a small gap between the ribbons attached
/// to it (see ``SankeyMetrics/linkSpacing``), and how much of the node edge that consumes depends
/// on how many ribbons meet there. A ribbon therefore tapers slightly from one end to the other.
struct RibbonGeometry: Equatable, Sendable {
    /// Center of the ribbon where it leaves the source node (the node's trailing edge).
    var start: CGPoint
    /// Center of the ribbon where it enters the target node (the node's leading edge).
    var end: CGPoint
    /// Vertical thickness at the source node.
    var startThickness: CGFloat
    /// Vertical thickness at the target node.
    var endThickness: CGFloat
    /// How far the control points travel *horizontally* along the connection, `0`–`1`.
    ///
    /// `0` leaves them on the endpoints and draws a straight diagonal; `0.5` puts them on the
    /// horizontal midpoint; `1` sends each one all the way to the opposite end.
    var curvature: Double

    /// The smallest horizontal control-point offset. Keeps the curve bending immediately at the
    /// node edge even when two columns nearly touch or overlap.
    static let minimumControlOffset: CGFloat = 24

    /// Horizontal distance used to place the control points.
    var controlOffset: CGFloat {
        max(Self.minimumControlOffset, end.x - start.x)
    }

    /// The two control points of the center curve.
    ///
    /// Each control point keeps its endpoint's `y` and only travels horizontally, which is what
    /// gives the ribbon its flat tangent at both nodes. At the default curvature of `0.5` both
    /// land on the horizontal midpoint of the connection, making the curve `d3-shape`'s `bumpX`.
    var controlPoints: (first: CGPoint, second: CGPoint) {
        let offset = controlOffset
        let factor = CGFloat(curvature)
        return (
            CGPoint(x: start.x + offset * factor, y: start.y),
            CGPoint(x: end.x - offset * factor, y: end.y)
        )
    }

    /// The cubic curve along the top edge of the ribbon.
    var topCurve: Curve { curve(direction: -1) }

    /// The cubic curve along the bottom edge of the ribbon.
    var bottomCurve: Curve { curve(direction: 1) }

    private func curve(direction: CGFloat) -> Curve {
        let (first, second) = controlPoints
        let atStart = direction * startThickness / 2
        let atEnd = direction * endThickness / 2
        return Curve(
            start: CGPoint(x: start.x, y: start.y + atStart),
            control1: CGPoint(x: first.x, y: first.y + atStart),
            control2: CGPoint(x: second.x, y: second.y + atEnd),
            end: CGPoint(x: end.x, y: end.y + atEnd)
        )
    }

    /// One cubic Bézier segment.
    struct Curve: Equatable, Sendable {
        var start: CGPoint
        var control1: CGPoint
        var control2: CGPoint
        var end: CGPoint
    }
}

extension RibbonGeometry {
    /// The seven scalars that fully describe the ribbon, for interpolation during animation.
    ///
    /// The control points are deliberately *not* part of this list. They are recomputed from the
    /// interpolated endpoints on every frame, which keeps every intermediate frame a proper
    /// S-curve instead of letting the curve and its endpoints drift apart.
    var animatableComponents: [CGFloat] {
        [start.x, start.y, end.x, end.y, startThickness, endThickness, CGFloat(curvature)]
    }

    /// The number of scalars ``animatableComponents`` produces.
    static let componentCount = 7

    /// Rebuilds a ribbon from interpolated components.
    ///
    /// - Parameter components: A list produced by ``animatableComponents``. A list of any other
    ///   length is ignored and leaves the ribbon unchanged, so a malformed animation can never trap.
    init?(animatableComponents components: [CGFloat]) {
        guard components.count == Self.componentCount else { return nil }
        self.init(
            start: CGPoint(x: components[0], y: components[1]),
            end: CGPoint(x: components[2], y: components[3]),
            startThickness: max(0, components[4]),
            endThickness: max(0, components[5]),
            curvature: Double(components[6])
        )
    }
}
