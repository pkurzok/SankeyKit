import CoreGraphics

/// The geometry of a single link ribbon: where it starts, where it ends, how thick it is at each
/// end and how strongly it bends.
///
/// A ribbon is drawn as two cubic Bézier curves — one along the top edge, one along the bottom —
/// joined by straight vertical caps at the two nodes.
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
    /// How far the control points travel along the connection, `0`–`1`.
    var curvature: Double

    /// The smallest horizontal control-point offset. Keeps the curve bending immediately at the
    /// node edge even when two columns nearly touch or overlap.
    static let minimumControlOffset: CGFloat = 24

    /// Horizontal distance used to place the control points.
    var controlOffset: CGFloat {
        max(Self.minimumControlOffset, end.x - start.x)
    }

    /// The two control points of the center curve.
    var controlPoints: (first: CGPoint, second: CGPoint) {
        let offset = controlOffset
        let factor = CGFloat(curvature)
        let rise = end.y - start.y
        return (
            CGPoint(x: start.x + offset * factor, y: start.y + rise * factor),
            CGPoint(x: end.x - offset * factor, y: end.y - rise * factor)
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
    /// The ten scalars that fully describe the ribbon, for interpolation during animation:
    /// start, end, both control points and the two thicknesses.
    var animatableComponents: [CGFloat] {
        let (first, second) = controlPoints
        return [
            start.x, start.y,
            first.x, first.y,
            second.x, second.y,
            end.x, end.y,
            startThickness, endThickness
        ]
    }
}
