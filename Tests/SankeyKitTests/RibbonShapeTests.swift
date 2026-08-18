import CoreGraphics
@testable import SankeyKit
import SwiftUI
import Testing

@Suite("Ribbon shape")
struct RibbonShapeTests {
    /// The ribbon has to span at least ``RibbonGeometry/minimumControlOffset`` horizontally:
    /// for narrower ones the control points sit outside the endpoints and the curve's bounding
    /// rect grows past the `start.x…end.x` span for reasons that have nothing to do with the
    /// overlap.
    private func ribbon(
        from start: CGPoint = CGPoint(x: 20, y: 50),
        to end: CGPoint = CGPoint(x: 120, y: 90),
        thickness: CGFloat = 10,
        endThickness: CGFloat? = nil
    ) -> RibbonGeometry {
        RibbonGeometry(
            start: start,
            end: end,
            startThickness: thickness,
            endThickness: endThickness ?? thickness,
            curvature: 0.5
        )
    }

    @Test("Both ends reach the overlap distance into their node")
    func overlapExtendsBothEnds() {
        let geometry = ribbon()
        let bounds = RibbonShape(geometry: geometry, overlap: 6).path(in: .zero).boundingRect
        #expect(bounds.minX == geometry.start.x - 6)
        #expect(bounds.maxX == geometry.end.x + 6)
    }

    @Test("Without an overlap the ribbon still ends on the node edges")
    func zeroOverlapKeepsTheOldSpan() {
        let geometry = ribbon()
        let bounds = RibbonShape(geometry: geometry, overlap: 0).path(in: .zero).boundingRect
        #expect(bounds.minX == geometry.start.x)
        #expect(bounds.maxX == geometry.end.x)
    }

    @Test("The overlap only widens the ribbon, it does not move it vertically")
    func overlapLeavesTheVerticalSpanAlone() {
        let geometry = ribbon()
        let plain = RibbonShape(geometry: geometry, overlap: 0).path(in: .zero).boundingRect
        let tucked = RibbonShape(geometry: geometry, overlap: 6).path(in: .zero).boundingRect
        #expect(tucked.minY == plain.minY)
        #expect(tucked.maxY == plain.maxY)
    }

    @Test("A ribbon without thickness draws nothing, overlap or not")
    func emptyRibbonStaysEmpty() {
        let geometry = ribbon(thickness: 0)
        #expect(RibbonShape(geometry: geometry, overlap: 6).path(in: .zero).isEmpty)
        #expect(RibbonShape(geometry: geometry, overlap: 0).path(in: .zero).isEmpty)
    }

    @Test("A ribbon that tapers to nothing at one end is still drawn")
    func oneSidedRibbonIsDrawn() {
        let geometry = ribbon(thickness: 10, endThickness: 0)
        #expect(!RibbonShape(geometry: geometry, overlap: 6).path(in: .zero).isEmpty)
    }
}
