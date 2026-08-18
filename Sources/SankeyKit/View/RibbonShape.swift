import SwiftUI

/// Draws a single link as a closed ribbon in the chart's coordinate space.
///
/// The outline runs along the top Bézier curve from source to target, straight down the cap inside
/// the target node, back along the bottom curve, and closes up the cap inside the source node.
///
/// Both ends are extended by ``overlap`` straight into their node, so the ribbon runs *under* the
/// node capsule instead of butting against its edge. Butting against it would leave a white wedge
/// where the capsule's rounded corners curve away from the edge, plus an antialiasing hairline
/// along the shared edge; the opaque node hides everything else of the tucked-under end.
struct RibbonShape: Shape {
    var geometry: RibbonGeometry

    /// How far each end reaches horizontally into its node, in points.
    var overlap: CGFloat = 0

    /// Lets SwiftUI morph one ribbon into another when the underlying values change.
    ///
    /// ``overlap`` is deliberately not part of this: it only changes when the caller changes the
    /// node width, which re-renders anyway.
    var animatableData: AnimatableVector {
        get { AnimatableVector(geometry.animatableComponents) }
        set {
            if let interpolated = RibbonGeometry(animatableComponents: newValue.values) {
                geometry = interpolated
            }
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard geometry.startThickness > 0 || geometry.endThickness > 0 else { return path }

        let top = geometry.topCurve
        let bottom = geometry.bottomCurve

        path.move(to: CGPoint(x: top.start.x - overlap, y: top.start.y))
        path.addLine(to: top.start)
        path.addCurve(to: top.end, control1: top.control1, control2: top.control2)
        path.addLine(to: CGPoint(x: top.end.x + overlap, y: top.end.y))
        path.addLine(to: CGPoint(x: bottom.end.x + overlap, y: bottom.end.y))
        path.addLine(to: bottom.end)
        path.addCurve(to: bottom.start, control1: bottom.control2, control2: bottom.control1)
        path.addLine(to: CGPoint(x: bottom.start.x - overlap, y: bottom.start.y))
        path.closeSubpath()
        return path
    }
}
