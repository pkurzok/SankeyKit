import SwiftUI

/// Decides the final fill of every node and ribbon.
///
/// Precedence, highest first:
/// 1. the style set on the mark itself — ``SankeyNode/foregroundStyle(_:)`` or
///    ``SankeyLink/foregroundStyle(_:)``,
/// 2. the chart's color scale from ``SwiftUICore/View/sankeyColorScale(_:)``,
/// 3. the built-in palette.
///
/// A ribbon without its own style takes the color of the node it leaves, which is what makes a
/// flow visually traceable from left to right.
struct SankeyStyleResolver {
    /// Colors assigned to nodes in `(layer, y)` order, cycling when there are more nodes than colors.
    var scale: [Color]

    /// The built-in palette, used when no color scale is set.
    static let defaultPalette: [Color] = [
        .blue, .teal, .green, .orange, .pink, .purple, .indigo, .mint, .red, .brown
    ]

    init(scale: [Color]? = nil) {
        let colors = scale?.isEmpty == false ? scale : nil
        self.scale = colors ?? Self.defaultPalette
    }

    /// The color a node takes from the scale, ignoring any style set on the mark.
    func scaleColor(at index: Int) -> Color {
        scale[((index % scale.count) + scale.count) % scale.count]
    }

    /// The fill of a node rectangle.
    func nodeStyle(_ node: LaidOutNode) -> AnyShapeStyle {
        node.node.style ?? AnyShapeStyle(scaleColor(at: node.paletteIndex))
    }

    /// The fill of a ribbon, falling back to the color of its source node.
    func linkStyle(_ link: LaidOutLink, sourceNode: LaidOutNode?) -> AnyShapeStyle {
        if let style = link.link.style {
            return style
        }
        guard let sourceNode else { return AnyShapeStyle(scaleColor(at: 0)) }
        return nodeStyle(sourceNode)
    }

    /// The opacity of a ribbon: the per-link value when set, otherwise the chart default.
    func linkOpacity(_ link: LaidOutLink, default defaultOpacity: Double) -> Double {
        link.link.opacity ?? defaultOpacity
    }
}
