import SwiftUI

/// Decides the final fill of every node and ribbon.
///
/// Precedence for a node, highest first:
/// 1. ``SankeyNode/foregroundStyle(_:)`` on the mark,
/// 2. the chart's color scale from ``SwiftUICore/View/sankeyColorScale(_:)``,
/// 3. the built-in palette.
///
/// A ribbon without a ``SankeyLink/foregroundStyle(_:)`` of its own is filled with a horizontal
/// gradient that blends the color of the node it leaves into the color of the node it enters, so
/// a flow reads as one continuous band from left to right.
struct SankeyStyleResolver {
    /// Colors assigned to nodes in `(layer, y)` order, cycling when there are more nodes than colors.
    var scale: [Color]
    /// The size of the chart canvas, needed to place gradient endpoints.
    var canvasSize: CGSize

    /// The built-in palette, used when no color scale is set.
    ///
    /// The colors walk the hue wheel in order. Because nodes take their color in `(layer, y)`
    /// order, neighbouring nodes end up with neighbouring hues, and the gradient between them
    /// stays saturated instead of passing through grey.
    static let defaultPalette: [Color] = [
        Color(red: 0.231, green: 0.510, blue: 0.965),  // blue
        Color(red: 0.024, green: 0.714, blue: 0.831),  // cyan
        Color(red: 0.078, green: 0.722, blue: 0.651),  // teal
        Color(red: 0.133, green: 0.773, blue: 0.369),  // green
        Color(red: 0.518, green: 0.800, blue: 0.086),  // lime
        Color(red: 0.918, green: 0.702, blue: 0.031),  // yellow
        Color(red: 0.976, green: 0.451, blue: 0.086),  // orange
        Color(red: 0.937, green: 0.267, blue: 0.267),  // red
        Color(red: 0.925, green: 0.282, blue: 0.600),  // pink
        Color(red: 0.659, green: 0.333, blue: 0.969),  // purple
        Color(red: 0.388, green: 0.400, blue: 0.945)   // indigo
    ]

    init(scale: [Color]? = nil, canvasSize: CGSize = .zero) {
        let colors = scale?.isEmpty == false ? scale : nil
        self.scale = colors ?? Self.defaultPalette
        self.canvasSize = canvasSize
    }

    /// The color a node takes from the scale, ignoring any style set on the mark.
    func scaleColor(at index: Int) -> Color {
        scale[((index % scale.count) + scale.count) % scale.count]
    }

    /// The color a node contributes to the ribbons that touch it.
    func nodeColor(_ node: LaidOutNode) -> Color {
        node.node.tint ?? scaleColor(at: node.paletteIndex)
    }

    /// The fill of a node rectangle.
    func nodeStyle(_ node: LaidOutNode) -> AnyShapeStyle {
        node.node.style ?? AnyShapeStyle(nodeColor(node))
    }

    /// The fill of a ribbon: its own style, or a gradient from its source to its target color.
    func linkStyle(_ link: LaidOutLink, from source: LaidOutNode?, to target: LaidOutNode?) -> AnyShapeStyle {
        if let style = link.link.style {
            return style
        }
        let leading = source.map(nodeColor) ?? scaleColor(at: 0)
        let trailing = target.map(nodeColor) ?? leading
        // Interpolating perceptually keeps the middle of the ribbon from turning grey when the
        // two nodes sit far apart on the color wheel.
        return AnyShapeStyle(
            .linearGradient(
                Gradient(colors: [leading, trailing]).colorSpace(.perceptual),
                startPoint: unitPoint(atX: link.geometry.start.x),
                endPoint: unitPoint(atX: link.geometry.end.x)
            )
        )
    }

    /// The opacity of a ribbon: the per-link value when set, otherwise the chart default.
    func linkOpacity(_ link: LaidOutLink, default defaultOpacity: Double) -> Double {
        link.link.opacity ?? defaultOpacity
    }

    /// Ribbons are drawn in the chart's coordinate space, so a gradient endpoint has to be
    /// expressed relative to the whole canvas rather than to the ribbon's own bounds.
    private func unitPoint(atX x: CGFloat) -> UnitPoint {
        guard canvasSize.width > 0 else { return UnitPoint(x: 0, y: 0.5) }
        return UnitPoint(x: x / canvasSize.width, y: 0.5)
    }
}
