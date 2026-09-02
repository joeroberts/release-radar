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

    static func load(from store: DeliveryStore, bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) async throws -> DashboardProjection {
        let projectIDs = try await store.read { c in
            try c.dashboardRows("SELECT id FROM projects ORDER BY id").map { ProjectID(rawValue: try $0.text("id")) }
        }
        var readbacks: [ProjectID: [EvidenceReadback]] = [:]
        for projectID in projectIDs {
            readbacks[projectID] = try await store.evidenceReadback(projectID: projectID, bookmarkStore: bookmarkStore)
        }
        let evidenceByProject = readbacks
        return try await store.read { connection in
            let projectRows = try connection.dashboardRows(
                """
                SELECT projects.id, projects.name, project_active_phases.phase_id AS active_phase_id
                FROM projects
                LEFT JOIN project_active_phases ON project_active_phases.project_id = projects.id
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM review_items
                    WHERE review_items.project_id = projects.id
                      AND review_items.kind = ?
                      AND review_items.status = 'open'
                )
                ORDER BY projects.name
                """,
                bindings: [.text(OnboardingReviewMarkerKind.pending.rawValue)]
            )
            var projects: [ProjectDashboardProjection] = []
            var boards: [ProjectID: PhaseBoardProjection] = [:]

            for projectRow in projectRows {
                let projectID = ProjectID(rawValue: try projectRow.text("id"))
                let projectName = try projectRow.text("name")
                let goalContext = try connection.projectGoalContext(projectID: projectID)
                let phases = try connection.dashboardRows(
                    "SELECT id, name FROM phases WHERE project_id = ? ORDER BY name COLLATE NOCASE, id",
                    bindings: [.text(projectID.rawValue)]
                ).map {
                    ProjectPhaseProjection(
                        id: PhaseID(rawValue: try $0.text("id")),
                        name: try $0.text("name")
                    )
                }
                guard let activePhaseID = try projectRow.nullableText("active_phase_id"),
                      let phaseRow = try connection.row(
                        "SELECT id, name FROM phases WHERE project_id = ? AND id = ?",
                        bindings: [.text(projectID.rawValue), .text(activePhaseID)]
                      ) else {
                    projects.append(.init(
                        id: projectID,
                        name: projectName,
                        activePhaseID: nil,
                        activePhaseName: "No active phase",
                        phases: phases,
                        goalContext: goalContext,
                        currentWorkCount: 0,
                        attentionCount: 0,
                        evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == nil }.map(EvidenceProjection.init)
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
                        outcome: outcome,
                        evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == ticketID }.map(EvidenceProjection.init)
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
                    activePhaseID: phaseID,
                    activePhaseName: try phaseRow.text("name"),
                    phases: phases,
                    goalContext: goalContext,
                    currentWorkCount: currentWorkCount,
                    attentionCount: attentionCount,
                    evidence: (evidenceByProject[projectID] ?? []).filter { $0.evidence.ticketID == nil }.map(EvidenceProjection.init)
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

struct ProjectPhaseProjection: Equatable, Sendable, Identifiable {
    let id: PhaseID
    let name: String
}

struct ProjectDashboardProjection: Equatable, Sendable, Identifiable {
    let id: ProjectID
    let name: String
    let activePhaseID: PhaseID?
    let activePhaseName: String
    let phases: [ProjectPhaseProjection]
    let goalContext: GoalContextProjection
    let currentWorkCount: Int
    let attentionCount: Int
    let evidence: [EvidenceProjection]

    init(
        id: ProjectID,
        name: String,
        activePhaseID: PhaseID? = nil,
        activePhaseName: String,
        phases: [ProjectPhaseProjection] = [],
        goalContext: GoalContextProjection,
        currentWorkCount: Int,
        attentionCount: Int,
        evidence: [EvidenceProjection] = []
    ) {
        self.id = id
        self.name = name
        self.activePhaseID = activePhaseID
        self.activePhaseName = activePhaseName
        self.phases = phases
        self.goalContext = goalContext
        self.currentWorkCount = currentWorkCount
        self.attentionCount = attentionCount
        self.evidence = evidence
    }
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
    let locator: EvidenceLocator
    let managedDocument: ResolvedManagedDocument?

    init(id: EvidenceID, label: String, path: String, isAvailable: Bool) {
        self.id = id; self.label = label; self.path = path; self.isAvailable = isAvailable
        locator = .filePath(path); managedDocument = nil
    }
    init(_ readback: EvidenceReadback) {
        id = readback.evidence.id; locator = readback.evidence.locator
        managedDocument = readback.managedDocument
        switch locator {
        case let .filePath(value):
            path = value; label = URL(fileURLWithPath: value).lastPathComponent
            isAvailable = readback.evidence.isAvailable
        case let .managedDocument(id):
            path = readback.managedDocument?.resolvedPath ?? ""
            label = readback.managedDocument?.label ?? id
            isAvailable = readback.managedDocument?.isAvailable == true
        }
    }
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
        outcome: String,
        evidence: [EvidenceProjection]
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
            FROM ticket_goal_links
            JOIN observed_goals
              ON observed_goals.project_id = ticket_goal_links.project_id
             AND observed_goals.id = ticket_goal_links.goal_id
             AND observed_goals.thread_id = ticket_goal_links.thread_id
            WHERE ticket_goal_links.project_id = ? AND ticket_goal_links.ticket_id = ?
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
