@testable import SankeyKit
import Testing

/// Resolves builder content the way ``SankeyChart`` does.
private func build(@SankeyContentBuilder _ content: () -> some SankeyContent) -> some SankeyContent {
    content()
}

private func resolve(_ content: some SankeyContent) -> SankeyResolution {
    var resolution = SankeyResolution()
    content._resolve(into: &resolution)
    return resolution
}

private struct Flow {
    var from: String
    var to: String
    var amount: Double
}

@Suite("Content builder")
struct ContentBuilderTests {
    @Test("A block resolves its marks in declaration order")
    func blockKeepsOrder() {
        let resolution = resolve(build {
            SankeyLink(from: "A", to: "B", value: 1)
            SankeyLink(from: "B", to: "C", value: 2)
            SankeyLink(from: "C", to: "D", value: 3)
        })
        #expect(resolution.links.map(\.sourceID) == ["A", "B", "C"])
        #expect(resolution.links.map(\.value) == [1, 2, 3])
    }

    @Test("An empty block resolves to nothing")
    func emptyBlock() {
        let resolution = resolve(build {})
        #expect(resolution.links.isEmpty)
        #expect(resolution.nodeOverrides.isEmpty)
    }

    @Test("An if statement includes its content only when the condition holds", arguments: [true, false])
    func optionalBranch(include: Bool) {
        let resolution = resolve(build {
            SankeyLink(from: "A", to: "B", value: 1)
            if include {
                SankeyLink(from: "B", to: "Savings", value: 2)
            }
        })
        #expect(resolution.links.count == (include ? 2 : 1))
    }

    @Test("An if/else statement resolves exactly one branch", arguments: [true, false])
    func eitherBranch(useFirst: Bool) {
        let resolution = resolve(build {
            if useFirst {
                SankeyLink(from: "A", to: "First", value: 1)
            } else {
                SankeyLink(from: "A", to: "Second", value: 2)
                SankeyLink(from: "A", to: "Third", value: 3)
            }
        })
        #expect(resolution.links.map(\.targetID) == (useFirst ? ["First"] : ["Second", "Third"]))
    }

    @Test("A for loop resolves one group of marks per element")
    func forLoop() {
        let expenses = [("Rent", 1900.0), ("Food", 800.0), ("Transport", 300.0)]
        let resolution = resolve(build {
            for expense in expenses {
                SankeyLink(from: "Budget", to: expense.0, value: expense.1)
            }
        })
        #expect(resolution.links.map(\.targetID) == ["Rent", "Food", "Transport"])
        #expect(resolution.links.map(\.value) == [1900, 800, 300])
    }

    @Test("An empty for loop resolves to nothing")
    func emptyForLoop() {
        let empty: [String] = []
        let resolution = resolve(build {
            for name in empty {
                SankeyLink(from: "A", to: name, value: 1)
            }
        })
        #expect(resolution.links.isEmpty)
    }

    @Test("Node marks land in the overrides, not in the links")
    func nodeMarksAreOverrides() {
        let resolution = resolve(build {
            SankeyLink(from: "A", to: "B", value: 1)
            SankeyNode("B", layer: 4)
                .label("Bee")
        })
        #expect(resolution.links.count == 1)
        #expect(resolution.nodeOverrides.count == 1)
        #expect(resolution.nodeOverrides[0].name == "B")
        #expect(resolution.nodeOverrides[0].displayLabel == "Bee")
        #expect(resolution.nodeOverrides[0].pinnedLayer == 4)
    }

    @Test("Labelled values are carried through to the resolved link")
    func labelledValues() {
        let resolution = resolve(build {
            SankeyLink(
                from: .value("Source", "Salary"),
                to: .value("Target", "Budget"),
                value: .value("Amount", 4800)
            )
        })
        let link = resolution.links[0]
        #expect(link.sourceID == "Salary")
        #expect(link.targetID == "Budget")
        #expect(link.value == 4800)
        #expect(link.sourceLabel == "Source")
        #expect(link.targetLabel == "Target")
        #expect(link.valueLabel == "Amount")
    }

    @Test("Type-erased content resolves the same as the original")
    func typeErasure() {
        let original = build {
            SankeyLink(from: "A", to: "B", value: 1)
            SankeyLink(from: "B", to: "C", value: 2)
        }
        #expect(resolve(AnySankeyContent(original)).links.map(\.targetID) == resolve(original).links.map(\.targetID))
    }

    @Test("Empty content contributes nothing")
    func emptyContent() {
        #expect(resolve(EmptySankeyContent()).links.isEmpty)
    }
}

@Suite("Data-driven chart")
struct DataDrivenChartTests {
    private let flows = [
        Flow(from: "Coal", to: "Grid", amount: 40),
        Flow(from: "Wind", to: "Grid", amount: 35),
        Flow(from: "Grid", to: "Homes", amount: 50)
    ]

    @Test("The collection initializer flattens the data into links")
    func flattensCollection() {
        let chart = SankeyChart(flows) { flow in
            SankeyLink(
                from: .value("Source", flow.from),
                to: .value("Target", flow.to),
                value: .value("Amount", flow.amount)
            )
        }
        var resolution = SankeyResolution()
        chart.content._resolve(into: &resolution)
        #expect(resolution.links.map(\.sourceID) == ["Coal", "Wind", "Grid"])
        #expect(resolution.links.map(\.value) == [40, 35, 50])
    }

    @Test("An element may contribute several marks")
    func multipleMarksPerElement() {
        let chart = SankeyChart(["Rent", "Food"]) { name in
            SankeyLink(from: "Budget", to: name, value: 100)
            SankeyNode(name)
        }
        var resolution = SankeyResolution()
        chart.content._resolve(into: &resolution)
        #expect(resolution.links.count == 2)
        #expect(resolution.nodeOverrides.map(\.name) == ["Rent", "Food"])
    }

    @Test("Marks written in a builder produce the same graph as a hand-built resolution")
    func builderMatchesHandBuiltGraph() throws {
        let fromBuilder = try SankeyGraph(resolution: resolve(build {
            SankeyLink(from: "Salary", to: "Budget", value: 4800)
            SankeyLink(from: "Budget", to: "Rent", value: 1900)
            SankeyNode("Budget").label("Monthly Budget")
        }))
        let byHand = try graph(
            [link("Salary", "Budget", 4800), link("Budget", "Rent", 1900)],
            overrides: [NodeOverride(name: "Budget", displayLabel: "Monthly Budget")]
        )

        #expect(fromBuilder.nodes.map(\.id) == byHand.nodes.map(\.id))
        #expect(fromBuilder.nodes.map(\.label) == byHand.nodes.map(\.label))
        #expect(fromBuilder.layers == byHand.layers)
        #expect(fromBuilder.links.map(\.value) == byHand.links.map(\.value))
    }
}
