import CoreGraphics
@testable import SankeyKit
import SwiftUI
import Testing

/// Lays out a graph and hands back the pieces the resolver needs.
private func laidOut(
    _ links: [ResolvedLink],
    overrides: [NodeOverride] = [],
    size: CGSize = CGSize(width: 400, height: 200)
) throws -> SankeyLayoutResult {
    SankeyLayout.compute(graph: try graph(links, overrides: overrides), size: size)
}

@Suite("Style resolution")
struct StyleResolutionTests {
    @Test("Nodes take their color from the scale in layer and y order")
    func scaleFollowsLayoutOrder() throws {
        let colors: [Color] = [.red, .green, .blue]
        let resolver = SankeyStyleResolver(scale: colors)
        let layout = try laidOut([link("A", "C", 30), link("B", "C", 10)])

        #expect(layout.nodes.map(\.id) == ["A", "B", "C"])
        #expect(layout.nodes.map { resolver.nodeFill($0).color } == [.red, .green, .blue])
    }

    @Test("The scale cycles when there are more nodes than colors")
    func scaleCycles() {
        let resolver = SankeyStyleResolver(scale: [.red, .green])
        #expect(resolver.scaleColor(at: 0) == .red)
        #expect(resolver.scaleColor(at: 1) == .green)
        #expect(resolver.scaleColor(at: 2) == .red)
        #expect(resolver.scaleColor(at: 7) == .green)
    }

    @Test("An empty scale falls back to the built-in palette")
    func emptyScaleFallsBack() {
        #expect(SankeyStyleResolver(scale: []).scale == SankeyStyleResolver.defaultPalette)
        #expect(SankeyStyleResolver(scale: nil).scale == SankeyStyleResolver.defaultPalette)
        #expect(SankeyStyleResolver.defaultPalette.isEmpty == false)
    }

    @Test("A node's own style beats the color scale")
    func nodeStyleBeatsScale() throws {
        let layout = try laidOut(
            [link("A", "B", 1)],
            overrides: [NodeOverride(name: "A", style: AnyShapeStyle(.orange), tint: .orange)]
        )
        let resolver = SankeyStyleResolver(scale: [.red])
        let styled = try #require(layout.nodes.first { $0.id == "A" })
        let plain = try #require(layout.nodes.first { $0.id == "B" })

        #expect(resolver.nodeFill(styled).isExplicitStyle)
        #expect(resolver.nodeFill(plain).color == .red)
    }

    @Test("A node tinted with a plain color also tints the ribbons touching it")
    func nodeTintReachesRibbons() throws {
        let layout = try laidOut(
            [link("A", "B", 1)],
            overrides: [NodeOverride(name: "A", style: AnyShapeStyle(.orange), tint: .orange)]
        )
        let resolver = SankeyStyleResolver(scale: [.red, .green])
        let laidOutLink = try #require(layout.links.first)
        let colors = try #require(
            resolver.linkFill(
                laidOutLink,
                from: layout.nodes.first { $0.id == "A" },
                to: layout.nodes.first { $0.id == "B" }
            ).gradientColors
        )
        #expect(colors.from == .orange)
        #expect(colors.to == .green)
    }

    @Test("A node styled with a gradient keeps the scale color for its ribbons")
    func nonColorNodeStyleDoesNotTintRibbons() throws {
        let gradient = AnyShapeStyle(LinearGradient(colors: [.red, .blue], startPoint: .top, endPoint: .bottom))
        let layout = try laidOut([link("A", "B", 1)], overrides: [NodeOverride(name: "A", style: gradient)])
        let resolver = SankeyStyleResolver(scale: [.red, .green])
        let source = try #require(layout.nodes.first { $0.id == "A" })

        #expect(resolver.nodeFill(source).isExplicitStyle)
        #expect(resolver.nodeColor(source) == .red)
    }

    @Test("Without its own style a ribbon blends from source to target color")
    func ribbonBlendsBetweenNodes() throws {
        let layout = try laidOut([link("A", "B", 1)])
        let resolver = SankeyStyleResolver(scale: [.red, .green])
        let laidOutLink = try #require(layout.links.first)
        let colors = try #require(
            resolver.linkFill(
                laidOutLink,
                from: layout.nodes.first { $0.id == "A" },
                to: layout.nodes.first { $0.id == "B" }
            ).gradientColors
        )
        #expect(colors.from == .red)
        #expect(colors.to == .green)
    }

    @Test("A link's own style beats the source node's color")
    func linkStyleBeatsSourceColor() throws {
        var styled = link("A", "B", 1)
        styled.style = AnyShapeStyle(.purple)
        let layout = try laidOut([styled])
        let resolver = SankeyStyleResolver(scale: [.red, .green])

        let laidOutLink = try #require(layout.links.first)
        let fill = resolver.linkFill(
            laidOutLink,
            from: layout.nodes.first { $0.id == "A" },
            to: layout.nodes.first { $0.id == "B" }
        )
        #expect(fill.isExplicitStyle)
        #expect(fill.gradientColors == nil)
    }

    @Test("A link's own opacity beats the chart default")
    func linkOpacityPrecedence() throws {
        var custom = link("A", "B", 1)
        custom.opacity = 0.2
        let layout = try laidOut([custom, link("A", "C", 1)])
        let resolver = SankeyStyleResolver()

        let overridden = try #require(layout.links.first { $0.id.target == "B" })
        let plain = try #require(layout.links.first { $0.id.target == "C" })
        #expect(resolver.linkOpacity(overridden, default: 0.75) == 0.2)
        #expect(resolver.linkOpacity(plain, default: 0.75) == 0.75)
    }
}

@Suite("Metrics")
struct MetricsTests {
    @Test("The defaults are the documented ones")
    func defaults() {
        let metrics = SankeyMetrics.default
        #expect(metrics.nodeWidth == 12)
        #expect(metrics.nodeSpacing == 8)
        #expect(metrics.linkSpacing == 3)
        #expect(metrics.cornerRadius == 3)
        #expect(metrics.curvature == 0.5)
        #expect(metrics.linkOpacity == 0.75)
    }

    @Test("A chart without modifiers uses the default configuration")
    func configurationDefaults() {
        let configuration = SankeyConfiguration()
        #expect(configuration.metrics == SankeyMetrics.default)
        #expect(configuration.colorScale == nil)
    }

    @Test("Curvature is clamped to zero through one", arguments: [
        (-1.0, 0.0), (0.0, 0.0), (0.45, 0.45), (1.0, 1.0), (2.5, 1.0)
    ])
    func curvatureClamping(input: Double, expected: Double) {
        var metrics = SankeyMetrics()
        metrics.curvature = input
        #expect(metrics.curvature == expected)
    }

    @Test("Opacity is clamped to zero through one", arguments: [
        (-0.5, 0.0), (0.3, 0.3), (1.0, 1.0), (4.0, 1.0)
    ])
    func opacityClamping(input: Double, expected: Double) {
        var metrics = SankeyMetrics()
        metrics.linkOpacity = input
        #expect(metrics.linkOpacity == expected)
    }

    @Test("Lengths never go negative")
    func lengthsAreNonNegative() {
        var metrics = SankeyMetrics()
        metrics.nodeWidth = -10
        metrics.nodeSpacing = -10
        metrics.linkSpacing = -10
        metrics.cornerRadius = -10
        #expect(metrics.nodeWidth == 0)
        #expect(metrics.nodeSpacing == 0)
        #expect(metrics.linkSpacing == 0)
        #expect(metrics.cornerRadius == 0)
    }

    @Test("Metrics reach the layout")
    func metricsDriveTheLayout() throws {
        let metrics = SankeyMetrics(nodeWidth: 30)
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "B", 1)]),
            size: CGSize(width: 400, height: 200),
            metrics: metrics
        )
        #expect(try #require(result.nodeFrames["A"]).width == 30)
        #expect(try #require(result.links.first).geometry.curvature == metrics.curvature)
    }
}

@Suite("Label placement")
struct LabelPlacementTests {
    private func nodes(_ links: [ResolvedLink]) throws -> [LaidOutNode] {
        SankeyLayout.compute(
            graph: try graph(links),
            size: CGSize(width: 400, height: 200)
        ).nodes
    }

    @Test("The first column reads outward left and the last outward right")
    func outerColumnsReadOutward() throws {
        let laidOut = try nodes([link("A", "B", 1), link("B", "C", 1)])
        let placements = laidOut.map { LabelLayer.placement(for: $0, layerCount: 3) }
        #expect(placements == [.leading, .over, .trailing])
    }

    @Test("With only two columns no label sits on a node")
    func twoColumnsHaveNoInnerLabels() throws {
        let laidOut = try nodes([link("A", "B", 1)])
        let placements = laidOut.map { LabelLayer.placement(for: $0, layerCount: 2) }
        #expect(placements == [.leading, .trailing])
    }

    @Test("Every column in between sits on its own node")
    func innerColumnsSitOnTheNode() throws {
        let laidOut = try nodes([
            link("A", "B", 1),
            link("B", "C", 1),
            link("C", "D", 1),
            link("D", "E", 1)
        ])
        let placements = laidOut.map { LabelLayer.placement(for: $0, layerCount: 5) }
        #expect(placements == [.leading, .over, .over, .over, .trailing])
    }

    @Test("The reserved label margin has a floor, a ceiling, and never takes the canvas over")
    func labelInsetScalesWithWidth() {
        // Phone width: the floor applies, and it stays well under the share-of-width cap.
        #expect(SankeyDiagram.labelInset(for: CGSize(width: 400, height: 200)) == 64)
        // Desktop width: proportional.
        #expect(SankeyDiagram.labelInset(for: CGSize(width: 900, height: 400)) == 108)
        // Very wide: capped, so a wide chart does not waste its width on margins.
        #expect(SankeyDiagram.labelInset(for: CGSize(width: 2000, height: 400)) == 140)
        // Very narrow: the share-of-width cap wins over the floor, leaving a diagram in the middle.
        #expect(SankeyDiagram.labelInset(for: CGSize(width: 180, height: 180)) == 180 * 0.22)
        #expect(SankeyDiagram.labelInset(for: .zero) == 0)
    }

    @Test("The diagram always keeps more than half of the width", arguments: [
        CGFloat(120), 180, 320, 400, 900, 2000
    ])
    func diagramKeepsMostOfTheWidth(width: CGFloat) {
        let inset = SankeyDiagram.labelInset(for: CGSize(width: width, height: 200))
        #expect(inset * 2 < width * 0.5)
    }

    @Test("A label between the columns never spills past its neighbours")
    func innerSlotWidthIsBounded() {
        let size = CGSize(width: 600, height: 200)
        let inset = SankeyDiagram.labelInset(for: size)
        let width = SankeyDiagram.innerSlotWidth(
            size: size,
            inset: inset,
            layerCount: 3,
            metrics: .default
        )
        let stride = (size.width - 2 * inset - SankeyMetrics.default.nodeWidth) / 2
        #expect(width <= stride)
        #expect(width >= 32)
    }
}
