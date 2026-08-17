import os
import SwiftUI

/// Identifies a link by its two endpoints.
struct LinkID: Hashable, Sendable {
    var source: String
    var target: String
}

/// A ``SankeyLink`` mark after content resolution, before graph validation.
struct ResolvedLink: Sendable {
    var sourceID: String
    var targetID: String
    var value: Double

    /// Label of the source dimension, e.g. `"Source"`, when declared with ``SankeyValue``.
    var sourceLabel: String?
    /// Label of the target dimension, e.g. `"Target"`, when declared with ``SankeyValue``.
    var targetLabel: String?
    /// Label of the value dimension, e.g. `"Amount"`, when declared with ``SankeyValue``.
    var valueLabel: String?

    var style: AnyShapeStyle?
    var opacity: Double?

    var id: LinkID { LinkID(source: sourceID, target: targetID) }
}

/// A ``SankeyNode`` mark after content resolution.
struct NodeOverride: Sendable {
    var name: String
    var displayLabel: String?
    var style: AnyShapeStyle?
    var pinnedLayer: Int?
}

/// A node of the validated graph. Nodes are derived from link endpoints.
struct ResolvedNode: Sendable {
    var id: String
    var displayLabel: String?
    var style: AnyShapeStyle?
    var pinnedLayer: Int?
    var inflow: Double = 0
    var outflow: Double = 0

    /// The thickness a node has to accommodate: the larger of its two sides.
    var magnitude: Double { max(inflow, outflow) }

    /// The text drawn next to the node.
    var label: String { displayLabel ?? id }
}

/// Problems that make a graph impossible to lay out.
enum SankeyGraphError: Error, Equatable, Sendable {
    /// The graph contains a directed cycle.
    ///
    /// The associated path lists the nodes of the cycle in order, with the entry node
    /// repeated at the end, for example `["Budget", "Salary", "Budget"]`.
    case cycle(path: [String])
}

extension SankeyGraphError: CustomStringConvertible {
    var description: String {
        switch self {
        case .cycle(let path):
            return "cycle \(path.joined(separator: " → "))"
        }
    }
}

/// A validated, deduplicated Sankey graph — the only input to ``SankeyLayout``.
struct SankeyGraph: Sendable {
    /// Nodes in first-appearance order.
    private(set) var nodes: [ResolvedNode]
    /// Links that survived validation, in declaration order.
    private(set) var links: [ResolvedLink]
    /// Layer index per node id, starting at zero.
    private(set) var layers: [String: Int]

    private let indexByID: [String: Int]

    /// An empty graph — nothing to draw.
    var isEmpty: Bool { nodes.isEmpty }

    /// The number of layers (columns) in the diagram.
    var layerCount: Int { (layers.values.max().map { $0 + 1 }) ?? 0 }

    subscript(nodeID: String) -> ResolvedNode? {
        indexByID[nodeID].map { nodes[$0] }
    }

    /// Builds the graph from resolved content.
    ///
    /// Nodes are derived from link endpoints and deduplicated by name. Node overrides are
    /// merged in by name. Self-links and links with a non-positive value are dropped and
    /// logged. Layers are inferred by longest-path topological ordering.
    ///
    /// - Throws: ``SankeyGraphError/cycle(path:)`` when the links form a directed cycle.
    init(resolution: SankeyResolution) throws(SankeyGraphError) {
        var validLinks: [ResolvedLink] = []
        var seenLinkIDs: Set<LinkID> = []

        for link in resolution.links {
            guard link.value > 0 else {
                Self.logger.error(
                    "Dropping link \(link.sourceID, privacy: .public) → \(link.targetID, privacy: .public): value must be positive."
                )
                continue
            }
            guard link.sourceID != link.targetID else {
                Self.logger.error("Dropping self-link on \(link.sourceID, privacy: .public).")
                continue
            }
            if seenLinkIDs.contains(link.id) {
                // Duplicate endpoints: accumulate into the existing link so a node's
                // in/outflow stays consistent with what is drawn.
                if let existing = validLinks.firstIndex(where: { $0.id == link.id }) {
                    validLinks[existing].value += link.value
                }
                continue
            }
            seenLinkIDs.insert(link.id)
            validLinks.append(link)
        }

        var order: [String] = []
        var byID: [String: ResolvedNode] = [:]

        func touch(_ id: String) {
            if byID[id] == nil {
                byID[id] = ResolvedNode(id: id)
                order.append(id)
            }
        }

        for link in validLinks {
            touch(link.sourceID)
            touch(link.targetID)
            byID[link.sourceID]?.outflow += link.value
            byID[link.targetID]?.inflow += link.value
        }

        for override in resolution.nodeOverrides {
            // A node mark for a name that no link mentions has nothing to attach to.
            guard byID[override.name] != nil else {
                Self.logger.error(
                    "SankeyNode(\"\(override.name, privacy: .public)\") does not appear in any link and is ignored."
                )
                continue
            }
            if let label = override.displayLabel { byID[override.name]?.displayLabel = label }
            if let style = override.style { byID[override.name]?.style = style }
            if let layer = override.pinnedLayer { byID[override.name]?.pinnedLayer = layer }
        }

        let orderedNodes = order.compactMap { byID[$0] }
        self.nodes = orderedNodes
        self.links = validLinks
        self.indexByID = Dictionary(
            uniqueKeysWithValues: orderedNodes.enumerated().map { ($0.element.id, $0.offset) }
        )
        self.layers = try LayerAssignment.assignLayers(nodes: orderedNodes, links: validLinks)
    }

    /// Nodes grouped by layer, outer index = layer, inner order = first-appearance order.
    func nodesByLayer() -> [[ResolvedNode]] {
        guard layerCount > 0 else { return [] }
        var buckets = [[ResolvedNode]](repeating: [], count: layerCount)
        for node in nodes {
            buckets[layers[node.id] ?? 0].append(node)
        }
        return buckets
    }

    /// Outgoing links of a node, in declaration order.
    func outgoingLinks(of nodeID: String) -> [ResolvedLink] {
        links.filter { $0.sourceID == nodeID }
    }

    /// Incoming links of a node, in declaration order.
    func incomingLinks(of nodeID: String) -> [ResolvedLink] {
        links.filter { $0.targetID == nodeID }
    }

    static let logger = Logger(subsystem: "de.peterkurzok.SankeyKit", category: "layout")
}
