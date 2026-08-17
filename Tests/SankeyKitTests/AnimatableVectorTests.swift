import CoreGraphics
@testable import SankeyKit
import Testing

@Suite("Animatable vector")
struct AnimatableVectorTests {
    @Test("Addition and subtraction are element-wise")
    func arithmetic() {
        let lhs = AnimatableVector([1, 2, 3])
        let rhs = AnimatableVector([10, 20, 30])
        #expect((lhs + rhs).values == [11, 22, 33])
        #expect((rhs - lhs).values == [9, 18, 27])
    }

    @Test("Mismatched lengths are zero-padded instead of trapping")
    func mismatchedLengths() {
        let short = AnimatableVector([1, 2])
        let long = AnimatableVector([1, 2, 3, 4])
        #expect((short + long).values == [2, 4, 3, 4])
        #expect((short - long).values == [0, 0, -3, -4])
    }

    @Test("Scaling multiplies every element")
    func scaling() {
        var vector = AnimatableVector([2, 4, 6])
        vector.scale(by: 0.5)
        #expect(vector.values == [1, 2, 3])
    }

    @Test("The magnitude is the squared euclidean length")
    func magnitude() {
        #expect(AnimatableVector([3, 4]).magnitudeSquared == 25)
        #expect(AnimatableVector.zero.magnitudeSquared == 0)
    }

    @Test("Interpolating halfway lands on the midpoint")
    func interpolationMidpoint() {
        let from = AnimatableVector([0, 10, 100])
        let to = AnimatableVector([10, 20, 200])
        var midpoint = from
        var delta = to - from
        delta.scale(by: 0.5)
        midpoint += delta
        #expect(midpoint.values == [5, 15, 150])
    }

    @Test("Interpolating two ribbon snapshots stays between the two")
    func ribbonInterpolation() throws {
        let start = RibbonGeometry(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 100, y: 0),
            startThickness: 10,
            endThickness: 10,
            curvature: 0.5
        )
        let end = RibbonGeometry(
            start: CGPoint(x: 0, y: 40),
            end: CGPoint(x: 100, y: 80),
            startThickness: 30,
            endThickness: 30,
            curvature: 0.5
        )
        var midpoint = AnimatableVector(start.animatableComponents)
        var delta = AnimatableVector(end.animatableComponents) - midpoint
        delta.scale(by: 0.5)
        midpoint += delta

        for (index, value) in midpoint.values.enumerated() {
            let low = min(start.animatableComponents[index], end.animatableComponents[index])
            let high = max(start.animatableComponents[index], end.animatableComponents[index])
            #expect(value >= low && value <= high)
        }
        // The two thicknesses interpolate to their averages.
        let halfway = try #require(RibbonGeometry(animatableComponents: midpoint.values))
        #expect(halfway.startThickness == 20)
        #expect(halfway.endThickness == 20)
        #expect(halfway.start.y == 20)
        #expect(halfway.end.y == 40)
    }
}
