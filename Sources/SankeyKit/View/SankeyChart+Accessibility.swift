import SwiftUI

/// Accessibility descriptions for the two kinds of chart element.
///
/// Both are derived from the same data the diagram draws, so what VoiceOver reads and what the
/// eye sees can never drift apart.
enum SankeyAccessibility {
    /// Formats a flow value the way it is spoken, honouring the reader's locale.
    static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// What a node announces: its label, and the larger of its in- and outflow.
    static func nodeValue(_ node: LaidOutNode) -> String {
        formatted(node.node.magnitude)
    }

    /// What a link announces, for example `"Salary to Budget"`.
    static func linkLabel(_ link: LaidOutLink, from source: LaidOutNode?, to target: LaidOutNode?) -> String {
        let sourceName = source?.node.label ?? link.id.source
        let targetName = target?.node.label ?? link.id.target
        return "\(sourceName) to \(targetName)"
    }

    /// What a link announces as its value.
    ///
    /// When the mark was written with ``SankeyValue``, its label is included — a link declared with
    /// `value: .value("Amount", 4800)` announces `"Amount: 4,800"` rather than just `"4,800"`.
    static func linkValue(_ link: LaidOutLink) -> String {
        let amount = formatted(link.link.value)
        guard let label = link.link.valueLabel else { return amount }
        return "\(label): \(amount)"
    }
}

extension View {
    /// Turns a node rectangle into a single accessibility element.
    ///
    /// - Parameters:
    ///   - node: The node being drawn.
    ///   - isSelected: Whether the node is the current selection.
    ///   - sortPriority: Higher values are read first. Nodes are ordered by column and then by
    ///     vertical position, and all of them are read before the links.
    func sankeyNodeAccessibility(_ node: LaidOutNode, isSelected: Bool, sortPriority: Double) -> some View {
        accessibilityElement()
            .accessibilityLabel(Text(node.node.label))
            .accessibilityValue(Text(SankeyAccessibility.nodeValue(node)))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilitySortPriority(sortPriority)
    }

    /// Turns a ribbon into a single accessibility element.
    ///
    /// - Parameters:
    ///   - link: The link being drawn.
    ///   - source: The node the link leaves, used for its display label.
    ///   - target: The node the link enters, used for its display label.
    ///   - isSelected: Whether the link is the current selection.
    ///   - sortPriority: Higher values are read first.
    func sankeyLinkAccessibility(
        _ link: LaidOutLink,
        from source: LaidOutNode?,
        to target: LaidOutNode?,
        isSelected: Bool,
        sortPriority: Double
    ) -> some View {
        accessibilityElement()
            .accessibilityLabel(Text(SankeyAccessibility.linkLabel(link, from: source, to: target)))
            .accessibilityValue(Text(SankeyAccessibility.linkValue(link)))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilitySortPriority(sortPriority)
    }
}
