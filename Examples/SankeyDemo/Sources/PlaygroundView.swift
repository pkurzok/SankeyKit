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
                SelectionReadout(selection: $selection)

                ValueSlider("Rent", value: $rent, range: 400...3000)
                ValueSlider("Groceries", value: $groceries, range: 100...2000)
                ValueSlider("Savings", value: $savings, range: 100...3000)

                // Animated in the setter rather than via `$showsSideGig.animation(.snappy)`:
                // iOS 27 drops the transaction a `Binding.animation(_:)` attaches to a Toggle's
                // write, so the chart would jump. See `FinanceDemoView` for the full note. The
                // sliders above keep the binding-animation pattern — Slider's write path is fine.
                Toggle("Side gig", isOn: Binding(
                    get: { showsSideGig },
                    set: { newValue in withAnimation(.snappy) { showsSideGig = newValue } }
                ))
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

    private var caption: String {
        """
        Everything at once: the sliders write the link values through an animated binding so the \
        ribbons morph rather than jump, the toggle adds and removes a mark, and tapping a node or \
        a flow keeps it and its neighbours lit while the rest dims.
        """
    }
}

/// What is selected right now, with a way to clear it.
private struct SelectionReadout: View {
    @Binding var selection: SankeySelection?

    var body: some View {
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
}

/// A labelled slider that animates the diagram while it is being dragged.
///
/// The animation rides on the binding rather than on a `withAnimation` in a setter, so every write
/// the slider makes — drag or keyboard — morphs the ribbons instead of jumping.
private struct ValueSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .frame(width: 78, alignment: .leading)
            Slider(value: $value.animation(.smooth(duration: 0.2)), in: range)
            Text(value.formatted(.number.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit())
                .frame(width: 48, alignment: .trailing)
        }
    }
}

#Preview {
    PlaygroundView()
}
