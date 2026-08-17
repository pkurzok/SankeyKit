import SwiftUI

/// Draws a node rectangle at an absolute frame in the chart's coordinate space.
struct NodeShape: Shape {
    var frame: CGRect
    var cornerRadius: CGFloat

    /// Lets a node slide and grow smoothly when the values behind it change.
    var animatableData: CGRect.AnimatableData {
        get { frame.animatableData }
        set { frame.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: frame, cornerRadius: min(cornerRadius, frame.height / 2))
    }
}

/// The text next to a node.
struct NodeLabel: View {
    /// Where a label sits relative to its node.
    enum Placement: Equatable {
        /// Outside the diagram on the left, right-aligned against the node. Used by the first column.
        case leading
        /// Outside the diagram on the right, left-aligned against the node. Used by the last column.
        case trailing
        /// Centred on the node, over the ribbons. Used by every column in between.
        case over
    }

    var node: LaidOutNode
    var placement: Placement
    /// Horizontal room the text may use.
    var slotWidth: CGFloat

    /// Distance between the node rectangle and its label.
    static let gap: CGFloat = 8

    var body: some View {
        text
            .font(.caption)
            .lineLimit(2)
            .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: slotWidth, alignment: alignment)
            .position(x: centerX, y: node.frame.midY)
    }

    @ViewBuilder
    private var text: some View {
        let label = Text(node.node.label)
        switch placement {
        case .leading, .trailing:
            label
        case .over:
            // A label in the middle of the diagram lies on top of the ribbons, so it carries the
            // page background with it to stay readable.
            label
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private var alignment: Alignment {
        switch placement {
        case .leading: .trailing
        case .trailing: .leading
        case .over: .center
        }
    }

    private var centerX: CGFloat {
        switch placement {
        case .leading: node.frame.minX - Self.gap - slotWidth / 2
        case .trailing: node.frame.maxX + Self.gap + slotWidth / 2
        case .over: node.frame.midX
        }
    }
}
