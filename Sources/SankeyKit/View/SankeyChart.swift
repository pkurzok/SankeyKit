import os
import SwiftUI

/// A Sankey diagram, built from ``SankeyLink`` and ``SankeyNode`` marks.
///
/// Nodes are implicit: a link creates whichever of its two endpoints does not exist yet, and the
/// columns are inferred from the flow direction. That makes the common case free of boilerplate.
///
/// ```swift
/// SankeyChart {
///     SankeyLink(from: "Salary", to: "Budget", value: 4800)
///     SankeyLink(from: "Side gig", to: "Budget", value: 700)
///     SankeyLink(from: "Budget", to: "Rent", value: 1900)
///     SankeyLink(from: "Budget", to: "Savings", value: 3600)
/// }
/// ```
///
/// Use ``init(_:content:)`` to build the same chart from a collection, and the `sankey…` chart
/// modifiers such as ``SwiftUICore/View/sankeyNodeWidth(_:)`` to style it.
///
/// > Note: The links must not form a cycle. A cyclic graph cannot be laid out in columns; the
/// chart then draws a diagnostic instead of a diagram and logs the offending path.
public struct SankeyChart<Content: SankeyContent>: View {
    /// The mark tree this chart draws.
    let content: Content

    @Environment(\.sankeyConfiguration) private var configuration

    /// Creates a chart from marks written in a builder closure.
    public init(@SankeyContentBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        switch makeGraph() {
        case .success(let graph):
            GeometryReader { proxy in
                SankeyDiagram(
                    graph: graph,
                    size: proxy.size,
                    metrics: configuration.metrics,
                    scale: configuration.colorScale,
                    selection: configuration.selection
                )
            }
            .clipped()
        case .failure(let error):
            SankeyDiagnosticView(error: error)
        }
    }

    private func makeGraph() -> Result<SankeyGraph, SankeyGraphError> {
        var resolution = SankeyResolution()
        content._resolve(into: &resolution)
        do {
            return .success(try SankeyGraph(resolution: resolution))
        } catch {
            return .failure(error)
        }
    }
}

extension SankeyChart {
    /// Creates a chart with one group of marks per element of a collection.
    ///
    /// ```swift
    /// SankeyChart(flows) { flow in
    ///     SankeyLink(
    ///         from: .value("Source", flow.from),
    ///         to: .value("Target", flow.to),
    ///         value: .value("Amount", flow.amount)
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - data: The collection to draw.
    ///   - content: Builds the marks for one element.
    ///
    /// > Note: This initializer assigns the stored property instead of delegating to another
    /// initializer. Xcode's preview instrumentation wraps every expression in a call it cannot
    /// nest `self.init` inside, which would break any `#Preview` declared in this file.
    public init<Data: RandomAccessCollection, C: SankeyContent>(
        _ data: Data,
        @SankeyContentBuilder content: @escaping (Data.Element) -> C
    ) where Content == SankeyForEachContent<Data, C> {
        self.content = SankeyForEachContent(data, content: content)
    }
}

/// Shown in place of the diagram when the graph cannot be laid out.
struct SankeyDiagnosticView: View {
    var error: SankeyGraphError

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                SankeyGraph.logger.error("SankeyChart cannot be drawn: \(message, privacy: .public)")
            }
    }

    private var message: String {
        switch error {
        case .cycle(let path):
            return "SankeyChart: the links form a cycle — \(path.joined(separator: " → "))"
        }
    }
}

#Preview("Finance") {
    SankeyChart {
        SankeyLink(from: "Salary", to: "Budget", value: 4800)
        SankeyLink(from: "Side gig", to: "Budget", value: 700)
        SankeyLink(from: "Budget", to: "Rent", value: 1900)
        SankeyLink(from: "Budget", to: "Groceries", value: 800)
        SankeyLink(from: "Budget", to: "Transport", value: 300)
        SankeyLink(from: "Budget", to: "Savings", value: 2500)
        SankeyNode("Budget")
            .label("Monthly Budget")
    }
    .padding(24)
    .frame(maxWidth: 520, maxHeight: 320)
}

#Preview("Styled") {
    let flows = [
        ("Coal", "Power plant", 40.0),
        ("Gas", "Power plant", 25.0),
        ("Wind", "Grid", 30.0),
        ("Power plant", "Grid", 45.0),
        ("Power plant", "Losses", 20.0),
        ("Grid", "Homes", 40.0),
        ("Grid", "Industry", 35.0)
    ]
    return SankeyChart(flows) { flow in
        SankeyLink(
            from: .value("Source", flow.0),
            to: .value("Target", flow.1),
            value: .value("Energy", flow.2)
        )
        if flow.1 == "Losses" {
            SankeyNode("Losses").foregroundStyle(.gray)
        }
    }
    .sankeyNodeWidth(16)
    .sankeyNodeSpacing(14)
    .sankeyNodeCornerRadius(8)
    .sankeyLinkSpacing(5)
    .sankeyLinkCurvature(0.55)
    .sankeyLinkOpacity(0.85)
    .sankeyColorScale([.blue, .cyan, .teal, .green, .yellow, .orange, .pink])
    .padding(24)
    .frame(maxWidth: 520, maxHeight: 320)
}

#Preview("Interactive") {
    @Previewable @State var selection: SankeySelection?
    @Previewable @State var savesMore = false

    let readout: String = switch selection {
    case nil: "Nothing selected — tap a node or a flow"
    case .node(let name): "Node: \(name)"
    case .link(let source, let target): "Flow: \(source) → \(target)"
    }

    VStack(spacing: 16) {
        SankeyChart {
            SankeyLink(from: "Salary", to: "Budget", value: 4800)
            SankeyLink(from: "Budget", to: "Rent", value: 1900)
            SankeyLink(from: "Budget", to: "Groceries", value: 800)
            SankeyLink(from: "Budget", to: "Savings", value: savesMore ? 2100 : 700)
        }
        .sankeySelection($selection)
        .frame(maxHeight: 280)

        Text(readout)
            .font(.footnote)
            .foregroundStyle(.secondary)

        Button(savesMore ? "Save less" : "Save more") {
            withAnimation(.snappy) { savesMore.toggle() }
        }
    }
    .padding(24)
}
