import SankeyKit
import SwiftUI

/// One year of national energy, from primary sources through conversion and distribution to use.
///
/// Shows the data-driven initializer and a custom color scale over a graph with five columns.
struct EnergyDemoView: View {
    /// One row of the dataset, in terawatt hours.
    struct Flow {
        var source: String
        var target: String
        var energy: Double
    }

    private static let flows: [Flow] = [
        // Primary sources → conversion
        Flow(source: "Coal", target: "Power plants", energy: 118),
        Flow(source: "Gas", target: "Power plants", energy: 94),
        Flow(source: "Nuclear", target: "Power plants", energy: 62),
        Flow(source: "Wind", target: "Renewables", energy: 137),
        Flow(source: "Solar", target: "Renewables", energy: 68),
        Flow(source: "Hydro", target: "Renewables", energy: 21),

        // Conversion → grid and losses
        Flow(source: "Power plants", target: "Grid", energy: 161),
        Flow(source: "Power plants", target: "Conversion losses", energy: 113),
        Flow(source: "Renewables", target: "Grid", energy: 214),
        Flow(source: "Renewables", target: "Conversion losses", energy: 12),

        // Grid → consumers
        Flow(source: "Grid", target: "Households", energy: 122),
        Flow(source: "Grid", target: "Industry", energy: 168),
        Flow(source: "Grid", target: "Transport", energy: 54),
        Flow(source: "Grid", target: "Grid losses", energy: 31)
    ]

    private static let scale: [Color] = [
        .blue, .cyan, .teal, .mint, .green, .yellow, .orange, .pink, .purple, .indigo
    ]

    var body: some View {
        DemoScreen(caption: caption) {
            SankeyChart(Self.flows) { flow in
                SankeyLink(
                    from: .value("Source", flow.source),
                    to: .value("Target", flow.target),
                    value: .value("Energy", flow.energy)
                )
            }
            .sankeyColorScale(Self.scale)
            .sankeyNodeWidth(12)
            .sankeyNodeSpacing(10)
            .sankeyLinkSpacing(4)
            .sankeyLinkOpacity(0.8)
        } controls: {
            Text("\(Int(Self.flows.reduce(0) { $0 + $1.energy })) TWh across \(Self.flows.count) flows")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        """
        The data-driven initializer: one SankeyLink per row of the dataset, with .value labels that \
        VoiceOver reads back. Columns are inferred from the flow direction, and the color scale \
        cycles through the nodes from left to right.
        """
    }
}

#Preview {
    EnergyDemoView()
}
