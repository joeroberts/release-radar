import CoreGraphics
import ReleaseRadarCore

struct DependencyGraphConnector: Equatable, Identifiable, Sendable {
    let id: TicketDependencyID
    let sourceID: TicketID
    let targetID: TicketID
    let start: CGPoint
    let end: CGPoint
}

struct DependencyGraphLayoutResult: Equatable, Sendable {
    let frames: [TicketID: CGRect]
    let connectors: [DependencyGraphConnector]
}

enum DependencyGraphLayout {
    static func makeLayout(graph: DependencyGraphProjection, size: CGSize) -> DependencyGraphLayoutResult {
        let nodeSize = CGSize(width: 112, height: 52)
        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = 24
        let depths = nodeDepths(nodes: graph.nodes, edges: graph.edges)
        let maximumDepth = max(depths.values.max() ?? 0, 1)
        let horizontalStep = max(
            nodeSize.width + 28,
            (size.width - horizontalPadding * 2 - nodeSize.width) / CGFloat(maximumDepth)
        )
        let grouped = Dictionary(grouping: graph.nodes) { depths[$0.id, default: 0] }
        var frames: [TicketID: CGRect] = [:]
        for depth in 0...maximumDepth {
            let column = (grouped[depth] ?? []).sorted { $0.id.rawValue < $1.id.rawValue }
            let availableHeight = max(size.height - verticalPadding * 2, nodeSize.height)
            let verticalStep = availableHeight / CGFloat(max(column.count, 1))
            for (index, node) in column.enumerated() {
                let centerY = verticalPadding + verticalStep * (CGFloat(index) + 0.5)
                frames[node.id] = CGRect(
                    x: horizontalPadding + CGFloat(depth) * horizontalStep,
                    y: centerY - nodeSize.height / 2,
                    width: nodeSize.width,
                    height: nodeSize.height
                )
            }
        }
        let connectors = graph.edges.compactMap { edge -> DependencyGraphConnector? in
            guard let source = frames[edge.sourceID], let target = frames[edge.targetID] else { return nil }
            return DependencyGraphConnector(
                id: edge.id,
                sourceID: edge.sourceID,
                targetID: edge.targetID,
                start: CGPoint(x: source.maxX, y: source.midY),
                end: CGPoint(x: target.minX, y: target.midY)
            )
        }
        return DependencyGraphLayoutResult(frames: frames, connectors: connectors)
    }

    private static func nodeDepths(
        nodes: [DependencyGraphNode],
        edges: [DependencyGraphEdge]
    ) -> [TicketID: Int] {
        var depths = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        for _ in nodes.indices {
            var changed = false
            for edge in edges {
                let candidate = depths[edge.sourceID, default: 0] + 1
                if candidate > depths[edge.targetID, default: 0] {
                    depths[edge.targetID] = candidate
                    changed = true
                }
            }
            if !changed { break }
        }
        return depths
    }
}
