/// The flat result of walking a ``SankeyContent`` tree.
///
/// Content resolution collects every ``SankeyLink`` mark into a list of links and every
/// ``SankeyNode`` mark into a list of node overrides. The chart's internal graph is built from that
/// flat description.
///
/// > Note: This type is part of the ``SankeyContent`` requirement and therefore public,
/// but it has no public members. It is not meant to be constructed or mutated outside
/// of SankeyKit.
public struct SankeyResolution: Sendable {
    /// Links in declaration order.
    var links: [ResolvedLink] = []

    /// Node customizations in declaration order.
    var nodeOverrides: [NodeOverride] = []

    mutating func append(_ link: ResolvedLink) {
        links.append(link)
    }

    mutating func append(_ override: NodeOverride) {
        nodeOverrides.append(override)
    }

    mutating func merge(_ other: SankeyResolution) {
        links.append(contentsOf: other.links)
        nodeOverrides.append(contentsOf: other.nodeOverrides)
    }
}
