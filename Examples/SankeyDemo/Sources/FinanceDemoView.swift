import SankeyKit
import SwiftUI

/// Income flowing into a budget and back out into expenses, written with explicit marks.
///
/// Shows the builder initializer, a ``SankeyNode`` customization, and the styling modifiers.
struct FinanceDemoView: View {
    @State private var showsSavings = true

    var body: some View {
        DemoScreen(caption: caption) {
            SankeyChart {
                SankeyLink(from: "Salary", to: "Budget", value: 4800)
                SankeyLink(from: "Side gig", to: "Budget", value: 700)

                SankeyLink(from: "Budget", to: "Rent", value: 1900)
                SankeyLink(from: "Budget", to: "Groceries", value: 800)
                SankeyLink(from: "Budget", to: "Transport", value: 300)
                SankeyLink(from: "Budget", to: "Fun", value: 400)

                // An `if` inside the builder — the mark simply disappears when the flag is off.
                if showsSavings {
                    SankeyLink(from: "Budget", to: "Savings", value: 2100)
                }

                SankeyNode("Budget")
                    .label("Monthly Budget")
                SankeyNode("Savings")
                    .foregroundStyle(.green)
            }
            .sankeyNodeWidth(14)
            .sankeyNodeCornerRadius(4)
            .sankeyLinkCurvature(0.5)
        } controls: {
            Toggle("Put money aside", isOn: $showsSavings.animation(.snappy))
                .toggleStyle(.switch)
        }
    }

    private var caption: String {
        """
        Explicit marks. Nodes are created by the links that mention them; the two SankeyNode marks \
        only rename "Budget" and recolor "Savings". Toggling the switch removes a mark from the \
        builder and the diagram re-lays out around it.
        """
    }
}

#Preview {
    FinanceDemoView()
}
