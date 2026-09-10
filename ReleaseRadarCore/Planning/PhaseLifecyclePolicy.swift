import CryptoKit
import Foundation

public enum PhaseLifecyclePolicy {
    public static func current(
        projectID: ProjectID,
        phaseID: PhaseID,
        connection: SQLiteConnection
    ) throws -> PhaseLifecycleRecord {
        guard let row = try connection.row(
            "SELECT * FROM phase_lifecycles WHERE project_id=? AND phase_id=?",
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
        ) else { throw PhaseLifecyclePolicyError.notFound(phaseID) }
        return try record(row)
    }

    public static func all(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> [PhaseLifecycleRecord] {
        try connection.rows(
            "SELECT * FROM phase_lifecycles WHERE project_id=? ORDER BY phase_id COLLATE BINARY",
            bindings: [.text(projectID.rawValue)]
        ).map(record)
    }

    public static func history(
        projectID: ProjectID,
        phaseID: PhaseID,
        connection: SQLiteConnection
    ) throws -> [PhaseLifecycleEventRecord] {
        try connection.rows(
            "SELECT * FROM phase_lifecycle_events WHERE project_id=? AND phase_id=? ORDER BY revision",
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
        ).map(event)
    }

    public static func assessCompletion(
        projectID: ProjectID,
        phaseID: PhaseID,
        connection: SQLiteConnection
    ) throws -> PhaseCompletionAssessment {
        _ = try current(projectID: projectID, phaseID: phaseID, connection: connection)
        let goalRows = try connection.rows(
            "SELECT id,lifecycle FROM delivery_goals WHERE project_id=? AND phase_id=? ORDER BY id COLLATE BINARY",
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
        )
        var blockers: [PhaseCompletionBlocker] = []
        var hasDeliveredOutcome = false
        for row in goalRows {
            guard let goalIDText = text(row["id"]),
                  let lifecycleText = text(row["lifecycle"]),
                  let lifecycle = DeliveryGoalLifecycle(rawValue: lifecycleText)
            else { throw PhaseLifecyclePolicyError.invalidStoredLifecycle }
            let goalID = DeliveryGoalID(rawValue: goalIDText)
            let coverage = try DeliveryGoalCoveragePolicy.assess(
                projectID: projectID,
                phaseID: phaseID,
                goalID: goalID,
                connection: connection
            )
            hasDeliveredOutcome = hasDeliveredOutcome || coverage.hasDeliveredOutcome
            if lifecycle == .superseded {
                if !coverage.obligations.isEmpty, !coverage.isResolved {
                    blockers.append(.init(
                        kind: .goalCoverageUnresolved,
                        entityID: goalIDText,
                        message: "Reconcile every retained obligation for superseded goal \(goalIDText)."
                    ))
                }
                continue
            }
            // Explicitly dropped obligations are resolved removed scope. They do
            // not require accepting a goal whose outcome is no longer part of
            // delivery; phase-level nonvacuity still requires another delivered
            // outcome before completion can succeed.
            if coverage.isResolved, !coverage.hasDeliveredOutcome {
                continue
            }
            if lifecycle != .accepted {
                blockers.append(.init(
                    kind: .goalNotAccepted,
                    entityID: goalIDText,
                    message: "Accept Delivery Goal \(goalIDText) before completing this phase."
                ))
            }
            if !coverage.isAcceptanceEligible {
                blockers.append(.init(
                    kind: .goalCoverageUnresolved,
                    entityID: goalIDText,
                    message: "Resolve the retained coverage obligations for Delivery Goal \(goalIDText)."
                ))
            }
        }

        let ticketRows = try connection.rows(
            """
            SELECT tickets.id,tickets.lane
            FROM tickets
            LEFT JOIN ticket_retirements
              ON ticket_retirements.project_id=tickets.project_id
             AND ticket_retirements.ticket_id=tickets.id
            WHERE tickets.project_id=? AND tickets.phase_id=?
              AND ticket_retirements.ticket_id IS NULL
            ORDER BY tickets.id COLLATE BINARY
            """,
            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
        )
        for row in ticketRows {
            guard let ticketID = text(row["id"]), let lane = text(row["lane"]) else {
                throw PhaseLifecyclePolicyError.invalidStoredLifecycle
            }
            if lane != TicketLane.accepted.rawValue {
                blockers.append(.init(
                    kind: .ticketNotAccepted,
                    entityID: ticketID,
                    message: "Move ticket \(ticketID) to Accepted before completing this phase."
                ))
            }
        }
        if goalRows.isEmpty,
           ticketRows.contains(where: { text($0["lane"]) == TicketLane.accepted.rawValue }) {
            hasDeliveredOutcome = true
        }
        if !hasDeliveredOutcome {
            blockers.append(.init(
                kind: .noDeliveredOutcome,
                entityID: nil,
                message: "Record at least one actually delivered outcome before completing this phase."
            ))
        }
        return .init(
            phaseID: phaseID,
            planningBaselineDigest: try completionBaselineDigest(
                projectID: projectID,
                phaseID: phaseID,
                connection: connection
            ),
            blockers: blockers
        )
    }

    public static func transition(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        action: PhaseLifecycleAction,
        planningBaselineDigest: String?,
        reason: String,
        registration: ProjectRegistration?,
        origin: AgentCommandOrigin,
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws -> PhaseLifecycleRecord {
        guard case .ownerApp = origin else {
            throw PhaseLifecyclePolicyError.ownerAuthorityRequired
        }
        guard let registration,
              registration.projectID == projectID
        else { throw PhaseLifecyclePolicyError.registrationRequired }
        let existing = try current(projectID: projectID, phaseID: phaseID, connection: connection)
        guard existing.revision == expectedRevision else {
            throw PhaseLifecyclePolicyError.revisionConflict(
                expected: expectedRevision,
                current: existing.revision
            )
        }
        guard transitionIsValid(from: existing.lifecycle, action: action) else {
            throw PhaseLifecyclePolicyError.invalidTransition(from: existing.lifecycle, action: action)
        }

        var completionDigest: String?
        if action == .complete {
            guard let planningBaselineDigest else {
                throw PhaseLifecyclePolicyError.planningBaselineRequired
            }
            let assessment = try assessCompletion(
                projectID: projectID,
                phaseID: phaseID,
                connection: connection
            )
            guard assessment.planningBaselineDigest == planningBaselineDigest else {
                throw PhaseLifecyclePolicyError.planningBaselineConflict
            }
            guard assessment.blockers.isEmpty else {
                throw PhaseLifecyclePolicyError.completionBlocked(assessment.blockers)
            }
            completionDigest = planningBaselineDigest
        } else if planningBaselineDigest != nil {
            throw PhaseLifecyclePolicyError.planningBaselineConflict
        }

        let nextRevision = existing.revision + 1
        guard nextRevision > existing.revision else {
            throw PhaseLifecyclePolicyError.invalidStoredLifecycle
        }
        let timestamp = operationTimestamp()
        let next = action.intendedLifecycle
        try connection.execute(
            """
            UPDATE phase_lifecycles
            SET lifecycle=?,revision=?,completion_baseline_digest=?,updated_at=?,completed_at=?
            WHERE project_id=? AND phase_id=? AND revision=?
            """,
            bindings: [
                .text(next.rawValue), .integer(nextRevision),
                completionDigest.map(SQLiteValue.text) ?? .null,
                .text(timestamp), next == .completed ? .text(timestamp) : .null,
                .text(projectID.rawValue), .text(phaseID.rawValue), .integer(expectedRevision),
            ]
        )
        try connection.execute(
            """
            INSERT INTO phase_lifecycle_events (
                project_id,phase_id,revision,previous_lifecycle,current_lifecycle,
                action,reason,audit_event_id,registration_id,request_generation,
                planning_baseline_digest,created_at
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            bindings: [
                .text(projectID.rawValue), .text(phaseID.rawValue), .integer(nextRevision),
                .text(existing.lifecycle.rawValue), .text(next.rawValue), .text(action.rawValue),
                .text(reason), .text(auditEventID.rawValue), .text(registration.registrationID),
                .integer(registration.requestGeneration),
                completionDigest.map(SQLiteValue.text) ?? .null, .text(timestamp),
            ]
        )
        return try current(projectID: projectID, phaseID: phaseID, connection: connection)
    }

    public static func requireOpen(
        projectID: ProjectID,
        phaseID: PhaseID,
        connection: SQLiteConnection
    ) throws {
        if try current(projectID: projectID, phaseID: phaseID, connection: connection).lifecycle == .completed {
            throw PhaseLifecyclePolicyError.completedPhaseReadOnly(phaseID)
        }
    }

    public static func requireTicketPhaseOpen(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws {
        guard let phaseID = try connection.scalarText(
            "SELECT phase_id FROM tickets WHERE project_id=? AND id=?",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ) else { return }
        try requireOpen(
            projectID: projectID,
            phaseID: .init(rawValue: phaseID),
            connection: connection
        )
    }

    private static func transitionIsValid(
        from lifecycle: PhaseLifecycle,
        action: PhaseLifecycleAction
    ) -> Bool {
        switch action {
        case .moveToUpcoming:
            lifecycle == .unassessed || lifecycle == .inDelivery
        case .beginDelivery:
            lifecycle == .unassessed || lifecycle == .upcoming
        case .complete:
            lifecycle != .completed
        case .reopenInDelivery, .reopenUpcoming:
            lifecycle == .completed
        }
    }

    private struct BaselineSection: Codable {
        let name: String
        let rows: [[String]]
    }

    private static func completionBaselineDigest(
        projectID: ProjectID,
        phaseID: PhaseID,
        connection: SQLiteConnection
    ) throws -> String {
        let project = SQLiteValue.text(projectID.rawValue)
        let phase = SQLiteValue.text(phaseID.rawValue)
        // Completion depends on the selected phase's plan/goals and ticket
        // work, plus the project-scoped obligation graph because carried
        // descendants may be delivered in another phase. Browsing context,
        // active-phase selection, and lifecycle history are intentionally not
        // completion inputs.
        let phaseQueries: [(String, String, [SQLiteValue])] = [
            ("phase", "SELECT id,project_id,name FROM phases WHERE project_id=? AND id=?", [project, phase]),
            ("phase_plan", "SELECT * FROM phase_plans WHERE project_id=? AND phase_id=?", [project, phase]),
            ("goals", "SELECT * FROM delivery_goals WHERE project_id=? AND phase_id=? ORDER BY id COLLATE BINARY", [project, phase]),
            ("goal_criteria", "SELECT * FROM delivery_goal_done_criteria WHERE project_id=? AND phase_id=? ORDER BY goal_id COLLATE BINARY,sort_order", [project, phase]),
            ("goal_assignments", "SELECT * FROM delivery_goal_ticket_assignments WHERE project_id=? AND phase_id=? ORDER BY ticket_id COLLATE BINARY", [project, phase]),
        ]
        var sections = try phaseQueries.map { name, sql, bindings in
            BaselineSection(
                name: name,
                rows: baselineRows(try connection.rows(sql, bindings: bindings, maximum: 20_000))
            )
        }

        let obligationRows = try connection.rows(
            "SELECT * FROM delivery_goal_obligations WHERE project_id=? ORDER BY phase_id COLLATE BINARY,goal_id COLLATE BINARY,ticket_id COLLATE BINARY",
            bindings: [project], maximum: 20_000
        )
        let lineageRows = try connection.rows(
            "SELECT * FROM delivery_goal_obligation_lineage WHERE project_id=? ORDER BY source_phase_id COLLATE BINARY,source_goal_id COLLATE BINARY,source_ticket_id COLLATE BINARY,descendant_phase_id COLLATE BINARY,descendant_goal_id COLLATE BINARY,descendant_ticket_id COLLATE BINARY",
            bindings: [project], maximum: 20_000
        )
        let obligationKey: ([String: SQLiteValue], String) -> String? = { row, prefix in
            guard let phase = text(row["\(prefix)phase_id"]),
                  let goal = text(row["\(prefix)goal_id"]),
                  let ticket = text(row["\(prefix)ticket_id"])
            else { return nil }
            return "\(phase)\u{1F}\(goal)\u{1F}\(ticket)"
        }
        var descendants: [String: [String]] = [:]
        for row in lineageRows {
            guard let source = obligationKey(row, "source_"),
                  let descendant = obligationKey(row, "descendant_")
            else { throw PhaseLifecyclePolicyError.invalidStoredLifecycle }
            descendants[source, default: []].append(descendant)
        }
        let roots = obligationRows.compactMap { row -> String? in
            guard text(row["phase_id"]) == phaseID.rawValue else { return nil }
            return obligationKey(row, "")
        }
        var relevantObligations = Set(roots)
        var pending = roots
        while let source = pending.popLast() {
            for descendant in descendants[source] ?? []
                where relevantObligations.insert(descendant).inserted {
                pending.append(descendant)
            }
        }
        let relevantObligationRows = try obligationRows.filter { row in
            guard let rowKey = obligationKey(row, "") else {
                throw PhaseLifecyclePolicyError.invalidStoredLifecycle
            }
            return relevantObligations.contains(rowKey)
        }
        let relevantLineageRows = try lineageRows.filter { row in
            guard let source = obligationKey(row, "source_"),
                  let descendant = obligationKey(row, "descendant_")
            else { throw PhaseLifecyclePolicyError.invalidStoredLifecycle }
            return relevantObligations.contains(source) && relevantObligations.contains(descendant)
        }
        let dropRows = try connection.rows(
            "SELECT * FROM delivery_goal_obligation_drops WHERE project_id=? ORDER BY phase_id COLLATE BINARY,goal_id COLLATE BINARY,ticket_id COLLATE BINARY",
            bindings: [project], maximum: 20_000
        )
        let relevantDropRows = try dropRows.filter { row in
            guard let rowKey = obligationKey(row, "") else {
                throw PhaseLifecyclePolicyError.invalidStoredLifecycle
            }
            return relevantObligations.contains(rowKey)
        }
        var relevantTicketIDs = Set(relevantObligationRows.compactMap { text($0["ticket_id"]) })
        let ticketRows = try connection.rows(
            "SELECT * FROM tickets WHERE project_id=? ORDER BY id COLLATE BINARY",
            bindings: [project], maximum: 20_000
        )
        for row in ticketRows where text(row["phase_id"]) == phaseID.rawValue {
            if let ticketID = text(row["id"]) { relevantTicketIDs.insert(ticketID) }
        }
        let relevantTicketRows = ticketRows.filter {
            text($0["id"]).map(relevantTicketIDs.contains) ?? false
        }
        let retirementRows = try connection.rows(
            "SELECT * FROM ticket_retirements WHERE project_id=? ORDER BY ticket_id COLLATE BINARY",
            bindings: [project], maximum: 20_000
        ).filter {
            text($0["ticket_id"]).map(relevantTicketIDs.contains) ?? false
        }
        sections.append(contentsOf: [
            .init(name: "goal_obligations", rows: baselineRows(relevantObligationRows)),
            .init(name: "goal_obligation_lineage", rows: baselineRows(relevantLineageRows)),
            .init(name: "goal_obligation_drops", rows: baselineRows(relevantDropRows)),
            .init(name: "tickets", rows: baselineRows(relevantTicketRows)),
            .init(name: "ticket_retirements", rows: baselineRows(retirementRows)),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(sections)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func baselineRows(_ rows: [[String: SQLiteValue]]) -> [[String]] {
        rows.map { row in
            row.keys.sorted().map { key in
                "\(key)=\(encodeBaselineValue(row[key] ?? .null))"
            }
        }
    }

    private static func encodeBaselineValue(_ value: SQLiteValue) -> String {
        switch value {
        case .null: "n"
        case let .integer(value): "i:\(value)"
        case let .real(value): "r:\(value.bitPattern)"
        case let .text(value): "t:\(Data(value.utf8).base64EncodedString())"
        case let .blob(value): "b:\(value.base64EncodedString())"
        }
    }

    private static func record(_ row: [String: SQLiteValue]) throws -> PhaseLifecycleRecord {
        guard let projectID = text(row["project_id"]),
              let phaseID = text(row["phase_id"]),
              let lifecycleText = text(row["lifecycle"]),
              let lifecycle = PhaseLifecycle(rawValue: lifecycleText),
              case let .integer(revision)? = row["revision"],
              let createdAt = date(row["created_at"]),
              let updatedAt = date(row["updated_at"])
        else { throw PhaseLifecyclePolicyError.invalidStoredLifecycle }
        return .init(
            projectID: .init(rawValue: projectID),
            phaseID: .init(rawValue: phaseID),
            lifecycle: lifecycle,
            revision: revision,
            completionBaselineDigest: text(row["completion_baseline_digest"]),
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: date(row["completed_at"])
        )
    }

    private static func event(_ row: [String: SQLiteValue]) throws -> PhaseLifecycleEventRecord {
        guard let projectID = text(row["project_id"]),
              let phaseID = text(row["phase_id"]),
              case let .integer(revision)? = row["revision"],
              let previousText = text(row["previous_lifecycle"]),
              let previous = PhaseLifecycle(rawValue: previousText),
              let currentText = text(row["current_lifecycle"]),
              let current = PhaseLifecycle(rawValue: currentText),
              let actionText = text(row["action"]),
              let action = PhaseLifecycleAction(rawValue: actionText),
              let reason = text(row["reason"]),
              let auditEventID = text(row["audit_event_id"]),
              let registrationID = text(row["registration_id"]),
              case let .integer(requestGeneration)? = row["request_generation"],
              let createdAt = date(row["created_at"])
        else { throw PhaseLifecyclePolicyError.invalidStoredLifecycle }
        return .init(
            projectID: .init(rawValue: projectID), phaseID: .init(rawValue: phaseID),
            revision: revision, previousLifecycle: previous, currentLifecycle: current,
            action: action, reason: reason, auditEventID: .init(rawValue: auditEventID),
            registration: .init(
                projectID: .init(rawValue: projectID),
                registrationID: registrationID,
                requestGeneration: requestGeneration
            ),
            planningBaselineDigest: text(row["planning_baseline_digest"]),
            createdAt: createdAt
        )
    }

    private static func text(_ value: SQLiteValue?) -> String? {
        guard case let .text(value)? = value else { return nil }
        return value
    }

    private static func date(_ value: SQLiteValue?) -> Date? {
        guard let value = text(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func operationTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
