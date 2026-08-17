import SwiftUI

/// Draws a node rectangle at an absolute frame in the chart's coordinate space.
struct NodeShape: Shape {
    var frame: CGRect
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: frame, cornerRadius: min(cornerRadius, frame.height / 2))
    }
}

/// The text next to a node.
///
/// Labels always point inward: nodes in the last column are labelled on their leading side,
/// every other node on its trailing side. That keeps text inside the chart bounds.
struct NodeLabel: View {
    var node: LaidOutNode
    /// Whether the node sits in the rightmost column.
    var isTrailingColumn: Bool
    /// Horizontal room available for the text.
    var slotWidth: CGFloat

    /// Distance between the node rectangle and its label.
    static let gap: CGFloat = 6

    var body: some View {
        Text(node.node.label)
            .font(.caption)
            .lineLimit(2)
            .multilineTextAlignment(isTrailingColumn ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: slotWidth, alignment: isTrailingColumn ? .trailing : .leading)
            .position(x: centerX, y: node.frame.midY)
    }

    private var centerX: CGFloat {
        isTrailingColumn
            ? node.frame.minX - Self.gap - slotWidth / 2
            : node.frame.maxX + Self.gap + slotWidth / 2
    }
}
