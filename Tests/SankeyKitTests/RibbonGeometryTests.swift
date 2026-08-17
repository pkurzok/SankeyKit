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

    @Test("Control points follow the article formula")
    func controlPointFormula() {
        let geometry = ribbon(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80), curvature: 0.5)
        let (first, second) = geometry.controlPoints
        // dx = 100, v = 0.5, rise = 60
        #expect(first == CGPoint(x: 60, y: 50))
        #expect(second == CGPoint(x: 60, y: 50))
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

    @Test("A ribbon exposes ten animatable components")
    func animatableComponents() {
        let geometry = ribbon(from: CGPoint(x: 1, y: 2), to: CGPoint(x: 101, y: 42), thickness: 7, endThickness: 9)
        let components = geometry.animatableComponents
        #expect(components.count == 10)
        #expect(components.first == 1)
        #expect(components.suffix(2) == [7, 9])
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
