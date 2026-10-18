import CoreGraphics
import ReleaseRadarCore

struct DependencyGraphRankOrder: Codable, Equatable, Sendable {
    struct Rank: Codable, Equatable, Sendable {
        let depth: Int
        let ticketIDs: [TicketID]
    }

    let ranks: [Rank]

    static let empty = DependencyGraphRankOrder(ranks: [])

    func moving(ticketID: TicketID, to destinationIndex: Int) -> DependencyGraphRankOrder {
        var updated = ranks
        guard let rankIndex = updated.firstIndex(where: { $0.ticketIDs.contains(ticketID) }),
              let sourceIndex = updated[rankIndex].ticketIDs.firstIndex(of: ticketID)
        else { return self }
        var ticketIDs = updated[rankIndex].ticketIDs
        ticketIDs.remove(at: sourceIndex)
        ticketIDs.insert(ticketID, at: min(max(destinationIndex, 0), ticketIDs.count))
        updated[rankIndex] = Rank(depth: updated[rankIndex].depth, ticketIDs: ticketIDs)
        return DependencyGraphRankOrder(ranks: updated)
    }
}

extension DependencyGraphRankOrder {
    init(presentation: DependencyGraphPresentationLayout) {
        ranks = presentation.ranks.map { .init(depth: $0.depth, ticketIDs: $0.ticketIDs) }
    }

    var presentation: DependencyGraphPresentationLayout {
        .init(ranks: ranks.map { .init(depth: $0.depth, ticketIDs: $0.ticketIDs) })
    }
}

enum DependencyGraphArrangementStatus: Equatable, Sendable {
    case automatic
    case loading
    case saving
    case saved
    case sessionOnly
    case unsupported(Int64)
    case loadFailed(String)
    case saveFailed(String)
    case resetFailed(String)

    var message: String? {
        switch self {
        case .automatic: nil
        case .loading: "Loading saved arrangement…"
        case .saving: "Saving arrangement…"
        case .saved: "Arrangement saved"
        case .sessionOnly: "Layout changes are session-only · register the project to retain them after restart"
        case let .unsupported(version):
            "Automatic layout shown · saved arrangement version \(version) is unsupported or unreadable and was preserved"
        case let .loadFailed(message): "Saved arrangement unavailable · \(message)"
        case let .saveFailed(message): "Arrangement kept for this session · save failed: \(message)"
        case let .resetFailed(message): "Arrangement retained · reset failed: \(message)"
        }
    }

    var isWarning: Bool {
        switch self {
        case .sessionOnly, .unsupported, .loadFailed, .saveFailed, .resetFailed: true
        case .automatic, .loading, .saving, .saved: false
        }
    }

    var systemImage: String {
        switch self {
        case .loading, .saving: "arrow.clockwise"
        case .saved: "checkmark.circle"
        case .automatic: "circle"
        case .sessionOnly, .unsupported, .loadFailed, .saveFailed, .resetFailed:
            "exclamationmark.circle"
        }
    }

    var canRetry: Bool {
        switch self {
        case .loadFailed, .saveFailed, .resetFailed: true
        default: false
        }
    }

    var blocksAdjustment: Bool {
        switch self {
        case .loading, .saving, .unsupported: true
        default: false
        }
    }

    var isBusy: Bool {
        switch self {
        case .loading, .saving: true
        default: false
        }
    }
}

struct DependencyGraphColumn: Equatable, Identifiable, Sendable {
    let depth: Int
    let ticketIDs: [TicketID]
    let frame: CGRect
    let containsSelection: Bool

    var id: Int { depth }
    var title: String {
        "Dependency depth \(depth + 1)" + (containsSelection ? " · selected ticket" : "")
    }
}

struct DependencyGraphConnector: Equatable, Identifiable, Sendable {
    let id: TicketDependencyID
    let sourceID: TicketID
    let targetID: TicketID
    let points: [CGPoint]
    let isBlocking: Bool

    var start: CGPoint { points.first ?? .zero }
    var end: CGPoint { points.last ?? .zero }
}

struct DependencyGraphLayoutResult: Equatable, Sendable {
    let columns: [DependencyGraphColumn]
    let frames: [TicketID: CGRect]
    let connectors: [DependencyGraphConnector]
    let rankOrder: DependencyGraphRankOrder

    func rank(for ticketID: TicketID) -> Int? {
        columns.first { $0.ticketIDs.contains(ticketID) }?.depth
    }

    func columnTitle(for ticketID: TicketID) -> String? {
        columns.first { $0.ticketIDs.contains(ticketID) }?.title
    }
}

enum DependencyGraphLayout {
    private static let nodeSize = CGSize(width: 132, height: 62)
    private static let verticalSpacing: CGFloat = 18
    private static let horizontalSpacing: CGFloat = 92
    private static let horizontalPadding: CGFloat = 28

    static func requiredCanvasHeight(for graph: DependencyGraphProjection, minimum: CGFloat) -> CGFloat {
        let groups = rankedNodes(for: graph, retainedOrder: nil)
        let largestRank = groups.map(\.ticketIDs.count).max() ?? 1
        let channelPadding = skippedRankChannelPadding(graph: graph, groups: groups)
        let required = channelPadding + 28
            + CGFloat(largestRank) * nodeSize.height
            + CGFloat(max(largestRank - 1, 0)) * verticalSpacing
            + 28
        return max(minimum, required)
    }

    static func requiredCanvasWidth(for graph: DependencyGraphProjection, minimum: CGFloat) -> CGFloat {
        let rankCount = max(rankedNodes(for: graph, retainedOrder: nil).count, 1)
        return max(
            minimum,
            horizontalPadding * 2
                + CGFloat(rankCount) * nodeSize.width
                + CGFloat(max(rankCount - 1, 0)) * horizontalSpacing
        )
    }

    static func makeLayout(
        graph: DependencyGraphProjection,
        size: CGSize,
        retainedOrder: DependencyGraphRankOrder? = nil
    ) -> DependencyGraphLayoutResult {
        let groups = rankedNodes(for: graph, retainedOrder: retainedOrder)
        guard !groups.isEmpty else {
            return .init(columns: [], frames: [:], connectors: [], rankOrder: .empty)
        }
        let contentWidth = horizontalPadding * 2
            + CGFloat(groups.count) * nodeSize.width
            + CGFloat(max(groups.count - 1, 0)) * horizontalSpacing
        let width = max(size.width, contentWidth)
        let availableSpacing = groups.count > 1
            ? max(horizontalSpacing, (width - horizontalPadding * 2 - CGFloat(groups.count) * nodeSize.width) / CGFloat(groups.count - 1))
            : 0
        let channelPadding = skippedRankChannelPadding(graph: graph, groups: groups)
        let selectedID = graph.selected?.ticket.id

        var frames: [TicketID: CGRect] = [:]
        var columns: [DependencyGraphColumn] = []
        for (index, group) in groups.enumerated() {
            let x = horizontalPadding + CGFloat(index) * (nodeSize.width + availableSpacing)
            let step = nodeSize.height + verticalSpacing
            for (nodeIndex, ticketID) in group.ticketIDs.enumerated() {
                frames[ticketID] = CGRect(
                    x: x,
                    y: channelPadding + 28 + CGFloat(nodeIndex) * step,
                    width: nodeSize.width,
                    height: nodeSize.height
                )
            }
            columns.append(.init(
                depth: group.depth,
                ticketIDs: group.ticketIDs,
                frame: CGRect(x: x - availableSpacing / 2, y: 0, width: nodeSize.width + availableSpacing, height: size.height),
                containsSelection: group.ticketIDs.contains { $0 == selectedID }
            ))
        }

        let rankByID = Dictionary(uniqueKeysWithValues: groups.flatMap { group in
            group.ticketIDs.map { ($0, group.depth) }
        })
        let visibleIDs = Set(frames.keys)
        let adjacentTracks = Dictionary(grouping: graph.edges.filter { edge in
            guard let sourceRank = rankByID[edge.sourceID], let targetRank = rankByID[edge.targetID] else { return false }
            return targetRank - sourceRank == 1
        }) { edge in
            "\(rankByID[edge.sourceID] ?? -1):\(rankByID[edge.targetID] ?? -1)"
        }.mapValues { $0.sorted { $0.id.rawValue < $1.id.rawValue } }
        var skippedIndex = 0
        let connectors = graph.edges
            .filter { visibleIDs.contains($0.sourceID) && visibleIDs.contains($0.targetID) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .compactMap { edge -> DependencyGraphConnector? in
                guard let source = frames[edge.sourceID],
                      let target = frames[edge.targetID],
                      let sourceRank = rankByID[edge.sourceID],
                      let targetRank = rankByID[edge.targetID]
                else { return nil }
                let start = CGPoint(x: source.maxX, y: source.midY)
                let end = CGPoint(x: target.minX, y: target.midY)
                let points: [CGPoint]
                if targetRank - sourceRank > 1 {
                    let outerY = CGFloat(12 + skippedIndex * 7)
                    skippedIndex += 1
                    points = [
                        start,
                        CGPoint(x: source.maxX + 24, y: start.y),
                        CGPoint(x: source.maxX + 24, y: outerY),
                        CGPoint(x: target.minX - 24, y: outerY),
                        CGPoint(x: target.minX - 24, y: end.y),
                        end,
                    ]
                } else {
                    let trackKey = "\(sourceRank):\(targetRank)"
                    let tracks = adjacentTracks[trackKey] ?? [edge]
                    let trackIndex = tracks.firstIndex(where: { $0.id == edge.id }) ?? 0
                    let channelX = source.maxX
                        + (target.minX - source.maxX) * CGFloat(trackIndex + 1) / CGFloat(tracks.count + 1)
                    points = [
                        start,
                        CGPoint(x: channelX, y: start.y),
                        CGPoint(x: channelX, y: end.y),
                        end,
                    ]
                }
                return .init(
                    id: edge.id,
                    sourceID: edge.sourceID,
                    targetID: edge.targetID,
                    points: points,
                    isBlocking: graph.node(id: edge.sourceID)?.lane == .blocked
                )
            }
        let rankOrder = DependencyGraphRankOrder(ranks: groups.map {
            .init(depth: $0.depth, ticketIDs: $0.ticketIDs)
        })
        return .init(columns: columns, frames: frames, connectors: connectors, rankOrder: rankOrder)
    }

    private static func skippedRankChannelPadding(
        graph: DependencyGraphProjection,
        groups: [DependencyGraphRankOrder.Rank]
    ) -> CGFloat {
        let rankByID = Dictionary(uniqueKeysWithValues: groups.flatMap { group in
            group.ticketIDs.map { ($0, group.depth) }
        })
        let count = graph.edges.filter { edge in
            guard let source = rankByID[edge.sourceID], let target = rankByID[edge.targetID] else { return false }
            return target - source > 1
        }.count
        return count == 0 ? 0 : CGFloat(22 + count * 7)
    }

    private static func rankedNodes(
        for graph: DependencyGraphProjection,
        retainedOrder: DependencyGraphRankOrder?
    ) -> [DependencyGraphRankOrder.Rank] {
        guard let selectedID = graph.selected?.ticket.id else { return [] }
        guard let selection = graph.selected else { return [] }
        let visibleIDs = Set(
            selection.directRequires.map(\.id)
                + selection.indirectRequires.map(\.id)
                + [selectedID]
                + selection.unlocks.map(\.id)
        )
        guard !visibleIDs.isEmpty else { return [] }
        let visibleEdges = graph.edges.filter {
            visibleIDs.contains($0.sourceID) && visibleIDs.contains($0.targetID)
        }
        var incoming = Dictionary(uniqueKeysWithValues: visibleIDs.map { ($0, 0) })
        for edge in visibleEdges { incoming[edge.targetID, default: 0] += 1 }
        var depths = Dictionary(uniqueKeysWithValues: visibleIDs.map { ($0, 0) })
        var ready = incoming.filter { $0.value == 0 }.map(\.key).sorted { $0.rawValue < $1.rawValue }
        var visited: Set<TicketID> = []
        while !ready.isEmpty {
            let current = ready.removeFirst()
            guard visited.insert(current).inserted else { continue }
            let outgoing = visibleEdges.filter { $0.sourceID == current }
                .sorted { $0.targetID.rawValue < $1.targetID.rawValue }
            for edge in outgoing {
                depths[edge.targetID] = max(depths[edge.targetID, default: 0], depths[current, default: 0] + 1)
                incoming[edge.targetID, default: 0] -= 1
                if incoming[edge.targetID] == 0 {
                    ready.append(edge.targetID)
                    ready.sort { $0.rawValue < $1.rawValue }
                }
            }
        }
        for unresolved in visibleIDs.subtracting(visited).sorted(by: { $0.rawValue < $1.rawValue }) {
            let predecessorDepth = visibleEdges.filter { $0.targetID == unresolved }
                .compactMap { depths[$0.sourceID] }.max()
            depths[unresolved] = predecessorDepth.map { $0 + 1 } ?? 0
        }

        var groups = Dictionary(grouping: visibleIDs) { depths[$0, default: 0] }
            .map { DependencyGraphRankOrder.Rank(depth: $0.key, ticketIDs: $0.value.sorted { $0.rawValue < $1.rawValue }) }
            .sorted { $0.depth < $1.depth }
        groups = minimizeCrossings(groups: groups, edges: visibleEdges)

        guard let retainedOrder else { return groups }
        let retainedByDepth = Dictionary(uniqueKeysWithValues: retainedOrder.ranks.map { ($0.depth, $0.ticketIDs) })
        return groups.map { group in
            let eligible = (retainedByDepth[group.depth] ?? []).filter { id in
                group.ticketIDs.contains(id) && depths[id] == group.depth
            }
            let eligibleSet = Set(eligible)
            let automatic = group.ticketIDs.filter { !eligibleSet.contains($0) }
            return .init(depth: group.depth, ticketIDs: eligible + automatic)
        }
    }

    private static func minimizeCrossings(
        groups: [DependencyGraphRankOrder.Rank],
        edges: [DependencyGraphEdge]
    ) -> [DependencyGraphRankOrder.Rank] {
        var ordered = groups
        guard ordered.count > 1 else { return ordered }
        for _ in 0..<3 {
            for index in ordered.indices.dropFirst() {
                let positions = Dictionary(uniqueKeysWithValues: ordered[index - 1].ticketIDs.enumerated().map { ($1, $0) })
                ordered[index] = sorted(
                    ordered[index],
                    neighbors: { id in edges.filter { $0.targetID == id }.map(\.sourceID) },
                    positions: positions
                )
            }
            for index in ordered.indices.dropLast().reversed() {
                let positions = Dictionary(uniqueKeysWithValues: ordered[index + 1].ticketIDs.enumerated().map { ($1, $0) })
                ordered[index] = sorted(
                    ordered[index],
                    neighbors: { id in edges.filter { $0.sourceID == id }.map(\.targetID) },
                    positions: positions
                )
            }
        }
        return ordered
    }

    private static func sorted(
        _ rank: DependencyGraphRankOrder.Rank,
        neighbors: (TicketID) -> [TicketID],
        positions: [TicketID: Int]
    ) -> DependencyGraphRankOrder.Rank {
        let ids = rank.ticketIDs.sorted { lhs, rhs in
            func barycenter(_ id: TicketID) -> Double? {
                let values = neighbors(id).compactMap { positions[$0] }
                guard !values.isEmpty else { return nil }
                return Double(values.reduce(0, +)) / Double(values.count)
            }
            switch (barycenter(lhs), barycenter(rhs)) {
            case let (left?, right?) where left != right: return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.rawValue < rhs.rawValue
            }
        }
        return .init(depth: rank.depth, ticketIDs: ids)
    }
}
