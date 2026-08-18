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

    /// The traits an element carries: selected when it is the current selection, and a button
    /// whenever the chart can select at all.
    ///
    /// Computing the set here keeps the modifier chain in ``SwiftUICore/View/sankeyNodeAccessibility(_:isSelected:sortPriority:selectAction:)``
    /// a single static type. Branching there instead would wrap every node and ribbon in a
    /// `_ConditionalContent`, adding a structural boundary to the view tree for no gain.
    static func traits(isSelected: Bool, isSelectable: Bool) -> AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isSelected { traits.formUnion(.isSelected) }
        if isSelectable { traits.formUnion(.isButton) }
        return traits
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
    ///   - selectAction: What activating the element does, or `nil` on a read-only chart. When
    ///     given, the node announces as a button and activating it toggles the selection; when
    ///     `nil` the element does not respond to interaction and carries no button trait.
    func sankeyNodeAccessibility(
        _ node: LaidOutNode,
        isSelected: Bool,
        sortPriority: Double,
        selectAction: (() -> Void)? = nil
    ) -> some View {
        accessibilityElement()
            .accessibilityLabel(Text(node.node.label))
            .accessibilityValue(Text(SankeyAccessibility.nodeValue(node)))
            .accessibilitySortPriority(sortPriority)
            .accessibilityAddTraits(
                SankeyAccessibility.traits(isSelected: isSelected, isSelectable: selectAction != nil)
            )
            .accessibilityAction { selectAction?() }
            .accessibilityRespondsToUserInteraction(selectAction != nil)
    }

    /// Turns a ribbon into a single accessibility element.
    ///
    /// - Parameters:
    ///   - link: The link being drawn.
    ///   - source: The node the link leaves, used for its display label.
    ///   - target: The node the link enters, used for its display label.
    ///   - isSelected: Whether the link is the current selection.
    ///   - sortPriority: Higher values are read first.
    ///   - selectAction: What activating the element does, or `nil` on a read-only chart. When
    ///     given, the ribbon announces as a button — which is the only way to reach it without a
    ///     pointer, because the synthesized activation tap lands on the element's centre point,
    ///     outside a curved ribbon's shape.
    func sankeyLinkAccessibility(
        _ link: LaidOutLink,
        from source: LaidOutNode?,
        to target: LaidOutNode?,
        isSelected: Bool,
        sortPriority: Double,
        selectAction: (() -> Void)? = nil
    ) -> some View {
        accessibilityElement()
            .accessibilityLabel(Text(SankeyAccessibility.linkLabel(link, from: source, to: target)))
            .accessibilityValue(Text(SankeyAccessibility.linkValue(link)))
            .accessibilitySortPriority(sortPriority)
            .accessibilityAddTraits(
                SankeyAccessibility.traits(isSelected: isSelected, isSelectable: selectAction != nil)
            )
            .accessibilityAction { selectAction?() }
            .accessibilityRespondsToUserInteraction(selectAction != nil)
    }
}
