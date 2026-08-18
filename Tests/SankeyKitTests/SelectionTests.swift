import CoreGraphics
@testable import SankeyKit
import SwiftUI
import Testing

@Suite("Selection")
struct SelectionTests {
    /// Salary and Side gig feed Budget; Budget feeds Rent and Savings.
    private func financeGraph() throws -> SankeyGraph {
        try graph([
            link("Salary", "Budget", 4800),
            link("Side gig", "Budget", 700),
            link("Budget", "Rent", 1900),
            link("Budget", "Savings", 3600)
        ])
    }

    @Test("No selection highlights nothing, so the whole diagram stays lit")
    func noSelection() throws {
        #expect(SankeyHighlight.related(to: nil, in: try financeGraph()) == nil)
    }

    @Test("Selecting a middle node keeps it, its links, and their counterparts")
    func middleNodeSelection() throws {
        let highlight = try #require(
            SankeyHighlight.related(to: .node("Budget"), in: try financeGraph())
        )
        #expect(highlight.nodes == ["Budget", "Salary", "Side gig", "Rent", "Savings"])
        #expect(highlight.links == [
            LinkID(source: "Salary", target: "Budget"),
            LinkID(source: "Side gig", target: "Budget"),
            LinkID(source: "Budget", target: "Rent"),
            LinkID(source: "Budget", target: "Savings")
        ])
    }

    @Test("Selecting a leaf node keeps only its single flow")
    func leafNodeSelection() throws {
        let highlight = try #require(
            SankeyHighlight.related(to: .node("Rent"), in: try financeGraph())
        )
        #expect(highlight.nodes == ["Rent", "Budget"])
        #expect(highlight.links == [LinkID(source: "Budget", target: "Rent")])
        #expect(highlight.contains(node: "Salary") == false)
        #expect(highlight.contains(link: LinkID(source: "Salary", target: "Budget")) == false)
    }

    @Test("Selecting a link keeps the link and its two nodes")
    func linkSelection() throws {
        let highlight = try #require(
            SankeyHighlight.related(to: .link(source: "Budget", target: "Rent"), in: try financeGraph())
        )
        #expect(highlight.nodes == ["Budget", "Rent"])
        #expect(highlight.links == [LinkID(source: "Budget", target: "Rent")])
        #expect(highlight.contains(node: "Salary") == false)
    }

    @Test("Selecting something the graph does not contain dims nothing")
    func unknownSelection() throws {
        let sankey = try financeGraph()
        #expect(SankeyHighlight.related(to: .node("Ghost"), in: sankey) == nil)
        #expect(SankeyHighlight.related(to: .link(source: "Rent", target: "Salary"), in: sankey) == nil)
    }

    @Test("Unrelated elements are dimmed, related ones are not")
    func dimming() {
        #expect(SankeyDiagram.dimming(true) == 1)
        #expect(SankeyDiagram.dimming(false) == SankeyDiagram.dimmedOpacity)
        #expect(SankeyDiagram.dimmedOpacity < 1)
    }

    @Test("Tapping an element selects it, tapping it again clears the selection")
    func toggling() {
        var stored: SankeySelection?
        let binding = Binding(get: { stored }, set: { stored = $0 })

        SankeyDiagram.toggle(.node("Budget"), in: binding)
        #expect(stored == .node("Budget"))

        SankeyDiagram.toggle(.node("Budget"), in: binding)
        #expect(stored == nil)

        SankeyDiagram.toggle(.link(source: "Budget", target: "Rent"), in: binding)
        #expect(stored == .link(source: "Budget", target: "Rent"))

        SankeyDiagram.toggle(.node("Rent"), in: binding)
        #expect(stored == .node("Rent"))
    }

    @Test("Without a binding a tap does nothing")
    func togglingWithoutBinding() {
        SankeyDiagram.toggle(.node("Budget"), in: nil)
    }

    /// The accessibility action the diagram attaches is a closure over the very same toggle the tap
    /// gesture calls, so activating an element from VoiceOver must behave exactly like tapping it.
    @Test("The accessibility action toggles selection the same way a tap does")
    func togglingThroughAnAction() {
        var stored: SankeySelection?
        let binding = Binding(get: { stored }, set: { stored = $0 })
        func action(for value: SankeySelection) -> () -> Void {
            { SankeyDiagram.toggle(value, in: binding) }
        }

        action(for: .node("Budget"))()
        #expect(stored == .node("Budget"))

        action(for: .node("Budget"))()
        #expect(stored == nil)

        action(for: .link(source: "Budget", target: "Rent"))()
        #expect(stored == .link(source: "Budget", target: "Rent"))

        action(for: .node("Salary"))()
        #expect(stored == .node("Salary"))
    }
}

@Suite("Accessibility descriptions")
struct AccessibilityTests {
    private func layout() throws -> SankeyLayoutResult {
        var custom = link("Salary", "Budget", 4800)
        custom.valueLabel = "Amount"
        return SankeyLayout.compute(
            graph: try graph(
                [custom, link("Budget", "Rent", 1900)],
                overrides: [NodeOverride(name: "Budget", displayLabel: "Monthly Budget")]
            ),
            size: CGSize(width: 400, height: 200)
        )
    }

    @Test("A node announces its label and total flow")
    func nodeDescription() throws {
        let result = try layout()
        let budget = try #require(result.nodes.first { $0.id == "Budget" })
        #expect(budget.node.label == "Monthly Budget")
        #expect(SankeyAccessibility.nodeValue(budget) == SankeyAccessibility.formatted(4800))
    }

    @Test("A link announces both endpoints by their display labels")
    func linkLabel() throws {
        let result = try layout()
        let laidOut = try #require(result.links.first { $0.id.target == "Budget" })
        let label = SankeyAccessibility.linkLabel(
            laidOut,
            from: result.nodes.first { $0.id == "Salary" },
            to: result.nodes.first { $0.id == "Budget" }
        )
        #expect(label == "Salary to Monthly Budget")
    }

    /// Traits are computed rather than branched on in the view body, which keeps every element a
    /// single static view type; this is the rule that decides what assistive technologies announce.
    @Test("Only a selectable chart announces its elements as buttons")
    func traits() {
        #expect(SankeyAccessibility.traits(isSelected: false, isSelectable: false) == [])
        #expect(SankeyAccessibility.traits(isSelected: true, isSelectable: false) == .isSelected)
        #expect(SankeyAccessibility.traits(isSelected: false, isSelectable: true) == .isButton)
        #expect(
            SankeyAccessibility.traits(isSelected: true, isSelectable: true) == [.isSelected, .isButton]
        )
    }

    @Test("A link declared with a labelled value announces that label")
    func linkValueUsesSankeyValueLabel() throws {
        let result = try layout()
        let labelled = try #require(result.links.first { $0.id.target == "Budget" })
        let plain = try #require(result.links.first { $0.id.target == "Rent" })

        #expect(SankeyAccessibility.linkValue(labelled) == "Amount: \(SankeyAccessibility.formatted(4800))")
        #expect(SankeyAccessibility.linkValue(plain) == SankeyAccessibility.formatted(1900))
    }
}
