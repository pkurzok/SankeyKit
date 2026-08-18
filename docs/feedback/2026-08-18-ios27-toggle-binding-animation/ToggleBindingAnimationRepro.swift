// ToggleBindingAnimationRepro.swift
//
// Minimal repro for: iOS 27 drops the transaction that `Binding.animation(_:)` attaches to a
// `Toggle`-initiated write.
//
// No third-party dependencies. Drop this file into a fresh SwiftUI app (iOS) and make
// `ReproView` the root view, or run it as an Xcode Preview.
//
// The three controls all flip the same `@State` flag, which changes both the membership and the
// frames of a `ForEach` of bars:
//
//   1. Toggle bound via `$flag.animation(.snappy)`
//        Expected: bars resize and the extra bar inserts over ~0.3 s.
//        Actual on iOS 27.0 (24A5408d): the switch thumb animates, the bars jump in one frame.
//        Actual on iOS 26.5 and macOS 26: animates as expected.
//
//   2. Button using `withAnimation(.snappy)`
//        Animates correctly on every OS, including iOS 27.
//
//   3. Toggle bound via a custom `Binding` whose setter calls `withAnimation(.snappy)`
//        Animates correctly on every OS, including iOS 27 — this is the workaround.
//
// A programmatic write through the *same* `$flag.animation(.snappy)` binding (see the `.task`
// below, disabled by default) also animates correctly on iOS 27, so the regression is specific to
// the `Toggle`'s own write path rather than to the binding.

import SwiftUI

struct ReproView: View {
    @State private var expanded = false

    /// Demonstrates that the binding itself is fine — flip this on to watch a programmatic write
    /// through `$expanded.animation(.snappy)` animate correctly on iOS 27.
    private let demonstratesProgrammaticWrite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            bars

            Divider()

            // 1. BROKEN on iOS 27: the transaction is dropped, the bars jump.
            Toggle("Binding.animation (broken on iOS 27)", isOn: $expanded.animation(.snappy))
                .toggleStyle(.switch)

            // 2. Works everywhere.
            Button("withAnimation in a Button (works)") {
                withAnimation(.snappy) { expanded.toggle() }
            }

            // 3. Works everywhere — the workaround.
            Toggle("withAnimation in the setter (works)", isOn: Binding(
                get: { expanded },
                set: { newValue in withAnimation(.snappy) { expanded = newValue } }
            ))
            .toggleStyle(.switch)

            Spacer()
        }
        .padding()
        .task {
            guard demonstratesProgrammaticWrite else { return }
            // Same binding as control 1, written programmatically: animates on iOS 27.
            let animated = $expanded.animation(.snappy)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                animated.wrappedValue.toggle()
            }
        }
    }

    /// Membership *and* frames change with the flag, so a dropped transaction is obvious.
    private var bars: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(widths.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tint)
                    .frame(width: widths[index], height: 28)
            }
        }
        .frame(height: 200, alignment: .top)
    }

    private var widths: [CGFloat] {
        expanded ? [280, 200, 120, 60] : [120, 60, 200]
    }
}

#Preview {
    ReproView()
}
