/// A labelled value, the SankeyKit analog of Swift Charts' `PlottableValue`.
///
/// Use the ``value(_:_:)`` factory to pair a human readable label with the underlying
/// data, exactly the way you would in a Swift Charts mark:
///
/// ```swift
/// SankeyLink(
///     from: .value("Source", flow.from),
///     to: .value("Target", flow.to),
///     value: .value("Amount", flow.amount)
/// )
/// ```
///
/// The labels are not drawn on the diagram. They are used to build accessibility
/// descriptions such as `"Amount: 4,800"`.
public struct SankeyValue<Value: Sendable>: Sendable {
    /// The human readable name of the dimension this value belongs to.
    public let label: String

    /// The underlying data.
    public let value: Value

    /// Creates a labelled value.
    ///
    /// - Parameters:
    ///   - label: The name of the dimension, for example `"Amount"`.
    ///   - value: The underlying data.
    public static func value(_ label: String, _ value: Value) -> Self {
        Self(label: label, value: value)
    }
}

extension SankeyValue: Equatable where Value: Equatable {}
extension SankeyValue: Hashable where Value: Hashable {}
