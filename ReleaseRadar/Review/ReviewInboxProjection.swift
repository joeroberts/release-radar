import Foundation
import ReleaseRadarCore

enum ReviewItemKind: Equatable, Sendable {
    case uncertainImport
    case duplicate
    case unresolvedDependency
    case unmatchedTask
    case excludedTask
    case agentReviewRequest
    case unsupported(String)

    init(storedValue: String) {
        switch storedValue {
        case "import", "uncertain_import": self = .uncertainImport
        case "duplicate": self = .duplicate
        case "unresolved_dependency": self = .unresolvedDependency
        case "unmatched_task": self = .unmatchedTask
        case "excluded_task": self = .excludedTask
        case "agent_review_request": self = .agentReviewRequest
        default: self = .unsupported(storedValue)
        }
    }

    var title: String {
        switch self {
        case .uncertainImport: "Uncertain import"
        case .duplicate: "Possible duplicate"
        case .unresolvedDependency: "Unresolved dependency"
        case .unmatchedTask: "Unmatched task"
        case .excludedTask: "Excluded task"
        case .agentReviewRequest: "Agent review request"
        case let .unsupported(value): value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .uncertainImport: "tray.and.arrow.down"
        case .duplicate: "square.on.square"
        case .unresolvedDependency: "arrow.triangle.branch"
        case .unmatchedTask: "questionmark.folder"
        case .excludedTask: "eye.slash"
        case .agentReviewRequest: "checkmark.bubble"
        case .unsupported: "questionmark.circle"
        }
    }
}

enum ReviewItemStatus: String, Equatable, Sendable {
    case open
    case resolved
    case dismissed
}

struct ReviewItemProjection: Equatable, Identifiable, Sendable {
    let id: ReviewItemID
    let projectID: ProjectID
    let ticketID: TicketID?
    let kind: ReviewItemKind
    let summary: String
    let status: ReviewItemStatus
}

struct ReviewInboxProjection: Equatable, Sendable {
    let projectID: ProjectID
    let openItems: [ReviewItemProjection]
    let completedItems: [ReviewItemProjection]
    var deliveryGoalAcceptances: [DeliveryGoalAcceptanceReviewProjection] = []

    static func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ReviewInboxProjection {
        try await store.read { connection in
            let rows = try connection.reviewRows(projectID: projectID)
            let items = try rows.map { row in
                guard let status = ReviewItemStatus(rawValue: try row.reviewText("status")) else {
                    throw ReviewInboxProjectionError.invalidStatus(try row.reviewText("status"))
                }
                return ReviewItemProjection(
                    id: ReviewItemID(rawValue: try row.reviewText("id")),
                    projectID: projectID,
                    ticketID: row.reviewOptionalText("ticket_id").map(TicketID.init(rawValue:)),
                    kind: ReviewItemKind(storedValue: try row.reviewText("kind")),
                    summary: try row.reviewText("summary"),
                    status: status
                )
            }
            let awaiting = try connection.rows(
                """
                SELECT goals.id, goals.phase_id, phases.name AS phase_name
                FROM delivery_goals AS goals
                JOIN phases ON phases.project_id = goals.project_id AND phases.id = goals.phase_id
                WHERE goals.project_id = ? AND goals.lifecycle = 'awaiting_acceptance'
                ORDER BY phases.name COLLATE NOCASE, phases.id, goals.sort_order, goals.id COLLATE BINARY
                """, bindings: [.text(projectID.rawValue)]
            )
            let acceptances = try awaiting.map { row in
                let phaseID = PhaseID(rawValue: try row.reviewText("phase_id"))
                let goalID = DeliveryGoalID(rawValue: try row.reviewText("id"))
                guard let plan = try DeliveryPlanningPolicy.loadPlan(projectID: projectID, phaseID: phaseID, connection: connection),
                      let goal = try DeliveryPlanningPolicy.loadGoal(projectID: projectID, goalID: goalID, connection: connection)
                else { throw ReviewInboxProjectionError.missingColumn("Delivery Goal plan") }
                return DeliveryGoalAcceptanceReviewProjection(
                    projectID: projectID, phaseID: phaseID, phaseName: try row.reviewText("phase_name"),
                    goalID: goalID, title: goal.title, outcome: goal.outcome,
                    doneCriteria: try DeliveryPlanningPolicy.loadCriteria(projectID: projectID, phaseID: phaseID, goalID: goalID, connection: connection).map(\.text),
                    ticketIDs: try DeliveryPlanningPolicy.loadAssignments(projectID: projectID, phaseID: phaseID, connection: connection)
                        .filter { $0.goalID.rawValue.utf8.elementsEqual(goalID.rawValue.utf8) }.map(\.ticketID),
                    expectedPlanRevision: plan.revision
                )
            }
            return ReviewInboxProjection(
                projectID: projectID,
                openItems: items.filter { $0.status == .open },
                completedItems: items.filter { $0.status != .open },
                deliveryGoalAcceptances: acceptances
            )
        }
    }
}

/// Derived owner attention, never a persisted import-review row or acceptance authority.
struct DeliveryGoalAcceptanceReviewProjection: Equatable, Identifiable, Sendable {
    struct ID: Hashable, Sendable {
        let projectID: ProjectID
        let phaseID: PhaseID
        let goalID: DeliveryGoalID

        static func == (lhs: Self, rhs: Self) -> Bool {
            PhaseBoardKey(projectID: lhs.projectID, phaseID: lhs.phaseID) == PhaseBoardKey(projectID: rhs.projectID, phaseID: rhs.phaseID)
                && lhs.goalID.rawValue.utf8.elementsEqual(rhs.goalID.rawValue.utf8)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(PhaseBoardKey(projectID: projectID, phaseID: phaseID))
            hasher.combine(Data(goalID.rawValue.utf8))
        }
    }

    let projectID: ProjectID
    let phaseID: PhaseID
    let phaseName: String
    let goalID: DeliveryGoalID
    let title: String
    let outcome: String
    let doneCriteria: [String]
    let ticketIDs: [TicketID]
    let expectedPlanRevision: Int64

    var id: ID { ID(projectID: projectID, phaseID: phaseID, goalID: goalID) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.phaseName == rhs.phaseName && lhs.title == rhs.title && lhs.outcome == rhs.outcome
            && lhs.doneCriteria == rhs.doneCriteria && lhs.ticketIDs == rhs.ticketIDs
            && lhs.expectedPlanRevision == rhs.expectedPlanRevision
    }
}

enum ReviewInboxProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidStatus(String)
}

private extension SQLiteConnection {
    func reviewRows(projectID: ProjectID) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row(
            "SELECT id, ticket_id, kind, summary, status FROM review_items WHERE project_id = ? ORDER BY rowid LIMIT 1 OFFSET ?",
            bindings: [.text(projectID.rawValue), .integer(offset)]
        ) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func reviewText(_ column: String) throws -> String {
        guard let value = self[column] else { throw ReviewInboxProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw ReviewInboxProjectionError.invalidColumn(column) }
        return text
    }

    func reviewOptionalText(_ column: String) -> String? {
        guard case let .text(text)? = self[column] else { return nil }
        return text
    }
}
