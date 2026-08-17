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
