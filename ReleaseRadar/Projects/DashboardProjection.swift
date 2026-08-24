import Foundation
import ReleaseRadarCore

enum DashboardCardPresentation: Equatable, Sendable {
    case fullOutcome
    case compactID
}
enum DashboardLayout {
    static func presentation(forLaneWidth width: CGFloat) -> DashboardCardPresentation {
        width > 180 ? .fullOutcome : .compactID
    }

    static func sidebarWidth(isCompact: Bool) -> CGFloat {
        isCompact ? 96 : 220
    }
}

struct DashboardProjection: Equatable, Sendable {
    let projects: [ProjectDashboardProjection]
    let boards: [ProjectID: PhaseBoardProjection]

    func board(for projectID: ProjectID) -> PhaseBoardProjection? {
        boards[projectID]
    }

    static func load(from store: DeliveryStore) async throws -> DashboardProjection {
        try await store.read { connection in
            let projectRows = try connection.dashboardRows(
                """
                SELECT projects.id, projects.name, project_active_phases.phase_id AS active_phase_id
                FROM projects
                LEFT JOIN project_active_phases ON project_active_phases.project_id = projects.id
                ORDER BY projects.name
                """
            )
            var projects: [ProjectDashboardProjection] = []
            var boards: [ProjectID: PhaseBoardProjection] = [:]

            for projectRow in projectRows {
                let projectID = ProjectID(rawValue: try projectRow.text("id"))
                let projectName = try projectRow.text("name")
                let goalContext = try connection.projectGoalContext(projectID: projectID)
                guard let activePhaseID = try projectRow.nullableText("active_phase_id"),
                      let phaseRow = try connection.row(
                        "SELECT id, name FROM phases WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(activePhaseID)]
                      ) else {
                    projects.append(.init(
                        id: projectID,
                        name: projectName,
                        activePhaseName: "No active phase",
                        goalContext: goalContext,
                        currentWorkCount: 0,
                        attentionCount: 0
                    ))
                    continue
                }

                let phaseID = PhaseID(rawValue: try phaseRow.text("id"))
                let ticketRows = try connection.dashboardRows(
                    "SELECT id, outcome, lane FROM tickets WHERE project_id = ? AND phase_id = ? ORDER BY rowid",
                    bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
                )
                var cardsByLane = Dictionary(uniqueKeysWithValues: TicketLane.allCases.map { ($0, [TicketCardProjection]()) })
                var details: [TicketID: TicketDetailProjection] = [:]

                for ticketRow in ticketRows {
                    let ticketID = TicketID(rawValue: try ticketRow.text("id"))
                    guard let lane = TicketLane(rawValue: try ticketRow.text("lane")) else {
                        throw DashboardProjectionError.invalidLane(try ticketRow.text("lane"))
                    }
                    let outcome = try ticketRow.text("outcome")
                    let dependencyCount = Int(try connection.scalarInt(
                        "SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = ? AND ticket_id = ?",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) ?? 0)
                    let blockerCount = Int(try connection.scalarInt(
                        "SELECT COUNT(*) FROM blockers WHERE project_id = ? AND ticket_id = ? AND resolved_at IS NULL",
                        bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
                    ) ?? 0)
                    let card = TicketCardProjection(
                        id: ticketID,
                        outcome: outcome,
                        dependencyCount: dependencyCount,
                        blockerCount: blockerCount
                    )
                    cardsByLane[lane, default: []].append(card)
                    details[ticketID] = try connection.ticketDetail(
                        projectID: projectID,
                        ticketID: ticketID,
                        outcome: outcome
                    )
                }

                let lanes = TicketLane.allCases.map {
                    DashboardLaneProjection(lane: $0, cards: cardsByLane[$0] ?? [])
                }
                let currentWorkCount = lanes
                    .filter { $0.lane != .accepted }
                    .reduce(0) { $0 + $1.count }
                let attentionCount = lanes
                    .filter { $0.lane == .needsReview || $0.lane == .blocked }
                    .reduce(0) { $0 + $1.count }
                let project = ProjectDashboardProjection(
                    id: projectID,
                    name: projectName,
                    activePhaseName: try phaseRow.text("name"),
                    goalContext: goalContext,
                    currentWorkCount: currentWorkCount,
                    attentionCount: attentionCount
                )
                projects.append(project)
                boards[projectID] = PhaseBoardProjection(
                    project: project,
                    phaseID: phaseID,
                    lanes: lanes,
                    details: details
                )
            }

            return DashboardProjection(projects: projects, boards: boards)
        }
    }
}

struct ProjectDashboardProjection: Equatable, Sendable, Identifiable {
    let id: ProjectID
    let name: String
    let activePhaseName: String
    let goalContext: GoalContextProjection
    let currentWorkCount: Int
    let attentionCount: Int
}

struct PhaseBoardProjection: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let phaseID: PhaseID
    let lanes: [DashboardLaneProjection]
    let details: [TicketID: TicketDetailProjection]

    func lane(_ lane: TicketLane) -> DashboardLaneProjection? {
        lanes.first { $0.lane == lane }
    }

    func detail(for ticketID: TicketID) -> TicketDetailProjection? {
        details[ticketID]
    }
}

struct DashboardLaneProjection: Equatable, Sendable, Identifiable {
    let lane: TicketLane
    let cards: [TicketCardProjection]

    var id: TicketLane { lane }
    var count: Int { cards.count }
}

struct TicketCardProjection: Equatable, Sendable, Identifiable {
    let id: TicketID
    let outcome: String
    let dependencyCount: Int
    let blockerCount: Int
}

struct TicketDetailProjection: Equatable, Sendable {
    let id: TicketID
    let outcome: String
    let goalContext: GoalContextProjection
    let requires: [TicketReferenceProjection]
    let unlocks: [TicketReferenceProjection]
    let ownerAttention: [String]
    let evidence: [EvidenceProjection]
    let auditHistory: [String]
    let notificationHistory: [String]
}

enum GoalLinkQuality: String, Equatable, Sendable {
    case verified = "Verified link"
    case unavailable = "No linked goal"
}

struct GoalContextProjection: Equatable, Sendable {
    let linkQuality: GoalLinkQuality
    let text: String?
    let status: String?
    let lastObservedAt: Date?
}

struct TicketReferenceProjection: Equatable, Sendable, Identifiable {
    let id: TicketID
    let outcome: String
}

struct EvidenceProjection: Equatable, Sendable, Identifiable {
    let id: EvidenceID
    let label: String
    let path: String
    let isAvailable: Bool
}

enum DashboardProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidLane(String)
}

extension TicketLane {
    var dashboardTitle: String {
        switch self {
        case .backlog: "Backlog"
        case .inProgress: "In progress"
        case .needsReview: "Needs review"
        case .blocked: "Blocked"
        case .accepted: "Accepted"
        }
    }
}

private extension SQLiteConnection {
    func dashboardRows(_ sql: String, bindings: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: bindings + [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }

    func ticketDetail(
        projectID: ProjectID,
        ticketID: TicketID,
        outcome: String
    ) throws -> TicketDetailProjection {
        let requires = try dashboardRows(
            """
            SELECT tickets.id, tickets.outcome
            FROM ticket_dependencies
            JOIN tickets ON tickets.id = ticket_dependencies.depends_on_ticket_id
            WHERE ticket_dependencies.project_id = ? AND ticket_dependencies.ticket_id = ?
            ORDER BY ticket_dependencies.rowid
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map {
            TicketReferenceProjection(
                id: TicketID(rawValue: try $0.text("id")),
                outcome: try $0.text("outcome")
            )
        }
        let unlocks = try dashboardRows(
            """
            SELECT tickets.id, tickets.outcome
            FROM ticket_dependencies
            JOIN tickets ON tickets.id = ticket_dependencies.ticket_id
            WHERE ticket_dependencies.project_id = ? AND ticket_dependencies.depends_on_ticket_id = ?
            ORDER BY ticket_dependencies.rowid
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map {
            TicketReferenceProjection(
                id: TicketID(rawValue: try $0.text("id")),
                outcome: try $0.text("outcome")
            )
        }
        let ownerAttention = try dashboardRows(
            "SELECT summary FROM blockers WHERE project_id = ? AND ticket_id = ? AND resolved_at IS NULL ORDER BY rowid",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map { try $0.text("summary") }
        let evidence = try dashboardRows(
            "SELECT id, path, is_available FROM evidence WHERE project_id = ? AND ticket_id = ? ORDER BY rowid",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map {
            let path = try $0.text("path")
            return EvidenceProjection(
                id: EvidenceID(rawValue: try $0.text("id")),
                label: URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                isAvailable: try $0.integer("is_available") == 1
            )
        }
        let auditHistory = try dashboardRows(
            "SELECT reason FROM audit_events WHERE reason LIKE ? ORDER BY created_at DESC",
            bindings: [.text("%\(ticketID.rawValue)%")]
        ).map { try $0.text("reason") }
        let notificationHistory = try dashboardRows(
            "SELECT fingerprint, state FROM notification_events WHERE ticket_id = ? ORDER BY rowid",
            bindings: [.text(ticketID.rawValue)]
        ).map { "\(try $0.text("fingerprint")) · \(try $0.text("state"))" }

        let goalRow = try row(
            """
            SELECT observed_goals.text, observed_goals.status, observed_goals.last_observed_at
            FROM thread_links
            JOIN observed_goals ON observed_goals.thread_id = thread_links.thread_id
            WHERE thread_links.project_id = ? AND thread_links.ticket_id = ?
            ORDER BY observed_goals.last_observed_at DESC LIMIT 1
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        )
        let goalContext: GoalContextProjection
        if let goalRow {
            goalContext = GoalContextProjection(
                linkQuality: .verified,
                text: try goalRow.text("text"),
                status: try goalRow.text("status"),
                lastObservedAt: ISO8601DateFormatter().date(from: try goalRow.text("last_observed_at"))
            )
        } else {
            goalContext = GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            )
        }

        return TicketDetailProjection(
            id: ticketID,
            outcome: outcome,
            goalContext: goalContext,
            requires: requires,
            unlocks: unlocks,
            ownerAttention: ownerAttention,
            evidence: evidence,
            auditHistory: auditHistory,
            notificationHistory: notificationHistory
        )
    }

    func projectGoalContext(projectID: ProjectID) throws -> GoalContextProjection {
        guard let goalRow = try row(
            """
            SELECT text, status, last_observed_at
            FROM observed_goals
            WHERE project_id = ?
            ORDER BY last_observed_at DESC, rowid DESC LIMIT 1
            """,
            bindings: [.text(projectID.rawValue)]
        ) else {
            return GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            )
        }

        return GoalContextProjection(
            linkQuality: .verified,
            text: try goalRow.text("text"),
            status: try goalRow.text("status"),
            lastObservedAt: ISO8601DateFormatter().date(from: try goalRow.text("last_observed_at"))
        )
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func nullableText(_ column: String) throws -> String? {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        if case .null = value { return nil }
        guard case let .text(text) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return text
    }

    func text(_ column: String) throws -> String {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return text
    }

    func integer(_ column: String) throws -> Int64 {
        guard let value = self[column] else { throw DashboardProjectionError.missingColumn(column) }
        guard case let .integer(integer) = value else { throw DashboardProjectionError.invalidColumn(column) }
        return integer
    }
}
