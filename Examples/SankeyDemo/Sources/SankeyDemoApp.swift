import SwiftUI

@main
struct SankeyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 680)
        #endif
    }
}

/// The three screens of the demo.
enum Demo: String, CaseIterable, Identifiable {
    case finance
    case energy
    case playground

    var id: Self { self }

    var title: String {
        switch self {
        case .finance: "Finance"
        case .energy: "Energy"
        case .playground: "Playground"
        }
    }

    var symbol: String {
        switch self {
        case .finance: "eurosign.circle"
        case .energy: "bolt.circle"
        case .playground: "slider.horizontal.3"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .finance: FinanceDemoView()
        case .energy: EnergyDemoView()
        case .playground: PlaygroundView()
        }
    }
}

/// Tabs on iOS, a sidebar on macOS.
struct RootView: View {
    @State private var selected: Demo = .finance

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Demo.allCases, selection: $selected) { demo in
                Label(demo.title, systemImage: demo.symbol)
                    .tag(demo)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            selected.view
                .navigationTitle(selected.title)
        }
        #else
        TabView(selection: $selected) {
            ForEach(Demo.allCases) { demo in
                NavigationStack {
                    demo.view
                        .navigationTitle(demo.title)
                }
                .tabItem { Label(demo.title, systemImage: demo.symbol) }
                .tag(demo)
            }
        }
        #endif
    }
}

/// Shared chrome so the three screens look alike.
struct DemoScreen<Chart: View, Controls: View>: View {
    var caption: String
    @ViewBuilder var chart: Chart
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            chart
                .frame(minHeight: 260)

            controls
        }
        .padding(20)
        // Without a minimum width the caption can be squeezed into a very narrow column, and
        // the window then adopts the height that wrapped paragraph needs — thousands of points.
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    RootView()
}
