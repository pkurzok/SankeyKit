import SankeyKit
import SwiftUI

/// A live diagram: drag the values, watch the ribbons morph, tap to select.
struct PlaygroundView: View {
    @State private var rent: Double = 1900
    @State private var groceries: Double = 800
    @State private var savings: Double = 2100
    @State private var showsSideGig = true
    @State private var selection: SankeySelection?

    var body: some View {
        DemoScreen(caption: caption) {
            SankeyChart {
                SankeyLink(from: "Salary", to: "Budget", value: 4800)
                if showsSideGig {
                    SankeyLink(from: "Side gig", to: "Budget", value: 700)
                }
                SankeyLink(from: "Budget", to: "Rent", value: rent)
                SankeyLink(from: "Budget", to: "Groceries", value: groceries)
                SankeyLink(from: "Budget", to: "Savings", value: savings)
                SankeyNode("Budget").label("Monthly Budget")
            }
            .sankeySelection($selection)
            .sankeyNodeWidth(14)
            .sankeyNodeCornerRadius(4)
        } controls: {
            VStack(alignment: .leading, spacing: 12) {
                selectionReadout

                valueSlider("Rent", value: $rent, range: 400...3000)
                valueSlider("Groceries", value: $groceries, range: 100...2000)
                valueSlider("Savings", value: $savings, range: 100...3000)

                Toggle("Side gig", isOn: $showsSideGig.animation(.snappy))
                    .toggleStyle(.switch)

                Button("Shuffle") {
                    withAnimation(.snappy) {
                        rent = .random(in: 700...2600)
                        groceries = .random(in: 200...1600)
                        savings = .random(in: 200...2600)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectionReadout: some View {
        let text: String = switch selection {
        case nil: "Nothing selected — tap a node or a flow"
        case .node(let name): "Node: \(name)"
        case .link(let source, let target): "Flow: \(source) → \(target)"
        }

        HStack {
            Text(text)
                .font(.footnote.weight(.medium))
            Spacer()
            if selection != nil {
                Button("Clear") { selection = nil }
                    .buttonStyle(.borderless)
                    .font(.footnote)
            }
        }
        .animation(.snappy, value: selection)
    }

    /// A slider that animates the diagram while it is being dragged.
    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        let animated = Binding(
            get: { value.wrappedValue },
            set: { newValue in withAnimation(.smooth(duration: 0.2)) { value.wrappedValue = newValue } }
        )

        return HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .frame(width: 78, alignment: .leading)
            Slider(value: animated, in: range)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit())
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var caption: String {
        """
        Everything at once: sliders change the link values inside withAnimation so the ribbons \
        morph rather than jump, the toggle adds and removes a mark, and tapping a node or a flow \
        keeps it and its neighbours lit while the rest dims.
        """
    }
}

#Preview {
    PlaygroundView()
}
