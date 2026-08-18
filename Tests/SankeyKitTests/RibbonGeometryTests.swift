import CoreGraphics
@testable import SankeyKit
import Testing

@Suite("Ribbon geometry")
struct RibbonGeometryTests {
    private func ribbon(
        from start: CGPoint,
        to end: CGPoint,
        thickness: CGFloat = 10,
        endThickness: CGFloat? = nil,
        curvature: Double = 0.5
    ) -> RibbonGeometry {
        RibbonGeometry(
            start: start,
            end: end,
            startThickness: thickness,
            endThickness: endThickness ?? thickness,
            curvature: curvature
        )
    }

    @Test("Control points keep their endpoint's y, as in d3-shape's bumpX")
    func controlPointFormula() {
        let geometry = ribbon(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80), curvature: 0.5)
        let (first, second) = geometry.controlPoints
        // dx = 100, v = 0.5
        #expect(first == CGPoint(x: 60, y: 20))
        #expect(second == CGPoint(x: 60, y: 80))
    }

    @Test("Both ends leave their node horizontally")
    func horizontalTangents() {
        let geometry = ribbon(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 60),
            thickness: 20,
            endThickness: 10
        )
        #expect(geometry.topCurve.control1.y == geometry.topCurve.start.y)
        #expect(geometry.topCurve.control2.y == geometry.topCurve.end.y)
        #expect(geometry.bottomCurve.control1.y == geometry.bottomCurve.start.y)
        #expect(geometry.bottomCurve.control2.y == geometry.bottomCurve.end.y)
    }

    @Test("The default curvature matches d3-shape's bumpX")
    func defaultCurvatureMatchesBumpX() {
        let geometry = ribbon(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 100))
        let (first, second) = geometry.controlPoints
        // bumpX emits bezierCurveTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1).
        #expect(first == CGPoint(x: 100, y: 0))
        #expect(second == CGPoint(x: 100, y: 100))
    }

    @Test("A sloped ribbon's control points never coincide")
    func slopedControlPointsAreDistinct() {
        let geometry = ribbon(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80))
        #expect(geometry.controlPoints.first != geometry.controlPoints.second)
    }

    @Test("The curve is symmetric about the middle of the connection")
    func curvePassesThroughTheMidpoint() {
        let geometry = ribbon(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80))
        let (first, second) = geometry.controlPoints
        let middle = cubic(
            at: 0.5,
            geometry.start,
            first,
            second,
            geometry.end
        )
        #expect(abs(middle.x - 60) < 1e-9)
        #expect(abs(middle.y - 50) < 1e-9)
    }

    /// Evaluates a cubic Bézier at `t`, for checking the shape the control points describe.
    private func cubic(
        at t: CGFloat,
        _ p0: CGPoint,
        _ p1: CGPoint,
        _ p2: CGPoint,
        _ p3: CGPoint
    ) -> CGPoint {
        let u = 1 - t
        let weights = [u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t]
        let points = [p0, p1, p2, p3]
        return zip(weights, points).reduce(into: CGPoint.zero) { result, pair in
            result.x += pair.0 * pair.1.x
            result.y += pair.0 * pair.1.y
        }
    }

    @Test("The horizontal control offset is clamped for close or overlapping columns")
    func controlOffsetIsClamped() {
        let close = ribbon(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 5, y: 0))
        #expect(close.controlOffset == RibbonGeometry.minimumControlOffset)

        let overlapping = ribbon(from: CGPoint(x: 100, y: 0), to: CGPoint(x: 40, y: 0))
        #expect(overlapping.controlOffset == RibbonGeometry.minimumControlOffset)

        let wide = ribbon(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 300, y: 0))
        #expect(wide.controlOffset == 300)
    }

    @Test("Zero curvature collapses the control points onto the endpoints")
    func zeroCurvature() {
        let geometry = ribbon(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 40), curvature: 0)
        let (first, second) = geometry.controlPoints
        #expect(first == geometry.start)
        #expect(second == geometry.end)
    }

    @Test("Higher curvature pushes the control points further along the connection")
    func curvatureIncreasesOffset() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 100, y: 40)
        let gentle = ribbon(from: start, to: end, curvature: 0.45)
        let strong = ribbon(from: start, to: end, curvature: 0.6)
        #expect(strong.controlPoints.first.x > gentle.controlPoints.first.x)
        #expect(strong.controlPoints.second.x < gentle.controlPoints.second.x)
        // Control points never travel past the opposite endpoint, so the curve cannot overshoot.
        #expect(strong.controlPoints.first.x <= end.x)
        #expect(strong.controlPoints.second.x >= start.x)
    }

    @Test("The two edge curves are the center curve offset by half the thickness")
    func edgeCurvesAreOffsetByHalfTheThickness() {
        let geometry = ribbon(from: CGPoint(x: 0, y: 50), to: CGPoint(x: 100, y: 50), thickness: 20)
        #expect(geometry.topCurve.start == CGPoint(x: 0, y: 40))
        #expect(geometry.topCurve.end == CGPoint(x: 100, y: 40))
        #expect(geometry.bottomCurve.start == CGPoint(x: 0, y: 60))
        #expect(geometry.bottomCurve.end == CGPoint(x: 100, y: 60))
        #expect(geometry.bottomCurve.control1.y - geometry.topCurve.control1.y == 20)
        #expect(geometry.bottomCurve.control2.y - geometry.topCurve.control2.y == 20)
    }

    @Test("A ribbon round-trips through its animatable components")
    func animatableComponents() throws {
        let geometry = ribbon(
            from: CGPoint(x: 1, y: 2),
            to: CGPoint(x: 101, y: 42),
            thickness: 7,
            endThickness: 9,
            curvature: 0.4
        )
        let components = geometry.animatableComponents
        #expect(components.count == RibbonGeometry.componentCount)
        #expect(try #require(RibbonGeometry(animatableComponents: components)) == geometry)
    }

    @Test("Rebuilding from a malformed component list fails instead of trapping")
    func malformedComponents() {
        #expect(RibbonGeometry(animatableComponents: []) == nil)
        #expect(RibbonGeometry(animatableComponents: [1, 2, 3]) == nil)
    }

    @Test("Interpolation can never produce a negative thickness")
    func negativeThicknessIsClamped() throws {
        let geometry = try #require(RibbonGeometry(animatableComponents: [0, 0, 10, 0, -4, -2, 0.5]))
        #expect(geometry.startThickness == 0)
        #expect(geometry.endThickness == 0)
    }

    @Test("A tapering ribbon offsets each end by its own half thickness")
    func taperingEnds() {
        let geometry = ribbon(
            from: CGPoint(x: 0, y: 50),
            to: CGPoint(x: 100, y: 50),
            thickness: 20,
            endThickness: 10
        )
        #expect(geometry.topCurve.start.y == 40)
        #expect(geometry.topCurve.control1.y == 40)
        #expect(geometry.topCurve.control2.y == 45)
        #expect(geometry.topCurve.end.y == 45)
        #expect(geometry.bottomCurve.start.y == 60)
        #expect(geometry.bottomCurve.end.y == 55)
    }
}
