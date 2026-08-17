@testable import SankeyKit
import Testing

@Suite("Layer assignment")
struct LayerAssignmentTests {
    @Test("A linear chain produces consecutive layers")
    func linearChain() throws {
        let result = try graph([link("A", "B", 1), link("B", "C", 1)])
        #expect(result.layers == ["A": 0, "B": 1, "C": 2])
        #expect(result.layerCount == 3)
    }

    @Test("A diamond keeps the join node one layer behind the longest path")
    func diamond() throws {
        // A → B → D and A → C → D, plus a long path A → B → C → D forces C to layer 2.
        let result = try graph([
            link("A", "B", 1),
            link("A", "C", 1),
            link("B", "C", 1),
            link("C", "D", 1),
            link("B", "D", 1)
        ])
        #expect(result.layers == ["A": 0, "B": 1, "C": 2, "D": 3])
    }

    @Test("Longest path wins over shortest path")
    func longestPathWins() throws {
        // A → D directly, and A → B → C → D. D must sit at layer 3, not layer 1.
        let result = try graph([
            link("A", "D", 1),
            link("A", "B", 1),
            link("B", "C", 1),
            link("C", "D", 1)
        ])
        #expect(result.layers["D"] == 3)
    }

    @Test("A pinned layer overrides the computed one")
    func pinnedLayerWins() throws {
        let result = try graph(
            [link("A", "B", 1), link("B", "C", 1)],
            overrides: [NodeOverride(name: "B", pinnedLayer: 4)]
        )
        #expect(result.layers["B"] == 4)
        #expect(result.layers["A"] == 0)
        #expect(result.layers["C"] == 2)
    }

    @Test("Layers are normalized so the leftmost column is zero")
    func negativePinnedLayerNormalizes() throws {
        let result = try graph(
            [link("A", "B", 1)],
            overrides: [NodeOverride(name: "A", pinnedLayer: -3)]
        )
        #expect(result.layers == ["A": 0, "B": 4])
    }

    @Test("Disconnected components both start at layer zero")
    func disconnectedComponents() throws {
        let result = try graph([link("A", "B", 1), link("X", "Y", 1)])
        #expect(result.layers == ["A": 0, "B": 1, "X": 0, "Y": 1])
    }

    @Test("A cycle throws with the cycle path")
    func cycleIsDetected() {
        #expect(throws: SankeyGraphError.cycle(path: ["A", "B", "C", "A"])) {
            try graph([link("A", "B", 1), link("B", "C", 1), link("C", "A", 1)])
        }
    }

    @Test("A cycle is detected even when reachable from a valid source")
    func cycleBehindASource() {
        let error = #expect(throws: SankeyGraphError.self) {
            try graph([
                link("Start", "A", 1),
                link("A", "B", 1),
                link("B", "A", 1)
            ])
        }
        guard case .cycle(let path)? = error else {
            Issue.record("expected a cycle error")
            return
        }
        #expect(path.first == path.last)
        #expect(Set(path) == ["A", "B"])
    }

    @Test("An empty graph has no layers")
    func emptyGraph() throws {
        let result = try graph([])
        #expect(result.layers.isEmpty)
        #expect(result.layerCount == 0)
        #expect(result.isEmpty)
    }
}
