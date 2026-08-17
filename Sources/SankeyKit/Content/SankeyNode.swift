import SwiftUI

/// Customizes a node that the links already created.
///
/// A chart derives its nodes from link endpoints, so a `SankeyNode` mark is optional. Add one to
/// change a node's color, its printed label, or the column it sits in. A node mark for a name no
/// link mentions has nothing to attach to and is ignored.
///
/// ```swift
/// SankeyChart {
///     SankeyLink(from: "Salary", to: "Budget", value: 4800)
///     SankeyNode("Budget")
///         .foregroundStyle(.blue)
///         .label("Monthly Budget")
/// }
/// ```
public struct SankeyNode: SankeyContent {
    private var override: NodeOverride

    /// Customizes the node with the given name.
    ///
    /// - Parameters:
    ///   - name: The node name, exactly as used in the links that touch it.
    ///   - layer: Pins the node to a column, overriding the inferred one. Columns are numbered
    ///     from the left starting at zero; the whole diagram is shifted if a pinned layer is
    ///     further left than any inferred one.
    public init(_ name: String, layer: Int? = nil) {
        self.override = NodeOverride(name: name, pinnedLayer: layer)
    }

    /// Fills this node with the given style instead of the color from the chart's color scale.
    ///
    /// When the style is a plain `Color`, the ribbons touching this node blend to it as well.
    /// Any other style paints the node rectangle only, and its ribbons keep the color scale.
    public func foregroundStyle(_ style: some ShapeStyle) -> Self {
        var copy = self
        copy.override.style = AnyShapeStyle(style)
        copy.override.tint = style as? Color
        return copy
    }

    /// Draws the given text next to the node instead of its name.
    public func label(_ text: String) -> Self {
        var copy = self
        copy.override.displayLabel = text
        return copy
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        resolution.append(override)
    }
}
