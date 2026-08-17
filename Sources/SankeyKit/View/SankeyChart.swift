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

    /// Creates a chart from marks written in a builder closure.
    public init(@SankeyContentBuilder content: () -> Content) {
        self.content = content()
    }

    init(resolvedContent: Content) {
        self.content = resolvedContent
    }

    public var body: some View {
        switch makeGraph() {
        case .success(let graph):
            GeometryReader { proxy in
                diagram(graph: graph, size: proxy.size)
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

    @ViewBuilder
    private func diagram(graph: SankeyGraph, size: CGSize) -> some View {
        let metrics = SankeyMetrics.default
        let layout = SankeyLayout.compute(graph: graph, size: size, metrics: metrics)
        let resolver = SankeyStyleResolver()
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        let slotWidth = Self.labelSlotWidth(size: size, layerCount: layout.layerCount, metrics: metrics)

        ZStack(alignment: .topLeading) {
            ForEach(layout.links) { laidOut in
                RibbonShape(geometry: laidOut.geometry)
                    .fill(resolver.linkStyle(laidOut, sourceNode: nodesByID[laidOut.id.source]))
                    .opacity(resolver.linkOpacity(laidOut, default: metrics.linkOpacity))
            }
            ForEach(layout.nodes) { node in
                NodeShape(frame: node.frame, cornerRadius: metrics.cornerRadius)
                    .fill(resolver.nodeStyle(node))
            }
            ForEach(layout.nodes) { node in
                NodeLabel(
                    node: node,
                    isTrailingColumn: node.layer == layout.layerCount - 1,
                    slotWidth: slotWidth
                )
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Horizontal room a label may use: the gap between two columns, within sensible bounds.
    static func labelSlotWidth(size: CGSize, layerCount: Int, metrics: SankeyMetrics) -> CGFloat {
        guard layerCount > 1 else { return max(0, size.width - metrics.nodeWidth - NodeLabel.gap) }
        let stride = (size.width - metrics.nodeWidth) / CGFloat(layerCount - 1)
        let room = stride - metrics.nodeWidth - 2 * NodeLabel.gap
        return min(max(room, 32), 160)
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
    public init<Data: RandomAccessCollection, C: SankeyContent>(
        _ data: Data,
        @SankeyContentBuilder content: @escaping (Data.Element) -> C
    ) where Content == SankeyForEachContent<Data, C> {
        self.init(resolvedContent: SankeyForEachContent(data, content: content))
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
    .frame(width: 480, height: 320)
}
