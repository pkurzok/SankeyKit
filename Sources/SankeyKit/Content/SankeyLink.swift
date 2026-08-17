import SwiftUI

/// A flow from one node to another — the ribbon of a Sankey diagram.
///
/// Nodes are implicit: naming a node in a link is enough to create it.
///
/// ```swift
/// SankeyChart {
///     SankeyLink(from: "Salary", to: "Budget", value: 4800)
///     SankeyLink(from: "Budget", to: "Rent", value: 1900)
///         .foregroundStyle(.orange)
/// }
/// ```
public struct SankeyLink: SankeyContent {
    private var link: ResolvedLink

    /// Creates a link between two nodes.
    ///
    /// - Parameters:
    ///   - source: Name of the node the flow leaves.
    ///   - target: Name of the node the flow enters.
    ///   - value: The size of the flow. Links with a value of zero or less are ignored.
    public init(from source: String, to target: String, value: Double) {
        self.link = ResolvedLink(sourceID: source, targetID: target, value: value)
    }

    /// Creates a link from labelled values, the way a Swift Charts mark is written.
    ///
    /// The labels are used for accessibility descriptions, for example `"Amount: 4,800"`.
    ///
    /// ```swift
    /// SankeyLink(
    ///     from: .value("Source", flow.from),
    ///     to: .value("Target", flow.to),
    ///     value: .value("Amount", flow.amount)
    /// )
    /// ```
    public init(from source: SankeyValue<String>, to target: SankeyValue<String>, value: SankeyValue<Double>) {
        self.link = ResolvedLink(
            sourceID: source.value,
            targetID: target.value,
            value: value.value,
            sourceLabel: source.label,
            targetLabel: target.label,
            valueLabel: value.label
        )
    }

    /// Fills this ribbon with the given style instead of the color derived from its source node.
    public func foregroundStyle(_ style: some ShapeStyle) -> Self {
        var copy = self
        copy.link.style = AnyShapeStyle(style)
        return copy
    }

    /// Overrides the ribbon opacity set by ``SwiftUICore/View/sankeyLinkOpacity(_:)``.
    ///
    /// - Parameter opacity: A value between `0` and `1`. Values outside that range are clamped.
    public func opacity(_ opacity: Double) -> Self {
        var copy = self
        copy.link.opacity = min(max(opacity, 0), 1)
        return copy
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        resolution.append(link)
    }
}
