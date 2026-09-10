import Foundation
import ReleaseRadarCore

enum WorkspaceExecutionLink: Equatable, Sendable {
    case linked(ticketID: TicketID, phaseID: PhaseID?, phaseName: String?)
    case unlinked

    var ticketID: TicketID? {
        guard case let .linked(ticketID, _, _) = self else { return nil }
        return ticketID
    }

    var phaseID: PhaseID? {
        guard case let .linked(_, phaseID, _) = self else { return nil }
        return phaseID
    }

    var phaseName: String? {
        guard case let .linked(_, _, phaseName) = self else { return nil }
        return phaseName
    }
}

struct WorkspaceDeliveryGoalProjection: Equatable, Sendable, Identifiable {
    let project: ProjectDashboardProjection
    let phaseID: PhaseID
    let phaseName: String
    let phasePlan: PhasePlanProjection
    let phaseLifecycle: PhaseLifecycleRecord?
    let goal: DeliveryGoalSummaryProjection

    var id: Data {
        Data(project.id.rawValue.utf8) + [0] + Data(phaseID.rawValue.utf8) + [0] + goal.id
    }
}

struct WorkspaceExecutionGoalProjection: Equatable, Sendable, Identifiable {
    let project: ProjectDashboardProjection
    let goalID: String
    let threadID: String
    let status: String
    let text: String
    let observedAt: Date?
    let link: WorkspaceExecutionLink

    var id: Data {
        Data(project.id.rawValue.utf8) + [0] + Data(threadID.utf8) + [0] + Data(goalID.utf8)
    }
}

struct WorkspaceUnassignedDeliveryWorkProjection: Equatable, Sendable, Identifiable {
    let project: ProjectDashboardProjection
    let phaseID: PhaseID
    let phaseName: String
    let tickets: [TicketCardProjection]

    var id: Data {
        Data(project.id.rawValue.utf8) + [0] + Data(phaseID.rawValue.utf8)
    }
}

struct WorkspaceGoalsProjection: Equatable, Sendable {
    let delivery: [WorkspaceDeliveryGoalProjection]
    let unassignedDeliveryWork: [WorkspaceUnassignedDeliveryWorkProjection]
    let execution: [WorkspaceExecutionGoalProjection]

    static let empty = WorkspaceGoalsProjection(delivery: [], unassignedDeliveryWork: [], execution: [])

    static func load(
        connection: SQLiteConnection,
        projects: [ProjectDashboardProjection],
        boards: [PhaseBoardKey: PhaseBoardProjection]
    ) throws -> WorkspaceGoalsProjection {
        let delivery = boards.values.flatMap { board in
            board.deliveryGoals.map {
                WorkspaceDeliveryGoalProjection(
                    project: board.project, phaseID: board.phaseID, phaseName: board.phaseName,
                    phasePlan: board.phasePlan, phaseLifecycle: board.phaseLifecycle, goal: $0
                )
            }
        }.sorted {
            ($0.project.name, $0.phaseName, $0.goal.goalID.rawValue)
                < ($1.project.name, $1.phaseName, $1.goal.goalID.rawValue)
        }
        let unassignedDeliveryWork = boards.values.compactMap { board -> WorkspaceUnassignedDeliveryWorkProjection? in
            let tickets = board.lanes.flatMap(\.cards).filter { $0.deliveryGoal == nil }
            guard !tickets.isEmpty else { return nil }
            return .init(
                project: board.project,
                phaseID: board.phaseID,
                phaseName: board.phaseName,
                tickets: tickets
            )
        }.sorted {
            ($0.project.name, $0.phaseName) < ($1.project.name, $1.phaseName)
        }

        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { (Data($0.id.rawValue.utf8), $0) })
        let execution = try connection.workspaceGoalRows(
            """
            SELECT observed_goals.project_id, observed_goals.id, observed_goals.thread_id,
                   observed_goals.status, observed_goals.text, observed_goals.last_observed_at,
                   ticket_goal_links.ticket_id
            FROM observed_goals
            LEFT JOIN ticket_goal_links
              ON ticket_goal_links.project_id = observed_goals.project_id
             AND ticket_goal_links.goal_id = observed_goals.id
             AND ticket_goal_links.thread_id = observed_goals.thread_id
            JOIN projects ON projects.id = observed_goals.project_id
            WHERE projects.lifecycle = 'active'
            ORDER BY observed_goals.last_observed_at DESC, observed_goals.project_id,
                     observed_goals.thread_id, observed_goals.id
            """
        ).compactMap { row -> WorkspaceExecutionGoalProjection? in
            let projectID = ProjectID(rawValue: try row.text("project_id"))
            guard let project = projectsByID[Data(projectID.rawValue.utf8)] else { return nil }
            let ticketID = try row.nullableText("ticket_id").map(TicketID.init(rawValue:))
            let linkedBoard = ticketID.flatMap { ticketID in
                boards.values.first { board in
                    board.project.id.rawValue.utf8.elementsEqual(projectID.rawValue.utf8)
                        && board.details.values.contains(where: {
                            $0.id.rawValue.utf8.elementsEqual(ticketID.rawValue.utf8)
                        })
                }
            }
            return WorkspaceExecutionGoalProjection(
                project: project, goalID: try row.text("id"), threadID: try row.text("thread_id"),
                status: try row.text("status"), text: try row.text("text"),
                observedAt: ISO8601DateFormatter().date(from: try row.text("last_observed_at")),
                link: ticketID.map {
                    .linked(ticketID: $0, phaseID: linkedBoard?.phaseID, phaseName: linkedBoard?.phaseName)
                } ?? .unlinked
            )
        }
        return .init(delivery: delivery, unassignedDeliveryWork: unassignedDeliveryWork, execution: execution)
    }
}

private extension SQLiteConnection {
    func workspaceGoalRows(_ sql: String) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func text(_ column: String) throws -> String {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return text
    }

    func nullableText(_ column: String) throws -> String? {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        if case .null = value { return nil }
        return try text(column)
    }
}
