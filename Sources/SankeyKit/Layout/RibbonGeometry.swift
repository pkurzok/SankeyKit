import CoreGraphics

/// The geometry of a single link ribbon: where it starts, where it ends, how thick it is and
/// how strongly it bends.
///
/// A ribbon is drawn as two cubic Bézier curves — one along the top edge, one along the bottom —
/// joined by straight vertical caps at the two nodes.
struct RibbonGeometry: Equatable, Sendable {
    /// Center of the ribbon where it leaves the source node (the node's trailing edge).
    var start: CGPoint
    /// Center of the ribbon where it enters the target node (the node's leading edge).
    var end: CGPoint
    /// Vertical thickness of the ribbon, proportional to the link value.
    var thickness: CGFloat
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
    var topCurve: Curve { curve(offsetBy: -thickness / 2) }

    /// The cubic curve along the bottom edge of the ribbon.
    var bottomCurve: Curve { curve(offsetBy: thickness / 2) }

    private func curve(offsetBy dy: CGFloat) -> Curve {
        let (first, second) = controlPoints
        return Curve(
            start: CGPoint(x: start.x, y: start.y + dy),
            control1: CGPoint(x: first.x, y: first.y + dy),
            control2: CGPoint(x: second.x, y: second.y + dy),
            end: CGPoint(x: end.x, y: end.y + dy)
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
    /// The nine scalars that fully describe the ribbon, for interpolation during animation:
    /// start, end, both control points and the thickness.
    var animatableComponents: [CGFloat] {
        let (first, second) = controlPoints
        return [start.x, start.y, first.x, first.y, second.x, second.y, end.x, end.y, thickness]
    }
}
