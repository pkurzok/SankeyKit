/// Assigns each node to a column (layer) of the diagram.
///
/// Layers are derived by *longest path from a source*: a node sits one column to the right of
/// the deepest node that feeds it. Nodes with no incoming links start at layer zero. Explicitly
/// pinned layers from ``SankeyNode`` overrides replace the computed value.
enum LayerAssignment {
    /// - Returns: A layer index per node id. The smallest index is always zero.
    /// - Throws: ``SankeyGraphError/cycle(path:)`` when the links form a directed cycle.
    static func assignLayers(
        nodes: [ResolvedNode],
        links: [ResolvedLink]
    ) throws(SankeyGraphError) -> [String: Int] {
        guard !nodes.isEmpty else { return [:] }

        var successors: [String: [String]] = [:]
        var inDegree: [String: Int] = [:]
        for node in nodes { inDegree[node.id] = 0 }
        for link in links {
            successors[link.sourceID, default: []].append(link.targetID)
            inDegree[link.targetID, default: 0] += 1
        }

        // Kahn's algorithm, relaxing to the *longest* distance from any source.
        var depth: [String: Int] = [:]
        var queue: [String] = []
        for node in nodes where inDegree[node.id] == 0 {
            depth[node.id] = 0
            queue.append(node.id)
        }

        var head = 0
        var processed = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            processed += 1
            let currentDepth = depth[current] ?? 0
            for next in successors[current] ?? [] {
                depth[next] = max(depth[next] ?? 0, currentDepth + 1)
                inDegree[next, default: 0] -= 1
                if inDegree[next] == 0 {
                    queue.append(next)
                }
            }
        }

        if processed < nodes.count {
            let unresolved = Set(nodes.map(\.id)).subtracting(queue)
            throw SankeyGraphError.cycle(path: findCycle(in: unresolved, successors: successors))
        }

        var result = depth
        for node in nodes {
            if let pinned = node.pinnedLayer {
                result[node.id] = pinned
            }
        }

        // Normalize so the leftmost column is zero (a pinned layer may be negative).
        let minimum = result.values.min() ?? 0
        if minimum != 0 {
            for key in result.keys {
                result[key, default: 0] -= minimum
            }
        }
        return result
    }

    /// Depth-first search over the nodes Kahn's algorithm could not resolve, returning the
    /// first cycle found as a node path whose first element is repeated at the end.
    private static func findCycle(in candidates: Set<String>, successors: [String: [String]]) -> [String] {
        var visiting: Set<String> = []
        var visited: Set<String> = []
        var stack: [String] = []

        func walk(_ node: String) -> [String]? {
            visiting.insert(node)
            stack.append(node)
            defer {
                visiting.remove(node)
                stack.removeLast()
                visited.insert(node)
            }
            for next in successors[node] ?? [] where candidates.contains(next) {
                if visiting.contains(next) {
                    let start = stack.firstIndex(of: next) ?? 0
                    return Array(stack[start...]) + [next]
                }
                if !visited.contains(next), let found = walk(next) {
                    return found
                }
            }
            return nil
        }

        for node in candidates.sorted() where !visited.contains(node) {
            if let cycle = walk(node) {
                return cycle
            }
        }
        return candidates.sorted()
    }
}
