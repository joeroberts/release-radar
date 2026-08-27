import CoreGraphics
import ReleaseRadarCore

enum DependencyGraphColumnRole: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case foundations
    case acceptedWork
    case selectedTicket
    case unlocksNext

    var id: Self { self }

    var title: String {
        switch self {
        case .foundations: "Foundations"
        case .acceptedWork: "Accepted work"
        case .selectedTicket: "Selected ticket"
        case .unlocksNext: "Unlocks next"
        }
    }
}

struct DependencyGraphColumn: Equatable, Identifiable, Sendable {
    let role: DependencyGraphColumnRole
    let ticketIDs: [TicketID]
    let frame: CGRect

    var id: DependencyGraphColumnRole { role }
    var title: String { role.title }
}

struct DependencyGraphConnector: Equatable, Identifiable, Sendable {
    let id: TicketDependencyID
    let sourceID: TicketID
    let targetID: TicketID
    let start: CGPoint
    let end: CGPoint
    let isBlocking: Bool
}

struct DependencyGraphLayoutResult: Equatable, Sendable {
    let columns: [DependencyGraphColumn]
    let frames: [TicketID: CGRect]
    let connectors: [DependencyGraphConnector]

    func role(for ticketID: TicketID) -> DependencyGraphColumnRole? {
        columns.first { $0.ticketIDs.contains(ticketID) }?.role
    }
}

enum DependencyGraphLayout {
    static func makeLayout(graph: DependencyGraphProjection, size: CGSize) -> DependencyGraphLayoutResult {
        let nodeSize = CGSize(width: 112, height: 52)
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 28
        let columnWidth = max(
            nodeSize.width + 24,
            (size.width - horizontalPadding * 2) / CGFloat(DependencyGraphColumnRole.allCases.count)
        )

        let memberships: [(DependencyGraphColumnRole, [DependencyGraphNode])] = [
            (.foundations, graph.selected.indirectRequires),
            (.acceptedWork, graph.selected.directRequires),
            (.selectedTicket, [graph.selected.ticket]),
            (.unlocksNext, graph.selected.unlocks),
        ].map { role, nodes in
            (role, nodes.sorted { $0.id.rawValue < $1.id.rawValue })
        }

        var frames: [TicketID: CGRect] = [:]
        var columns: [DependencyGraphColumn] = []
        for (index, membership) in memberships.enumerated() {
            let columnX = horizontalPadding + CGFloat(index) * columnWidth
            let columnFrame = CGRect(
                x: columnX,
                y: 0,
                width: columnWidth,
                height: size.height
            )
            let nodes = membership.1
            let availableHeight = max(size.height - verticalPadding * 2, nodeSize.height)
            let verticalStep = availableHeight / CGFloat(max(nodes.count, 1))
            for (nodeIndex, node) in nodes.enumerated() {
                let centerY = verticalPadding + verticalStep * (CGFloat(nodeIndex) + 0.5)
                frames[node.id] = CGRect(
                    x: columnFrame.midX - nodeSize.width / 2,
                    y: centerY - nodeSize.height / 2,
                    width: nodeSize.width,
                    height: nodeSize.height
                )
            }
            columns.append(DependencyGraphColumn(
                role: membership.0,
                ticketIDs: nodes.map(\.id),
                frame: columnFrame
            ))
        }

        let visibleIDs = Set(frames.keys)
        let connectors = graph.edges.compactMap { edge -> DependencyGraphConnector? in
            guard visibleIDs.contains(edge.sourceID),
                  visibleIDs.contains(edge.targetID),
                  let source = frames[edge.sourceID],
                  let target = frames[edge.targetID]
            else { return nil }
            return DependencyGraphConnector(
                id: edge.id,
                sourceID: edge.sourceID,
                targetID: edge.targetID,
                start: CGPoint(x: source.maxX, y: source.midY),
                end: CGPoint(x: target.minX, y: target.midY),
                isBlocking: graph.node(id: edge.sourceID)?.lane == .blocked
            )
        }
        return DependencyGraphLayoutResult(
            columns: columns,
            frames: frames,
            connectors: connectors
        )
    }
}
