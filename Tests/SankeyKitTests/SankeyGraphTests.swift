@testable import SankeyKit
import SwiftUI
import Testing

@Suite("Graph resolution")
struct SankeyGraphTests {
    @Test("Nodes are derived from link endpoints and deduplicated")
    func implicitNodeDerivation() throws {
        let result = try graph([
            link("Salary", "Budget", 4800),
            link("Side gig", "Budget", 700),
            link("Budget", "Rent", 1900)
        ])
        #expect(result.nodes.map(\.id) == ["Salary", "Budget", "Side gig", "Rent"])
        #expect(result.nodes.filter { $0.id == "Budget" }.count == 1)
    }

    @Test("Inflow, outflow and magnitude are accumulated per node")
    func flowTotals() throws {
        let result = try graph([
            link("Salary", "Budget", 4800),
            link("Side gig", "Budget", 700),
            link("Budget", "Rent", 1900)
        ])
        let budget = try #require(result["Budget"])
        #expect(budget.inflow == 5500)
        #expect(budget.outflow == 1900)
        #expect(budget.magnitude == 5500)
    }

    @Test("Node overrides merge by name")
    func overridesMergeByName() throws {
        let result = try graph(
            [link("A", "B", 1)],
            overrides: [
                NodeOverride(name: "B", displayLabel: "Bee", style: AnyShapeStyle(.red), pinnedLayer: 3)
            ]
        )
        let node = try #require(result["B"])
        #expect(node.displayLabel == "Bee")
        #expect(node.label == "Bee")
        #expect(node.style != nil)
        #expect(node.pinnedLayer == 3)
    }

    @Test("A node without an override falls back to its id as label")
    func defaultLabel() throws {
        let result = try graph([link("A", "B", 1)])
        #expect(try #require(result["A"]).label == "A")
    }

    @Test("Overrides for unknown names are ignored")
    func unknownOverrideIgnored() throws {
        let result = try graph([link("A", "B", 1)], overrides: [NodeOverride(name: "Ghost", displayLabel: "?")])
        #expect(result.nodes.map(\.id) == ["A", "B"])
    }

    @Test("Links with a non-positive value are dropped", arguments: [0.0, -5.0])
    func nonPositiveLinksDropped(value: Double) throws {
        let result = try graph([link("A", "B", 10), link("A", "C", value)])
        #expect(result.links.count == 1)
        #expect(result.nodes.map(\.id) == ["A", "B"])
    }

    @Test("Self-links are dropped")
    func selfLinksDropped() throws {
        let result = try graph([link("A", "A", 10), link("A", "B", 5)])
        #expect(result.links.count == 1)
        #expect(result.links[0].targetID == "B")
    }

    @Test("Duplicate endpoints accumulate into a single link")
    func duplicateLinksAccumulate() throws {
        let result = try graph([link("A", "B", 3), link("A", "B", 7)])
        #expect(result.links.count == 1)
        #expect(result.links[0].value == 10)
        #expect(try #require(result["A"]).outflow == 10)
    }

    @Test("Incoming and outgoing lookups keep declaration order")
    func adjacencyLookups() throws {
        let result = try graph([
            link("A", "C", 1),
            link("B", "C", 2),
            link("C", "D", 3)
        ])
        #expect(result.incomingLinks(of: "C").map(\.sourceID) == ["A", "B"])
        #expect(result.outgoingLinks(of: "C").map(\.targetID) == ["D"])
        #expect(result.outgoingLinks(of: "D").isEmpty)
    }

    @Test("Nodes are bucketed by layer in first-appearance order")
    func nodesByLayer() throws {
        let result = try graph([
            link("A", "C", 1),
            link("B", "C", 1)
        ])
        let buckets = result.nodesByLayer()
        #expect(buckets.count == 2)
        #expect(buckets[0].map(\.id) == ["A", "B"])
        #expect(buckets[1].map(\.id) == ["C"])
    }

    @Test("A graph with only invalid links is empty")
    func onlyInvalidLinks() throws {
        let result = try graph([link("A", "A", 5), link("B", "C", 0)])
        #expect(result.isEmpty)
        #expect(result.links.isEmpty)
    }
}
