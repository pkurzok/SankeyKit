import Foundation
@testable import SankeyKit

/// Builds a link without having to spell out every optional payload.
func link(_ source: String, _ target: String, _ value: Double) -> ResolvedLink {
    ResolvedLink(sourceID: source, targetID: target, value: value)
}

/// Builds a resolution directly, bypassing the content builder.
func resolution(_ links: [ResolvedLink], overrides: [NodeOverride] = []) -> SankeyResolution {
    var result = SankeyResolution()
    for link in links { result.append(link) }
    for override in overrides { result.append(override) }
    return result
}

/// Builds a validated graph, failing the test on unexpected errors.
func graph(_ links: [ResolvedLink], overrides: [NodeOverride] = []) throws -> SankeyGraph {
    try SankeyGraph(resolution: resolution(links, overrides: overrides))
}
