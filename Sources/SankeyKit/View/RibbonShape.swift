import SwiftUI

/// Draws a single link as a closed ribbon in the chart's coordinate space.
///
/// The outline runs along the top Bézier curve from source to target, straight down the target
/// node's leading edge, back along the bottom curve, and closes up the source node's trailing edge.
struct RibbonShape: Shape {
    var geometry: RibbonGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard geometry.startThickness > 0 || geometry.endThickness > 0 else { return path }

        let top = geometry.topCurve
        let bottom = geometry.bottomCurve

        path.move(to: top.start)
        path.addCurve(to: top.end, control1: top.control1, control2: top.control2)
        path.addLine(to: bottom.end)
        path.addCurve(to: bottom.start, control1: bottom.control2, control2: bottom.control1)
        path.closeSubpath()
        return path
    }
}
