import Foundation

public enum PhaseCreationMode: Sendable {
    case governed
    case legacyUnassessedImport
}

public enum DeliveryPlanningPolicyError: Error, LocalizedError, Equatable, Sendable {
    case phasePlanNotFound
    case planRevisionConflict(expected: Int64, current: Int64)
    case phasePlanNotReady
    case phasePlanIncomplete(PhasePlanReadinessFailure)
    case goalPhaseMismatch(DeliveryGoalID)
    case goalNotFound(DeliveryGoalID)
    case goalNotActionable(DeliveryGoalID)
    case invalidGoalTransition(from: DeliveryGoalLifecycle, to: DeliveryGoalLifecycle)
    case ownerAcceptanceRequired
    case goalAcceptanceEvidenceUnavailable([TicketID])
    case invalidPlanMutation(String)

    public var errorDescription: String? {
        switch self {
        case .phasePlanNotFound: "The phase plan does not exist. Refresh the project."
        case .planRevisionConflict: "The phase plan changed. Refresh its revision before retrying."
        case .phasePlanNotReady: "Finalize the current phase plan before changing the Delivery Goal lifecycle."
        case .phasePlanIncomplete:
            "Complete the listed Delivery Goals and assign every upcoming ticket before finalizing."
        case .goalPhaseMismatch:
            "The Delivery Goal belongs to a different phase. Refresh the plan and use its owning phase."
        case .goalNotFound: "The Delivery Goal does not exist. Refresh the plan."
        case .goalNotActionable: "This Delivery Goal cannot receive upcoming work. Select an actionable goal."
        case .invalidGoalTransition:
            "That Delivery Goal transition is not permitted. Planning, activation and supersession must use their governing operations."
        case .ownerAcceptanceRequired: "Only the owner application can accept a Delivery Goal."
        case .goalAcceptanceEvidenceUnavailable:
            "Restore the unavailable evidence linked to the listed tickets before requesting or recording goal acceptance."
        case .invalidPlanMutation(let message): message
        }
    }
}

/// Called only with a connection leased by DeliveryStore. The caller owns the
/// transaction, audit and (when exposed by a command) request receipt.
public enum DeliveryPlanningPolicy {
    public static let maximumGoalOperationsPerRevision = 64
    public static let maximumAssignmentOperationsPerRevision = 512

    @discardableResult
    public static func applyRevision(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        goalUpserts: [DeliveryGoalDraft],
        assignments: [DeliveryGoalAssignment],
        unassignedTicketIDs: [TicketID],
        supersededGoalIDs: [DeliveryGoalID],
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws -> PhasePlanRecord {
        let plan = try requirePlan(projectID, phaseID, expectedRevision, connection)
        let goalCount = goalUpserts.count + supersededGoalIDs.count
        let assignmentCount = assignments.count + unassignedTicketIDs.count
        guard goalCount + assignmentCount > 0 else { throw invalid("Supply at least one explicit plan operation.") }
        guard goalCount <= maximumGoalOperationsPerRevision,
            assignmentCount <= maximumAssignmentOperationsPerRevision
        else {
            throw invalid("A revision permits at most 64 goal operations and 512 assignment operations.")
        }
        guard plan.revision < Int64.max else { throw invalid("The phase plan revision cannot advance further.") }
        try requireDistinct(goalUpserts.map(\.id.rawValue) + supersededGoalIDs.map(\.rawValue))
        try requireDistinct(assignments.map(\.ticketID.rawValue) + unassignedTicketIDs.map(\.rawValue))
        try validateID(auditEventID.rawValue)
        let timestamp = operationTimestamp()
        let revision = plan.revision + 1

        for draft in goalUpserts {
            try validateDraft(draft)
            if let current = try loadGoal(projectID: projectID, goalID: draft.id, connection: connection) {
                guard identityKey(current.phaseID.rawValue) == identityKey(phaseID.rawValue) else {
                    throw DeliveryPlanningPolicyError.goalPhaseMismatch(draft.id)
                }
                guard current.lifecycle != .accepted, current.lifecycle != .superseded else {
                    throw invalid("Accepted and Superseded Delivery Goal definitions are immutable.")
                }
            }
            try writeGoal(draft, projectID, phaseID, timestamp, connection)
        }

        // Validate against the original membership before any transfer can hide
        // work that makes supersession illegal.
        for id in supersededGoalIDs {
            let goal = try requireGoal(projectID, phaseID, id, connection)
            guard goal.lifecycle == .draft || goal.lifecycle == .planned else {
                throw invalid("Only unstarted Draft or Planned Delivery Goals can be superseded.")
            }
            let started =
                try connection.scalarInt(
                    """
                    SELECT COUNT(*) FROM delivery_goal_ticket_assignments a
                    JOIN tickets t ON t.project_id=a.project_id AND t.id=a.ticket_id
                    WHERE a.project_id=? AND a.phase_id=? AND a.goal_id=? AND t.lane<>'backlog'
                    """, bindings: identity(projectID, phaseID) + [.text(id.rawValue)]) ?? 0
            guard started == 0 else {
                throw invalid("A Delivery Goal with started or Accepted tickets cannot be superseded.")
            }
        }

        for assignment in assignments {
            try validateID(assignment.goalID.rawValue)
            let goal = try requireGoal(projectID, phaseID, assignment.goalID, connection)
            guard goal.lifecycle != .accepted, goal.lifecycle != .superseded,
                !supersededGoalIDs.contains(where: { identityKey($0.rawValue) == identityKey(goal.id.rawValue) })
            else {
                throw DeliveryPlanningPolicyError.goalNotActionable(goal.id)
            }
            try changeAssignment(projectID, phaseID, assignment.ticketID, goal, revision, auditEventID, connection)
        }
        for ticketID in unassignedTicketIDs {
            try changeAssignment(projectID, phaseID, ticketID, nil, revision, auditEventID, connection)
        }
        for id in supersededGoalIDs {
            let remaining =
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM delivery_goal_ticket_assignments WHERE project_id=? AND goal_id=?",
                    bindings: [.text(projectID.rawValue), .text(id.rawValue)]) ?? 0
            guard remaining == 0 else {
                throw invalid("Explicitly remove or transfer every assignment in the same supersession revision.")
            }
            try writeLifecycle(projectID, id, .superseded, timestamp, connection)
        }
        try invalidatePlan(projectID, phaseID, revision, timestamp, connection)
        return try requirePlan(projectID, phaseID, revision, connection)
    }

    @discardableResult
    public static func finalizePlan(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        connection: SQLiteConnection
    ) throws -> PhasePlanRecord {
        let plan = try requirePlan(projectID, phaseID, expectedRevision, connection)
        // A delivered Ready plan remains valid even after the last ticket is Accepted.
        if plan.state == .ready, plan.readyRevision == plan.revision { return plan }
        let goals = try loadGoals(projectID: projectID, phaseID: phaseID, connection: connection)
        let assignments = try loadAssignments(projectID: projectID, phaseID: phaseID, connection: connection)
        let tickets = try connection.rows(
            "SELECT id,lane,plan_legacy_continuation FROM tickets WHERE project_id=? AND phase_id=? ORDER BY id",
            bindings: identity(projectID, phaseID))
        let upcoming = tickets.filter { text($0["lane"]) != TicketLane.accepted.rawValue }
        var incomplete: [DeliveryGoalID] = []
        var unassigned: [TicketID] = []
        var conflicting: [TicketID] = []
        var adoptedGoals = Set<Data>()
        var adoptedTickets: [TicketID] = []
        let goalsByID = Dictionary(uniqueKeysWithValues: goals.map { (identityKey($0.id.rawValue), $0) })
        let assignmentsByTicket = Dictionary(grouping: assignments, by: { identityKey($0.ticketID.rawValue) })
        let assignmentsByGoal = Dictionary(grouping: assignments, by: { identityKey($0.goalID.rawValue) })

        for goal in goals where goal.lifecycle != .superseded {
            let criteria = try loadCriteria(
                projectID: projectID, phaseID: phaseID, goalID: goal.id, connection: connection)
            if blank(goal.title) || blank(goal.outcome) || criteria.isEmpty
                || criteria.contains(where: { blank($0.text) })
                || assignmentsByGoal[identityKey(goal.id.rawValue), default: []].isEmpty
            {
                incomplete.append(goal.id)
            }
        }
        for ticket in upcoming {
            let id = TicketID(rawValue: try requiredText(ticket, "id"))
            let matches = assignmentsByTicket[identityKey(id.rawValue), default: []]
            guard !matches.isEmpty else {
                unassigned.append(id)
                continue
            }
            guard matches.count == 1, let goal = goalsByID[identityKey(matches[0].goalID.rawValue)],
                goal.lifecycle != .accepted, goal.lifecycle != .superseded
            else {
                conflicting.append(id)
                continue
            }
            if integer(ticket["plan_legacy_continuation"]) == 1 {
                // The sole adoption exception: existing migration authority plus
                // an explicit, exact Draft assignment. Never infer from observations.
                guard
                    [TicketLane.inProgress.rawValue, TicketLane.needsReview.rawValue].contains(
                        text(ticket["lane"]) ?? ""),
                    goal.lifecycle == .draft
                else {
                    conflicting.append(id)
                    continue
                }
                adoptedGoals.insert(identityKey(goal.id.rawValue))
                adoptedTickets.append(id)
            } else if [TicketLane.inProgress.rawValue, TicketLane.needsReview.rawValue].contains(
                text(ticket["lane"]) ?? ""), goal.lifecycle == .draft
            {
                conflicting.append(id)
            }
        }
        guard !upcoming.isEmpty, goals.contains(where: { $0.lifecycle != .superseded }),
            incomplete.isEmpty, unassigned.isEmpty, conflicting.isEmpty
        else {
            throw DeliveryPlanningPolicyError.phasePlanIncomplete(
                .init(unassignedTicketIDs: unassigned, incompleteGoalIDs: incomplete, conflictingTicketIDs: conflicting)
            )
        }
        let timestamp = operationTimestamp()
        for goal in goals where goal.lifecycle == .draft {
            try writeLifecycle(
                projectID, goal.id, adoptedGoals.contains(identityKey(goal.id.rawValue)) ? .active : .planned,
                timestamp, connection)
        }
        for ticketID in adoptedTickets { try clearContinuation(projectID, ticketID, connection) }
        try markReady(projectID, phaseID, plan.revision, timestamp, connection)
        return try requirePlan(projectID, phaseID, plan.revision, connection)
    }

    @discardableResult
    public static func transitionGoal(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        expectedPlanRevision: Int64,
        to lifecycle: DeliveryGoalLifecycle,
        origin: AgentCommandOrigin,
        connection: SQLiteConnection
    ) throws -> DeliveryGoalRecord {
        let plan = try requirePlan(projectID, phaseID, expectedPlanRevision, connection)
        let goal = try requireGoal(projectID, phaseID, goalID, connection)
        guard plan.state == .ready, plan.readyRevision == plan.revision else {
            throw DeliveryPlanningPolicyError.phasePlanNotReady
        }
        guard
            (goal.lifecycle == .active && lifecycle == .awaitingAcceptance)
                || (goal.lifecycle == .awaitingAcceptance && lifecycle == .accepted)
        else {
            throw DeliveryPlanningPolicyError.invalidGoalTransition(from: goal.lifecycle, to: lifecycle)
        }
        if lifecycle == .accepted {
            guard case .ownerApp = origin else { throw DeliveryPlanningPolicyError.ownerAcceptanceRequired }
        }
        let tickets = try connection.rows(
            """
            SELECT t.id,t.lane FROM delivery_goal_ticket_assignments a
            JOIN tickets t ON t.project_id=a.project_id AND t.phase_id=a.phase_id AND t.id=a.ticket_id
            WHERE a.project_id=? AND a.phase_id=? AND a.goal_id=? ORDER BY t.id
            """, bindings: identity(projectID, phaseID) + [.text(goalID.rawValue)])
        guard !tickets.isEmpty, tickets.allSatisfy({ text($0["lane"]) == TicketLane.accepted.rawValue }) else {
            throw invalid(
                "Every assigned ticket must be Accepted before requesting or recording Delivery Goal acceptance.")
        }
        // Evidence availability is canonical store state; neither prose nor paths
        // create new evidence requirements. Ticket task gates run at ticket acceptance.
        let unavailable = try connection.rows(
            """
            SELECT DISTINCT a.ticket_id FROM delivery_goal_ticket_assignments a
            JOIN evidence e ON e.project_id=a.project_id AND e.ticket_id=a.ticket_id
            WHERE a.project_id=? AND a.phase_id=? AND a.goal_id=? AND e.is_available=0
            ORDER BY a.ticket_id
            """, bindings: identity(projectID, phaseID) + [.text(goalID.rawValue)])
        guard unavailable.isEmpty else {
            throw DeliveryPlanningPolicyError.goalAcceptanceEvidenceUnavailable(
                try unavailable.map { .init(rawValue: try requiredText($0, "ticket_id")) })
        }
        try writeLifecycle(projectID, goalID, lifecycle, operationTimestamp(), connection)
        return try requireGoal(projectID, phaseID, goalID, connection)
    }

    public static func loadPlan(projectID: ProjectID, phaseID: PhaseID, connection: SQLiteConnection) throws
        -> PhasePlanRecord?
    {
        try validateID(projectID.rawValue)
        try validateID(phaseID.rawValue)
        guard
            let row = try connection.row(
                "SELECT * FROM phase_plans WHERE project_id=? AND phase_id=?", bindings: identity(projectID, phaseID))
        else { return nil }
        guard let state = PhasePlanState(rawValue: try requiredText(row, "state")),
            let revision = integer(row["revision"])
        else { throw invalidRow() }
        return .init(
            projectID: projectID, phaseID: phaseID, state: state, revision: revision,
            readyRevision: integer(row["ready_revision"]), createdAt: try date(row, "created_at"),
            updatedAt: try date(row, "updated_at"), finalizedAt: try optionalDate(row, "finalized_at"))
    }

    public static func loadGoals(projectID: ProjectID, phaseID: PhaseID, connection: SQLiteConnection) throws
        -> [DeliveryGoalRecord]
    {
        try connection.rows(
            "SELECT * FROM delivery_goals WHERE project_id=? AND phase_id=? ORDER BY sort_order,id COLLATE BINARY",
            bindings: identity(projectID, phaseID)
        ).map(goalRecord)
    }

    public static func loadGoal(projectID: ProjectID, goalID: DeliveryGoalID, connection: SQLiteConnection) throws
        -> DeliveryGoalRecord?
    {
        guard
            let row = try connection.row(
                "SELECT * FROM delivery_goals WHERE project_id=? AND id=?",
                bindings: [.text(projectID.rawValue), .text(goalID.rawValue)])
        else { return nil }
        return try goalRecord(row)
    }

    public static func loadCriteria(
        projectID: ProjectID, phaseID: PhaseID, goalID: DeliveryGoalID, connection: SQLiteConnection
    ) throws -> [DeliveryGoalCriterionRecord] {
        try connection.rows(
            "SELECT sort_order,criterion FROM delivery_goal_done_criteria WHERE project_id=? AND phase_id=? AND goal_id=? ORDER BY sort_order",
            bindings: identity(projectID, phaseID) + [.text(goalID.rawValue)]
        ).map { row in
            guard let order = integer(row["sort_order"]) else { throw invalidRow() }
            return .init(
                projectID: projectID, phaseID: phaseID, goalID: goalID, sortOrder: Int(order),
                text: try requiredText(row, "criterion"))
        }
    }

    public static func loadAssignments(projectID: ProjectID, phaseID: PhaseID, connection: SQLiteConnection) throws
        -> [DeliveryGoalAssignmentRecord]
    {
        try connection.rows(
            "SELECT goal_id,ticket_id FROM delivery_goal_ticket_assignments WHERE project_id=? AND phase_id=? ORDER BY ticket_id COLLATE BINARY",
            bindings: identity(projectID, phaseID)
        ).map {
            .init(
                projectID: projectID, phaseID: phaseID, goalID: .init(rawValue: try requiredText($0, "goal_id")),
                ticketID: .init(rawValue: try requiredText($0, "ticket_id")))
        }
    }

    public static func loadAssignmentHistory(projectID: ProjectID, ticketID: TicketID, connection: SQLiteConnection)
        throws -> [DeliveryGoalAssignmentEventRecord]
    {
        try connection.rows(
            "SELECT * FROM delivery_goal_assignment_events WHERE project_id=? AND ticket_id=? ORDER BY phase_id,revision,audit_event_id",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ).map { row in
            guard let revision = integer(row["revision"]) else { throw invalidRow() }
            return .init(
                auditEventID: .init(rawValue: try requiredText(row, "audit_event_id")), projectID: projectID,
                phaseID: .init(rawValue: try requiredText(row, "phase_id")), ticketID: ticketID,
                previousGoalID: text(row["previous_goal_id"]).map { .init(rawValue: $0) },
                currentGoalID: text(row["current_goal_id"]).map { .init(rawValue: $0) }, revision: revision,
                action: try requiredText(row, "action"))
        }
    }

    private static func changeAssignment(
        _ project: ProjectID, _ phase: PhaseID, _ ticket: TicketID, _ goal: DeliveryGoalRecord?, _ revision: Int64,
        _ audit: AuditEventID, _ db: SQLiteConnection
    ) throws {
        try validateID(ticket.rawValue)
        guard
            let row = try db.row(
                "SELECT lane,plan_legacy_continuation FROM tickets WHERE project_id=? AND phase_id=? AND id=?",
                bindings: identity(project, phase) + [.text(ticket.rawValue)])
        else { throw invalid("Assign only an existing ticket in this project and phase.") }
        let previous = try db.scalarText(
            "SELECT goal_id FROM delivery_goal_ticket_assignments WHERE project_id=? AND ticket_id=?",
            bindings: [.text(project.rawValue), .text(ticket.rawValue)])
        let current = goal?.id.rawValue
        if previous.map(identityKey) == current.map(identityKey) { return }
        let lane = try requiredText(row, "lane")
        if previous != nil {
            guard lane == TicketLane.backlog.rawValue else {
                throw invalid("Started and Accepted ticket assignments cannot be removed or transferred.")
            }
        } else if lane != TicketLane.backlog.rawValue && lane != TicketLane.blocked.rawValue {
            guard integer(row["plan_legacy_continuation"]) == 1,
                [TicketLane.inProgress.rawValue, TicketLane.needsReview.rawValue].contains(lane),
                goal?.lifecycle == .draft
            else {
                throw invalid(
                    "Only migration-continuation work may receive its first assignment after starting, and only to a Draft goal."
                )
            }
        }
        try db.execute(
            "DELETE FROM delivery_goal_ticket_assignments WHERE project_id=? AND ticket_id=?",
            bindings: [.text(project.rawValue), .text(ticket.rawValue)])
        if let current {
            try db.execute(
                "INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES (?,?,?,?)",
                bindings: identity(project, phase) + [.text(current), .text(ticket.rawValue)])
        }
        let action = previous == nil ? "assigned" : (current == nil ? "unassigned" : "reassigned")
        try db.execute(
            """
            INSERT INTO delivery_goal_assignment_events
                (audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,current_goal_id,revision,action)
            VALUES (?,?,?,?,?,?,?,?)
            """,
            bindings: [.text(audit.rawValue)] + identity(project, phase) + [
                .text(ticket.rawValue), previous.map(SQLiteValue.text) ?? .null, current.map(SQLiteValue.text) ?? .null,
                .integer(revision), .text(action),
            ])
    }

    private static func writeGoal(
        _ goal: DeliveryGoalDraft, _ project: ProjectID, _ phase: PhaseID, _ timestamp: String, _ db: SQLiteConnection
    ) throws {
        try db.execute(
            """
            INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at)
            VALUES (?,?,?,?,?,'draft',?,?,?)
            ON CONFLICT(project_id,id) DO UPDATE SET title=excluded.title,outcome=excluded.outcome,sort_order=excluded.sort_order,updated_at=excluded.updated_at
            """,
            bindings: identity(project, phase) + [
                .text(goal.id.rawValue), .text(goal.title), .text(goal.outcome), .integer(Int64(goal.sortOrder)),
                .text(timestamp), .text(timestamp),
            ])
        try db.execute(
            "DELETE FROM delivery_goal_done_criteria WHERE project_id=? AND goal_id=?",
            bindings: [.text(project.rawValue), .text(goal.id.rawValue)])
        for (order, criterion) in goal.doneCriteria.enumerated() {
            try db.execute(
                "INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES (?,?,?,?,?)",
                bindings: identity(project, phase) + [
                    .text(goal.id.rawValue), .integer(Int64(order)), .text(criterion),
                ])
        }
    }

    private static func writeLifecycle(
        _ project: ProjectID, _ goal: DeliveryGoalID, _ lifecycle: DeliveryGoalLifecycle, _ timestamp: String,
        _ db: SQLiteConnection
    ) throws {
        try db.execute(
            """
            UPDATE delivery_goals SET lifecycle=?,updated_at=?,
                activated_at=CASE WHEN ?='active' THEN COALESCE(activated_at,?) ELSE activated_at END,
                accepted_at=CASE WHEN ?='accepted' THEN ? ELSE accepted_at END
            WHERE project_id=? AND id=?
            """,
            bindings: [
                .text(lifecycle.rawValue), .text(timestamp), .text(lifecycle.rawValue), .text(timestamp),
                .text(lifecycle.rawValue), .text(timestamp), .text(project.rawValue), .text(goal.rawValue),
            ])
    }

    private static func invalidatePlan(
        _ project: ProjectID, _ phase: PhaseID, _ revision: Int64, _ timestamp: String, _ db: SQLiteConnection
    ) throws {
        try db.execute(
            "UPDATE phase_plans SET state='draft',revision=?,ready_revision=NULL,updated_at=?,finalized_at=NULL WHERE project_id=? AND phase_id=?",
            bindings: [.integer(revision), .text(timestamp)] + identity(project, phase))
    }

    private static func markReady(
        _ project: ProjectID, _ phase: PhaseID, _ revision: Int64, _ timestamp: String, _ db: SQLiteConnection
    ) throws {
        try db.execute(
            "UPDATE phase_plans SET state='ready',ready_revision=?,updated_at=?,finalized_at=? WHERE project_id=? AND phase_id=?",
            bindings: [.integer(revision), .text(timestamp), .text(timestamp)] + identity(project, phase))
    }

    private static func clearContinuation(_ project: ProjectID, _ ticket: TicketID, _ db: SQLiteConnection) throws {
        try db.execute(
            "UPDATE tickets SET plan_legacy_continuation=0 WHERE project_id=? AND id=?",
            bindings: [.text(project.rawValue), .text(ticket.rawValue)])
    }

    private static func requirePlan(_ project: ProjectID, _ phase: PhaseID, _ revision: Int64, _ db: SQLiteConnection)
        throws -> PhasePlanRecord
    {
        guard let plan = try loadPlan(projectID: project, phaseID: phase, connection: db) else {
            throw DeliveryPlanningPolicyError.phasePlanNotFound
        }
        guard revision == plan.revision else {
            throw DeliveryPlanningPolicyError.planRevisionConflict(expected: revision, current: plan.revision)
        }
        return plan
    }

    private static func requireGoal(
        _ project: ProjectID, _ phase: PhaseID, _ id: DeliveryGoalID, _ db: SQLiteConnection
    ) throws -> DeliveryGoalRecord {
        try validateID(id.rawValue)
        guard let goal = try loadGoal(projectID: project, goalID: id, connection: db) else {
            throw DeliveryPlanningPolicyError.goalNotFound(id)
        }
        guard identityKey(goal.phaseID.rawValue) == identityKey(phase.rawValue) else {
            throw DeliveryPlanningPolicyError.goalPhaseMismatch(id)
        }
        return goal
    }

    private static func validateDraft(_ goal: DeliveryGoalDraft) throws {
        try validateID(goal.id.rawValue)
        guard goal.sortOrder >= 0, !goal.title.contains("\0"), !goal.outcome.contains("\0"),
            goal.doneCriteria.allSatisfy({ !blank($0) && !$0.contains("\0") })
        else {
            throw invalid("Use a nonnegative sort order and nonblank criteria without NUL characters.")
        }
    }
    private static func requireDistinct(_ ids: [String]) throws {
        try ids.forEach(validateID)
        guard Set(ids.map(identityKey)).count == ids.count else {
            throw invalid("A revision cannot contain duplicate or contradictory operations for the same identity.")
        }
    }
    private static func validateID(_ id: String) throws {
        guard !blank(id), !id.contains("\0") else { throw invalid("Use a nonblank identity without NUL characters.") }
    }
    // SQLite identity columns use BINARY collation, while Swift String equality
    // normalizes canonical Unicode equivalents. Preserve the persisted bytes.
    private static func identityKey(_ value: String) -> Data { Data(value.utf8) }

    private static func identity(_ project: ProjectID, _ phase: PhaseID) -> [SQLiteValue] {
        [.text(project.rawValue), .text(phase.rawValue)]
    }
    private static func blank(_ value: String) -> Bool { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private static func invalid(_ message: String) -> DeliveryPlanningPolicyError { .invalidPlanMutation(message) }
    private static func invalidRow() -> SQLiteError {
        .init(code: 20, message: "Invalid Delivery Goal or phase-plan record")
    }
    private static func text(_ value: SQLiteValue?) -> String? {
        if case .text(let value) = value { return value }
        return nil
    }
    private static func integer(_ value: SQLiteValue?) -> Int64? {
        if case .integer(let value) = value { return value }
        return nil
    }
    private static func requiredText(_ row: [String: SQLiteValue], _ field: String) throws -> String {
        guard let value = text(row[field]) else { throw invalidRow() }
        return value
    }
    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
    private static func operationTimestamp() -> String { formatter().string(from: Date()) }
    private static func date(_ row: [String: SQLiteValue], _ field: String) throws -> Date {
        guard let value = try optionalDate(row, field) else { throw invalidRow() }
        return value
    }
    private static func optionalDate(_ row: [String: SQLiteValue], _ field: String) throws -> Date? {
        guard let value = text(row[field]) else {
            if row[field] == .null { return nil }
            throw invalidRow()
        }
        guard let date = formatter().date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
            throw invalidRow()
        }
        return date
    }
    private static func goalRecord(_ row: [String: SQLiteValue]) throws -> DeliveryGoalRecord {
        guard let lifecycle = DeliveryGoalLifecycle(rawValue: try requiredText(row, "lifecycle")),
            let order = integer(row["sort_order"])
        else { throw invalidRow() }
        return .init(
            id: .init(rawValue: try requiredText(row, "id")),
            projectID: .init(rawValue: try requiredText(row, "project_id")),
            phaseID: .init(rawValue: try requiredText(row, "phase_id")), title: try requiredText(row, "title"),
            outcome: try requiredText(row, "outcome"), lifecycle: lifecycle, sortOrder: Int(order),
            createdAt: try date(row, "created_at"), updatedAt: try date(row, "updated_at"),
            activatedAt: try optionalDate(row, "activated_at"), acceptedAt: try optionalDate(row, "accepted_at"))
    }
}
