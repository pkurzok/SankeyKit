/// Builds the content of a ``SankeyChart`` from ``SankeyLink`` and ``SankeyNode`` marks.
///
/// The builder supports the same control flow as a SwiftUI `ViewBuilder`: `if`, `if`/`else`,
/// `if #available`, and `for` loops.
///
/// ```swift
/// SankeyChart {
///     SankeyLink(from: "Salary", to: "Budget", value: 4800)
///     for expense in expenses {
///         SankeyLink(from: "Budget", to: expense.name, value: expense.amount)
///     }
///     if showSavings {
///         SankeyLink(from: "Budget", to: "Savings", value: 900)
///     }
/// }
/// ```
@resultBuilder
public enum SankeyContentBuilder {
    /// Combines the marks of a block in declaration order.
    public static func buildBlock<each C: SankeyContent>(_ content: repeat each C) -> SankeyTupleContent<repeat each C> {
        SankeyTupleContent(repeat each content)
    }

    /// Passes a single mark through unchanged.
    public static func buildExpression<C: SankeyContent>(_ content: C) -> C {
        content
    }

    /// Supports an `if` statement without an `else` branch.
    public static func buildOptional<C: SankeyContent>(_ content: C?) -> SankeyOptionalContent<C> {
        SankeyOptionalContent(content)
    }

    /// Supports the `if` branch of an `if`/`else` statement.
    public static func buildEither<First: SankeyContent, Second: SankeyContent>(
        first content: First
    ) -> SankeyConditionalContent<First, Second> {
        SankeyConditionalContent(first: content)
    }

    /// Supports the `else` branch of an `if`/`else` statement.
    public static func buildEither<First: SankeyContent, Second: SankeyContent>(
        second content: Second
    ) -> SankeyConditionalContent<First, Second> {
        SankeyConditionalContent(second: content)
    }

    /// Supports a `for` loop.
    public static func buildArray<C: SankeyContent>(_ content: [C]) -> SankeyForEachContent<[C], C> {
        SankeyForEachContent(content) { $0 }
    }

    /// Supports an `if #available` block by erasing the availability-constrained type.
    public static func buildLimitedAvailability(_ content: some SankeyContent) -> AnySankeyContent {
        AnySankeyContent(content)
    }
}
