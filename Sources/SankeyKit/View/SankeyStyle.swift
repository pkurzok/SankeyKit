import SwiftUI

/// How one element of the diagram should be painted.
///
/// Keeping this separate from `ShapeStyle` makes the precedence rules in ``SankeyStyleResolver``
/// inspectable — an `AnyShapeStyle` can be drawn but not compared.
enum SankeyFill {
    /// A style set directly on the mark.
    case style(AnyShapeStyle)
    /// A flat color taken from the chart's color scale.
    case color(Color)
    /// A blend from the source node's color to the target node's color.
    case gradient(from: Color, to: Color)
}

extension SankeyFill {
    /// The flat color, if this fill is one.
    var color: Color? {
        if case .color(let color) = self { return color }
        return nil
    }

    /// The two ends of the blend, if this fill is a gradient.
    var gradientColors: (from: Color, to: Color)? {
        if case .gradient(let from, let to) = self { return (from, to) }
        return nil
    }

    /// Whether the fill came from a style set on the mark itself.
    var isExplicitStyle: Bool {
        if case .style = self { return true }
        return false
    }
}

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

    /// The color at a position in the scale, cycling for indices beyond its end.
    func scaleColor(at index: Int) -> Color {
        scale[((index % scale.count) + scale.count) % scale.count]
    }

    /// The color a node contributes to the ribbons that touch it.
    func nodeColor(_ node: LaidOutNode) -> Color {
        node.node.tint ?? scaleColor(at: node.paletteIndex)
    }

    /// How a node rectangle is painted.
    func nodeFill(_ node: LaidOutNode) -> SankeyFill {
        if let style = node.node.style {
            return .style(style)
        }
        return .color(scaleColor(at: node.paletteIndex))
    }

    /// How a ribbon is painted.
    func linkFill(_ link: LaidOutLink, from source: LaidOutNode?, to target: LaidOutNode?) -> SankeyFill {
        if let style = link.link.style {
            return .style(style)
        }
        let leading = source.map(nodeColor) ?? scaleColor(at: 0)
        return .gradient(from: leading, to: target.map(nodeColor) ?? leading)
    }

    /// The opacity of a ribbon: the per-link value when set, otherwise the chart default.
    func linkOpacity(_ link: LaidOutLink, default defaultOpacity: Double) -> Double {
        link.link.opacity ?? defaultOpacity
    }

    /// Turns a fill into something SwiftUI can paint.
    ///
    /// A gradient is anchored to the ribbon's two endpoints. Ribbons are drawn in the chart's
    /// coordinate space rather than their own bounds, so the endpoints have to be expressed
    /// relative to the whole canvas.
    func shapeStyle(for fill: SankeyFill, spanning geometry: RibbonGeometry? = nil) -> AnyShapeStyle {
        switch fill {
        case .style(let style):
            return style
        case .color(let color):
            return AnyShapeStyle(color)
        case .gradient(let from, let to):
            guard let geometry else { return AnyShapeStyle(from) }
            // Interpolating perceptually keeps the middle of the ribbon from turning grey when
            // the two nodes sit far apart on the color wheel.
            return AnyShapeStyle(
                .linearGradient(
                    Gradient(colors: [from, to]).colorSpace(.perceptual),
                    startPoint: unitPoint(atX: geometry.start.x),
                    endPoint: unitPoint(atX: geometry.end.x)
                )
            )
        }
    }

    private func unitPoint(atX x: CGFloat) -> UnitPoint {
        guard canvasSize.width > 0 else { return UnitPoint(x: 0, y: 0.5) }
        return UnitPoint(x: x / canvasSize.width, y: 0.5)
    }
}
