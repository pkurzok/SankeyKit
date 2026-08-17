import CoreGraphics
@testable import SankeyKit
import Testing

@Suite("Layout")
struct SankeyLayoutTests {
    private let size = CGSize(width: 400, height: 200)

    @Test("Node heights are proportional to magnitude")
    func heightsAreProportional() throws {
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "C", 30), link("B", "C", 10)]),
            size: size
        )
        let heightA = try #require(result.nodeFrames["A"]).height
        let heightB = try #require(result.nodeFrames["B"]).height
        #expect(abs(heightA - heightB * 3) < 0.001)
    }

    @Test("The busiest layer fills the height minus its spacing")
    func busiestLayerFillsHeight() throws {
        let metrics = SankeyMetrics(nodeSpacing: 8)
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "C", 30), link("B", "C", 10)]),
            size: size,
            metrics: metrics
        )
        // Layer 0 holds two nodes, layer 1 holds one node of the same total magnitude,
        // so layer 0 is the constraint: 200 - 8 = 192 points of node height.
        let heightA = try #require(result.nodeFrames["A"]).height
        let heightB = try #require(result.nodeFrames["B"]).height
        #expect(abs(heightA + heightB - (size.height - metrics.nodeSpacing)) < 0.001)
        // The single node in layer 1 uses the same scale and therefore stays shorter.
        let heightC = try #require(result.nodeFrames["C"]).height
        #expect(heightC < size.height)
    }

    @Test("Layers span the full width, first at zero and last flush right")
    func layersSpanTheWidth() throws {
        let metrics = SankeyMetrics(nodeWidth: 12)
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "B", 1), link("B", "C", 1)]),
            size: size,
            metrics: metrics
        )
        #expect(try #require(result.nodeFrames["A"]).minX == 0)
        #expect(try #require(result.nodeFrames["C"]).maxX == size.width)
        #expect(try #require(result.nodeFrames["B"]).minX == (size.width - metrics.nodeWidth) / 2)
        #expect(result.layerCount == 3)
    }

    @Test("A node override without any link produces an empty layout")
    func nodeOverrideWithoutLinks() throws {
        var resolution = SankeyResolution()
        resolution.append(NodeOverride(name: "A"))
        // No links at all: the graph is empty, which must not crash the layout.
        let result = SankeyLayout.compute(graph: try SankeyGraph(resolution: resolution), size: size)
        #expect(result.isEmpty)
    }

    @Test("Nodes are stacked top-aligned with the configured spacing")
    func stackingUsesSpacing() throws {
        let metrics = SankeyMetrics(nodeSpacing: 20)
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "C", 30), link("B", "C", 10)]),
            size: size,
            metrics: metrics
        )
        let frameA = try #require(result.nodeFrames["A"])
        let frameB = try #require(result.nodeFrames["B"])
        #expect(frameA.minY == 0)
        #expect(abs(frameB.minY - (frameA.maxY + metrics.nodeSpacing)) < 0.001)
    }

    @Test("Ribbons at a node stack without overlapping and stay inside it")
    func ribbonsDoNotOverlap() throws {
        let sankey = try graph([
            link("A", "X", 30),
            link("A", "Y", 20),
            link("A", "Z", 10)
        ])
        let result = SankeyLayout.compute(graph: sankey, size: size)
        let frameA = try #require(result.nodeFrames["A"])

        let outgoing = result.links
            .filter { $0.id.source == "A" }
            .sorted { $0.geometry.start.y < $1.geometry.start.y }

        var expectedTop = frameA.minY
        for laidOut in outgoing {
            let top = laidOut.geometry.start.y - laidOut.geometry.thickness / 2
            #expect(abs(top - expectedTop) < 0.001)
            expectedTop += laidOut.geometry.thickness
        }
        #expect(expectedTop <= frameA.maxY + 0.001)
    }

    @Test("Ribbon thickness is proportional to the link value")
    func ribbonThicknessIsProportional() throws {
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "X", 30), link("A", "Y", 10)]),
            size: size
        )
        let thick = try #require(result.links.first { $0.id.target == "X" }).geometry.thickness
        let thin = try #require(result.links.first { $0.id.target == "Y" }).geometry.thickness
        #expect(abs(thick - thin * 3) < 0.001)
    }

    @Test("Ribbons start on the source trailing edge and end on the target leading edge")
    func ribbonEndpointsSitOnNodeEdges() throws {
        let result = SankeyLayout.compute(graph: try graph([link("A", "B", 5)]), size: size)
        let laidOut = try #require(result.links.first)
        let frameA = try #require(result.nodeFrames["A"])
        let frameB = try #require(result.nodeFrames["B"])
        #expect(laidOut.geometry.start.x == frameA.maxX)
        #expect(laidOut.geometry.end.x == frameB.minX)
    }

    @Test("Ribbon order at a node follows the counterpart's vertical position")
    func ribbonOrderReducesCrossings() throws {
        // W's links fix the vertical order of layer 1 to X, Y, Z. A then declares its links in
        // the reverse order, so ordering by declaration would produce three crossings.
        let sankey = try graph([
            link("W", "X", 10),
            link("W", "Y", 10),
            link("W", "Z", 10),
            link("A", "Z", 10),
            link("A", "Y", 10),
            link("A", "X", 10)
        ])
        let result = SankeyLayout.compute(graph: sankey, size: size)
        let targetsTopToBottom = result.links
            .filter { $0.id.source == "A" }
            .sorted { $0.geometry.start.y < $1.geometry.start.y }
            .map(\.id.target)
        let byNodeY = ["X", "Y", "Z"].sorted { (result.nodeFrames[$0]?.midY ?? 0) < (result.nodeFrames[$1]?.midY ?? 0) }
        #expect(targetsTopToBottom == byNodeY)
    }

    @Test("A zero-sized canvas yields an empty result", arguments: [
        CGSize.zero,
        CGSize(width: 0, height: 100),
        CGSize(width: 100, height: 0)
    ])
    func zeroSize(size: CGSize) throws {
        let result = SankeyLayout.compute(graph: try graph([link("A", "B", 1)]), size: size)
        #expect(result.isEmpty)
        #expect(result.links.isEmpty)
    }

    @Test("An empty graph yields an empty result")
    func emptyGraph() throws {
        let result = SankeyLayout.compute(graph: try graph([]), size: size)
        #expect(result.isEmpty)
        #expect(result.nodeFrames.isEmpty)
    }

    @Test("Nodes never collapse below the minimum visible height")
    func minimumNodeHeight() throws {
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "C", 100_000), link("B", "C", 1)]),
            size: size
        )
        #expect(try #require(result.nodeFrames["B"]).height >= SankeyLayout.minimumNodeHeight)
    }

    @Test("Laid out nodes are ordered by layer and then vertically")
    func paletteOrder() throws {
        let result = SankeyLayout.compute(
            graph: try graph([link("A", "C", 30), link("B", "C", 10)]),
            size: size
        )
        #expect(result.nodes.map(\.id) == ["A", "B", "C"])
        #expect(result.nodes.map(\.paletteIndex) == [0, 1, 2])
        #expect(result.nodes.map(\.layer) == [0, 0, 1])
        #expect(result.nodes.map(\.indexInLayer) == [0, 1, 0])
    }
}
