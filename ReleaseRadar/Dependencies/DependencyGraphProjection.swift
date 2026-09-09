import Foundation
import ReleaseRadarCore

struct DependencyGraphNode: Equatable, Identifiable, Sendable {
    let id: TicketID
    let outcome: String
    let lane: TicketLane?
    let blockerCount: Int
    let phaseName: String

    init(id: TicketID, outcome: String, lane: TicketLane?, blockerCount: Int, phaseName: String = "") {
        self.id = id
        self.outcome = outcome
        self.lane = lane
        self.blockerCount = blockerCount
        self.phaseName = phaseName
    }
}

struct DependencyGraphEdge: Equatable, Identifiable, Sendable {
    let id: TicketDependencyID
    let sourceID: TicketID
    let targetID: TicketID
}

struct DependencyInspectorProjection: Equatable, Sendable {
    let ticket: DependencyGraphNode
    let directRequires: [DependencyGraphNode]
    let indirectRequires: [DependencyGraphNode]
    let unlocks: [DependencyGraphNode]

    var blockerCount: Int { ticket.blockerCount }
}

struct DependencyGraphProjection: Equatable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID
    let nodes: [DependencyGraphNode]
    let edges: [DependencyGraphEdge]
    let selected: DependencyInspectorProjection

    func node(id: TicketID) -> DependencyGraphNode? {
        nodes.first { $0.id == id }
    }

    func selecting(_ ticketID: TicketID) -> DependencyGraphProjection? {
        guard let inspector = Self.makeInspector(nodes: nodes, edges: edges, selectedTicketID: ticketID) else {
            return nil
        }
        return DependencyGraphProjection(
            projectID: projectID,
            phaseID: phaseID,
            nodes: nodes,
            edges: edges,
            selected: inspector
        )
    }

    static func load(
        from store: DeliveryStore,
        projectID: ProjectID,
        phaseID: PhaseID,
        selectedTicketID: TicketID
    ) async throws -> DependencyGraphProjection {
        try await store.read { connection in
            let nodeRows = try connection.graphRows(
                "SELECT tickets.id, tickets.outcome, tickets.lane, phases.name AS phase_name FROM tickets LEFT JOIN phases ON phases.id = tickets.phase_id AND phases.project_id = tickets.project_id WHERE tickets.project_id = ? ORDER BY tickets.rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let nodes = try nodeRows.map { row in
                let id = TicketID(rawValue: try row.graphText("id"))
                let laneText = try row.graphOptionalText("lane")
                guard laneText == nil || TicketLane(rawValue: laneText!) != nil else {
                    throw DependencyGraphProjectionError.invalidLane(laneText!)
                }
                return DependencyGraphNode(
                    id: id,
                    outcome: try row.graphText("outcome"),
                    lane: laneText.flatMap(TicketLane.init(rawValue:)),
                    blockerCount: Int(try connection.scalarInt(
                        "SELECT COUNT(*) FROM blockers WHERE project_id = ? AND ticket_id = ? AND resolved_at IS NULL",
                        bindings: [.text(projectID.rawValue), .text(id.rawValue)]
                    ) ?? 0),
                    phaseName: try row.graphOptionalText("phase_name") ?? "Unassigned"
                )
            }
            let edgeRows = try connection.graphRows(
                "SELECT id, ticket_id, depends_on_ticket_id FROM ticket_dependencies WHERE project_id = ? ORDER BY rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let nodeIDs = Set(nodes.map(\.id))
            let edges = try edgeRows.map { row in
                DependencyGraphEdge(
                    id: TicketDependencyID(rawValue: try row.graphText("id")),
                    sourceID: TicketID(rawValue: try row.graphText("depends_on_ticket_id")),
                    targetID: TicketID(rawValue: try row.graphText("ticket_id"))
                )
            }.filter { edge in
                nodeIDs.contains(edge.sourceID) && nodeIDs.contains(edge.targetID)
            }
            guard let selected = makeInspector(nodes: nodes, edges: edges, selectedTicketID: selectedTicketID) else {
                throw DependencyGraphProjectionError.missingSelectedTicket(selectedTicketID.rawValue)
            }

            return DependencyGraphProjection(
                projectID: projectID,
                phaseID: phaseID,
                nodes: nodes,
                edges: edges,
                selected: selected
            )
        }
    }

    private static func makeInspector(
        nodes: [DependencyGraphNode],
        edges: [DependencyGraphEdge],
        selectedTicketID: TicketID
    ) -> DependencyInspectorProjection? {
        guard let selectedTicket = nodes.first(where: { $0.id == selectedTicketID }) else { return nil }
        let incomingIDs = edges.filter { $0.targetID == selectedTicketID }.map(\.sourceID)
        let directIDs = incomingIDs.filter { candidate in
            !incomingIDs.contains { other in
                other != candidate && reaches(from: candidate, to: other, edges: edges)
            }
        }
        let indirectIDs = ancestors(of: selectedTicketID, edges: edges).subtracting(directIDs)
        let unlockIDs = Set(edges.filter { $0.sourceID == selectedTicketID }.map(\.targetID))
        func orderedNodes(_ ids: Set<TicketID>) -> [DependencyGraphNode] {
            nodes.filter { ids.contains($0.id) }.sorted { $0.id.rawValue < $1.id.rawValue }
        }
        return DependencyInspectorProjection(
            ticket: selectedTicket,
            directRequires: orderedNodes(Set(directIDs)),
            indirectRequires: orderedNodes(indirectIDs),
            unlocks: orderedNodes(unlockIDs)
        )
    }

    private static func reaches(
        from source: TicketID,
        to target: TicketID,
        edges: [DependencyGraphEdge]
    ) -> Bool {
        var pending = [source]
        var visited: Set<TicketID> = []
        while let current = pending.popLast() {
            guard visited.insert(current).inserted else { continue }
            for next in edges where next.sourceID == current {
                if next.targetID == target { return true }
                pending.append(next.targetID)
            }
        }
        return false
    }

    private static func ancestors(
        of ticketID: TicketID,
        edges: [DependencyGraphEdge]
    ) -> Set<TicketID> {
        var result: Set<TicketID> = []
        var pending = edges.filter { $0.targetID == ticketID }.map(\.sourceID)
        while let current = pending.popLast() {
            guard result.insert(current).inserted else { continue }
            pending.append(contentsOf: edges.filter { $0.targetID == current }.map(\.sourceID))
        }
        return result
    }
}

enum DependencyGraphProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidLane(String)
    case missingSelectedTicket(String)
}

private extension SQLiteConnection {
    func graphRows(_ sql: String, bindings: [SQLiteValue]) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: bindings + [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func graphText(_ column: String) throws -> String {
        guard let value = self[column] else { throw DependencyGraphProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw DependencyGraphProjectionError.invalidColumn(column) }
        return text
    }

    func graphOptionalText(_ column: String) throws -> String? {
        guard let value = self[column] else { throw DependencyGraphProjectionError.missingColumn(column) }
        if value == .null { return nil }
        guard case let .text(text) = value else { throw DependencyGraphProjectionError.invalidColumn(column) }
        return text
    }
}
