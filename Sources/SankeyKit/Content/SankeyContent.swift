/// A mark, or a group of marks, inside a ``SankeyChart``.
///
/// ``SankeyLink`` and ``SankeyNode`` conform to this protocol, and the
/// ``SankeyContentBuilder`` result builder composes them into the tree that a chart draws.
///
/// > Important: This protocol is not designed for conformance outside of SankeyKit. Its only
/// requirement is underscored to signal that it is an implementation detail which may change.
public protocol SankeyContent {
    /// Appends this mark's contribution to the flat resolution the chart is built from.
    ///
    /// - Parameter resolution: The accumulator collecting links and node overrides.
    func _resolve(into resolution: inout SankeyResolution)
}

/// The content of an empty builder block.
public struct EmptySankeyContent: SankeyContent {
    /// Creates empty content.
    public init() {}

    public func _resolve(into resolution: inout SankeyResolution) {}
}

/// Several pieces of content in declaration order.
public struct SankeyTupleContent<each C: SankeyContent>: SankeyContent {
    private let content: (repeat each C)

    init(_ content: repeat each C) {
        self.content = (repeat each content)
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        for element in repeat each content {
            element._resolve(into: &resolution)
        }
    }
}

/// Content that may be absent, produced by an `if` statement without an `else` branch.
public struct SankeyOptionalContent<C: SankeyContent>: SankeyContent {
    private let content: C?

    init(_ content: C?) {
        self.content = content
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        content?._resolve(into: &resolution)
    }
}

/// One of two kinds of content, produced by an `if`/`else` statement.
public struct SankeyConditionalContent<First: SankeyContent, Second: SankeyContent>: SankeyContent {
    private enum Storage {
        case first(First)
        case second(Second)
    }

    private let storage: Storage

    init(first: First) {
        self.storage = .first(first)
    }

    init(second: Second) {
        self.storage = .second(second)
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        switch storage {
        case .first(let content): content._resolve(into: &resolution)
        case .second(let content): content._resolve(into: &resolution)
        }
    }
}

/// Content produced once per element of a collection.
///
/// This is what backs both the `for` loop inside a builder and the data-driven
/// ``SankeyChart/init(_:content:)`` initializer.
public struct SankeyForEachContent<Data: RandomAccessCollection, C: SankeyContent>: SankeyContent {
    private let data: Data
    private let content: (Data.Element) -> C

    init(_ data: Data, content: @escaping (Data.Element) -> C) {
        self.data = data
        self.content = content
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        for element in data {
            content(element)._resolve(into: &resolution)
        }
    }
}

/// A type-erased piece of content.
///
/// Used by ``SankeyContentBuilder/buildLimitedAvailability(_:)`` so that an `if #available`
/// block does not leak its concrete type into the chart's generic signature.
public struct AnySankeyContent: SankeyContent {
    private let resolve: (inout SankeyResolution) -> Void

    /// Wraps the given content.
    public init(_ content: some SankeyContent) {
        self.resolve = content._resolve(into:)
    }

    public func _resolve(into resolution: inout SankeyResolution) {
        resolve(&resolution)
    }
}
