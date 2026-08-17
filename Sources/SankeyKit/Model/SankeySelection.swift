/// An element of a Sankey diagram that the user selected.
///
/// Bind a `SankeySelection?` state to a chart with ``SwiftUICore/View/sankeySelection(_:)``.
/// Selecting an element keeps it and everything it connects to at full opacity and dims the rest.
public enum SankeySelection: Hashable, Sendable {
    /// A node, identified by the name used in the links that touch it.
    case node(String)
    /// A link, identified by the names of its two endpoints.
    case link(source: String, target: String)
}

/// The elements a selection keeps at full opacity. Everything else is dimmed.
struct SankeyHighlight: Equatable {
    var nodes: Set<String>
    var links: Set<LinkID>

    /// Whether a node stays at full opacity.
    func contains(node id: String) -> Bool { nodes.contains(id) }

    /// Whether a link stays at full opacity.
    func contains(link id: LinkID) -> Bool { links.contains(id) }

    /// Works out what a selection highlights.
    ///
    /// Selecting a node keeps the node itself, every link touching it, and the node on the far end
    /// of each of those links. Selecting a link keeps the link and its two nodes.
    ///
    /// - Returns: `nil` when nothing is selected, or when the selection names an element the graph
    ///   does not contain — in both cases the whole diagram stays at full opacity.
    static func related(to selection: SankeySelection?, in graph: SankeyGraph) -> SankeyHighlight? {
        switch selection {
        case nil:
            return nil

        case .node(let id):
            guard graph[id] != nil else { return nil }
            var nodes: Set<String> = [id]
            var links: Set<LinkID> = []
            for link in graph.links where link.sourceID == id || link.targetID == id {
                links.insert(link.id)
                nodes.insert(link.sourceID)
                nodes.insert(link.targetID)
            }
            return SankeyHighlight(nodes: nodes, links: links)

        case .link(let source, let target):
            let id = LinkID(source: source, target: target)
            guard graph.links.contains(where: { $0.id == id }) else { return nil }
            return SankeyHighlight(nodes: [source, target], links: [id])
        }
    }
}
