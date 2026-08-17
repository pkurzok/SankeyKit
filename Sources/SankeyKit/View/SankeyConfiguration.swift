import SwiftUI

/// Everything a ``SankeyChart`` reads from its environment.
///
/// The chart modifiers below each transform one field, so they compose the way the Swift Charts
/// `chart…` modifiers do: applying two of them keeps both.
struct SankeyConfiguration {
    var metrics = SankeyMetrics()
    /// Colors assigned to nodes in `(layer, y)` order. `nil` means "use the built-in palette".
    var colorScale: [Color]?
    /// Where a tap on a node or ribbon is reported. `nil` means the chart is read-only.
    var selection: Binding<SankeySelection?>?
}

extension EnvironmentValues {
    @Entry var sankeyConfiguration = SankeyConfiguration()
}

extension View {
    /// Sets how wide the node rectangles are drawn.
    ///
    /// - Parameter width: The width in points. The default is 12.
    public func sankeyNodeWidth(_ width: CGFloat) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.nodeWidth = width }
    }

    /// Sets the vertical gap between two nodes stacked in the same column.
    ///
    /// In a column so crowded that the gaps would not fit, the chart shrinks them so the nodes
    /// always keep at least half of the available height.
    ///
    /// - Parameter spacing: The gap in points. The default is 8.
    public func sankeyNodeSpacing(_ spacing: CGFloat) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.nodeSpacing = spacing }
    }

    /// Sets the corner radius of the node rectangles.
    ///
    /// - Parameter radius: The radius in points, capped at half the node's height. The default is 3.
    public func sankeyNodeCornerRadius(_ radius: CGFloat) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.cornerRadius = radius }
    }

    /// Sets the vertical gap between two ribbons where they meet the same node.
    ///
    /// The gap is taken out of the node edge the ribbons share, never added to it, so the diagram
    /// stays proportional. It is clamped so the gaps never consume more than half of a node edge.
    ///
    /// - Parameter spacing: The gap in points. The default is 3.
    public func sankeyLinkSpacing(_ spacing: CGFloat) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.linkSpacing = spacing }
    }

    /// Sets how strongly the ribbons bend.
    ///
    /// - Parameter curvature: `0` draws straight ribbons, `1` bends as hard as possible. Values
    ///   outside `0...1` are clamped. The default is 0.5.
    public func sankeyLinkCurvature(_ curvature: Double) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.curvature = curvature }
    }

    /// Sets how opaque the ribbons are drawn.
    ///
    /// A ribbon with its own ``SankeyLink/opacity(_:)`` keeps that value.
    ///
    /// - Parameter opacity: A value between `0` and `1`. Values outside that range are clamped.
    ///   The default is 0.75.
    public func sankeyLinkOpacity(_ opacity: Double) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.metrics.linkOpacity = opacity }
    }

    /// Sets the colors the chart assigns to its nodes.
    ///
    /// Colors are handed out in `(layer, y)` order — top to bottom, column by column — and cycle
    /// when the diagram has more nodes than colors. A node with its own
    /// ``SankeyNode/foregroundStyle(_:)`` keeps that style. Passing an empty array restores the
    /// built-in palette.
    ///
    /// Because a ribbon blends from its source color to its target color, a scale whose colors are
    /// ordered by hue produces the cleanest gradients.
    ///
    /// - Parameter colors: The colors to cycle through.
    public func sankeyColorScale(_ colors: [Color]) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.colorScale = colors.isEmpty ? nil : colors }
    }

    /// Lets the reader select a node or a ribbon by tapping it.
    ///
    /// The selected element and everything it connects to stay at full opacity; the rest of the
    /// diagram dims. Tapping the selected element again, or tapping the background, clears the
    /// selection. Without this modifier the chart is read-only and lets taps pass straight through.
    ///
    /// ```swift
    /// @State private var selection: SankeySelection?
    ///
    /// SankeyChart { … }
    ///     .sankeySelection($selection)
    /// ```
    ///
    /// > Note: On tvOS the diagram stays read-only. `onTapGesture` compiles there, but a shape
    /// cannot take focus, so per-element taps never arrive.
    ///
    /// - Parameter selection: The binding that receives the selected element.
    public func sankeySelection(_ selection: Binding<SankeySelection?>) -> some View {
        transformEnvironment(\.sankeyConfiguration) { $0.selection = selection }
    }
}
