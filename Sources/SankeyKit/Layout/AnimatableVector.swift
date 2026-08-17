import CoreGraphics
import SwiftUI

/// A `VectorArithmetic` container for an arbitrary list of `CGFloat`s.
///
/// SwiftUI can only interpolate `Animatable` shapes through a single `VectorArithmetic` value.
/// A ribbon needs nine numbers (see ``RibbonGeometry/animatableComponents``), so this type packs
/// them into one animatable quantity.
///
/// Operations are element-wise. If two vectors differ in length the shorter one is treated as if
/// it were zero-padded, so interpolation never traps.
struct AnimatableVector: VectorArithmetic, Sendable {
    private(set) var values: [CGFloat]

    init(_ values: [CGFloat] = []) {
        self.values = values
    }

    static var zero: AnimatableVector { AnimatableVector() }

    static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        AnimatableVector(combine(lhs.values, rhs.values, +))
    }

    static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        AnimatableVector(combine(lhs.values, rhs.values, -))
    }

    static func += (lhs: inout AnimatableVector, rhs: AnimatableVector) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout AnimatableVector, rhs: AnimatableVector) {
        lhs = lhs - rhs
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * CGFloat(rhs) }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + Double($1 * $1) }
    }

    private static func combine(
        _ lhs: [CGFloat],
        _ rhs: [CGFloat],
        _ operation: (CGFloat, CGFloat) -> CGFloat
    ) -> [CGFloat] {
        let count = max(lhs.count, rhs.count)
        return (0..<count).map { index in
            operation(
                index < lhs.count ? lhs[index] : 0,
                index < rhs.count ? rhs[index] : 0
            )
        }
    }
}
